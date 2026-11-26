extends GutTest
## Quests over the network (protocol 9, Plan 8.2): HELLO carries the quest log, the host
## sends QUESTS to its owner on every change and checks every QUEST_ACTION.

const VERSION := "0.1.0"
const QUESTS := "res://tests/data/quests/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var db: ItemDB


func before_each() -> void:
	db = ItemDB.load_default()
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": [20, 22], "facing": 0}, {"id": "merchant", "at": [22, 20], "facing": 0}]})
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


func _msgs(c: MemoryTransport, type: int) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == type:
			out.append(m)
	return out


func _act(c: MemoryTransport, action: String, args: Array = []) -> void:
	c.send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _kill_wolf(id: int) -> void:
	var w := host.world_of(id)
	var m := MonsterDB.load_default().make("hunter_wolf", w.next_monster_id(), host.state_of(id).position, w, 3)
	w.add_entity(m)
	m.hp = 0.0
	w.on_zero_hp(m)


func test_hello_carries_quests() -> void:
	_guest("Ana", {"active": {"q_one": {"step": 0, "counts": [2]}}, "flags": ["visto"]})
	var p := host.state_of(1)
	assert_true(p.quests.is_active("q_one"))
	assert_eq(p.quests.active.q_one.counts, [2])
	assert_true(p.quests.has_flag("visto"))


func test_change_flows_back() -> void:
	var c := _guest("Ana", {"active": {"q_one": {"step": 0, "counts": [0]}}})
	_msgs(c, Protocol.Msg.QUESTS)
	_kill_wolf(1)
	host.tick()
	var got := _msgs(c, Protocol.Msg.QUESTS)
	assert_eq(got.size(), 1)
	assert_eq(got[0].quests.active.q_one.counts, [1])


func test_guest_completes_chain() -> void:
	var c := _guest("Ana")
	host.state_of(1).position = Vector3(20.5, 0, 21.0) # next to Brann
	_act(c, "accept", ["q_collect"])
	assert_true(host.state_of(1).quests.is_active("q_collect"))
	_kill_wolf(1)
	_kill_wolf(1)
	host.tick()
	_act(c, "turn_in", ["q_collect", ""])
	var p := host.state_of(1)
	assert_true(p.quests.is_done("q_collect"))
	assert_eq(p.inventory.count_of("q_colmillo"), 0)
	var last: Array = _msgs(c, Protocol.Msg.QUESTS)
	assert_true("q_collect" in (last[-1].quests.done as Array))


func test_accept_needs_giver_near() -> void:
	var c := _guest("Ana")
	host.state_of(1).position = Vector3(40.5, 0, 40.5)
	_act(c, "accept", ["q_collect"])
	assert_false(host.state_of(1).quests.is_active("q_collect"))


func test_bad_requests_ignored() -> void:
	var c := _guest("Ana")
	host.state_of(1).position = Vector3(20.5, 0, 21.0)
	_act(c, "accept", ["q_reward"])
	_act(c, "turn_in", ["q_reward", "sword_t1"])
	assert_true(host.state_of(1).quests.is_active("q_reward"), "not finished")
	_act(c, "accept", [5])
	_act(c, "turn_in", [])
	_act(c, "talk_done", [1, 2])
	_act(c, "nonsense", ["x"])
	assert_eq(host.state_of(1).quests.active.keys(), ["q_reward"])


func test_track() -> void:
	var c := _guest("Ana")
	host.state_of(1).position = Vector3(20.5, 0, 21.0)
	_act(c, "accept", ["q_collect"])
	_act(c, "accept", ["q_reward"])
	_act(c, "track", ["q_reward"])
	assert_eq(host.state_of(1).quests.tracked, "q_reward")
	_act(c, "track", ["nope"])
	assert_eq(host.state_of(1).quests.tracked, "q_reward")


func test_events_only_to_owner() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	host.state_of(1).position = Vector3(20.5, 0, 21.0)
	_msgs(b, Protocol.Msg.EVENTS)
	_act(a, "accept", ["q_collect"])
	var seen := []
	for m: Dictionary in _msgs(b, Protocol.Msg.EVENTS):
		for ev: Array in m.events:
			seen.append(ev[0])
	assert_false("quest_started" in seen)


func test_commands() -> void:
	var c := _guest("Ana")
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/mision q_one"), true)
	host.tick()
	assert_true(host.state_of(1).quests.is_active("q_one"))
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/mision paso"), true)
	host.tick()
	assert_eq(int(host.state_of(1).quests.active.q_one.step), 1)
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/marca visto"), true)
	host.tick()
	assert_true(host.state_of(1).quests.has_flag("visto"))
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/marca quitar visto"), true)
	host.tick()
	assert_false(host.state_of(1).quests.has_flag("visto"))
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/mision fin"), true)
	host.tick()
	assert_true(QuestRules.is_ready(host.world_of(1), host.state_of(1), "q_one"))
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/mision borrar q_one"), true)
	host.tick()
	assert_false(host.state_of(1).quests.is_active("q_one"))


func test_client_receives_quests() -> void:
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": []})
	var client := ClientSession.new(Balance.load_from(), map, VERSION, "Ana")
	client.quests = QuestLog.from_dict({"flags": ["visto"]}, QuestDB.load_dir(QUESTS))
	client.connect_to(net.connect_client(host_t))
	for i in 3:
		host.tick()
		client.tick(Vector2.ZERO, Vector3.ZERO)
	assert_true(host.state_of(1).quests.has_flag("visto"), "HELLO carried the client's log")
	watch_signals(client)
	QuestRules.set_flag(host.world_of(1), host.state_of(1), "otra")
	host.tick()
	client.tick(Vector2.ZERO, Vector3.ZERO)
	assert_signal_emitted(client, "quests_changed")
	assert_true(client.quests.has_flag("otra"))


func test_choose_flag_only_if_offered() -> void:
	DialogueRunner.dir = "res://tests/data/dialogues/"
	var c := _guest("Ana")
	_act(c, "choose_flag", ["d_test", "pregunto"])
	_act(c, "choose_flag", ["d_test", "secreto_ok"])
	_act(c, "choose_flag", ["nope", "x"])
	DialogueRunner.dir = DialogueRunner.DIR
	var p := host.state_of(1)
	assert_true(p.quests.has_flag("pregunto"))
	assert_false(p.quests.has_flag("secreto_ok"), "needs the flag visto first")
	assert_false(p.quests.has_flag("x"))


func test_choose_class_without_trainer_only_with_objective() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Vil", "villager", {}, [], {"level": 1}, {}, {}, {}), true)
	host.tick()
	host.state_of(1).position = Vector3(50.5, 0, 50.5)
	c.send(Transport.HOST_PEER, Protocol.choose_class("mage"), true)
	host.tick()
	assert_eq(host.state_of(1).class_id, "villager", "no trainer and no story step: refused")
	QuestRules.force_start(host.world_of(1), host.state_of(1), "q_train")
	host.state_of(1).quests.active.q_train = {"step": 1, "counts": [0]}
	c.send(Transport.HOST_PEER, Protocol.choose_class("mage"), true)
	host.tick()
	assert_eq(host.state_of(1).class_id, "mage")
	assert_eq(int(host.state_of(1).quests.active.q_train.step), 2, "the class objective is done")


func test_arena_command() -> void:
	var c := _guest("Ana")
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/arena 12"), true)
	host.tick()
	assert_eq(host.world.arena_level, 12)
	var d := _guest("Bea")
	d.send(Transport.HOST_PEER, Protocol.chat(0, "/arena 30"), true)
	host.tick()
	assert_eq(host.world.arena_level, 12, "only the host")
