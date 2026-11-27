extends GutTest
## Mission 4, "La capital" (Plan 8.3b), played through the host with a client's requests:
## the caravan and the ambush on the road, the arrival, the audience, the mask for Oriel and
## the crypt's gate that the king opens.

const VERSION := "0.1.0"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var c: MemoryTransport


func before_each() -> void:
	QuestDB._default = QuestDB.load_dir(QuestDB.DIR)
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), ZoneLayout.load_id("aldea").collision(), VERSION)
	host.add_transport(host_t)
	var log := QuestLog.new()
	log.done.append_array(["prologo_1", "prologo_2", "prologo_3"])
	log.flags.append_array(["apodo", "prologo_3_hecho"])
	log.marks.append("tutorial_done")
	var bag := Inventory.new()
	var mask := ItemRoll.new_item("q_mascara_culto", 1)
	bag.add(mask, ItemDB.load_default())
	c = net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Aren", "warrior", {}, [], {"level": 4},
		bag.to_wire(), {}, log.to_dict()), true)
	host.tick()


func after_each() -> void:
	QuestDB._default = null


func _p() -> PlayerState:
	return host.state_of(1)


func _act(action: String, args: Array = []) -> void:
	c.send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _step() -> int:
	return int(_p().quests.active.prologo_4.step) if _p().quests.is_active("prologo_4") else -1


func _go(zone: String) -> void:
	host.send_to_zone(1, host.zones.open(zone), host.zones.layout(host.zones.open(zone)).entry("default"))
	host.tick()


func _at_point(name: String) -> void:
	var at: Vector2i = host.world_of(1).map.quest_points[name].at
	_p().position = Vector3(at.x + 0.5, 0, at.y + 0.5)


func _reach(name: String) -> void:
	_at_point(name)
	for i in host.balance.tick_rate * 2:
		host.tick()


func _talk(npc: String, dialogue: String) -> void:
	_p().position = QuestRules._npc_position(host.world_of(1), npc) + Vector3(1, 0, 0)
	_act("talk_done", [npc, dialogue])


func _calm() -> void:
	var w := host.world_of(1)
	for id: int in w.monsters.keys():
		w.remove_entity(id)
	_p().last_hurt_tick = -100000


func _watch(scene: String) -> void:
	for i in host.balance.tick_rate * 4:
		if _p().in_scene():
			break
		host.tick()
	assert_true(_p().in_scene(), scene + " plays")
	_act("scene_done", [scene])


func _kill(type_id: String) -> void:
	var w := host.world_of(1)
	var m := MonsterDB.load_default().make(type_id, w.next_monster_id(), _p().position + Vector3(1, 0, 0), w, 5)
	w.add_entity(m)
	m.hp = 0.0
	w.on_zero_hp(m)


## Review point 4: a character of the 0.13.0 that finished mission 3 starts mission 4 on joining.
func test_prologue_4_starts_for_013_characters() -> void:
	assert_true(_p().quests.is_active("prologo_4"))
	assert_eq(_step(), 0)


func test_prologue_4() -> void:
	var level := _p().progress.level
	_go("camino")
	_calm()
	_reach("caravana")
	assert_eq(_step(), 1, "at the caravan")
	_talk("caravanero", "prologo4_caravanero_salida")
	_calm()
	_reach("emboscada")
	assert_eq(_step(), 3)
	_calm()
	_watch("prologo_emboscada")
	for i in 4:
		_kill("bandit")
	for i in 2:
		_kill("bandit_archer")
	_kill("bandit_chief")
	assert_eq(_step(), 4, "the caravan is safe")
	_calm()
	_talk("caravanero", "prologo4_caravanero_despues")
	_go("capital")
	_reach("puerta_capital")
	_watch("prologo_llegada")
	_go("palacio")
	_reach("salon_trono")
	_watch("prologo_audiencia")
	assert_eq(_p().inventory.count_of("q_mascara_culto"), 1)
	_talk("oriel", "prologo4_oriel_mascara")
	assert_eq(_p().inventory.count_of("q_mascara_culto"), 0, "the mask is Oriel's now")
	assert_false(_p().quests.has_flag("cripta_abierta"))
	var gold := _p().inventory.gold # the bandits dropped some on the road
	_talk("rey", "prologo4_rey_encargo")
	assert_true(_p().quests.has_flag("cripta_abierta"), "the king opens the gate")
	_watch("prologo_descenso")
	host.tick()
	assert_true(_p().quests.is_done("prologo_4"))
	assert_true(_p().quests.has_flag("prologo_hecho"))
	assert_eq(_p().progress.level, level + 1)
	assert_eq(_p().inventory.gold, gold + 100)
	# Through the gate, into the crypt, and back up to the palace.
	var gate: Dictionary = host.zones.layout(host._players[1].zone_key).exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba")[0]
	var r: Rect2i = gate.area
	_p().position = Vector3(r.position.x + r.size.x / 2.0, 0, r.position.y + r.size.y / 2.0)
	host.tick()
	c.send(Transport.HOST_PEER, Protocol.enter_dungeon("cripta_prueba", 5), true)
	host.tick()
	host.tick()
	var crypt_key := str(host._players[1].zone_key)
	assert_true(crypt_key.begins_with("cripta_prueba"), "into the crypt: " + crypt_key)
	var out: Rect2i = host.zones.layout(crypt_key).exits[0].area
	_calm()
	_p().position = Vector3(out.position.x + 1.5, 0, out.position.y + 0.5)
	host.tick()
	host.tick()
	assert_eq(str(host._players[1].zone_key), "palacio", "back up in the palace")


func test_mission_4_data_is_valid() -> void:
	var errors := QuestDB.load_default().validate(NpcDB.load_default(), MonsterDB.load_default(), ItemDB.load_default(),
		ZoneLayout.DIR, DialogueRunner.DIR, CutsceneData.DIR)
	assert_eq(errors, [])
	for id: String in ["prologo_emboscada", "prologo_llegada", "prologo_audiencia", "prologo_descenso"]:
		assert_eq(CutsceneData.validate(id), [], id)
