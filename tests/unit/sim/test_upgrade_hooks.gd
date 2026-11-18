extends GutTest
## The passive hooks of the class upgrades, one test each (the name is the hook).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))


func _hook(name: String, params := {}) -> Dictionary:
	var h := {"type": "hook", "hook": name}
	h.merge(params)
	return h


func _dmg(base: float, extra := {}) -> Dictionary:
	var d := {"base": base, "coef": 0, "kind": "magic", "can_crit": false}
	d.merge(extra, true)
	return d


func _pair(hooks: Array) -> Array:
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	p.passives = hooks
	var t := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	return [p, t]


func test_damage_per_missing_hp() -> void:
	var s := _pair([_hook("damage_per_missing_hp", {"max_pct": 0.25})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 100.0, 0.001, "full health: no bonus")
	p.hp = 20.0
	t.hp = 1000.0
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 100.0 * (1.0 + 0.25 * 0.8), 0.001)


func test_on_kill() -> void:
	var s := _pair([_hook("on_kill", {"reset_cooldown": "warrior_charge", "heal_pct": 0.05})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	t.hp = 10.0
	p.hp = 50.0
	p.cooldowns["warrior_charge"] = 99999
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_false(p.cooldowns.has("warrior_charge"), "the recharge was reset")
	assert_eq(p.hp, 55.0, "5 % of 100")
	var other := f.dummy(2001, Vector3(12, 0, 10), 1000.0)
	p.cooldowns["warrior_charge"] = 99999
	Combat.deal(f.world, p, other, {"damage": _dmg(100)}, {})
	assert_true(p.cooldowns.has("warrior_charge"), "no kill, no reset")


func test_low_hp_guard() -> void:
	var s := _pair([_hook("low_hp_guard", {"below_pct": 0.2, "reduction": 0.4, "duration_s": 8, "cooldown_s": 60})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	p.hp = 30.0
	Combat.deal(f.world, t, p, {"damage": _dmg(5)}, {})
	assert_eq(p.hp, 25.0)
	assert_false(p.has_status("damage_reduction"), "25 % is not low enough")
	Combat.deal(f.world, t, p, {"damage": _dmg(10)}, {})
	assert_eq(p.hp, 15.0)
	assert_almost_eq(p.status_magnitude("damage_reduction"), 0.4, 0.001)
	Combat.deal(f.world, t, p, {"damage": _dmg(10)}, {})
	assert_eq(p.hp, 9.0, "10 x 0.6")
	p.statuses.clear()
	Combat.deal(f.world, t, p, {"damage": _dmg(2)}, {})
	assert_false(p.has_status("damage_reduction"), "on its 60 s recharge")


func test_cheat_death() -> void:
	var s := _pair([_hook("cheat_death", {"hp_pct": 0.3, "cooldown_s": 180})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	Combat.deal(f.world, t, p, {"damage": _dmg(500)}, {})
	assert_true(p.is_alive())
	assert_eq(p.hp, 30.0)


func test_cheat_death_has_cooldown() -> void:
	var s := _pair([_hook("cheat_death", {"hp_pct": 0.3, "cooldown_s": 180})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	Combat.deal(f.world, t, p, {"damage": _dmg(500)}, {})
	Combat.deal(f.world, t, p, {"damage": _dmg(500)}, {})
	assert_false(p.is_alive(), "the second time it dies")
	var q := f.player(2, Vector3(20, 0, 20), 100.0)
	q.passives = [_hook("cheat_death", {"hp_pct": 0.3, "cooldown_s": 1})]
	Combat.deal(f.world, t, q, {"damage": _dmg(500)}, {})
	f.run(1.5)
	Combat.deal(f.world, t, q, {"damage": _dmg(500)}, {})
	assert_true(q.is_alive(), "ready again after its recharge")


func test_guardian_angel() -> void:
	var s := _pair([])
	var healer: PlayerState = s[0]
	healer.passives = [_hook("guardian_angel", {"radius": 20, "hp_pct": 0.25, "cooldown_s": 120})]
	var ally := f.player(2, Vector3(20, 0, 10), 100.0)
	Combat.deal(f.world, s[1], ally, {"damage": _dmg(500)}, {})
	assert_true(ally.is_alive())
	assert_eq(ally.hp, 25.0)
	Combat.deal(f.world, s[1], ally, {"damage": _dmg(500)}, {})
	assert_false(ally.is_alive(), "the angel is recharging")


func test_guardian_angel_only_allies_in_radius() -> void:
	var s := _pair([])
	var healer: PlayerState = s[0]
	healer.passives = [_hook("guardian_angel", {"radius": 20, "hp_pct": 0.25, "cooldown_s": 120})]
	var far_ally := f.player(2, Vector3(45, 0, 10), 100.0)
	Combat.deal(f.world, s[1], far_ally, {"damage": _dmg(500)}, {})
	assert_false(far_ally.is_alive(), "35 m away")
	var enemy := f.dummy(2001, Vector3(12, 0, 10), 100.0)
	Combat.deal(f.world, healer, enemy, {"damage": _dmg(500)}, {})
	assert_false(enemy.is_alive(), "the angel only saves its own team")


func test_melee_hit_restores() -> void:
	var s := _pair([_hook("melee_hit_restores", {"amount": 4})])
	var p: PlayerState = s[0]
	p.resource = 10.0
	Combat.deal(f.world, p, s[1], {"type": "melee_arc", "damage": _dmg(5)}, {})
	assert_eq(p.resource, 14.0)
	Combat.deal(f.world, p, s[1], {"type": "projectile", "damage": _dmg(5)}, {})
	assert_eq(p.resource, 14.0, "only melee hits")


func test_stacking_school_damage() -> void:
	var s := _pair([_hook("stacking_school_damage", {"school": "arcane", "pct": 0.04, "max": 5, "duration_s": 6})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	var before := t.hp
	Combat.deal(f.world, p, t, {"damage": _dmg(100, {"school": "arcane"})}, {})
	assert_almost_eq(before - t.hp, 100.0, 0.001, "the first hit has no stacks")
	assert_eq(p.status_stacks("stack_arcane"), 1)
	for i in 8:
		Combat.deal(f.world, p, t, {"damage": _dmg(0, {"school": "arcane"})}, {})
	assert_eq(p.status_stacks("stack_arcane"), 5, "up to 5")
	before = t.hp
	Combat.deal(f.world, p, t, {"damage": _dmg(100, {"school": "arcane"})}, {})
	assert_almost_eq(before - t.hp, 120.0, 0.001, "5 x 4 %")
	before = t.hp
	Combat.deal(f.world, p, t, {"damage": _dmg(100, {"school": "fire"})}, {})
	assert_almost_eq(before - t.hp, 100.0, 0.001, "other schools get nothing")
	f.run(7.0)
	assert_eq(p.status_stacks("stack_arcane"), 0, "they fade")


func test_school_crit() -> void:
	var s := _pair([_hook("school_crit", {"school": "arcane", "add": 1.0})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	var arcane := Damage.roll(p, t, _dmg(100, {"school": "arcane", "can_crit": true}), f.world)
	var fire := Damage.roll(p, t, _dmg(100, {"school": "fire", "can_crit": true}), f.world)
	assert_true(arcane.crit)
	assert_false(fire.crit)


func test_slow_adds_attack_slow() -> void:
	var s := _pair([_hook("slow_adds_attack_slow", {"pct": 0.25})])
	Combat.apply_status(f.world, s[0], s[1], {"kind": "slow", "duration_s": 3, "magnitude": 0.4})
	assert_true((s[1] as CombatEntity).has_status("slow"))
	assert_almost_eq((s[1] as CombatEntity).status_magnitude("attack_slow"), 0.25, 0.001)


func test_freeze_reduces_cooldowns() -> void:
	var s := _pair([_hook("freeze_reduces_cooldowns", {"seconds": 1})])
	var p: PlayerState = s[0]
	p.cooldowns["x"] = f.world.tick + f.world.ticks(10.0)
	Combat.apply_status(f.world, p, s[1], {"kind": "freeze", "duration_s": 2})
	assert_eq(p.cooldowns["x"], f.world.tick + f.world.ticks(9.0))
	var more: Array = []
	for i in 5:
		more.append(f.dummy(2100 + i, Vector3(12, 0, 10), 100.0))
	p.cooldowns["x"] = f.world.tick + f.world.ticks(10.0)
	f.world.cast_cd_reduced = 0.0
	for e: CombatEntity in more:
		Combat.apply_status(f.world, p, e, {"kind": "freeze", "duration_s": 2})
	assert_eq(p.cooldowns["x"], f.world.tick + f.world.ticks(7.0), "3 s at most per cast")


func test_stationary_damage() -> void:
	var s := _pair([_hook("stationary_damage", {"seconds": 1.5, "pct": 0.15})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	f.run(0.1)
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 100.0, 0.001, "just arrived")
	f.run(2.0)
	t.hp = 1000.0
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 115.0, 0.001, "still for 1.5 s")
	p.position += Vector3(2, 0, 0)
	f.run(0.1)
	t.hp = 1000.0
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 100.0, 0.001, "moving resets it")


func test_traps_rearm() -> void:
	f.world.abilities = AbilityDB.from_list([{"id": "trap", "class": "test", "kind": "active", "cost": 0, "cooldown_s": 1, "gcd": false, "range": 30,
		"effects": [{"type": "trap", "radius": 2, "arm_s": 0.5, "lifetime_s": 30, "damage": _dmg(10)}]}])
	var s := _pair([_hook("traps_rearm", {"times": 1})])
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	t.position = Vector3(10, 0, 20)
	assert_true(Combat.try_cast(f.world, p, "trap", Vector3(10, 0, 20)))
	f.run(0.7)
	assert_eq(t.hp, 990.0, "the first time")
	assert_eq(f.world.traps.size(), 1, "it armed itself again")
	f.run(0.6)
	assert_eq(t.hp, 980.0, "and went off a second time")
	assert_eq(f.world.traps.size(), 0)


func test_bonus_vs_low_hp() -> void:
	var s := _pair([_hook("bonus_vs_low_hp", {"below_pct": 0.3, "pct": 0.2})])
	var t: CombatEntity = s[1]
	Combat.deal(f.world, s[0], t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 100.0, 0.001)
	t.hp = 200.0
	Combat.deal(f.world, s[0], t, {"damage": _dmg(100)}, {})
	assert_almost_eq(200.0 - t.hp, 120.0, 0.001)


func test_stealth_duration_pct() -> void:
	f.world.abilities = AbilityDB.from_list([{"id": "s", "class": "test", "kind": "active", "cost": 0, "cooldown_s": 1, "gcd": false, "range": 0,
		"effects": [{"type": "stealth", "duration_s": 8}]}])
	var s := _pair([_hook("stealth_duration_pct", {"pct": 0.5})])
	var p: PlayerState = s[0]
	assert_true(Combat.try_cast(f.world, p, "s", p.position))
	assert_eq(p.statuses[0].end_tick, f.world.tick + f.world.ticks(12.0))


func test_poison_max_stacks() -> void:
	var s := _pair([_hook("poison_max_stacks", {"max": 10})])
	for i in 12:
		Combat.apply_status(f.world, s[0], s[1], {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1, "max_stacks": 5})
	assert_eq((s[1] as CombatEntity).status_stacks("poison"), 10)


func test_poison_spreads_on_death() -> void:
	var s := _pair([])
	var t: CombatEntity = s[1]
	var near := f.dummy(2001, Vector3(14, 0, 10), 1000.0)
	var far := f.dummy(2002, Vector3(30, 0, 10), 1000.0)
	Combat.apply_status(f.world, s[0], t, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1, "max_stacks": 5, "stacks": 3})
	Combat.apply_status(f.world, s[0], t, {"kind": "contagion", "duration_s": 10, "magnitude": 6})
	t.hp = 5.0
	Combat.deal(f.world, s[0], t, {"damage": _dmg(100)}, {})
	assert_false(t.is_alive())
	assert_eq(near.status_stacks("poison"), 3, "within 6 m it caught the poison")
	assert_false(far.has_status("poison"))


func test_poisoned_deal_less() -> void:
	var s := _pair([_hook("poisoned_deal_less", {"pct": 0.1})])
	var t: CombatEntity = s[1]
	Combat.apply_status(f.world, s[0], t, {"kind": "poison", "duration_s": 6, "magnitude": 2, "every_s": 1})
	assert_almost_eq(t.status_magnitude("weaken"), 0.1, 0.001)


func test_finisher_refund_per_combo() -> void:
	f.world.abilities = AbilityDB.from_list([{"id": "fin", "class": "test", "kind": "secondary", "cost": 35, "cooldown_s": 0, "gcd": false, "range": 3,
		"finisher": true, "effects": [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": _dmg(10)}]}])
	var s := _pair([_hook("finisher_refund_per_combo", {"amount": 8})])
	var p: PlayerState = s[0]
	p.combo = 3
	p.resource = 100.0
	assert_true(Combat.try_cast(f.world, p, "fin", (s[1] as CombatEntity).position))
	assert_eq(p.resource, 100.0 - 35.0 + 24.0)
	assert_eq(p.combo, 0)

