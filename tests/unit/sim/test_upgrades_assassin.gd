extends GutTest
## The assassin's level 50 upgrades (Shadow and Venomancer).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String, pos := Vector3(10, 0, 10)) -> PlayerState:
	var p := f.world.add_player(1, pos)
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "assassin", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	return p


func _foe(id: int, pos: Vector3, hp := 50000.0) -> CombatEntity:
	var d := f.dummy(id, pos, hp)
	d.stats.dodge_chance = 0.0
	return d


# --- Shadow ------------------------------------------------------------------------------

func test_vanish() -> void:
	var p := _hero("shadow")
	p.last_combat_tick = f.world.tick # in combat
	assert_true(p.in_combat(f.world))
	var speed := p.move_mult()
	assert_true(Combat.try_cast(f.world, p, "assassin_vanish", p.position), "usable in combat")
	assert_eq(p.resource, p.stats.max_resource, "free")
	assert_eq(p.gcd_end, 0, "no global cooldown")
	assert_eq(p.cooldowns["assassin_vanish"], f.world.tick + f.world.ticks(60.0))
	assert_true(p.has_status("stealth"))
	assert_false(p.in_combat(f.world), "it leaves combat")
	var stealth: StatusEffect = p.statuses.filter(func(s: StatusEffect) -> bool: return s.kind == "stealth")[0]
	assert_eq(stealth.end_tick, f.world.tick + f.world.ticks(8.0 * 1.5), "8 s, +50 % from Velo")
	assert_almost_eq(p.move_mult(), speed * 1.3, 0.0001)
	f.run(3.2)
	assert_almost_eq(p.move_mult(), speed, 0.0001, "the speed lasts 3 s")


func test_shadow_strike() -> void:
	var p := _hero("shadow")
	p.passives = p.passives.filter(func(m: Dictionary) -> bool: return m.get("hook") != "back_damage_pct")
	var foe := _foe(2000, Vector3(10, 0, 18))
	assert_true(Combat.try_cast(f.world, p, "assassin_shadow_strike", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 40.0)
	assert_eq(p.cooldowns["assassin_shadow_strike"], f.world.tick + f.world.ticks(15.0))
	assert_lt(p.position.z, foe.position.z, "behind the target")
	assert_lt(Effects.flat(p.position).distance_to(Effects.flat(foe.position)), 2.0)
	assert_almost_eq(50000.0 - foe.hp, (20.0 + 1.6 * p.stats.attack_power) * f.world.balance.crit_multiplier, 0.01, "a sure crit")
	assert_eq(p.combo, 2)


func test_shadow_strike_range_is_12() -> void:
	var p := _hero("shadow")
	var far := _foe(2000, Vector3(10, 0, 30))
	assert_false(Combat.try_cast(f.world, p, "assassin_shadow_strike", far.position))
	assert_eq(p.resource, p.stats.max_resource)


func test_born_killer() -> void:
	var p := _hero("shadow")
	var h := Passives.has_hook(p, "bonus_vs_low_hp")
	assert_eq([h.below_pct, h.pct], [0.3, 0.2])
	var foe := _foe(2000, Vector3(11, 0, 10), 1000.0)
	var spec := {"base": 100, "coef": 0, "kind": "magic", "can_crit": false}
	var full: float = Damage.roll(p, foe, spec, f.world).amount
	foe.hp = 250.0
	var low: float = Damage.roll(p, foe, spec, f.world).amount
	assert_almost_eq(low / full, 1.2, 0.001)


func test_veil() -> void:
	var p := _hero("shadow")
	assert_eq(Passives.has_hook(p, "stealth_duration_pct").pct, 0.5)
	assert_true(Combat.try_cast(f.world, p, "assassin_stealth", p.position))
	var stealth: StatusEffect = p.statuses[0]
	assert_eq(stealth.end_tick, f.world.tick + f.world.ticks(30.0), "20 s x 1.5")


func test_eviscerate_evolution() -> void:
	var p := _hero("shadow")
	var foe := _foe(2000, Vector3(10, 0, 11.5))
	p.combo = 3
	assert_true(Combat.try_cast(f.world, p, "assassin_eviscerate", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 35.0 + 24.0, "8 energy per combo point spent")
	assert_eq(p.combo, 0)
	f.world.players.clear()
	var plain := _hero("venomancer")
	plain.combo = 3
	assert_true(Combat.try_cast(f.world, plain, "assassin_eviscerate", foe.position))
	assert_eq(plain.resource, plain.stats.max_resource - 35.0, "no refund without the upgrade")


# --- Venomancer --------------------------------------------------------------------------

func test_toxic_cloud() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(10, 0, 20))
	var out := _foe(2001, Vector3(10, 0, 27))
	assert_true(Combat.try_cast(f.world, p, "assassin_toxic_cloud", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 35.0)
	assert_eq(p.cooldowns["assassin_toxic_cloud"], f.world.tick + f.world.ticks(20.0))
	assert_eq(foe.status_stacks("poison"), 1, "one stack on the first pulse")
	f.run(7.2)
	assert_eq(foe.status_stacks("poison"), 8, "one more every second")
	assert_false(out.has_status("poison"))
	assert_eq(f.world.pending_areas.size(), 0)


func test_contagion() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(10, 0, 20), 50.0)
	var near := _foe(2001, Vector3(14, 0, 20))
	var far := _foe(2002, Vector3(25, 0, 20))
	Combat.apply_status(f.world, p, foe, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1, "stacks": 3, "max_stacks": 5})
	assert_true(Combat.try_cast(f.world, p, "assassin_contagion", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 25.0)
	assert_eq(p.cooldowns["assassin_contagion"], f.world.tick + f.world.ticks(25.0))
	assert_eq(foe.status_magnitude("contagion"), 6.0)
	Combat.deal(f.world, p, foe, {"damage": {"base": 999, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_false(foe.is_alive())
	assert_eq(near.status_stacks("poison"), 3, "6 m: its poison jumped")
	assert_false(far.has_status("poison"))


func test_contagion_without_poison_spreads_nothing() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(10, 0, 20), 50.0)
	var near := _foe(2001, Vector3(14, 0, 20))
	assert_true(Combat.try_cast(f.world, p, "assassin_contagion", foe.position))
	Combat.deal(f.world, p, foe, {"damage": {"base": 999, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_false(near.has_status("poison"))


func test_toxicology() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	for i in 14:
		Combat.apply_status(f.world, p, foe, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1, "max_stacks": 5})
	assert_eq(foe.status_stacks("poison"), 10)
	f.world.players.clear()
	var q := _hero("shadow")
	var foe2 := _foe(2001, Vector3(21, 0, 10))
	for i in 14:
		Combat.apply_status(f.world, q, foe2, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1, "max_stacks": 5})
	assert_eq(foe2.status_stacks("poison"), 5)


func test_corrupt_blood() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	Combat.apply_status(f.world, p, foe, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1})
	assert_almost_eq(foe.status_magnitude("weaken"), 0.1, 0.001)
	Combat.deal(f.world, foe, p, {"damage": {"base": 100, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_almost_eq(p.stats.max_hp - p.hp, 90.0, 0.01, "its hits do 10 % less")


func test_stab_evolution_always_poisons() -> void:
	var p := _hero("venomancer")
	var foe := _foe(2000, Vector3(10, 0, 11.5))
	assert_true(Combat.try_cast(f.world, p, "assassin_stab", foe.position))
	assert_eq(foe.status_stacks("poison"), 1)
	p.cooldowns.clear()
	assert_true(Combat.try_cast(f.world, p, "assassin_stab", foe.position))
	assert_eq(foe.status_stacks("poison"), 2)
	f.world.players.clear()
	var q := _hero("shadow", Vector3(30, 0, 10))
	var foe2 := _foe(2001, Vector3(30, 0, 11.5))
	assert_true(Combat.try_cast(f.world, q, "assassin_stab", foe2.position))
	assert_false(foe2.has_status("poison"), "without the evolution it only poisons when envenomed")


# --- Shape --------------------------------------------------------------------------------

func test_speed_buff_is_described() -> void:
	assert_ne(tr("DETAIL_ST_SPEED_BUFF"), "DETAIL_ST_SPEED_BUFF")
	var lines := AbilityDetails.lines(f.world.abilities.get_ability("assassin_vanish"), CombatStats.new(), "energy")
	assert_gt(lines.size(), 2)


func test_each_upgrade_is_complete_with_texts_and_icons() -> void:
	for id: String in ["shadow", "venomancer"]:
		var u := f.world.upgrades.upgrade(id)
		assert_eq(u.actives.size(), 2)
		assert_eq(u.passives.size(), 2)
		assert_false(u.evolves.is_empty())
		for aid: String in u.actives + u.passives:
			var a := f.world.abilities.get_ability(aid)
			assert_eq(int(a.level), 50, aid)
			assert_ne(tr(str(a.name)), str(a.name), aid)
			assert_ne(tr(str(a.desc)), str(a.desc), aid)
			assert_true(ResourceLoader.exists(CombatHud.ICON_DIR % a.icon), aid)
		assert_ne(tr(str(u.evolves.desc)), str(u.evolves.desc))
	assert_eq(f.world.upgrades.validate(f.world.abilities, true), [] as Array[String], "every upgrade of every class is complete")
