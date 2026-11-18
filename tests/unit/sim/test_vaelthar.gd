extends GutTest
## Vaelthar, the First Apostle: a boss whose attacks come from data ("specials" by phase,
## "phase_abilities" once per phase) on top of the boss rules.


func _fixture() -> CombatFixture:
	var f := CombatFixture.new([], Vector2i(48, 48))
	f.world.abilities = AbilityDB.load_default()
	return f


func _boss(f: CombatFixture, pos := Vector3(20, 0, 20)) -> MonsterState:
	var m := MonsterDB.load_default().make("vaelthar", f.world.next_monster_id(), pos, f.world)
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


func test_data_is_a_strong_boss() -> void:
	var d := MonsterDB.load_default().get_type("vaelthar")
	var acolyte := MonsterDB.load_default().get_type("cult_acolyte")
	assert_eq(d.behavior, "boss")
	assert_true(bool(d.get("boss", false)), "boss bar at the top of the screen")
	assert_gt(float(d.stats.max_hp), float(acolyte.stats.max_hp) * 3.0)
	assert_gt(float(d.stats.attack_power), float(acolyte.stats.attack_power))
	var abilities := AbilityDB.load_default()
	var ids: Array = d.abilities + d.specials.map(func(s: Dictionary) -> String: return s.ability) + d.phase_abilities.values()
	assert_eq(ids.size(), 6)
	for id: String in ids:
		assert_true(abilities.has(id), id)
		var ab := abilities.get_ability(id)
		assert_ne(tr(str(ab.name)), str(ab.name), id + " name translated")
		assert_ne(tr(str(ab.desc)), str(ab.desc), id + " description translated")
	assert_eq(tr("MON_VAELTHAR"), "Vaelthar, Primer Apóstol")


func test_phase_1_uses_tentacles_and_tears_at_range() -> void:
	var f := _fixture()
	var boss := _boss(f)
	f.player(1, Vector3(20, 0, 28), 50000.0) # 8 m away
	_steps(f, 1.0)
	var casts := _casts(f, boss)
	assert_true(casts.has("vaelthar_embrace"), "the tentacles come up under the player")
	assert_false(casts.has("vaelthar_halo"), "no halo in phase 1")
	assert_false(casts.has("vaelthar_pool"), "no pool in phase 1")
	var tele := f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == "telegraph")
	assert_eq(tele.size(), 1, "the embrace is warned")
	_steps(f, 3.0)
	assert_true(_casts(f, boss).has("vaelthar_tears"), "then the tears")


func test_embrace_roots_who_stays() -> void:
	var f := _fixture()
	_boss(f)
	var p := f.player(1, Vector3(20, 0, 28), 50000.0)
	_steps(f, 1.4)
	assert_lt(p.hp, 50000.0)
	assert_true(p.has_status("root"), "held by the tentacles")


func test_lash_bleeds_in_melee() -> void:
	var f := _fixture()
	_boss(f)
	var p := f.player(1, Vector3(20, 0, 22), 50000.0)
	_steps(f, 0.5)
	assert_lt(p.hp, 50000.0)
	assert_true(p.has_status("bleed"))


func test_phase_2_halo_up_close_can_be_escaped() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 22), 50000.0)
	for i in f.world.ticks(2.0):
		_step(f)
		if _casts(f, boss).has("vaelthar_halo"):
			break
	assert_true(_casts(f, boss).has("vaelthar_halo"), "close in phase 2: the halo first")
	var tele: Array = f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == "telegraph").back()
	assert_almost_eq(float(tele[3]), 7.0, 0.001, "7 m around it")
	assert_almost_eq(Effects.flat(tele[2]).distance_to(Effects.flat(boss.position)), 0.0, 0.01, "centred on itself")
	var where := boss.position
	p.position = Vector3(20, 0, 30) # run out
	var hp := p.hp
	_steps(f, 2.1)
	assert_almost_eq(Effects.flat(boss.position).distance_to(Effects.flat(where)), 0.0, 0.01, "it stands still while it warns")
	assert_false(p.has_status("weaken"), "out of the halo")
	assert_true(hp - p.hp < 60.0, "only the tears or tentacles could reach that far")


func test_phase_2_halo_hits_who_stays() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 22), 50000.0)
	_steps(f, 2.5)
	assert_true(p.has_status("weaken"))


func test_phase_3_fervor_once_and_calls() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.3
	f.player(1, Vector3(20, 0, 22), 500000.0)
	_steps(f, 3.0)
	assert_eq(_casts(f, boss).count("vaelthar_fervor"), 1, "once when phase 3 starts")
	assert_true(boss.has_status("haste"))
	assert_true(boss.has_status("damage_buff"))
	var called := f.world.monsters.values().filter(func(m: CombatEntity) -> bool: return m.type_id == "cultist" and m.is_alive())
	assert_eq(called.size(), 4, "4 cultists")


func test_fervor_again_after_a_reset() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.3
	f.player(1, Vector3(20, 0, 22), 500000.0)
	_steps(f, 0.5)
	assert_eq(boss.phase_casts, [3])
	MonsterAI._start_return(boss)
	boss.position = boss.home
	_steps(f, 0.2)
	assert_eq(boss.phase_casts, [], "forgotten at home")
	assert_false(boss.has_status("haste"))
