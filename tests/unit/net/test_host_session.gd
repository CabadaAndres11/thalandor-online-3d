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
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2(1, 0), start]]), false)
	host.tick()
	assert_gt(host.world.players[1].position.x, start.x)


## A guest must not be able to put NaN or infinity into the shared simulation.
func test_non_finite_inputs_are_dropped() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	a.send(Transport.HOST_PEER, Protocol.input([
		[1, Vector2(NAN, 0), start],
		[2, Vector2(INF, 1), start],
		[3, Vector2(1, 0), Vector3(NAN, 0, 0)],
		[4, Vector2(1, 0), Vector3(0, -INF, 0)],
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
	var i1 := [1, Vector2(1, 0), start]
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
		rows.append([s, Vector2(1, 0), Vector3.ZERO])
	a.send(Transport.HOST_PEER, Protocol.input(rows), false)
	host.tick()
	assert_lte(host.pending_inputs(1), balance.max_pending_inputs)
	assert_eq(host.last_seq(1), 7, "oldest inputs dropped: queue kept 7..10 and consumed 7")


func test_missing_input_repeats_last() -> void:
	var a := _guest("Ana")
	host.tick()
	var start: Vector3 = host.world.players[1].position
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2(0, 1), start]]), false)
	host.tick()
	host.tick()
	var one_step := balance.move_speed * balance.dt()
	assert_almost_eq(host.world.players[1].position.z - start.z, one_step * 2, 0.001)
	assert_eq(host.last_seq(1), 1)


func test_snapshot_reports_last_seq() -> void:
	var a := _guest("Ana")
	host.tick()
	_messages(a)
	a.send(Transport.HOST_PEER, Protocol.input([[1, Vector2.ZERO, Vector3.ZERO], [2, Vector2.ZERO, Vector3.ZERO]]), false)
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
