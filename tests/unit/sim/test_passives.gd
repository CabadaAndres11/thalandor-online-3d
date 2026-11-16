extends GutTest
## Passive modifiers: stat changes and named hooks (one test per hook).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new()


func _ab(id: String, effects: Array, extra: Dictionary = {}) -> Dictionary:
	var a := {"id": id, "class": "test", "kind": "active", "cost": 0, "cooldown_s": 0, "gcd": false,
		"range": 30, "effects": effects}
	a.merge(extra, true)
	return a


func _hook(name: String, params: Dictionary = {}) -> Dictionary:
	var h := {"type": "hook", "hook": name}
	h.merge(params)
	return h


func _magic(base: float) -> Dictionary:
	return {"base": base, "coef": 0, "kind": "magic"}


# --- Lookup and stats ------------------------------------------------------------------

func test_stat_mods_and_has_hook() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	p.passives = [{"type": "stat", "stat": "armor_pct", "value": 0.10}, {"type": "stat", "stat": "armor_pct", "value": 0.05},
		_hook("rage_decay_mult", {"mult": 0.5})]
	assert_almost_eq(float(Passives.stat_mods(p).armor_pct), 0.15, 0.0001)
	assert_eq(Passives.has_hook(p, "rage_decay_mult").get("mult"), 0.5)
	assert_eq(Passives.has_hook(p, "nope"), {})


func test_stat_passives_change_stats() -> void:
	f.world.abilities = AbilityDB.from_list([{"id": "pa", "class": "warrior", "kind": "passive", "level": 1, "passive": [
		{"type": "stat", "stat": "armor_pct", "value": 0.10}, {"type": "stat", "stat": "dodge_add", "value": 0.05}]}])
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	ClassRules.setup_player(p, "warrior", null, f.world)
	assert_almost_eq(p.stats.armor, 44.0, 0.001)
	assert_almost_eq(p.stats.dodge_chance, 0.05, 0.001)


func test_passives_unlocked_by_level() -> void:
	var db := AbilityDB.from_list([
		{"id": "p5", "class": "mage", "kind": "passive", "level": 5, "passive": [_hook("a")]},
		{"id": "p15", "class": "mage", "kind": "passive", "level": 15, "passive": [_hook("b")]},
	])
	assert_eq(Passives.collect(db, "mage", 1).size(), 0)
	assert_eq(Passives.collect(db, "mage", 10).size(), 1)
	assert_eq(Passives.collect(db, "mage", 15).size(), 2)


# --- Warrior ------------------------------------------------------------------------------

func test_hook_rage_decay_mult() -> void:
	var p := f.player(1, Vector3(5, 0, 5), 100.0, 50.0)
	p.resource_kind = "rage"
	p.resource_def = {"decay_per_s": 10.0}
	p.passives = [_hook("rage_decay_mult", {"mult": 0.5})]
	f.run(1.0)
	assert_almost_eq(p.resource, 45.0, 0.01, "decays half as fast")


func test_hook_block_generates_rage() -> void:
	var p := f.player(1, Vector3(5, 0, 5), 100.0, 0.0)
	p.resource_kind = "rage"
	p.passives = [_hook("block_generates_rage", {"amount": 10})]
	var d := f.dummy(1000, Vector3(6, 0, 5))
	p.add_status(StatusEffect.make("evasion", 999, 1.0))
	Combat.deal(f.world, d, p, {"damage": {"base": 10}}, {})
	assert_eq(p.resource, 10.0, "a dodged hit is a block")
	p.remove_status("evasion")
	p.shield = 100.0
	p.shield_end = 999
	Combat.deal(f.world, d, p, {"damage": {"base": 10}}, {})
	assert_eq(p.resource, 20.0, "a hit fully absorbed by a shield is a block")


func test_hook_on_crit_heal_pct() -> void:
	var p := f.player(1, Vector3(5, 0, 5), 200.0)
	p.hp = 100.0
	p.stats.crit_chance = 1.0
	p.passives = [_hook("on_crit_heal_pct", {"pct": 0.03})]
	var d := f.dummy(1000, Vector3(6, 0, 5))
	Combat.deal(f.world, p, d, {"damage": {"base": 10}}, {})
	assert_almost_eq(p.hp, 106.0, 0.01, "3 % of 200")


# --- Cleric -------------------------------------------------------------------------------

func test_hook_mana_regen_in_combat() -> void:
	var p := f.player(1, Vector3(5, 0, 5), 100.0, 0.0)
	p.resource_kind = "mana"
	p.resource_def = {"regen_per_s": 10.0, "regen_in_combat_mult": 0.0}
	p.last_combat_tick = 0
	p.passives = [_hook("mana_regen_in_combat", {"mult": 0.5})]
	f.run(1.0)
	assert_almost_eq(p.resource, 5.0, 0.01, "half regen while fighting")


func test_hook_healing_received_and_done_pct() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("heal", [{"type": "heal", "target": "ally_or_self", "amount": {"base": 100, "coef": 0}}])])
	var p := f.player(1, Vector3(5, 0, 5), 1000.0)
	var ally := f.player(2, Vector3(9, 0, 5), 1000.0)
	ally.hp = 100.0
	p.stats.healing_done_mult = 1.1
	ally.stats.healing_received_mult = 1.1
	assert_true(Combat.try_cast(f.world, p, "heal", ally.position))
	assert_almost_eq(ally.hp, 221.0, 0.01, "100 × 1.1 × 1.1")


func test_hook_heal_leaves_hot() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("heal", [{"type": "heal", "target": "self", "amount": {"base": 100, "coef": 0}}])])
	var p := f.player(1, Vector3(5, 0, 5), 1000.0)
	p.hp = 100.0
	p.passives = [_hook("heal_leaves_hot", {"pct": 0.3, "duration_s": 3, "every_s": 1})]
	assert_true(Combat.try_cast(f.world, p, "heal", p.position))
	assert_eq(p.hp, 200.0)
	assert_true(p.has_status("hot"))
	f.run(3.1)
	assert_almost_eq(p.hp, 230.0, 0.01, "30 % more over time")


# --- Mage ---------------------------------------------------------------------------------

func test_hook_spell_power_after_no_damage_s() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	p.passives = [_hook("spell_power_after_no_damage_s", {"seconds": 3, "pct": 0.10})]
	f.world.tick = 1000
	p.last_hurt_tick = 990
	assert_eq(Damage.roll(p, d, _magic(100), f.world).amount, 100.0, "hurt recently")
	p.last_hurt_tick = 900
	assert_almost_eq(float(Damage.roll(p, d, _magic(100), f.world).amount), 110.0, 0.01)
	assert_eq(Damage.roll(p, d, {"base": 100, "kind": "physical"}, f.world).amount, 100.0, "spells only")


func test_hook_fire_crit_burn() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	p.stats.crit_chance = 1.0
	p.passives = [_hook("fire_crit_burn", {"magnitude": 4, "duration_s": 4, "every_s": 1})]
	var d := f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	Combat.deal(f.world, p, d, {"damage": {"base": 10, "kind": "magic"}}, {})
	assert_false(d.has_status("burn"), "not fire")
	Combat.deal(f.world, p, d, {"damage": {"base": 10, "kind": "magic", "element": "fire"}}, {})
	assert_true(d.has_status("burn"))


func test_hook_bonus_vs_status() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	p.passives = [_hook("bonus_vs_status", {"statuses": ["freeze", "slow"], "pct": 0.20})]
	assert_eq(Damage.roll(p, d, _magic(100), f.world).amount, 100.0)
	d.add_status(StatusEffect.make("slow", 999, 0.3))
	assert_almost_eq(float(Damage.roll(p, d, _magic(100), f.world).amount), 120.0, 0.01)


# --- Archer -------------------------------------------------------------------------------

func test_hook_range_pct() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("shot", [{"type": "projectile", "speed": 30, "radius": 0.2, "range": 10,
		"damage": {"base": 10}}], {"kind": "basic"})])
	var p := f.player(1, Vector3(2, 0, 5))
	var d := f.dummy(1000, Vector3(13.5, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "shot", d.position))
	f.run(1.0)
	assert_eq(d.hp, 100.0, "out of range")
	p.passives = [_hook("range_pct", {"pct": 0.15})]
	assert_true(Combat.try_cast(f.world, p, "shot", d.position))
	f.run(1.0)
	assert_lt(d.hp, 100.0, "15 % more range reaches it")


func test_hook_bonus_vs_far() -> void:
	var p := f.player(1, Vector3(2, 0, 5))
	var near := f.dummy(1000, Vector3(4, 0, 5), 1000.0)
	var far := f.dummy(1001, Vector3(20, 0, 5), 1000.0)
	p.passives = [_hook("bonus_vs_far", {"distance": 10, "pct": 0.15})]
	assert_eq(Damage.roll(p, near, _magic(100), f.world).amount, 100.0)
	assert_almost_eq(float(Damage.roll(p, far, _magic(100), f.world).amount), 115.0, 0.01)


func test_hook_every_nth_basic_crits() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("shot", [{"type": "melee_arc", "angle_deg": 360, "range": 3,
		"damage": {"base": 10}}], {"kind": "basic"})])
	var p := f.player(1, Vector3(5, 0, 5))
	f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	p.passives = [_hook("every_nth_basic_crits", {"n": 5})]
	var crits: Array = []
	for i in 10:
		f.world.events.clear()
		assert_true(Combat.try_cast(f.world, p, "shot", Vector3(6, 0, 5)))
		var hit: Array = f.world.events.filter(func(ev: Array) -> bool: return ev[0] == "hit")[0]
		crits.append(hit[3])
	assert_eq(crits, [false, false, false, false, true, false, false, false, false, true])


# --- Assassin -----------------------------------------------------------------------------

func test_hook_back_damage_pct() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(5, 0, 6), 1000.0)
	p.passives = [_hook("back_damage_pct", {"pct": 0.20})]
	d.facing = 0.0 # looks toward +Z, away from the player at its back
	assert_almost_eq(float(Damage.roll(p, d, _magic(100), f.world).amount), 120.0, 0.01, "from behind")
	d.facing = PI # looks at the player
	assert_eq(Damage.roll(p, d, _magic(100), f.world).amount, 100.0, "from the front")


func test_hook_stealth_opener_crit_bonus() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("stab", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 10}}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	p.passives = [_hook("stealth_opener_crit_bonus", {"pct": 0.5})]
	p.add_status(StatusEffect.make("stealth", 99999))
	assert_true(Combat.try_cast(f.world, p, "stab", d.position))
	var hit: Array = f.world.events.filter(func(ev: Array) -> bool: return ev[0] == "hit")[0]
	assert_true(hit[3], "critical")
	assert_almost_eq(float(hit[2]), 10.0 * 1.5 * 1.5, 0.01, "crit × 1.5 and +50 %")
	f.world.events.clear()
	assert_true(Combat.try_cast(f.world, p, "stab", d.position))
	var second: Array = f.world.events.filter(func(ev: Array) -> bool: return ev[0] == "hit")[0]
	assert_false(second[3], "only the opener")


func test_hook_after_dodge_combo() -> void:
	f.world.abilities = AbilityDB.from_list([_ab("stab", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 10}}],
		{"combo_gain": 1})])
	var p := f.player(1, Vector3(5, 0, 5))
	f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	p.passives = [_hook("after_dodge_combo", {"combo": 2})]
	f.world.step({1: PlayerInput.new(1, Vector2.ZERO, Vector3(6, 0, 5), PlayerInput.BTN_DODGE)})
	assert_true(Combat.try_cast(f.world, p, "stab", Vector3(6, 0, 5)))
	assert_eq(p.combo, 2, "the hit after a dodge gives 2")
	assert_true(Combat.try_cast(f.world, p, "stab", Vector3(6, 0, 5)))
	assert_eq(p.combo, 3, "then back to 1")
