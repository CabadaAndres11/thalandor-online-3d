extends GutTest

var f: CombatFixture
var b: Balance


func before_each() -> void:
	f = CombatFixture.new()
	b = f.world.balance


func _hero(class_id: String, level := 1) -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	return p


func _class_def(id: String) -> Dictionary:
	return CharacterCatalog.load_default().class_def(id)


func test_free_points() -> void:
	var pr := PlayerProgress.new()
	assert_eq(Attributes.free_points(pr, b), 0)
	pr.level = 11
	assert_eq(Attributes.free_points(pr, b), 50)
	assert_true(Attributes.spend(pr, "strength", b))
	assert_true(Attributes.spend(pr, "strength", b))
	assert_true(Attributes.spend(pr, "spirit", b))
	assert_eq(Attributes.free_points(pr, b), 47)
	assert_eq(pr.attributes.strength, 2)


func test_spend_rejects_without_points() -> void:
	var pr := PlayerProgress.new()
	assert_false(Attributes.spend(pr, "strength", b))
	assert_eq(pr.attributes.strength, 0)


func test_spend_rejects_unknown_attribute() -> void:
	var pr := PlayerProgress.new()
	pr.level = 5
	assert_false(Attributes.spend(pr, "luck", b))
	assert_false(pr.attributes.has("luck"))
	assert_eq(Attributes.free_points(pr, b), 20)


func test_every_attribute_grows_five_per_level() -> void:
	var pr := PlayerProgress.new()
	pr.level = 11
	var t := Attributes.totals(pr, _class_def("warrior"), b)
	for a: String in PlayerProgress.ATTRIBUTES:
		assert_eq(t[a], 50, a)
	pr.attributes.agility = 3
	assert_eq(Attributes.totals(pr, _class_def("archer"), b).agility, 53)


func test_effective_soft_caps() -> void:
	assert_almost_eq(Attributes.effective(200, b), 200.0, 0.001)
	assert_almost_eq(Attributes.effective(300, b), 250.0, 0.001)
	assert_almost_eq(Attributes.effective(600, b), 375.0, 0.001)
	assert_almost_eq(Attributes.effective(0, b), 0.0, 0.001)


func test_strength_gives_attack_and_block() -> void:
	var p := _hero("warrior")
	p.progress.attributes.strength = 100
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.attack_power, 20.0 + 50.0, 0.001)
	assert_almost_eq(p.stats.block_chance, 0.2, 0.0001)


func test_archer_attack_from_agility() -> void:
	var p := _hero("archer")
	p.progress.attributes.agility = 100
	p.progress.attributes.strength = 100
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.attack_power, 20.0 + 50.0, 0.001)
	assert_almost_eq(p.stats.crit_chance, 0.05 + 0.05, 0.0001)
	assert_almost_eq(p.stats.dodge_chance, 0.05 + 0.03, 0.0001)


func test_intellect_stamina_spirit() -> void:
	var p := _hero("mage")
	p.progress.attributes.intellect = 100
	p.progress.attributes.stamina = 10
	p.progress.attributes.spirit = 100
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.spell_power, 20.0 + 50.0, 0.001)
	assert_almost_eq(p.stats.max_resource, 160.0 + 200.0, 0.001)
	assert_almost_eq(p.stats.max_hp, 130.0 + 50.0, 0.001)
	assert_almost_eq(p.stats.hp_regen, 5.0, 0.001)
	assert_almost_eq(p.stats.resource_regen_add, 3.0, 0.001)


func test_caps() -> void:
	var p := _hero("archer")
	p.progress.attributes.agility = 100000
	p.progress.attributes.strength = 100000
	Progression.rebuild(p, f.world)
	assert_true(p.stats.crit_chance <= 0.4 + 1e-6)
	assert_true(p.stats.dodge_chance <= 0.25 + 1e-6)
	assert_true(p.stats.block_chance <= 0.3 + 1e-6)
	f.world.abilities = AbilityDB.from_list([{"id": "pa", "class": "archer", "kind": "passive", "level": 1,
		"passive": [{"type": "stat", "stat": "cooldown_reduction_add", "value": 5.0}]}])
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.cooldown_reduction, 0.4, 0.0001)


func test_percent_bonuses_add_then_multiply() -> void:
	var p := _hero("warrior")
	f.world.abilities = AbilityDB.from_list([
		{"id": "pa", "class": "warrior", "kind": "passive", "level": 1, "passive": [{"type": "stat", "stat": "max_hp_pct", "value": 0.1}]},
		{"id": "pb", "class": "warrior", "kind": "passive", "level": 1, "passive": [{"type": "stat", "stat": "max_hp_pct", "value": 0.1}]},
		{"id": "pc", "class": "warrior", "kind": "passive", "level": 1, "passive": [{"type": "stat", "stat": "max_hp_add", "value": 20}]}])
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.max_hp, (200.0 + 20.0) * 1.2, 0.001)


func test_rebuild_keeps_hp_ratio() -> void:
	var p := _hero("warrior")
	p.hp = p.stats.max_hp * 0.5
	p.progress.attributes.stamina = 20
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.max_hp, 300.0, 0.001)
	assert_almost_eq(p.hp, 150.0, 0.001)


func test_rebuild_keeps_resource_ratio() -> void:
	var p := _hero("mage")
	p.resource = 80.0
	p.progress.attributes.intellect = 50
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.resource / p.stats.max_resource, 0.5, 0.001)


func test_rebuild_keeps_statuses_and_cooldowns() -> void:
	var p := _hero("warrior")
	p.add_status(StatusEffect.make("slow", f.world.tick + 300, 0.3), 1)
	p.cooldowns["warrior_charge"] = 500
	p.gcd_end = 77
	p.position = Vector3(9, 0, 9)
	p.progress.level = 4
	Progression.rebuild(p, f.world)
	assert_true(p.has_status("slow"))
	assert_eq(p.cooldowns["warrior_charge"], 500)
	assert_eq(p.gcd_end, 77)
	assert_eq(p.position, Vector3(9, 0, 9))
	assert_eq(p.level, 4)


func test_rebuild_at_zero_hp_stays_downed() -> void:
	var p := _hero("warrior")
	p.hp = 0.0
	p.life = CombatEntity.DOWNED
	p.progress.attributes.stamina = 10
	Progression.rebuild(p, f.world)
	assert_eq(p.hp, 0.0)
	assert_eq(p.life, CombatEntity.DOWNED)


func test_rebuild_does_not_heal_a_wounded_player_to_full() -> void:
	var p := _hero("warrior")
	p.hp = 1.0
	p.progress.level = 30
	Progression.rebuild(p, f.world)
	assert_lt(p.hp, 5.0)
	assert_gt(p.hp, 0.0)


func test_fresh_player_is_full() -> void:
	var p := _hero("warrior")
	assert_eq(p.hp, p.stats.max_hp)
	assert_eq(p.resource, 0.0, "rage starts empty")
	var m := f.world.add_player(2, Vector3(7, 0, 5))
	ClassRules.setup_player(m, "mage", null, f.world)
	assert_eq(m.resource, m.stats.max_resource)


func test_villager_keeps_points_on_class_choice() -> void:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = 6
	p.progress.attributes.strength = 7
	ClassRules.setup_player(p, "villager", null, f.world)
	ClassRules.setup_player(p, "warrior", null, f.world)
	assert_eq(p.progress.attributes.strength, 7)
	assert_eq(p.class_id, "warrior")
	assert_almost_eq(p.stats.attack_power, 20.0 + 0.5 * (7 + 25), 0.001)


func test_block_halves_melee_physical_only() -> void:
	var a := CombatEntity.new()
	a.team = CombatEntity.TEAM_MONSTERS
	a.stats = CombatStats.from_dict({"attack_power": 10, "crit_chance": 0})
	var t := CombatEntity.new()
	t.stats = CombatStats.from_dict({"max_hp": 100})
	t.stats.block_chance = 1.0
	t.position = Vector3(1, 0, 0)
	var spec := {"base": 100.0, "kind": "physical", "can_crit": false}
	f.world.balance.damage_variance = 0.0
	var close := Damage.roll(a, t, spec, f.world)
	assert_true(close.blocked)
	assert_almost_eq(close.amount, 50.0, 0.01)
	var magic := Damage.roll(a, t, {"base": 100.0, "kind": "magic", "can_crit": false}, f.world)
	assert_false(magic.blocked)
	assert_almost_eq(magic.amount, 100.0, 0.01)
	a.position = Vector3(10, 0, 0)
	var far := Damage.roll(a, t, spec, f.world)
	assert_false(far.blocked, "ranged physical is not blocked")
	var arc := Damage.roll(a, t, spec, f.world, true)
	assert_true(arc.blocked, "a melee arc is blocked at any distance")


func test_block_event_from_deal() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	p.stats.block_chance = 1.0
	var m := f.dummy(2000, Vector3(6, 0, 5))
	m.stats.crit_chance = 0.0
	Combat.deal(f.world, m, p, {"type": "melee_arc", "damage": {"base": 40.0, "kind": "physical", "can_crit": false}}, {})
	assert_true(f.world.events.any(func(e: Array) -> bool: return e == ["block", 1]))
	assert_almost_eq(p.hp, 80.0, 0.01)


func test_cooldown_reduction_shortens_recharge() -> void:
	f.world.abilities = AbilityDB.from_list([{"id": "x", "class": "test", "kind": "active", "cost": 0, "cooldown_s": 10.0,
		"gcd": false, "range": 30, "effects": [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 1, "kind": "physical"}}]}])
	var p := f.player(1, Vector3(5, 0, 5))
	p.stats.cooldown_reduction = 0.5
	assert_true(Combat.try_cast(f.world, p, "x", Vector3(6, 0, 5)))
	assert_eq(p.cooldowns["x"] - f.world.tick, f.world.ticks(5.0))


func test_lifesteal_heals_attacker() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	p.stats.lifesteal = 0.5
	p.stats.crit_chance = 0.0
	p.hp = 10.0
	var t := f.dummy(2000, Vector3(6, 0, 5), 1000.0)
	Combat.deal(f.world, p, t, {"damage": {"base": 40.0, "kind": "physical", "can_crit": false}}, {})
	assert_almost_eq(p.hp, 10.0 + 20.0, 0.01)


func test_crit_damage_adds_to_multiplier() -> void:
	var a := CombatEntity.new()
	a.stats = CombatStats.from_dict({"crit_chance": 1.0})
	a.stats.crit_damage = 0.5
	var t := CombatEntity.new()
	t.team = CombatEntity.TEAM_MONSTERS
	t.stats = CombatStats.from_dict({})
	f.world.balance.damage_variance = 0.0
	var r := Damage.roll(a, t, {"base": 100.0, "kind": "magic"}, f.world)
	assert_almost_eq(r.amount, 100.0 * (f.world.balance.crit_multiplier + 0.5), 0.01)


func test_hp_regen_out_of_combat() -> void:
	var p := f.player(1, Vector3(5, 0, 5), 100.0)
	p.stats.hp_regen = 2.0
	p.hp = 10.0
	f.run(2.0)
	assert_almost_eq(p.hp, 14.0, 0.2)
	p.last_combat_tick = f.world.tick
	var before := p.hp
	f.run(1.0)
	assert_almost_eq(p.hp, before, 0.01)
