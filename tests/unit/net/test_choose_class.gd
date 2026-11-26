extends GutTest
## A villager picks a class when the story asks for it (Plan 8.3a: the awakening in the
## assault): the client asks, the host checks it (a villager, alive, with the class step
## active, a class that can be chosen) and tells everyone.

const VERSION := "0.1.0"
const STORY := {"active": {"q_train": {"step": 1, "counts": [0]}}}

var balance: Balance
var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func _start() -> void:
	balance = Balance.load_from()
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(balance, map, VERSION)
	host.set_quests(QuestDB.load_dir("res://tests/data/quests/"))
	host.add_transport(host_t)


func _guest(name: String, class_id := "villager", story := true) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, class_id, {}, [], {}, {}, {}, STORY if story else {}), true)
	host.tick()
	return c


func _decoded(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func _class_msgs(c: MemoryTransport) -> Array:
	return _decoded(c).filter(func(m: Dictionary) -> bool: return m.get("type") == Protocol.Msg.PLAYER_CLASS)


func _choose(c: MemoryTransport, class_id: String) -> void:
	c.send(Transport.HOST_PEER, Protocol.choose_class(class_id), true)
	host.tick()


func test_choose_class_roundtrip() -> void:
	assert_eq(Protocol.decode(Protocol.choose_class("mage")), {"type": Protocol.Msg.CHOOSE_CLASS, "class_id": "mage"})
	var m := Protocol.decode(Protocol.player_class(3, "archer", ["a", "", "", "", "", "", "", "", ""]))
	assert_eq([m.id, m.class_id, m.bar], [3, "archer", ["a", "", "", "", "", "", "", "", ""]])


func test_host_accepts_a_villager_in_the_awakening() -> void:
	_start()
	var a := _guest("Ana")
	var b := _guest("Bea")
	_decoded(a)
	_decoded(b)
	_choose(a, "mage")
	var p: PlayerState = host.world.players[1]
	assert_eq(p.class_id, "mage")
	assert_eq(p.resource_kind, "mana")
	assert_eq(p.stats.max_hp, 130.0)
	assert_almost_eq(p.resource, 160.0, 0.5, "mana starts at the class start value")
	var mine := _class_msgs(a)
	assert_eq(mine.size(), 1)
	assert_eq([mine[0].id, mine[0].class_id], [1, "mage"])
	assert_eq(mine[0].bar, AbilityDB.load_default().default_bar("mage"))
	assert_eq(_class_msgs(b).size(), 1, "everyone hears it")
	assert_eq(host.roster()[0][3], "mage", "the roster has the new class")


func test_host_rejects_bad_choices() -> void:
	_start()
	var a := _guest("Ana")
	_decoded(a)
	for bad: String in ["villager", "druid", ""]:
		_choose(a, bad)
		assert_eq(host.world.players[1].class_id, "villager", bad)
	assert_eq(_class_msgs(a).size(), 0)
	_choose(a, "warrior")
	_decoded(a)
	_choose(a, "mage")
	assert_eq(host.world.players[1].class_id, "warrior", "the choice is final")
	assert_eq(_class_msgs(a).size(), 0)


func test_host_rejects_without_the_story_step() -> void:
	_start()
	var a := _guest("Ana", "villager", false)
	_decoded(a)
	_choose(a, "mage")
	assert_eq(host.world.players[1].class_id, "villager")
	assert_eq(_class_msgs(a).size(), 0)


func test_host_rejects_downed_or_dead() -> void:
	_start()
	var a := _guest("Ana")
	_decoded(a)
	for life: int in [CombatEntity.DOWNED, CombatEntity.DEAD]:
		host.world.players[1].life = life
		_choose(a, "mage")
		assert_eq(host.world.players[1].class_id, "villager", "life %d" % life)
	assert_eq(_class_msgs(a).size(), 0)


func _pump(client: ClientSession, n: int) -> void:
	for i in n:
		net.advance(balance.dt() * 1000.0)
		client.tick(Vector2.ZERO, Vector3(20.5, 0, 30))
		host.tick()
		client.update(balance.dt())


func test_client_updates_roster_and_emits() -> void:
	_start()
	var client := ClientSession.new(balance, CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []}), VERSION, "Ana")
	client.quests = QuestLog.from_dict(STORY, QuestDB.load_dir("res://tests/data/quests/"))
	client.connect_to(net.connect_client(host_t))
	_pump(client, 10)
	assert_eq(client.class_id, "villager")
	watch_signals(client)
	client.choose_class("archer")
	_pump(client, 10)
	assert_signal_emitted_with_parameters(client, "class_changed", [client.my_id, "archer"])
	assert_eq(client.class_id, "archer")
	assert_eq(client.roster[client.my_id].class_id, "archer")
	assert_eq(client.bar, AbilityDB.load_default().default_bar("archer"))




func test_choosing_keeps_the_health_ratio() -> void:
	_start()
	var a := _guest("Ana")
	_decoded(a)
	var p: PlayerState = host.world.players[1]
	host.world.balance.out_of_combat_hp_pct = 0.0 # only the class change may move the health
	p.hp = p.stats.max_hp * 0.25
	_choose(a, "warrior")
	assert_almost_eq(p.hp, p.stats.max_hp * 0.25, 0.01, "no free heal from choosing in combat")


func test_choose_class_gives_kit() -> void:
	_start()
	var a := _guest("Ana")
	_decoded(a)
	var p: PlayerState = host.world.players[1]
	p.inventory = Inventory.starter("villager", ItemDB.load_default())
	_choose(a, "warrior")
	var worn: Array = p.inventory.equipment.values().map(func(it: Item) -> String: return it.base_id)
	worn.sort()
	var kit: Array = ItemDB.load_default().starter("warrior").duplicate()
	kit.sort()
	assert_eq(worn, kit, "the wood sword is gone, the warrior kit is worn")
	assert_true(_decoded(a).any(func(m: Dictionary) -> bool: return m.get("type") == Protocol.Msg.INVENTORY), "the owner gets it")
