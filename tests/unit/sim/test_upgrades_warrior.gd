extends GutTest
## The warrior's level 50 upgrades (Protector and Berserker) with the numbers of the plan.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String, hp := -1.0) -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "warrior", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = 100.0
	p.resource_def["decay_per_s"] = 0.0
	p.resource_def["gain_per_hit"] = 0.0
	if hp > 0.0:
		p.hp = hp
	return p


func _foe(id: int, pos: Vector3, hp := 5000.0) -> CombatEntity:
	var d := f.dummy(id, pos, hp)
	d.stats.dodge_chance = 0.0
	return d


func _cultist(pos: Vector3) -> MonsterState:
	var m := MonsterDB.load_default().make("cultist", f.world.next_monster_id(), pos, f.world)
	f.world.add_entity(m)
	return m


func _passive(id: String) -> Dictionary:
	return f.world.abilities.get_ability(id).passive[0]


# --- Protector ---------------------------------------------------------------------------

func test_mass_taunt() -> void:
	var p := _hero("protector")
	var a := _cultist(Vector3(18, 0, 10)) # 8 m
	var b := _cultist(Vector3(30, 0, 30)) # out of range
	a.add_threat(99, 100.0)
	a.add_threat(p.id, 50.0)
	assert_true(Combat.try_cast(f.world, p, "warrior_mass_taunt", p.position))
	assert_eq(p.resource, 80.0)
	assert_true(a.has_status("taunted"))
	assert_eq(a.statuses[0].end_tick, f.world.tick + f.world.ticks(6.0))
	assert_eq(a.threat[p.id], 150.0, "50 x 3 beats 100 x 1.1")
	assert_eq(a.target_id, p.id)
	assert_false(b.has_status("taunted"))
	assert_eq(p.cooldowns["warrior_mass_taunt"], f.world.tick + f.world.ticks(20.0))


func test_retaliation() -> void:
	var p := _hero("protector")
	var foe := _foe(2000, Vector3(11, 0, 10), 5000.0)
	assert_true(Combat.try_cast(f.world, p, "warrior_retaliation", p.position))
	assert_eq(p.resource, 75.0)
	assert_almost_eq(p.shield, 40.0 + 2.0 * p.stats.attack_power, 0.01)
	var before := p.shield
	Combat.deal(f.world, foe, p, {"damage": {"base": 60, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_almost_eq(5000.0 - foe.hp, 30.0, 0.01, "half of what the shield absorbed")
	assert_almost_eq(p.shield, before - 60.0, 0.01)
	assert_eq(p.cooldowns["warrior_retaliation"], f.world.tick + f.world.ticks(30.0))


func test_defensive_stance() -> void:
	var base := _hero("")
	var hp := base.stats.max_hp
	f.world.players.clear()
	var p := _hero("protector")
	assert_almost_eq(p.stats.max_hp, hp * 1.15, 0.01)
	assert_almost_eq(p.stats.threat_mult, 2.0, 0.001, "+100 % threat")


func test_last_stand() -> void:
	var p := _hero("protector")
	var h := Passives.has_hook(p, "low_hp_guard")
	assert_eq([h.below_pct, h.reduction, h.duration_s, h.cooldown_s], [0.2, 0.4, 8.0, 60.0])
	p.hp = p.stats.max_hp * 0.19
	var foe := _foe(2000, Vector3(11, 0, 10))
	Combat.deal(f.world, foe, p, {"damage": {"base": 5, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_almost_eq(p.status_magnitude("damage_reduction"), 0.4, 0.001)


func test_shield_wall_evolution() -> void:
	var p := _hero("protector")
	var near := f.player(2, Vector3(16, 0, 10), 100.0)
	var far := f.player(3, Vector3(25, 0, 10), 100.0)
	assert_true(Combat.try_cast(f.world, p, "warrior_shield_wall", p.position))
	assert_almost_eq(p.status_magnitude("damage_reduction"), 0.5, 0.001)
	assert_almost_eq(near.status_magnitude("damage_reduction"), 0.5, 0.001, "an ally at 6 m")
	assert_eq(far.status_magnitude("damage_reduction"), 0.0)
	f.world.players.erase(2)
	var plain := _hero("berserker")
	plain.cooldowns.clear()
	assert_true(Combat.try_cast(f.world, plain, "warrior_shield_wall", plain.position))


# --- Berserker ---------------------------------------------------------------------------

func test_frenzy() -> void:
	var p := _hero("berserker")
	assert_true(Combat.try_cast(f.world, p, "warrior_frenzy", p.position))
	assert_eq(p.resource, 100.0, "free")
	assert_almost_eq(p.status_magnitude("damage_buff"), 0.25, 0.001)
	assert_almost_eq(p.status_magnitude("haste"), 0.3, 0.001)
	assert_almost_eq(p.status_magnitude("vulnerable"), 0.15, 0.001)
	assert_eq(p.statuses[0].end_tick, f.world.tick + f.world.ticks(10.0))
	assert_eq(p.cooldowns["warrior_frenzy"], f.world.tick + f.world.ticks(45.0))
	assert_eq(p.gcd_end, 0, "no global cooldown")


func test_execute() -> void:
	var p := _hero("berserker")
	var healthy := _foe(2000, Vector3(10, 0, 11.5), 5000.0)
	assert_true(Combat.try_cast(f.world, p, "warrior_execute", healthy.position))
	var base := 20.0 + 1.5 * p.stats.attack_power
	var armor := 1.0 - Damage.mitigation(healthy.stats.armor, f.world.balance)
	assert_almost_eq(5000.0 - healthy.hp, base * armor, 0.01)
	assert_eq(p.resource, 70.0)
	p.cooldowns.clear()
	p.gcd_end = 0
	healthy.hp = 1000.0 # 20 %
	assert_true(Combat.try_cast(f.world, p, "warrior_execute", healthy.position))
	assert_almost_eq(1000.0 - healthy.hp, base * 2.5 * armor, 0.01, "x 2.5 below 25 %")


func test_execute_refunds_on_kill() -> void:
	var p := _hero("berserker")
	var weak := _foe(2000, Vector3(10, 0, 11.5), 30.0)
	assert_true(Combat.try_cast(f.world, p, "warrior_execute", weak.position))
	assert_false(weak.is_alive())
	assert_eq(p.resource, 100.0)
	assert_eq(f.world.abilities.get_ability("warrior_execute").range, 2.5)


func test_blood_fury() -> void:
	var p := _hero("berserker")
	assert_eq(Passives.has_hook(p, "damage_per_missing_hp").max_pct, 0.25)
	var foe := _foe(2000, Vector3(11, 0, 10))
	var spec := {"base": 100, "coef": 0, "kind": "magic", "can_crit": false}
	var full: float = Damage.roll(p, foe, spec, f.world).amount
	p.hp = p.stats.max_hp * 0.2
	var low: float = Damage.roll(p, foe, spec, f.world).amount
	assert_almost_eq(low / full, 1.0 + 0.25 * 0.8, 0.001)


func test_massacre() -> void:
	var p := _hero("berserker")
	var h := Passives.has_hook(p, "on_kill")
	assert_eq([h.reset_cooldown, h.heal_pct], ["warrior_charge", 0.05])
	var foe := _foe(2000, Vector3(11, 0, 10), 10.0)
	p.cooldowns["warrior_charge"] = f.world.tick + 999
	p.hp = 100.0
	Combat.deal(f.world, p, foe, {"damage": {"base": 50, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_false(p.cooldowns.has("warrior_charge"))
	assert_almost_eq(p.hp, 100.0 + p.stats.max_hp * 0.05, 0.01)


func test_slash_evolution() -> void:
	var p := _hero("berserker")
	var foe := _foe(2000, Vector3(10, 0, 11.5))
	assert_true(Combat.try_cast(f.world, p, "warrior_slash", foe.position))
	f.run(0.5)
	var armor := 1.0 - Damage.mitigation(foe.stats.armor, f.world.balance)
	var one := (7.0 + 0.42 * p.stats.attack_power) * armor
	assert_almost_eq(5000.0 - foe.hp, 2.0 * one, 0.01, "two hits at 70 % each")
	assert_almost_eq(one, 0.7 * (10.0 + 0.6 * p.stats.attack_power) * armor, 0.01)
	f.world.players.clear()
	var plain := _hero("protector")
	var foe2 := _foe(2001, Vector3(10, 0, 11.5))
	assert_true(Combat.try_cast(f.world, plain, "warrior_slash", foe2.position))
	f.run(0.5)
	assert_almost_eq(5000.0 - foe2.hp, (10.0 + 0.6 * plain.stats.attack_power) * armor, 0.01, "without it, one hit")


# --- Shape --------------------------------------------------------------------------------

func test_each_upgrade_is_complete_and_only_its_own_abilities_work() -> void:
	for id: String in ["protector", "berserker"]:
		var u := f.world.upgrades.upgrade(id)
		assert_eq(u.actives.size(), 2)
		assert_eq(u.passives.size(), 2)
		assert_false(u.evolves.is_empty())
	var p := _hero("protector")
	assert_false(Combat.try_cast(f.world, p, "warrior_frenzy", p.position), "another upgrade's ability")
	var q := _hero("")
	assert_false(Combat.try_cast(f.world, q, "warrior_mass_taunt", q.position), "needs its upgrade")


func test_new_abilities_have_texts_and_icons() -> void:
	for id: String in ["warrior_mass_taunt", "warrior_retaliation", "warrior_defensive_stance", "warrior_last_stand",
			"warrior_frenzy", "warrior_execute", "warrior_blood_fury", "warrior_massacre"]:
		var a := f.world.abilities.get_ability(id)
		assert_eq(int(a.level), 50, id)
		assert_ne(tr(str(a.name)), str(a.name), id)
		assert_ne(tr(str(a.desc)), str(a.desc), id)
		assert_true(ResourceLoader.exists(CombatHud.ICON_DIR % a.icon), id)
	for key: String in ["UP_PROTECTOR_EVO", "UP_BERSERKER_EVO"]:
		assert_ne(tr(key), key)
