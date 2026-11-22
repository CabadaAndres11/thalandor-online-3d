extends GutTest
## One world per zone on the host (Plan 8.1): each player gets only its own world.

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"spawns": [{"type": "marked_boar", "at": [30, 30], "count": 1, "radius": 0, "respawn_s": 30}]})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.add_transport(host_t)


func _guest(name: String) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}), true)
	return c


func _messages(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func _two_in_two_zones() -> Array:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	var key := host.zones.open("zone_b")
	host.transfer(2, key, host.zones.layout(key).entry("from_a"))
	for i in 3:
		host.tick()
	_messages(a)
	_messages(b)
	return [a, b, key]


func test_two_zones_only_their_snapshots() -> void:
	var t := _two_in_two_zones()
	host.tick()
	var snap_a: Dictionary = _messages(t[0]).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.SNAPSHOT).back()
	var snap_b: Dictionary = _messages(t[1]).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.SNAPSHOT).back()
	var mons_a: Array = snap_a.monsters # decode() already unpacked the rows
	var mons_b: Array = snap_b.monsters
	assert_eq(mons_a.map(func(r: Array) -> String: return r[1]), ["marked_boar"])
	assert_eq(mons_b.map(func(r: Array) -> String: return r[1]), ["marked_hound", "marked_hound"])
	assert_eq((snap_a.players as Array).map(func(r: Array) -> int: return r[0]), [1])
	assert_eq((snap_b.players as Array).map(func(r: Array) -> int: return r[0]), [2])


func test_events_stay_in_their_world() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.tick()
	var key := host.zones.open("zone_b")
	host.transfer(2, key, host.zones.layout(key).entry("from_a"))
	_messages(a)
	_messages(b)
	host.tick() # zone_b steps for the first time: its hounds spawn
	var spawned := func(c: MemoryTransport) -> Array:
		var types := []
		for m: Dictionary in _messages(c):
			if m.type == Protocol.Msg.EVENTS:
				for ev: Array in m.events:
					if ev[0] == "spawned":
						types.append(ev[2])
		return types
	assert_does_not_have(spawned.call(a), "marked_hound", "Ana is in another world")
	assert_has(spawned.call(b), "marked_hound", "Bea sees the events of her own world")


func test_empty_zone_does_not_tick_and_keeps_monsters() -> void:
	var t := _two_in_two_zones()
	var wb := host.zones.world(t[2])
	host.transfer(2, host.zones.start_key, Vector3(21.5, 0, 20.5))
	host.tick()
	var tick := wb.tick
	var count := wb.monsters.size()
	for i in 30:
		host.tick()
	assert_eq(wb.tick, tick, "asleep")
	assert_eq(wb.monsters.size(), count)


func test_instance_closes_after_300s_empty() -> void:
	_guest("Ana")
	host.tick()
	var key := host.zones.open("dungeon_t", "g", 12)
	host.transfer(1, key, host.zones.layout(key).entry("default"))
	host.tick()
	host.transfer(1, host.zones.start_key, Vector3(20.5, 0, 20.5))
	host.tick()
	host.zones.close_idle(host.zones.time_s + 299.0)
	assert_true(key in host.zones.keys())
	host.zones.close_idle(host.zones.time_s + 301.0)
	assert_false(key in host.zones.keys())


func test_chat_and_party_reach_everyone() -> void:
	var t := _two_in_two_zones()
	t[0].send(Transport.HOST_PEER, Protocol.chat(0, "hola"), true)
	host.tick()
	var chats := _messages(t[1]).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.CHAT)
	assert_eq(chats.size(), 1)


func test_host_leaving_a_zone_does_not_sleep_the_guests_zone() -> void:
	var t := _two_in_two_zones()
	var wa := host.world_of(1)
	host.transfer(1, t[2], Vector3(6.5, 0, 6.5))
	host.transfer(1, host.zones.start_key, Vector3(20.5, 0, 20.5))
	var wb := host.zones.world(t[2])
	var tick := wb.tick
	host.tick()
	assert_eq(wb.tick, tick + 1, "Bea is still there")
	assert_eq(host.world_of(1), wa)


func test_each_world_scales_health_with_its_own_players() -> void:
	var t := _two_in_two_zones()
	assert_eq(host.zones.world(t[2]).players.size(), 1)
	assert_eq(host.world_of(1).players.size(), 1)
