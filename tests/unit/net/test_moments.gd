extends GutTest
## Story moments played alone (Plan 8.2): a quest step sends its player to its own copy of a
## zone variant; nobody else gets in, and the player comes back there after leaving.

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"
const QUESTS := "res://tests/data/quests/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var m_key: String


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.fallback_zone = "zone_m"
	host.set_quests(QuestDB.load_dir(QUESTS))
	host.add_transport(host_t)
	m_key = host.zones.open("zone_m")


func _guest(name: String, quests: Dictionary = {}, place: Dictionary = {}) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}, [], {"level": 5}, {}, place, quests), true)
	host.tick()
	return c


func _id(name: String) -> int:
	for id: int in host._players:
		if host._players[id].name == name:
			return id
	return 0


func _act(c: MemoryTransport, action: String, args: Array = []) -> void:
	c.send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _zone_msgs(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == Protocol.Msg.ZONE:
			out.append(m)
	return out


func _start_moment(name: String) -> MemoryTransport:
	var c := _guest(name, {"active": {"q_moment": {"step": 0, "counts": [0]}}})
	host.transfer(_id(name), m_key, Vector3(5.5, 0, 5.5))
	_act(c, "scene_done", ["m1"])
	return c


func test_personal_instance_only_owner() -> void:
	var a := _start_moment("Ana")
	var key: String = host._players[_id("Ana")].zone_key
	assert_eq(key, "zone_m~noche#p%d" % _id("Ana"))
	var zm := _zone_msgs(a)
	assert_eq(zm[-1].variant, "noche")
	_guest("Bea")
	host.transfer(_id("Bea"), m_key, Vector3(6.5, 0, 6.5))
	host.tick()
	assert_eq(host._players[_id("Bea")].zone_key, m_key, "Bea stays in the shared zone")


func test_moment_has_variant() -> void:
	_start_moment("Ana")
	var w := host.world_of(_id("Ana"))
	assert_eq(w.map.npcs.map(func(n: Dictionary) -> String: return n.id), ["merchant"])
	assert_eq(host.zones.layout(host._players[_id("Ana")].zone_key).ambience, "noche_fuego")
	assert_eq(w.map.respawn_cell, Vector2i(12, 12))


func test_return_on_done() -> void:
	var a := _start_moment("Ana")
	var key: String = host._players[_id("Ana")].zone_key
	_act(a, "scene_done", ["m2"])
	assert_eq(host._players[_id("Ana")].zone_key, m_key, "moment null: back to the shared zone")
	host.zones.close_idle(host.zones.time_s + ZoneManager.CLOSE_IDLE_S + 1.0)
	assert_null(host.zones.world(key), "the empty personal copy closes")


func test_place_is_the_base_zone() -> void:
	var a := _start_moment("Ana")
	var places := []
	for p: Dictionary in a.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == Protocol.Msg.PLACE:
			places.append(m)
	host._players[_id("Ana")].place_dirty = true
	host.tick()
	for p: Dictionary in a.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == Protocol.Msg.PLACE:
			places.append(m)
	assert_eq(places[-1].zone, "zone_m")


func test_rejoin_inside_moment() -> void:
	var a := _start_moment("Ana")
	var log := host.state_of(_id("Ana")).quests.to_dict()
	a.close()
	host.tick()
	_guest("Ana", log, {"zone": "zone_m", "at": [5, 5]})
	assert_eq(host._players[_id("Ana")].zone_key, "zone_m~noche#p%d" % _id("Ana"))


func test_death_respawns_inside() -> void:
	_start_moment("Ana")
	var id := _id("Ana")
	var key: String = host._players[id].zone_key
	var p := host.state_of(id)
	p.hp = 0.0
	host.world_of(id).on_zero_hp(p)
	for i in host.balance.tick_rate * 30:
		host.tick()
	assert_eq(host._players[id].zone_key, key)
	assert_true(p.is_alive())


func test_ambience_files_load() -> void:
	for id in ["atardecer", "noche_fuego", "alba"]:
		assert_true(Ambience.ids().has(id), id)
		assert_not_null(Ambience.load_id(id), id)


func test_load_variant() -> void:
	assert_eq(ZoneLayout.load_variant("aldea", "").id, "aldea")
	assert_eq(ZoneLayout.load_variant("aldea", "nada").variant, "", "an unknown variant is the base zone")
