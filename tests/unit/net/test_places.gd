extends GutTest
## Characters remember their zone and position (Plan 8.1).

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [[3, 3, 1]]})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.fallback_zone = "zone_a"
	host.add_transport(host_t)


func _guest(place: Dictionary) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Ana", "warrior", {}, [], {}, {}, place), true)
	host.tick()
	return c


func _messages(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func test_appears_where_it_was_saved() -> void:
	_guest({"zone": "zone_b", "at": [12, 14]})
	assert_eq(host.world_of(1), host.zones.world("zone_b"))
	assert_almost_eq(host.state_of(1).position, Vector3(12.5, 0, 14.5), Vector3.ONE * 0.01)


func test_unknown_zone_place_goes_to_the_fallback() -> void:
	_guest({"zone": "atlantis", "at": [12, 14]})
	assert_eq(host.world_of(1), host.zones.world("zone_a"))
	assert_almost_eq(host.state_of(1).position, Vector3(5.5, 0, 5.5), Vector3.ONE * 0.01)


func test_saved_inside_dungeon_returns_to_the_fallback() -> void:
	_guest({"zone": "dungeon_t", "at": [2, 2]})
	assert_eq(host.world_of(1), host.zones.world("zone_a"))


func test_solid_or_empty_place_goes_to_default_entry() -> void:
	_guest({"zone": "zone_b", "at": [-4, 900]})
	assert_almost_eq(host.state_of(1).position, Vector3(5.5, 0, 5.5), Vector3.ONE * 0.01)


func test_empty_place_keeps_the_host_start() -> void:
	_guest({})
	assert_eq(host.world_of(1), host.world)


func test_place_sent_on_zone_change_and_every_30s() -> void:
	var c := _guest({"zone": "zone_b", "at": [12, 14]})
	_messages(c)
	host.send_to_zone(1, host.zones.open("zone_a"), Vector3(6.5, 0, 6.5))
	host.tick()
	var places := _messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.PLACE)
	assert_eq(places.size(), 1)
	assert_eq([places[0].zone, places[0].at], ["zone_a", [6, 6]])
	for i in host.world.ticks(30.1):
		host.tick()
	assert_gt(_messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.PLACE).size(), 0)


func test_place_inside_a_dungeon_is_outside() -> void:
	var c := _guest({"zone": "zone_a", "at": [10, 10]})
	host.state_of(1).progress.level = 10
	host.state_of(1).position = Vector3(10.5, 0, 25.5)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 10), true)
	host.tick()
	host.tick()
	var places := _messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.PLACE)
	assert_eq(places.back().zone, "zone_a")
	assert_eq(places.back().at, [5, 5], "the entry outside (no way back declared: the default one)")


func test_host_rejects_guest_without_tutorial() -> void:
	_guest({"zone": "zone_b", "at": [12, 14], "tutorial_done": true}) # the host's own player
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Bea", "warrior", {}, [], {}, {}, {"zone": "zone_b", "at": [], "tutorial_done": false}), true)
	host.tick()
	var rejects := _messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.REJECT)
	assert_eq(rejects.size(), 1)
	assert_eq(rejects[0].reason, "tutorial")
	assert_eq(host.player_count(), 1)


# --- Final review fixes ----------------------------------------------------------------

func test_joining_outside_the_start_zone_tells_the_client() -> void:
	var c := _guest({"zone": "zone_b", "at": [12, 14]})
	var zones := _messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.ZONE)
	assert_eq(zones.size(), 1, "the client draws the zone it is really in")
	assert_eq(zones[0].zone, "zone_b")


func test_joining_in_the_start_zone_sends_no_zone() -> void:
	var c := _guest({})
	assert_eq(_messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.ZONE).size(), 0)


func test_malformed_place_is_sanitized() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Ana", "warrior", {}, [], {}, {}, {"zone": "zone_b", "at": "nope"}), true)
	host.tick()
	assert_eq(host.player_count(), 1, "let in")
	assert_eq(host.world_of(1), host.zones.world("zone_b"))


func test_dungeon_place_is_the_outside_entry_not_the_door() -> void:
	var c := _guest({"zone": "zone_a", "at": [10, 10]})
	host.state_of(1).progress.level = 10
	host.state_of(1).position = Vector3(10.5, 0, 25.5)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 10), true)
	host.tick()
	host.tick()
	var places := _messages(c).filter(func(m: Dictionary) -> bool: return m.type == Protocol.Msg.PLACE)
	var at: Array = places.back().at
	assert_true(host.zones.layout("zone_a").exit_at(Vector3(at[0] + 0.5, 0, at[1] + 0.5)).is_empty(), "not on the exit (no new offer on return)")
