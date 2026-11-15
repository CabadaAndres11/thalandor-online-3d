extends GutTest

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))
	f.world.abilities = AbilityDB.load_default()


func _hero(class_id: String, id := 1, pos := Vector3(10, 0, 10)) -> PlayerState:
	var p := f.world.add_player(id, pos)
	ClassRules.setup_player(p, class_id)
	p.stats.crit_chance = 0.0
	p.resource_def["regen_per_s"] = 0.0 # exact resource numbers in these tests
	return p


func _target(pos := Vector3(10, 0, 11.5), hp := 1000.0) -> CombatEntity:
	var d := f.dummy(1000 + f.world.monsters.size(), pos, hp)
	d.stats.dodge_chance = 0.0
	return d


func _db() -> AbilityDB:
	return f.world.abilities


func test_setup_player_uses_class_stats_and_resource() -> void:
	var w := _hero("warrior")
	assert_eq(w.stats.max_hp, 200.0)
	assert_eq(w.hp, 200.0)
	assert_eq(w.resource_kind, "rage")
	assert_eq(w.resource, 0.0, "rage starts empty")
	var m := _hero("mage", 2)
	assert_eq(m.resource_kind, "mana")
	assert_eq(m.resource, m.stats.max_resource, "mana starts full")
	assert_eq(m.class_id, "mage")


func test_every_class_has_basic_secondary_and_a_level1_active() -> void:
	for c: String in ["warrior", "cleric", "mage", "archer", "assassin"]:
		assert_ne(_db().kind_of(c, "basic"), "", c + " basic")
		assert_ne(_db().kind_of(c, "secondary"), "", c + " secondary")
		assert_false(_db().actives(c).is_empty(), c + " actives")


func test_all_ability_files_validate() -> void:
	assert_eq(_db().validate(true), [] as Array[String])


func test_warrior_basic_secondary_level1() -> void:
	var w := _hero("warrior")
	var d := _target()
	assert_true(Combat.try_cast(f.world, w, "warrior_slash", d.position))
	assert_almost_eq(1000.0 - d.hp, (10 + 0.6 * 20) * (1.0 - Damage.mitigation(0, f.world.balance)), 0.01)
	assert_eq(w.resource, 8.0, "slash generates rage")
	assert_false(Combat.try_cast(f.world, w, "warrior_brutal", d.position), "brutal needs 30 rage")
	w.resource = 40.0
	var before := d.hp
	assert_true(Combat.try_cast(f.world, w, "warrior_brutal", d.position))
	assert_almost_eq(before - d.hp, 28 + 1.2 * 20, 0.01)
	assert_eq(w.resource, 40.0 - 30.0 + 8.0, "costs 30, the hit gives 8 back")


func test_warrior_charge_dashes_and_stuns() -> void:
	var w := _hero("warrior", 1, Vector3(5, 0, 10))
	var d := _target(Vector3(11, 0, 10))
	assert_true(Combat.try_cast(f.world, w, "warrior_charge", d.position))
	f.run(1.0)
	assert_lt(Effects.flat(w.position).distance_to(Effects.flat(d.position)), 2.0, "arrived next to it")
	assert_true(d.has_status("stun") or f.events_of("status").any(func(ev: Array) -> bool: return ev[2] == "stun"))


func test_cleric_basic_secondary_level1() -> void:
	var c := _hero("cleric")
	var d := _target(Vector3(10, 0, 15))
	Combat.try_cast(f.world, c, "cleric_smite", d.position)
	f.run(0.5)
	assert_almost_eq(1000.0 - d.hp, 9 + 0.6 * 20, 0.01)


func test_heal_targets_ally_under_cursor_else_self() -> void:
	var c := _hero("cleric")
	var ally := _hero("warrior", 2, Vector3(14, 0, 10))
	ally.hp = 100.0
	c.hp = 100.0
	assert_true(Combat.try_cast(f.world, c, "cleric_heal", Vector3(14.3, 0, 10)))
	assert_almost_eq(ally.hp, 100.0 + 25 + 1.0 * 20, 0.01, "the ally under the cursor")
	assert_eq(c.hp, 100.0)
	f.run(2.0)
	assert_true(Combat.try_cast(f.world, c, "cleric_heal", Vector3(30, 0, 30)))
	assert_almost_eq(c.hp, 145.0, 0.01, "nobody under the cursor: self")
	assert_eq(c.resource, c.stats.max_resource - 40.0, "two casts of 20 mana")


func test_heal_capped_at_max_hp() -> void:
	var c := _hero("cleric")
	c.hp = c.stats.max_hp - 5.0
	Combat.try_cast(f.world, c, "cleric_heal", Vector3(30, 0, 30))
	assert_eq(c.hp, c.stats.max_hp)


func test_shield_word_absorbs_and_expires() -> void:
	var c := _hero("cleric")
	assert_true(Combat.try_cast(f.world, c, "cleric_shield", Vector3(30, 0, 30)))
	assert_almost_eq(c.shield, 40 + 1.0 * 20, 0.01)
	f.run(8.5)
	assert_eq(c.shield, 0.0, "gone after 8 s")


func test_mage_basic_secondary_level1() -> void:
	var m := _hero("mage")
	var d := _target(Vector3(10, 0, 16))
	Combat.try_cast(f.world, m, "mage_missile", d.position)
	f.run(0.6)
	assert_almost_eq(1000.0 - d.hp, 10 + 0.7 * 20, 0.01)
	var hp := d.hp
	assert_true(Combat.try_cast(f.world, m, "mage_blast", d.position))
	f.run(0.3)
	assert_eq(d.hp, hp, "blast waits")
	f.run(0.5)
	assert_almost_eq(hp - d.hp, 26 + 1.1 * 20, 0.01)


func test_mage_blink() -> void:
	var m := _hero("mage")
	assert_true(Combat.try_cast(f.world, m, "mage_blink", Vector3(30, 0, 10)))
	assert_almost_eq(m.position.x, 18.0, 0.01, "8 m toward the cursor")


func test_archer_quick_shot_is_free() -> void:
	var a := _hero("archer")
	var d := _target(Vector3(10, 0, 18))
	a.resource = 50.0
	assert_true(ClassRules.release_charged(f.world, a, "archer_shot", d.position, 0.0))
	f.run(0.6)
	assert_eq(a.resource, 50.0)
	assert_almost_eq(1000.0 - d.hp, 9 + 0.6 * 20, 0.01)


func test_archer_charged_shot_costs_focus_and_scales() -> void:
	var a := _hero("archer")
	var d := _target(Vector3(10, 0, 18))
	a.resource = 50.0
	assert_true(ClassRules.release_charged(f.world, a, "archer_shot", d.position, 1.0))
	f.run(0.6)
	assert_eq(a.resource, 35.0, "full charge costs 15 focus")
	assert_almost_eq(1000.0 - d.hp, (9 + 0.6 * 20) * 2.2, 0.01)


func test_archer_charged_shot_without_focus_is_a_normal_shot() -> void:
	var a := _hero("archer")
	var d := _target(Vector3(10, 0, 18))
	a.resource = 5.0
	ClassRules.release_charged(f.world, a, "archer_shot", d.position, 1.0)
	f.run(0.6)
	assert_eq(a.resource, 5.0)
	assert_almost_eq(1000.0 - d.hp, 9 + 0.6 * 20, 0.01)


func test_archer_piercing_and_roll() -> void:
	var a := _hero("archer")
	var d1 := _target(Vector3(10, 0, 13))
	var d2 := _target(Vector3(10, 0, 16))
	assert_true(Combat.try_cast(f.world, a, "archer_piercing", Vector3(10, 0, 25)))
	f.run(1.0)
	assert_lt(d1.hp, 1000.0)
	assert_lt(d2.hp, 1000.0, "pierces")
	var z := a.position.z
	a.facing = 0.0
	assert_true(Combat.try_cast(f.world, a, "archer_roll", Vector3(10, 0, 25)))
	f.run(0.5)
	assert_lt(a.position.z, z - 4.0, "jumped back")


func test_assassin_stab_builds_combo_and_eviscerate_spends_it() -> void:
	var s := _hero("assassin")
	var d := _target()
	assert_false(Combat.try_cast(f.world, s, "assassin_eviscerate", d.position), "no combo points yet")
	assert_eq(s.resource, s.stats.max_resource, "refused without cost")
	for i in 3:
		Combat.try_cast(f.world, s, "assassin_stab", d.position)
		f.run(0.6)
	assert_eq(s.combo, 3)
	s.resource = 100.0
	var before := d.hp
	assert_true(Combat.try_cast(f.world, s, "assassin_eviscerate", d.position))
	assert_almost_eq(before - d.hp, (12 + 0.4 * 20) * 3, 0.01)
	assert_eq(s.combo, 0)


func test_combo_caps_at_five_and_needs_a_hit() -> void:
	var s := _hero("assassin")
	Combat.try_cast(f.world, s, "assassin_stab", Vector3(10, 0, 20))
	assert_eq(s.combo, 0, "missed: no point")
	var d := _target()
	for i in 7:
		Combat.try_cast(f.world, s, "assassin_stab", d.position)
		f.run(0.6)
	assert_eq(s.combo, 5)


func test_assassin_shadowstep() -> void:
	var s := _hero("assassin")
	var d := _target(Vector3(10, 0, 18))
	assert_true(Combat.try_cast(f.world, s, "assassin_shadowstep", d.position))
	assert_gt(s.position.z, 15.0)
