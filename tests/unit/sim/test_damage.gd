extends GutTest

var balance: Balance
var world: SimWorld


func before_each() -> void:
	balance = Balance.load_from()
	world = SimWorld.new(balance, CollisionMap.from_layout({"size": [20, 20], "spawn": [5, 5], "blocks": []}), 42)


func _entity(team: int, stats := {}) -> CombatEntity:
	var e := CombatEntity.new()
	e.team = team
	e.stats = CombatStats.from_dict(stats)
	e.hp = e.stats.max_hp
	return e


func _no_luck(e: CombatEntity) -> void:
	e.stats.crit_chance = 0.0
	e.stats.dodge_chance = 0.0


func test_mitigation_formula_and_cap() -> void:
	assert_almost_eq(Damage.mitigation(60.0, balance), 0.5, 0.0001)
	assert_almost_eq(Damage.mitigation(10000.0, balance), balance.mitigation_cap, 0.0001)
	assert_almost_eq(Damage.mitigation(0.0, balance), 0.0, 0.0001)


func test_physical_damage_uses_power_coefficient_and_armor() -> void:
	balance.damage_variance = 0.0
	var a := _entity(CombatEntity.TEAM_PLAYERS, {"attack_power": 20})
	var t := _entity(CombatEntity.TEAM_MONSTERS, {"armor": 60, "max_hp": 500})
	_no_luck(a)
	_no_luck(t)
	var r := Damage.roll(a, t, {"base": 10, "coef": 0.5, "kind": "physical"}, world)
	assert_almost_eq(float(r.amount), (10 + 0.5 * 20) * 0.5, 0.001)
	assert_false(r.crit)
	assert_false(r.dodged)


func test_magic_ignores_armor() -> void:
	balance.damage_variance = 0.0
	var a := _entity(CombatEntity.TEAM_PLAYERS, {"spell_power": 10})
	var t := _entity(CombatEntity.TEAM_MONSTERS, {"armor": 1000})
	_no_luck(a)
	_no_luck(t)
	var r := Damage.roll(a, t, {"base": 10, "coef": 1.0, "kind": "magic"}, world)
	assert_almost_eq(float(r.amount), 20.0, 0.001)


func test_crit_multiplies_by_1_5() -> void:
	balance.damage_variance = 0.0
	var a := _entity(CombatEntity.TEAM_PLAYERS)
	var t := _entity(CombatEntity.TEAM_MONSTERS)
	_no_luck(t)
	a.stats.crit_chance = 1.0
	var r := Damage.roll(a, t, {"base": 10, "coef": 0.0, "kind": "magic"}, world)
	assert_true(r.crit)
	assert_almost_eq(float(r.amount), 15.0, 0.001)


func test_variance_within_10_percent_and_seeded() -> void:
	var a := _entity(CombatEntity.TEAM_PLAYERS)
	var t := _entity(CombatEntity.TEAM_MONSTERS)
	_no_luck(a)
	_no_luck(t)
	var other := SimWorld.new(balance, world.map, 42)
	for i in 50:
		var r1 := Damage.roll(a, t, {"base": 100, "coef": 0.0, "kind": "magic"}, world)
		var r2 := Damage.roll(a, t, {"base": 100, "coef": 0.0, "kind": "magic"}, other)
		assert_between(float(r1.amount), 90.0, 110.0)
		assert_eq(r1.amount, r2.amount, "same seed, same rolls")


func test_dodge_chance_avoids_hit() -> void:
	var a := _entity(CombatEntity.TEAM_PLAYERS)
	var t := _entity(CombatEntity.TEAM_MONSTERS)
	a.stats.crit_chance = 0.0
	t.stats.dodge_chance = 1.0
	var r := Damage.roll(a, t, {"base": 10, "coef": 0.0, "kind": "physical"}, world)
	assert_true(r.dodged)
	assert_eq(float(r.amount), 0.0)


func test_shield_absorbs_before_hp() -> void:
	var t := _entity(CombatEntity.TEAM_MONSTERS, {"max_hp": 100})
	t.shield = 30.0
	var r := {"amount": 50.0, "crit": false, "dodged": false, "absorbed": 0.0}
	Damage.apply(t, r, world)
	assert_eq(t.shield, 0.0)
	assert_eq(t.hp, 80.0)
	assert_eq(float(r.absorbed), 30.0)


func test_zero_hp_marks_dead() -> void:
	var t := _entity(CombatEntity.TEAM_MONSTERS, {"max_hp": 10})
	Damage.apply(t, {"amount": 50.0, "crit": false, "dodged": false, "absorbed": 0.0}, world)
	assert_eq(t.hp, 0.0)
	assert_false(t.is_alive())
