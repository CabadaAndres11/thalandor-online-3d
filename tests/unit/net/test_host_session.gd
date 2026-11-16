extends GutTest

const VERSION := "0.1.0"

var balance: Balance
var map: CollisionMap
var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	balance = Balance.load_from()
	map = CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(balance, map, VERSION)
	host.add_transport(host_t)


## A raw guest: returns the client transport after sending HELLO.
func _guest(name: String, version := VERSION, protocol := Protocol.VERSION, class_id := "warrior", appearance := {}) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(version, protocol, name, class_id, appearance), true)
	return c


func _messages(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func _first(c: MemoryTransport, type: int) -> Dictionary:
	for m: Dictionary in _messages(c):
		if m.get("type") == type:
			return m
	return {}


func _all_of(msgs: Array, type: int) -> Array:
	return msgs.filter(func(m: Dictionary) -> bool: return m.get("type") == type)


func test_hello_gets_welcome_with_roster() -> void:
	var a := _guest("Ana")
	host.tick()
	var w := _first(a, Protocol.Msg.WELCOME)
	assert_eq(w.player_id, 1)
	assert_eq(w.roster.map(_head3), [[1, "Ana", 0]])
	var b := _guest("Bea")
	host.tick()
	var w2 := _first(b, Protocol.Msg.WELCOME)
	assert_eq(w2.roster.map(_head3), [[1, "Ana", 0], [2, "Bea", 1]])
	var joined := _first(a, Protocol.Msg.PLAYER_JOINED)
	assert_eq([joined.id, joined.name, joined.slot], [2, "Bea", 1])
	assert_eq(host.player_count(), 2)


func test_rejects_other_game_version() -> void:
	var a := _guest("Ana", "0.0.9")
	host.tick()
	var r := _first(a, Protocol.Msg.REJECT)
	assert_eq(r.reason, "version")
	assert_eq(r.host_version, VERSION)
	assert_eq(host.player_count(), 0)


func test_rejects_other_protocol() -> void:
	var a := _guest("Ana", VERSION, Protocol.VERSION + 1)
	host.tick()
	assert_eq(_first(a, Protocol.Msg.REJECT).reason, "version")


func test_rejects_fifth_player() -> void:
	for n in ["Ana", "Bea", "Cris", "Dani"]:
		_guest(n)
	host.tick()
	var e := _guest("Eva")
	host.tick()
	assert_eq(_first(e, Protocol.Msg.REJECT).reason, "full")
	assert_eq(host.player_count(), 4)


func test_rejects_invalid_name() -> void:
	for bad in ["A", "Abcdefghijklmnopq", "<b>", "   ", "Ana\tBea"]:
		var c := _guest(bad)
		host.tick()
		assert_eq(_first(c, Protocol.Msg.REJECT).get("reason"), "name", "should reject %s" % bad)


func test_accepts_accented_names() -> void:
	for good in ["Andrés", "O'Brien", "Ñu-2", "José María"]:
		assert_true(HostSession.is_valid_name(good), good)


func test_inputs_move_player() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2(1, 0), start, 0]]), false)
	host.tick()
	assert_gt(host.world.players[1].position.x, start.x)


## A guest must not be able to put NaN or infinity into the shared simulation.
func test_non_finite_inputs_are_dropped() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	a.send(Transport.HOST_PEER, Protocol.input([
		[1, Vector2(NAN, 0), start, 0],
		[2, Vector2(INF, 1), start, 0],
		[3, Vector2(1, 0), Vector3(NAN, 0, 0), 0],
		[4, Vector2(1, 0), Vector3(0, -INF, 0), 0],
	]), false)
	for i in 6:
		host.tick()
	var s: PlayerState = host.world.players[1]
	assert_true(s.position.is_finite(), "position stays finite")
	assert_true(s.aim.is_finite(), "aim stays finite")
	assert_true(is_finite(s.facing), "facing stays finite")
	assert_eq(s.position, start, "rejected inputs do not move the player")


func test_duplicate_inputs_ignored() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	var i1 := [1, Vector2(1, 0), start, 0]
	a.send(Transport.HOST_PEER, Protocol.input([i1]), false)
	a.send(Transport.HOST_PEER, Protocol.input([i1]), false)
	a.send(Transport.HOST_PEER, Protocol.input([i1]), false)
	host.tick()
	host.tick()
	host.tick()
	var one_step := balance.move_speed * balance.dt()
	# First tick moves once; later ticks repeat the last input (still moving), so
	# measure that seq 1 was consumed exactly once via last_seq.
	assert_eq(host.last_seq(1), 1)
	assert_almost_eq(host.world.players[1].position.x - start.x, one_step * 3, 0.001)


func test_input_queue_is_capped() -> void:
	var a := _guest("Ana")
	host.tick()
	var rows := []
	for s in range(1, 11):
		rows.append([s, Vector2(1, 0), Vector3.ZERO, 0])
	a.send(Transport.HOST_PEER, Protocol.input(rows), false)
	host.tick()
	assert_lte(host.pending_inputs(1), balance.max_pending_inputs)
	assert_eq(host.last_seq(1), 7, "oldest inputs dropped: queue kept 7..10 and consumed 7")


func test_missing_input_repeats_last() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2(0, 1), start, 0]]), false)
	host.tick()
	host.tick()
	var one_step := balance.move_speed * balance.dt()
	assert_almost_eq(host.world.players[1].position.z - start.z, one_step * 2, 0.001)
	assert_eq(host.last_seq(1), 1)


func test_snapshot_reports_last_seq() -> void:
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2.ZERO, Vector3.ZERO, 0], [2, Vector2.ZERO, Vector3.ZERO, 0]]), false)
	host.tick()
	var snap := _first(a, Protocol.Msg.SNAPSHOT)
	assert_eq(snap.players[0][0], 1)
	assert_eq(snap.players[0][4], 1)


func test_chat_is_trimmed_and_relayed() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	_messages(a)
	_messages(b)
	a.send(Transport.HOST_PEER, Protocol.chat(0, "  " + "x".repeat(130) + "  "), true)
	host.tick()
	var got := _first(b, Protocol.Msg.CHAT)
	assert_eq(got.from_id, 1)
	assert_eq(got.text.length(), balance.chat_max_len)
	assert_eq(_first(a, Protocol.Msg.CHAT).from_id, 1, "sender also receives it")


func test_empty_chat_ignored() -> void:
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	a.send(Transport.HOST_PEER, Protocol.chat(0, "   "), true)
	host.tick()
	assert_eq(_first(a, Protocol.Msg.CHAT), {})


func test_chat_before_hello_ignored() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.chat(0, "hola"), true)
	host.tick()
	assert_eq(_first(c, Protocol.Msg.CHAT), {})


func test_disconnect_broadcasts_player_left() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	_messages(a)
	watch_signals(host)
	b.close()
	host.tick()
	assert_eq(_first(a, Protocol.Msg.PLAYER_LEFT).id, 2)
	assert_signal_emitted_with_parameters(host, "player_left", [2])
	assert_false(host.world.players.has(2))


func test_slot_reuse_after_leave() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_guest("Cris")
	host.tick()
	b.close()
	host.tick()
	var d := _guest("Dani")
	host.tick()
	var w := _first(d, Protocol.Msg.WELCOME)
	assert_eq(w.player_id, 4, "ids are never reused")
	assert_true(w.roster.map(_head3).has([4, "Dani", 1]), "free slot 1 reused")


func test_garbage_packet_ignored() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, PackedByteArray([1, 2, 3]), true)
	host.tick()
	assert_eq(host.player_count(), 0)


func _head3(row: Array) -> Array:
	return row.slice(0, 3)


func test_roster_carries_class_and_appearance() -> void:
	var a := _guest("Ana", VERSION, Protocol.VERSION, "mage", {"hair_style": "hair_long"})
	host.tick()
	var row: Array = _first(a, Protocol.Msg.WELCOME).roster[0]
	assert_eq(row[3], "mage")
	assert_eq(row[4].hair_style, "hair_long")
	assert_eq((row[4] as Dictionary).size(), CharacterCatalog.KINDS.size(), "full sanitized appearance")


## A modified or broken guest may send anything: the host cleans it up and lets the
## player in with defaults.
func test_host_sanitizes_invented_appearance() -> void:
	var junk := {"skin": "glowing", "eyes": 3, "hair_style": ["x"]}
	for i in 300:
		junk["extra_%d" % i] = i
	var a := _guest("Ana", VERSION, Protocol.VERSION, "", junk)
	host.tick()
	var w := _first(a, Protocol.Msg.WELCOME)
	assert_eq(w.player_id, 1, "the player gets in")
	var row: Array = w.roster[0]
	var catalog := CharacterCatalog.load_default()
	assert_eq(row[3], CharacterCatalog.DEFAULT_CLASS)
	assert_eq(row[4], catalog.default_appearance())


## A friend still on 0.1.x sends the old 3-field HELLO: they must get the clear
## "different version" rejection (REJECT kept its layout), not a silent timeout.
func test_old_client_hello_gets_version_reject() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.pack([Protocol.Msg.HELLO, "0.1.2", 1, "Ana"]), true)
	host.tick()
	var r := _first(c, Protocol.Msg.REJECT)
	assert_eq(r.get("reason"), "version")
	assert_eq(host.player_count(), 0)


# --- Combat input (Plan 3) -------------------------------------------------------

func _combat_db() -> AbilityDB:
	var hit := [{"type": "area", "at": "self", "radius": 1.0, "delay_s": 0, "telegraph": false,
		"damage": {"base": 1, "coef": 0, "kind": "magic", "can_crit": false}}]
	return AbilityDB.from_list([
		{"id": "w_basic", "class": "warrior", "kind": "basic", "level": 1, "cooldown_s": 0, "effects": hit},
		{"id": "w_a1", "class": "warrior", "kind": "active", "level": 1, "cooldown_s": 0, "effects": hit},
		{"id": "w_a2", "class": "warrior", "kind": "active", "level": 3, "cooldown_s": 0, "effects": hit},
	])


func _casts(c: MemoryTransport) -> Array:
	var out: Array = []
	for m: Dictionary in _messages(c):
		if m.get("type") == Protocol.Msg.EVENTS:
			for ev: Array in m.events:
				if ev[0] == "cast":
					out.append(ev)
	return out


func _row(seq: int, buttons := 0) -> Array:
	return [seq, Vector2.ZERO, Vector3(20, 0, 25), buttons]


## Attention point 1: the client repeats each input in 3 packets; one press, one cast.
func test_press_with_redundancy_casts_once() -> void:
	host.world.abilities = _combat_db()
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	var r1 := _row(1, PlayerInput.BTN_BASIC)
	a.send(Transport.HOST_PEER, Protocol.input([r1]), false)
	a.send(Transport.HOST_PEER, Protocol.input([r1, _row(2)]), false)
	a.send(Transport.HOST_PEER, Protocol.input([r1, _row(2), _row(3)]), false)
	for i in 4:
		host.tick()
	assert_eq(_casts(a).size(), 1)


func test_lost_packet_press_still_casts_once() -> void:
	host.world.abilities = _combat_db()
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	# The packet with only seq 1 is lost; the next one still carries it.
	a.send(Transport.HOST_PEER, Protocol.input([_row(1, PlayerInput.BTN_BASIC), _row(2)]), false)
	for i in 3:
		host.tick()
	assert_eq(_casts(a).size(), 1)


func test_repeated_last_input_does_not_recast() -> void:
	host.world.abilities = _combat_db()
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	a.send(Transport.HOST_PEER, Protocol.input([_row(1, PlayerInput.BTN_BASIC | PlayerInput.BTN_SLOT1)]), false)
	for i in 8: # no more inputs: the host keeps reusing the last one
		host.tick()
	assert_eq(_casts(a).size(), 2, "basic + slot 1, once each")


func test_set_bar_validates_ability_ids_of_class() -> void:
	host.world.abilities = _combat_db()
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Ana", "warrior", {}, ["w_a2", "bogus", "w_a2", 7]), true)
	host.tick()
	assert_eq(host._players[1].bar, ["w_a2", "", "", ""])
	c.send(Transport.HOST_PEER, Protocol.set_bar(["w_a1", "w_a2", "fireball", ""]), true)
	host.tick()
	assert_eq(host._players[1].bar, ["w_a1", "w_a2", "", ""])


func test_events_reach_all_clients_in_order() -> void:
	host.world.abilities = _combat_db()
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	_messages(a)
	_messages(b)
	a.send(Transport.HOST_PEER, Protocol.input([_row(1, PlayerInput.BTN_BASIC)]), false)
	host.tick()
	var seen_a := _casts(a)
	var seen_b := _casts(b)
	assert_eq(seen_a.size(), 1)
	assert_eq(seen_a, seen_b)


## A friend still on 0.2.x sends the protocol 2 HELLO (no bar): "different version".
func test_protocol2_hello_gets_version_reject() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.pack([Protocol.Msg.HELLO, "0.2.1", 2, "Ana", "mage", {}]), true)
	host.tick()
	assert_eq(_first(c, Protocol.Msg.REJECT).get("reason"), "version")


func test_player_gets_class_stats_on_join() -> void:
	_guest("Ana", VERSION, Protocol.VERSION, "warrior")
	host.tick()
	var p: PlayerState = host.world.players[1]
	assert_eq(p.class_id, "warrior")
	assert_eq(p.stats.max_hp, 200.0)
	assert_eq(p.resource_kind, "rage")


## Archer: holding the basic button charges, releasing fires once (and costs focus
## when charged); a quick tap fires a free shot.
func test_archer_hold_and_release_fires_charged_shot() -> void:
	var a := _guest("Ana", VERSION, Protocol.VERSION, "archer")
	host.tick()
	_messages(a)
	var p: PlayerState = host.world.players[1]
	p.resource_def["regen_per_s"] = 0.0
	var focus := p.resource
	var held := PlayerInput.BTN_BASIC_HELD
	a.send(Transport.HOST_PEER, Protocol.input([_row(1, PlayerInput.BTN_BASIC | held)]), false)
	host.tick()
	for s in range(2, 47):
		a.send(Transport.HOST_PEER, Protocol.input([_row(s, held)]), false)
		host.tick()
		assert_eq(_casts(a).size(), 0, "nothing while holding (seq %d)" % s)
	a.send(Transport.HOST_PEER, Protocol.input([_row(47)]), false)
	host.tick()
	assert_eq(_casts(a).size(), 1, "fires on release")
	assert_eq(p.resource, focus - 15.0, "a full charge costs focus")
	host.world.tick += 30
	a.send(Transport.HOST_PEER, Protocol.input([_row(48, PlayerInput.BTN_BASIC | held)]), false)
	host.tick()
	a.send(Transport.HOST_PEER, Protocol.input([_row(49)]), false)
	host.tick()
	assert_eq(_casts(a).size(), 1, "a tap fires once more")
	assert_eq(p.resource, focus - 15.0, "the tap is free")


## Each player gets the nearest max_monsters_per_snapshot monsters (Plan 3, point 4).
func test_snapshot_limits_to_nearest_32_monsters() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	host.world.players[1].position = Vector3(2, 0, 2)
	host.world.players[2].position = Vector3(38, 0, 38)
	var db := MonsterDB.load_default()
	for i in 40:
		var m := db.make("marked_hound", host.world.next_monster_id(), Vector3(1 + i * 0.9, 0, 1 + i * 0.9), host.world)
		m.elite = i == 0
		host.world.add_entity(m)
	_messages(a)
	_messages(b)
	host.tick()
	for pair: Array in [[a, Vector3(2, 0, 2)], [b, Vector3(38, 0, 38)]]:
		var snaps := _all_of(_messages(pair[0]), Protocol.Msg.SNAPSHOT)
		assert_false(snaps.is_empty())
		var rows: Array = snaps[-1].monsters
		assert_eq(rows.size(), balance.max_monsters_per_snapshot)
		var pos: Vector3 = pair[1]
		var dists := host.world.monsters.values().map(func(m: CombatEntity) -> float:
			return Effects.flat(m.position).distance_to(Effects.flat(pos)))
		dists.sort()
		var limit: float = dists[balance.max_monsters_per_snapshot - 1]
		for row: Array in rows:
			assert_lte(Effects.flat(row[2]).distance_to(Effects.flat(pos)), limit + 0.001, "only the nearest")
	_messages(a)
	host.tick()
	var rows_a: Array = _all_of(_messages(a), Protocol.Msg.SNAPSHOT)[-1].monsters
	var elite_row: Array = rows_a.filter(func(r: Array) -> bool: return int(r[0]) == 1000)[0]
	assert_eq(int(elite_row[8]), 1, "the elite flag travels in the row")
