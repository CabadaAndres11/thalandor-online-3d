extends GutTest
## Safe while watching a cutscene (Plan 8.2): monsters neither pick nor hurt a player in a
## scene; a scene starts only out of combat and never outlives its time.

const VERSION := "0.1.0"
const QUESTS := "res://tests/data/quests/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.set_quests(QuestDB.load_dir(QUESTS))
	host.add_transport(host_t)


func _guest(name: String, quests: Dictionary = {}) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}, [], {"level": 5}, {}, {}, quests), true)
	host.tick()
	return c


func _act(c: MemoryTransport, action: String, args: Array = []) -> void:
	c.send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _wolf_next_to(id: int) -> MonsterState:
	var w := host.world_of(id)
	var m := MonsterDB.load_default().make("hunter_wolf", w.next_monster_id(), host.state_of(id).position + Vector3(1, 0, 0), w, 5)
	w.add_entity(m)
	return m


func test_no_damage_in_scene() -> void:
	var c := _guest("Ana")
	_act(c, "scene_start", ["s1"])
	var p := host.state_of(1)
	assert_true(p.in_scene())
	var m := _wolf_next_to(1)
	var hp := p.hp
	for i in host.balance.tick_rate * 5:
		host.tick()
	assert_eq(p.hp, hp)
	assert_ne(m.target_id, 1)
	assert_false(m.threat.has(1))


func test_damage_after_scene() -> void:
	var c := _guest("Ana")
	_act(c, "scene_start", ["s1"])
	_act(c, "scene_done", ["s1"])
	var p := host.state_of(1)
	assert_false(p.in_scene())
	_wolf_next_to(1)
	var hp := p.hp
	for i in host.balance.tick_rate * 5:
		host.tick()
	assert_lt(p.hp, hp, "a wolf bites a player who is not in a scene")


func test_not_in_combat() -> void:
	var c := _guest("Ana")
	var p := host.state_of(1)
	p.last_hurt_tick = host.world_of(1).tick - host.balance.tick_rate
	_act(c, "scene_start", ["s1"])
	assert_false(p.in_scene())


func test_cleared_on_zone_change_and_timeout() -> void:
	var c := _guest("Ana")
	_act(c, "scene_start", ["s1"])
	var p := host.state_of(1)
	for i in host.balance.tick_rate * 121:
		host.world_of(1).step({})
		Combat.tick(host.world_of(1))
	assert_false(p.in_scene(), "120 s at most")
	_act(c, "scene_start", ["s1"])
	assert_true(p.in_scene())
	host.send_to_zone(1, host.zones.start_key, Vector3(10.5, 0, 10.5))
	assert_false(host.state_of(1).in_scene(), "changing zone ends the scene")


func test_input_ignored_in_scene() -> void:
	var c := _guest("Ana")
	_act(c, "scene_start", ["s1"])
	var p := host.state_of(1)
	var at := p.position
	for i in 10:
		c.send(Transport.HOST_PEER, Protocol.input([[i + 1, Vector2(1, 0), Vector3.ZERO, 0]]), false)
		host.tick()
	assert_eq(p.position, at)


func test_objective_survives_disconnect() -> void:
	var c := _guest("Ana", {"active": {"q_req": {"step": 0, "counts": [0]}}})
	_act(c, "scene_start", ["s_req"])
	var log := host.state_of(1).quests.to_dict()
	c.close()
	host.tick()
	assert_eq(host.player_count(), 0)
	var back := _guest("Ana", log)
	var p := host.state_of(host._players.keys()[0])
	assert_true(p.quests.is_active("q_req"))
	assert_eq(p.quests.active.q_req.counts, [0])
	assert_false(p.in_scene())
