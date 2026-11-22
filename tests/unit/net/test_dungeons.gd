extends GutTest
## Instanced dungeons with a difficulty chosen at the door (Plan 8.1).

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var a_key: String


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.add_transport(host_t)
	a_key = host.zones.open("zone_a")


func _guest(name: String) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}), true)
	host.tick()
	var id := host.player_count()
	host.transfer(id, a_key, Vector3(10.5, 0, 10.5))
	host.state_of(id).progress.level = 20
	_messages(c)
	return c


func _messages(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func _of(msgs: Array, type: int) -> Array:
	return msgs.filter(func(m: Dictionary) -> bool: return m.type == type)


func _at_door(id: int) -> void:
	host.state_of(id).position = Vector3(10.5, 0, 25.5)


func test_instanced_exit_offers_level_range() -> void:
	var c := _guest("Ana")
	_at_door(1)
	host.tick()
	host.tick()
	var offers := _of(_messages(c), Protocol.Msg.DUNGEON_OFFER)
	assert_eq(offers.size(), 1, "offered once while standing there")
	assert_eq([offers[0].zone, offers[0].min_level, offers[0].max_level, offers[0].default_level], ["dungeon_t", 15, 30, 20])
	assert_eq(host.world_of(1), host.zones.world(a_key), "not moved until the player enters")


func test_offer_clamped_to_balance() -> void:
	var c := _guest("Ana")
	host.state_of(1).progress.level = 2
	_at_door(1)
	host.tick()
	var offer: Dictionary = _of(_messages(c), Protocol.Msg.DUNGEON_OFFER)[0]
	assert_eq(offer.min_level, int(host.balance.monster_scaling.get("arena_min", 1)))


func test_enter_creates_instance_at_level() -> void:
	var c := _guest("Ana")
	_at_door(1)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 25), true)
	host.tick()
	host.tick()
	var w := host.world_of(1)
	assert_eq(w.instance_level, 25)
	assert_true(host.zones.is_instance(host._players[1].zone_key))
	for m: MonsterState in w.monsters.values():
		assert_eq(m.level, 25)
	assert_eq(_of(_messages(c), Protocol.Msg.ZONE).back().level, 25)


func test_enter_out_of_range_or_away_is_refused() -> void:
	var c := _guest("Ana")
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 25), true)
	host.tick()
	assert_eq(host.world_of(1), host.zones.world(a_key), "not at the door")
	_at_door(1)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 99), true)
	host.tick()
	assert_eq(host.world_of(1).instance_level, 30, "clamped to the offered range")


func test_partner_joins_existing_instance_even_with_other_level() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_at_door(1)
	host.tick()
	a.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 22), true)
	host.tick()
	_at_door(2)
	host.tick()
	b.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 30), true)
	host.tick()
	assert_eq(host.world_of(2), host.world_of(1))
	assert_eq(host.world_of(2).instance_level, 22)


func test_death_in_dungeon_respawns_at_its_entry() -> void:
	var c := _guest("Ana")
	_at_door(1)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("dungeon_t", 20), true)
	host.tick()
	assert_eq(host.world_of(1).map.respawn_point(), Vector3(2.5, 0, 3.5))
