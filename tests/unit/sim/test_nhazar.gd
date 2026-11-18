extends GutTest
## Nhazar, the Bishop of a Thousand Voices: a boss whose attacks come from data ("specials" by phase,
## "phase_abilities" once per phase) on top of the boss rules.


func _fixture() -> CombatFixture:
	var f := CombatFixture.new([], Vector2i(48, 48))
	f.world.abilities = AbilityDB.load_default()
	return f


func _boss(f: CombatFixture, pos := Vector3(20, 0, 20)) -> MonsterState:
	var m := MonsterDB.load_default().make("nhazar", f.world.next_monster_id(), pos, f.world)
	m.facing = 0.0
	f.world.add_entity(m)
	return m


func _step(f: CombatFixture) -> void:
	f.world.events.clear()
	f.world.step({})
	f.log.append_array(f.world.events)


func _steps(f: CombatFixture, seconds: float) -> void:
	for i in f.world.ticks(seconds):
		_step(f)


## Ability ids the boss cast, in order.
func _casts(f: CombatFixture, boss: MonsterState) -> Array:
	return f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == "cast" and int(ev[1]) == boss.id).map(
		func(ev: Array) -> String: return str(ev[2]))


func test_data_is_the_stronger_second_priest() -> void:
	var d := MonsterDB.load_default().get_type("nhazar")
	var first := MonsterDB.load_default().get_type("vaelthar")
	assert_true(bool(d.get("boss", false)), "boss bar at the top of the screen")
	assert_gt(float(d.stats.max_hp), float(first.stats.max_hp))
	assert_gt(float(d.hover), 0.0, "it floats")
	assert_gt(float(d.bar_height), 1.9 * 2.0, "the head mass towers over the body")
	var abilities := AbilityDB.load_default()
	var ids: Array = d.abilities + d.specials.map(func(s: Dictionary) -> String: return s.ability) + d.phase_abilities.values()
	assert_eq(ids.size(), 9)
	for id: String in ids:
		var ab := abilities.get_ability(id)
		assert_false(ab.is_empty(), id)
		assert_ne(tr(str(ab.name)), str(ab.name), id + " name translated")
		assert_ne(tr(str(ab.desc)), str(ab.desc), id + " description translated")
	assert_eq(tr("MON_NHAZAR"), "Nhazar, Obispo de las Mil Voces")


func test_most_of_the_set_inflicts_statuses() -> void:
	var abilities := AbilityDB.load_default()
	var d := MonsterDB.load_default().get_type("nhazar")
	var ids: Array = d.abilities + d.specials.map(func(s: Dictionary) -> String: return s.ability)
	var kinds := {}
	var with_status := 0
	for id: String in ids:
		var found := false
		for e: Dictionary in abilities.get_ability(id).effects:
			for st: Dictionary in e.get("statuses", []):
				kinds[st.kind] = true
				found = true
		with_status += 1 if found else 0
	assert_eq(with_status, ids.size(), "every attack leaves a status")
	for k: String in ["slow", "attack_slow", "weaken", "armor_break", "vulnerable", "stun"]:
		assert_true(kinds.has(k), k)


func test_phase_1_litany_whisper_and_chorus_at_range() -> void:
	var f := _fixture()
	var boss := _boss(f)
	var p := f.player(1, Vector3(20, 0, 28), 50000.0)
	_steps(f, 1.5)
	var casts := _casts(f, boss)
	for id: String in ["nhazar_litany", "nhazar_whisper"]:
		assert_true(casts.has(id), id)
	assert_true(p.has_status("vulnerable"), "marked: takes more damage")
	assert_true(p.has_status("slow") and p.has_status("attack_slow"), "the litany weighs on who stays")
	_steps(f, 2.0)
	assert_true(_casts(f, boss).has("nhazar_chorus"), "then the fan of voices")
	for id: String in ["nhazar_howl", "nhazar_masks", "nhazar_confession", "nhazar_chant"]:
		assert_false(_casts(f, boss).has(id), id + " not in phase 1")


func test_phase_2_confession_breaks_armour() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 30), 50000.0)
	_steps(f, 1.5)
	assert_true(_casts(f, boss).has("nhazar_confession"))
	assert_true(p.has_status("armor_break"))
	assert_true(p.has_status("weaken"))


func test_phase_3_chant_follows_him() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.3
	var p := f.player(1, Vector3(20, 0, 24), 500000.0)
	_steps(f, 3.0) # the choir, then the howl first (it is close)
	assert_true(_casts(f, boss).has("nhazar_chant"))
	_steps(f, 1.0)
	assert_true(p.has_status("slow"))
	assert_true(p.has_status("weaken"))


func test_chorus_pierces_everyone_in_line() -> void:
	var f := _fixture()
	_boss(f)
	var a := f.player(1, Vector3(20, 0, 26), 50000.0)
	var b := f.player(2, Vector3(20, 0, 29), 50000.0)
	_steps(f, 3.0)
	assert_true(a.has_status("weaken") or a.hp < 50000.0)
	assert_lt(b.hp, 50000.0, "the voices go through the first one")


func test_chain_slows_and_cracks_armour_in_melee() -> void:
	var f := _fixture()
	var boss := _boss(f)
	var p := f.player(1, Vector3(20, 0, 22.5), 50000.0)
	_steps(f, 3.0)
	assert_true(_casts(f, boss).has("nhazar_chain"))
	assert_true(p.has_status("armor_break"), "only the chain cracks armour in phase 1")


func test_phase_2_howl_stuns_who_stays() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 23), 50000.0)
	_steps(f, 0.2)
	assert_true(_casts(f, boss).has("nhazar_howl"), "close in phase 2: the howl first")
	var tele: Array = f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == "telegraph").back()
	assert_almost_eq(float(tele[3]), 8.0, 0.001, "8 m around it")
	_steps(f, 1.8)
	assert_true(p.has_status("stun"))


func test_phase_2_masks_rain_on_a_far_player() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	f.player(1, Vector3(20, 0, 30), 50000.0)
	_steps(f, 3.0)
	assert_true(_casts(f, boss).has("nhazar_masks"))


func test_phase_3_choir_once_and_archers() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.3
	f.player(1, Vector3(20, 0, 23), 500000.0)
	_steps(f, 3.0)
	assert_eq(_casts(f, boss).count("nhazar_choir"), 1)
	assert_true(boss.has_status("damage_reduction"))
	var called := f.world.monsters.values().filter(func(m: CombatEntity) -> bool: return m.type_id == "cult_archer" and m.is_alive())
	assert_eq(called.size(), 3, "3 cult archers")
