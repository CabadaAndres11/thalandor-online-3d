extends GutTest
## The example quest chain (Plan 8.2, provisional until 8.3) played through the host, with
## the requests a client would send: talk, deliver, hunt and collect, reach, a scene,
## examine, a choice, a story moment alone at night, and the rewards.

const VERSION := "0.1.0"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var c: MemoryTransport


func before_each() -> void:
	var layout := ZoneLayout.load_id("aldea")
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), layout.collision(), VERSION)
	host.add_transport(host_t)
	c = net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Aren", "warrior", {}, [], {"level": 3}, {}, {}, {}), true)
	host.tick()


func _p() -> PlayerState:
	return host.state_of(1)


func _act(action: String, args: Array = []) -> void:
	c.send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _at(x: float, z: float) -> void:
	_p().position = Vector3(x, 0, z)


func _go(zone: String, x: float, z: float) -> void:
	host.send_to_zone(1, host.zones.open(zone), Vector3(x, 0, z))
	host.tick()


func _kill(type_id: String) -> void:
	var w := host.world_of(1)
	var m := MonsterDB.load_default().make(type_id, w.next_monster_id(), _p().position + Vector3(1, 0, 0), w, 5)
	w.add_entity(m)
	m.hp = 0.0
	w.on_zero_hp(m)


func _ticks(seconds: float) -> void:
	for i in host.balance.tick_rate * seconds:
		host.tick()


func test_example_chain() -> void:
	var level := _p().progress.level
	assert_true(_p().quests.is_active("ej_encargo"), "the first quest starts by itself")
	# 1. Brann's errand.
	_at(37.5, 36.5)
	_act("talk_done", ["brann", "ej_brann_encargo"])
	assert_eq(_p().inventory.count_of("q_paquete"), 1)
	var gold := _p().inventory.gold
	_at(54.5, 47.5)
	_act("talk_done", ["merchant", "ej_merchant_paquete"])
	assert_true(_p().quests.is_done("ej_encargo"))
	assert_eq(_p().inventory.gold, gold + 25)
	# 2. Wolves on the road.
	_act("accept", ["ej_lobos"])
	assert_true(_p().quests.is_active("ej_lobos"))
	_go("bosque", 20.5, 30.5)
	for i in 60:
		if _p().quests.active.ej_lobos.step > 0:
			break
		_kill("marked_hound")
	assert_eq(int(_p().quests.active.ej_lobos.step), 1, "five hounds and three teeth")
	for id: int in host.world_of(1).monsters.keys():
		host.world_of(1).remove_entity(id) # the hounds of the horde were biting: no scene in a fight
	_at(30.5, 40.5)
	_ticks(6.0)
	assert_eq(int(_p().quests.active.ej_lobos.step), 2, "the clearing")
	assert_true(_p().in_scene(), "the scene of the tracks plays")
	_act("scene_done", ["ej_huellas"])
	_at(33.5, 43.5)
	_act("interact", ["huellas"])
	assert_true(QuestRules.is_ready(host.world_of(1), _p(), "ej_lobos"))
	_go("aldea", 37.5, 36.5)
	_act("turn_in", ["ej_lobos", "ring_t1"])
	assert_true(_p().quests.is_done("ej_lobos"))
	assert_eq(_p().progress.level, level + 1)
	assert_eq(_p().inventory.count_of("ring_t1"), 1)
	# 3. What the night saw: a choice, the village alone at night, the dawn.
	_act("choose_flag", ["ej_brann_noche", "ej_vigilar"])
	_act("accept", ["ej_noche"])
	host.tick()
	var key: String = host._players[1].zone_key
	assert_eq(key, "aldea~noche#p1", "alone in the village at night")
	var w := host.world_of(1)
	for i in host.balance.tick_rate * 20:
		host.tick()
		if w.monsters.size() >= 4:
			break
	for m: CombatEntity in w.monsters.values():
		_p().position = m.position + Vector3(1, 0, 0)
		m.hp = 0.0
		w.on_zero_hp(m)
	assert_eq(int(_p().quests.active.ej_noche.step), 2, "the cultists are gone")
	host._follow_story_moments() # these kills happened outside a host tick: pick up their events
	_ticks(6.0)
	assert_true(_p().in_scene(), "the dawn scene plays")
	_act("scene_done", ["ej_alba"])
	host.tick()
	assert_eq(host._players[1].zone_key, "aldea", "back in the shared village")
	_at(37.5, 36.5)
	_act("turn_in", ["ej_noche", ""])
	assert_true(_p().quests.is_done("ej_noche"))
	assert_true(_p().quests.has_flag("ej_vigilar"))
	assert_eq(NpcTalk.pick("brann", _p().quests, _p().progress.level, "warrior", QuestDB.load_default()).dialogue, "ej_brann_vigilar")
