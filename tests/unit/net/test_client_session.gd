extends GutTest

const VERSION := "0.1.0"

var balance: Balance
var map: CollisionMap
var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var clients: Array = []


func before_each() -> void:
	balance = Balance.load_from()
	map = CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(3)
	host_t = net.create_host()
	host = HostSession.new(balance, map, VERSION)
	host.add_transport(host_t)
	clients = []


func _client(name: String, version := VERSION, class_id := "warrior", appearance := {}) -> ClientSession:
	var c := ClientSession.new(balance, map, version, name, class_id, appearance)
	c.connect_to(net.connect_client(host_t))
	clients.append(c)
	return c


## One simulation tick for everyone. `moves` maps ClientSession -> Vector2.
func _step(moves := {}) -> void:
	var dt := balance.dt()
	net.advance(dt * 1000.0)
	for c: ClientSession in clients:
		c.tick(moves.get(c, Vector2.ZERO), Vector3(20.5, 0, 30))
	host.tick()
	for c: ClientSession in clients:
		c.update(dt)


func _steps(n: int, moves := {}) -> void:
	for i in n:
		_step(moves)


func _own_pos(c: ClientSession) -> Vector3:
	return c.render_state(c.my_id).position


func test_welcome_sets_status_and_id() -> void:
	var a := _client("Ana")
	watch_signals(a)
	_steps(2)
	assert_eq(a.status, ClientSession.Status.IN_GAME)
	assert_eq(a.my_id, 1)
	assert_signal_emitted_with_parameters(a, "welcomed", [1])
	assert_eq(a.roster[1].name, "Ana")


func test_rejected_signal_carries_reason() -> void:
	var a := _client("Ana", "0.0.1")
	watch_signals(a)
	_steps(2)
	assert_signal_emitted_with_parameters(a, "rejected", ["version", VERSION])
	assert_eq(a.status, ClientSession.Status.CLOSED)


func test_prediction_moves_immediately() -> void:
	net.latency_ms = 100
	var a := _client("Ana")
	_steps(20)
	var before := _own_pos(a)
	a.tick(Vector2(1, 0), Vector3.ZERO)
	assert_gt(_own_pos(a).x, before.x)


func test_zero_latency_matches_host() -> void:
	var a := _client("Ana")
	_steps(3)
	_steps(30, {a: Vector2(1, 0.5)})
	_steps(2)
	assert_almost_eq(_own_pos(a).distance_to(host.world.players[1].position), 0.0, 0.001)


func test_reconcile_replays_pending() -> void:
	net.latency_ms = 100
	var a := _client("Ana")
	_steps(15)
	_steps(30, {a: Vector2(1, 0)})
	_steps(30)
	assert_almost_eq(_own_pos(a).distance_to(host.world.players[1].position), 0.0, 0.001)
	assert_gt(host.world.players[1].position.x, 22.0)
	# Only inputs still in flight (~200 ms round trip = 6-7 ticks) remain pending.
	assert_lte(a.pending_count(), 8)


func test_small_error_is_smoothed() -> void:
	var a := _client("Ana")
	_steps(5)
	var before := _own_pos(a)
	host.world.players[1].position.x += 0.5
	_steps(2)
	assert_almost_eq(a.last_correction, 0.5, 0.01)
	assert_lt(_own_pos(a).distance_to(before), 0.5)
	assert_gt(_own_pos(a).distance_to(before), 0.0)
	a.update(0.1)
	assert_almost_eq(_own_pos(a).distance_to(host.world.players[1].position), 0.0, 0.001)


func test_large_error_snaps() -> void:
	var a := _client("Ana")
	_steps(5)
	host.world.players[1].position.x += 5.0
	_steps(2)
	assert_almost_eq(_own_pos(a).distance_to(host.world.players[1].position), 0.0, 0.001)


func test_others_are_interpolated_between_snapshots() -> void:
	var a := _client("Ana")
	var b := _client("Bea")
	_steps(15)
	var start: Vector3 = host.world.players[2].position
	_steps(30, {b: Vector2(1, 0)})
	var seen: Vector3 = a.render_state(2).position
	var now: Vector3 = host.world.players[2].position
	assert_gt(seen.x, start.x)
	assert_lt(seen.x, now.x, "drawn in the past")
	var delay_m := balance.move_speed * balance.interp_delay_ms / 1000.0
	assert_almost_eq(now.x - seen.x, delay_m, balance.move_speed * 2.0 * balance.dt())


func test_slow_frames_do_not_break_render_clock() -> void:
	var a := _client("Ana")
	_steps(10)
	a.update(2.0)
	var elapsed := 0.0
	while elapsed < 1.0:
		net.advance(100)
		for i in 3:
			a.tick(Vector2.ZERO, Vector3.ZERO)
			host.tick()
		a.update(0.1)
		elapsed += 0.1
	assert_almost_eq(a.render_tick, a.target_render_tick(), 1.0)


func test_timeout_disconnects() -> void:
	var a := _client("Ana")
	_steps(3)
	watch_signals(a)
	for i in 52:
		a.update(0.1)
	assert_signal_emitted_with_parameters(a, "disconnected", ["timeout"])
	assert_eq(a.status, ClientSession.Status.CLOSED)


func test_host_close_disconnects_with_host_left() -> void:
	var a := _client("Ana")
	_steps(3)
	watch_signals(a)
	host.close()
	a.tick(Vector2.ZERO, Vector3.ZERO)
	assert_signal_emitted_with_parameters(a, "disconnected", ["host_left"])


func test_chat_roundtrip() -> void:
	var a := _client("Ana")
	var b := _client("Bea")
	_steps(3)
	watch_signals(b)
	a.send_chat("  ¡hola!  ")
	_steps(2)
	assert_signal_emitted_with_parameters(b, "chat_received", ["Ana", "¡hola!", false])


func test_system_messages_on_join_and_leave() -> void:
	var a := _client("Ana")
	_steps(3)
	watch_signals(a)
	var b := _client("Bea")
	_steps(3)
	var params: Array = get_signal_parameters(a, "chat_received")
	assert_true(String(params[1]).contains("Bea"))
	assert_true(params[2])
	b.leave()
	clients.erase(b)
	_steps(3)
	params = get_signal_parameters(a, "chat_received")
	assert_true(String(params[1]).contains("Bea"))
	assert_false(a.roster.has(2))


func test_player_joined_updates_roster_with_appearance() -> void:
	var a := _client("Ana")
	_steps(2)
	var b := _client("Bea", VERSION, "mage", {"hair_style": "hair_bun"})
	_steps(3)
	assert_eq(a.roster[2].class_id, "mage")
	assert_eq(a.roster[2].appearance.hair_style, "hair_bun")
	assert_eq(b.roster[1].class_id, "warrior", "the welcome roster carries the others too")


func test_dodge_prediction_matches_host() -> void:
	net.latency_ms = 100
	var a := _client("Ana")
	_steps(15)
	var start := _own_pos(a)
	var dt := balance.dt()
	net.advance(dt * 1000.0)
	a.tick(Vector2(1, 0), Vector3(20.5, 0, 30), PlayerInput.BTN_DODGE)
	host.tick()
	a.update(dt)
	var right_after := _own_pos(a)
	var worst := 0.0
	for i in 20:
		_step({a: Vector2(1, 0)})
		worst = maxf(worst, a.last_correction)
	assert_lt(worst, 0.01, "no correction while the dodge plays out")
	_steps(30)
	assert_gt(right_after.x, start.x + 0.2, "the dodge shows at once (predicted)")
	assert_almost_eq(_own_pos(a).distance_to(host.world.players[1].position), 0.0, 0.01)
	assert_lt(a.last_correction, 0.01, "no correction needed")
	assert_gt(host.world.players[1].position.x, start.x + balance.dodge_distance)


# --- Zones (Plan 8.1) ------------------------------------------------------------------

func test_zone_message_swaps_the_prediction_map() -> void:
	var c := ClientSession.new(balance, map, VERSION, "Ana", "warrior", {})
	c.status = ClientSession.Status.IN_GAME
	c.my_id = 1
	c.monsters[9] = {"type": "x"}
	watch_signals(c)
	c._handle(Protocol.decode(Protocol.zone("arena", "arena", 0)))
	assert_eq(c.map.zone_id, "arena")
	assert_eq(c.map.size, Vector2i(48, 48))
	assert_eq(c.zone_id, "arena")
	assert_true(c.zone_loading)
	assert_true(c.monsters.is_empty(), "the old zone's monsters are gone")
	assert_signal_emitted_with_parameters(c, "zone_changed", ["arena", "arena", 0])


func test_first_snapshot_after_a_zone_ends_the_loading() -> void:
	var a := _client("Ana")
	for i in 5:
		_step()
	watch_signals(a)
	a._handle(Protocol.decode(Protocol.zone("arena", "arena", 0)))
	for i in 3:
		_step()
	assert_false(a.zone_loading)
	assert_signal_emitted(a, "zone_ready")


func test_partner_out_of_the_snapshots_is_forgotten() -> void:
	var a := _client("Ana")
	var b := _client("Bea")
	for i in 10:
		_step()
	assert_false(a.render_state(2).is_empty())
	var key := host.zones.open("arena")
	host.transfer(2, key, Vector3(20.5, 0, 20.5))
	for i in 5:
		_step()
	assert_true(a.render_state(2).is_empty(), "Bea is in another zone")
	assert_false(a.combat.has(2))


func test_party_rows_are_kept() -> void:
	var c := ClientSession.new(balance, map, VERSION, "Ana", "warrior", {})
	c._handle(Protocol.decode(Protocol.party([[2, "ZONE_BOSQUE", 12, 0.5]])))
	assert_eq(c.party[2], {"zone": "ZONE_BOSQUE", "level": 12, "hp": 0.5})


func test_a_late_snapshot_of_the_old_zone_is_ignored() -> void:
	var a := _client("Ana")
	for i in 5:
		_step()
	var last := a.latest_tick()
	a._handle(Protocol.decode(Protocol.zone("arena", "arena", 0)))
	a._on_snapshot(last, [], [[1000, "marked_boar", Vector3.ONE, 0.0, 10.0, 10.0, 0, 0, 0, 1]])
	assert_true(a.zone_loading, "still waiting for the new zone")
	assert_true(a.monsters.is_empty())
