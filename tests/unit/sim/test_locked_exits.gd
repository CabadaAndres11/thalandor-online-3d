extends GutTest
## Exits the story opens (Plan 8.3b): the crypt's gate lets through only whoever has its flag.

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var key: String


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.add_transport(host_t)
	key = host.zones.open("zone_gate")


func _player(name: String) -> Array:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}), true)
	host.tick()
	var id := host.player_count()
	host.transfer(id, key, Vector3(10.5, 0, 5.5))
	c.poll()
	return [c, id]


func _locked_events(c: MemoryTransport) -> int:
	var n := 0
	for pk: Dictionary in c.poll():
		var m := Protocol.decode(pk.data)
		if m.type == Protocol.Msg.EVENTS:
			for ev: Array in m.events:
				n += 1 if ev[0] == "exit_locked" else 0
	return n


func test_exit_open_needs_flags() -> void:
	var z := ZoneLayout.load_path(ZONES + "zone_gate.json", ZONES + "pieces.json")
	var log := QuestLog.new()
	assert_false(ZoneLayout.exit_open(z.exits[0], log))
	log.flags.append("reja_abierta")
	assert_true(ZoneLayout.exit_open(z.exits[0], log))
	assert_true(ZoneLayout.exit_open({"to": "x"}, QuestLog.new()), "no requires: always open")


func test_host_refuses_locked_exit() -> void:
	var a: Array = _player("Ana")
	var p := host.state_of(a[1])
	p.position = Vector3(25.5, 0, 5.5)
	host.tick()
	assert_eq(str(host._players[a[1]].zone_key), key, "stays")
	assert_gt(_locked_events(a[0]), 0, "and is told")
	p.quests.flags.append("reja_abierta")
	host.tick()
	assert_ne(str(host._players[a[1]].zone_key), key, "with the flag it goes through")


func test_guest_without_flag_stays() -> void:
	var a: Array = _player("Ana")
	var b: Array = _player("Bea")
	host.state_of(a[1]).quests.flags.append("reja_abierta")
	for pl: Array in [a, b]:
		host.state_of(pl[1]).position = Vector3(25.5, 0, 5.5)
	host.tick()
	assert_ne(str(host._players[a[1]].zone_key), key, "the one with the flag goes")
	assert_eq(str(host._players[b[1]].zone_key), key, "the other stays")


func test_gate_piece_follows_flags() -> void:
	var z := ZoneLayout.load_path(ZONES + "zone_gate.json", ZONES + "pieces.json")
	var view := ZoneView.new()
	add_child_autofree(view)
	view.layout = z
	var log := QuestLog.new()
	view.show_gates(log)
	assert_eq(view.gate_piece(0), "hut", "closed")
	log.flags.append("reja_abierta")
	view.show_gates(log)
	assert_eq(view.gate_piece(0), "tree", "open")
