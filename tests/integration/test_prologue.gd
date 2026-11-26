extends GutTest
## The prologue (Plan 8.3a) played through the host with the requests a client would send:
## the eve alone in the festive village, the assault alone at night (the class is chosen
## there), and "Llegan tarde" in the shared ruins and the forest.

const VERSION := "0.1.0"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var c: MemoryTransport


func before_each() -> void:
	QuestDB._default = QuestDB.load_dir(QuestDB.DIR)
	var layout := ZoneLayout.load_id("aldea")
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), layout.collision(), VERSION)
	host.add_transport(host_t)
	c = _join("Aren")
	host.tick()


func after_each() -> void:
	QuestDB._default = null


func _join(name: String) -> MemoryTransport:
	var t := net.connect_client(host_t)
	t.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "villager", {}, [], {"level": 1}, {}, {}, {}), true)
	return t


func _p(id: int = 1) -> PlayerState:
	return host.state_of(id)


func _act(action: String, args: Array = [], t: MemoryTransport = null) -> void:
	(t if t != null else c).send(Transport.HOST_PEER, Protocol.quest_action(action, args), true)
	host.tick()


func _at(x: float, z: float, id: int = 1) -> void:
	_p(id).position = Vector3(x + 0.5, 0, z + 0.5)


func _ticks(seconds: float) -> void:
	for i in host.balance.tick_rate * seconds:
		host.tick()


func _step(id: String) -> int:
	return int(_p().quests.active[id].step) if _p().quests.is_active(id) else -1


func _key() -> String:
	return str(host._players[1].zone_key)


## Watches the scene the host started: it has to be playing (the player is safe).
func _watch(scene: String) -> void:
	for i in host.balance.tick_rate * 4:
		if _p().in_scene():
			break
		host.tick()
	assert_true(_p().in_scene(), scene + " plays")
	_act("scene_done", [scene])


func _point(name: String) -> Vector2i:
	return host.world_of(1).map.quest_points[name].at


func _reach(name: String) -> void:
	var at := _point(name)
	_at(at.x, at.y)
	_ticks(1.5)


func _clear_monsters(keep: String = "") -> void:
	var w := host.world_of(1)
	for id: int in w.monsters.keys():
		if (w.monsters[id] as MonsterState).type_id != keep:
			w.remove_entity(id)
	_p().last_hurt_tick = -100000 # the horde was biting: out of combat now, so the scene may start


func _kill(type_id: String) -> void:
	var w := host.world_of(1)
	var m := MonsterDB.load_default().make(type_id, w.next_monster_id(), _p().position + Vector3(1, 0, 0), w, 1)
	w.add_entity(m)
	m.hp = 0.0
	w.on_zero_hp(m)


func _talk(npc: String, dialogue: String) -> void:
	var at: Vector3 = QuestRules._npc_position(host.world_of(1), npc)
	_p().position = at + Vector3(1, 0, 0)
	_act("talk_done", [npc, dialogue])


func test_the_prologue() -> void:
	# 1. The eve.
	assert_true(_p().quests.is_active("prologo_1"), "a new character starts the prologue")
	host.tick()
	assert_eq(_key(), "aldea~vispera#p1", "alone in the festive village")
	assert_eq(host.world_of(1).map.respawn_cell, Vector2i(31, 35))
	_reach("mira_casa")
	assert_eq(_step("prologo_1"), 1)
	_talk("mira", "prologo_mira_despierta")
	_talk("brann", "prologo_brann_recados")
	for item: String in ["q_pala_horno", "q_puntas_flecha", "q_candil"]:
		assert_eq(_p().inventory.count_of(item), 1, item)
	_talk("panadero", "prologo_panadero_recado")
	_talk("cazador", "prologo_cazador_recado")
	_talk("anciana_cantora", "prologo_anciana_recado")
	assert_eq(_step("prologo_1"), 4, "the errands are done")
	var potions := _p().inventory.count_of("potion_health")
	_talk("brann", "prologo_brann_practica")
	assert_eq(_p().inventory.count_of("potion_health"), potions + 2)
	var w := host.world_of(1)
	var dummy: MonsterState = w.monsters.values().filter(func(m: MonsterState) -> bool: return m.type_id == "training_dummy")[0]
	for i in 10:
		QuestRules.on_hit(w, _p(), dummy, "basic")
	for i in 3:
		QuestRules.on_hit(w, _p(), dummy, "secondary")
	for i in 3:
		QuestRules.on_dodge(w, _p())
	assert_eq(_step("prologo_1"), 8, "the practice is done")
	_reach("colina")
	_watch("prologo_colina")
	_reach("plaza")
	_watch("prologo_fiesta")
	# 2. The assault.
	assert_true(_p().quests.is_done("prologo_1"))
	assert_true(_p().quests.is_active("prologo_2"))
	host.tick()
	assert_eq(_key(), "aldea~asalto#p1", "alone in the burning village")
	_watch("prologo_alarma")
	_reach("alarma")
	assert_eq(_step("prologo_2"), 1)
	w = host.world_of(1)
	for i in 6:
		_kill("cultist")
	assert_eq(_step("prologo_2"), 2, "the neighbours are saved")
	host._follow_story_moments() # kills made outside a host tick: pick up their events
	_clear_monsters()
	_watch("prologo_secuestro")
	_reach("tras_mira")
	_watch("prologo_despertar")
	assert_true(QuestRules.allows_class_choice(w, _p()), "the class is chosen here, with no trainer")
	c.send(Transport.HOST_PEER, Protocol.choose_class("warrior"), true)
	host.tick()
	assert_eq(_p().class_id, "warrior")
	assert_eq(_step("prologo_2"), 4)
	_watch("prologo_alba")
	for i in 4:
		_kill("marked_hound")
	_clear_monsters()
	var heraldo := MonsterDB.load_default().make("heraldo", w.next_monster_id(), _p().position + Vector3(1, 0, 0), w, 2)
	w.add_entity(heraldo)
	w.current_source = _p().id
	Damage.apply(heraldo, {"amount": heraldo.hp, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	assert_true(heraldo.fled, "the Heraldo flees")
	assert_eq(_step("prologo_2"), 5, "and that counts as his defeat")
	host._follow_story_moments()
	_watch("prologo_huida")
	_reach("puerta")
	var level := _p().progress.level
	_watch("prologo_brann")
	host.tick()
	assert_true(_p().quests.is_done("prologo_2"))
	assert_true("tutorial_done" in _p().quests.marks)
	assert_eq(_key(), "aldea", "back in the shared village, now in ruins")
	assert_eq(_p().progress.level, level + 2, "two levels")
	# 3. Late.
	assert_true(_p().quests.is_active("prologo_3"))
	for pt: String in ["herido_1", "herido_2", "escombros_1"]:
		var at := _point(pt)
		_at(at.x, at.y)
		_act("interact", [pt])
	_talk("panadero", "prologo_panadero_despues")
	_talk("cazador", "prologo_cazador_despues")
	_watch("prologo_ejercito")
	_talk("verrin", "prologo_verrin_explica")
	assert_eq(_step("prologo_3"), 2)
	host.send_to_zone(1, host.zones.open("bosque"), Vector3(12, 0, 64))
	host.tick()
	_clear_monsters()
	_reach("campamento")
	var mask := _point("mascara")
	_at(mask.x, mask.y)
	_act("interact", ["mascara"])
	assert_eq(_p().inventory.count_of("q_mascara_culto"), 1, "the mask goes in the bag")
	var tracks := _point("huellas_carro")
	_at(tracks.x, tracks.y)
	_act("interact", ["huellas_carro"])
	_reach("rio")
	_watch("prologo_rio")
	host.send_to_zone(1, host.zones.open("aldea"), Vector3(40, 0, 48))
	host.tick()
	_talk("anciana_cantora", "prologo_anciana_nombre")
	assert_true(_p().quests.has_flag("apodo"), "Thal An Dor")
	_watch("prologo_nombre")
	level = _p().progress.level
	_talk("verrin", "prologo_verrin_capital")
	assert_true(_p().quests.is_done("prologo_3"))
	assert_true(_p().quests.has_flag("prologo_3_hecho"))
	assert_eq(_p().progress.level, level + 1)
	assert_eq(_p().inventory.count_of("q_mascara_culto"), 1, "the mask stays until the capital")


## A friend who joins while the host is in a story moment lands in the shared village.
func test_a_guest_never_lands_in_the_hosts_moment() -> void:
	host.tick()
	assert_eq(_key(), "aldea~vispera#p1")
	var guest := _join("Bea")
	host.tick()
	host.tick()
	var guest_id := 2
	assert_true(host._players.has(guest_id))
	var gkey := str(host._players[guest_id].zone_key)
	assert_ne(gkey, "aldea~vispera#p1", "never in the host's own moment")
	assert_true(gkey == "aldea" or gkey.ends_with("#p%d" % guest_id), "shared village or the guest's own moment: " + gkey)
	assert_not_null(guest)


func test_the_prologue_data_is_valid() -> void:
	var errors := QuestDB.load_default().validate(NpcDB.load_default(), MonsterDB.load_default(), ItemDB.load_default(),
		ZoneLayout.DIR, DialogueRunner.DIR, CutsceneData.DIR)
	assert_eq(errors, [])
	for id: String in CutsceneData.ids():
		assert_eq(CutsceneData.validate(id), [], id)
	assert_eq(DialogueRunner.validate_dir(DialogueRunner.DIR), [])
	assert_eq(QuestDB.load_default().ids(), ["prologo_1", "prologo_2", "prologo_3"])


## Review point 1: leaving in the middle of the awakening and coming back puts the player in
## the assault again, and the scene plays again (its step waits for it), then the class.
func test_coming_back_in_the_awakening() -> void:
	var log := QuestLog.new()
	log.done.append("prologo_1")
	log.active["prologo_2"] = {"step": 3, "counts": [0, 0]}
	var t := net.connect_client(host_t)
	t.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Ciro", "villager", {}, [], {"level": 1}, {}, {}, log.to_dict()), true)
	host.tick()
	host.tick()
	var id := 2
	assert_eq(str(host._players[id].zone_key), "aldea~asalto#p%d" % id, "back in the assault")
	assert_true(host.state_of(id).in_scene(), "the awakening plays again")
	t.send(Transport.HOST_PEER, Protocol.quest_action("scene_done", ["prologo_despertar"]), true)
	host.tick()
	assert_true(QuestRules.allows_class_choice(host.world_of(id), host.state_of(id)), "and the class is chosen")
