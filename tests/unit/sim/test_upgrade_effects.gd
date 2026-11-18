extends GutTest
## Generic effects and statuses the class upgrades are made of.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))


func _dmg(base: float, extra := {}) -> Dictionary:
	var d := {"base": base, "coef": 0, "kind": "magic", "can_crit": false}
	d.merge(extra, true)
	return d


func _ab(id: String, effects: Array, extra := {}) -> Dictionary:
	var a := {"id": id, "class": "test", "kind": "active", "cost": 0, "cooldown_s": 10, "gcd": false, "range": 30, "effects": effects}
	a.merge(extra, true)
	return a


func _use(abilities: Array) -> void:
	f.world.abilities = AbilityDB.from_list(abilities)


func _hurt(e: CombatEntity, hp: float) -> void:
	e.hp = hp


# --- area ---------------------------------------------------------------------------------

func test_area_heal() -> void:
	_use([_ab("a", [{"type": "area", "at": "self", "radius": 5, "delay_s": 0, "telegraph": false, "heal": {"base": 30, "coef": 0}}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var ally := f.player(2, Vector3(12, 0, 10), 100.0)
	var far := f.player(3, Vector3(40, 0, 40), 100.0)
	for e: PlayerState in [p, ally, far]:
		e.hp = 50.0
	assert_true(Combat.try_cast(f.world, p, "a", p.position))
	assert_eq(p.hp, 80.0)
	assert_eq(ally.hp, 80.0)
	assert_eq(far.hp, 50.0, "out of the radius")


func test_area_follow_caster() -> void:
	_use([_ab("a", [{"type": "area", "at": "self", "radius": 2, "delay_s": 0, "telegraph": false, "pulses": 3, "interval_s": 1.0,
		"follow_caster": true, "damage": _dmg(10)}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var e := f.dummy(2000, Vector3(30, 0, 10), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "a", p.position))
	p.position = Vector3(30, 0, 12)
	f.run(1.2)
	assert_eq(e.hp, 990.0, "the second pulse went with the caster")


# --- projectiles --------------------------------------------------------------------------

func test_projectile_fan() -> void:
	_use([_ab("a", [{"type": "projectile", "speed": 20, "radius": 0.3, "range": 20, "pierce": false, "count": 5, "spread_deg": 40, "damage": _dmg(5)}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	assert_true(Combat.try_cast(f.world, p, "a", Vector3(10, 0, 20)))
	assert_eq(f.world.projectiles.size(), 5)
	var angles := f.world.projectiles.map(func(pr: Projectile) -> float: return rad_to_deg(pr.dir.angle_to(Vector2(0, 1))))
	angles.sort()
	assert_almost_eq(float(angles[0]), -20.0, 0.1)
	assert_almost_eq(float(angles[2]), 0.0, 0.1)
	assert_almost_eq(float(angles[4]), 20.0, 0.1)


func test_projectile_explode_leaves_an_area() -> void:
	_use([_ab("a", [{"type": "projectile", "speed": 30, "radius": 0.3, "range": 20, "pierce": false, "damage": _dmg(5),
		"explode": {"radius": 1.0, "damage": _dmg(0), "leave": {"type": "area", "radius": 3, "delay_s": 0, "pulses": 4, "interval_s": 1.0, "damage": _dmg(4)}}}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var t := f.dummy(2000, Vector3(10, 0, 16), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "a", t.position))
	f.run(1.0)
	assert_eq(f.world.pending_areas.size(), 1, "the area stays")
	f.run(4.0)
	assert_eq(1000.0 - t.hp, 5.0 + 4.0 * 4.0)


# --- beam ---------------------------------------------------------------------------------

func test_beam() -> void:
	_use([_ab("a", [{"type": "beam", "range": 18, "width": 1.2, "damage": _dmg(35)}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var a := f.dummy(2000, Vector3(10, 0, 14), 1000.0)
	var b := f.dummy(2001, Vector3(10, 0, 26), 1000.0)
	var side := f.dummy(2002, Vector3(13, 0, 14), 1000.0)
	var beyond := f.dummy(2003, Vector3(10, 0, 40), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "a", Vector3(10, 0, 20)))
	assert_eq(a.hp, 965.0)
	assert_eq(b.hp, 965.0, "everything in the line")
	assert_eq(side.hp, 1000.0)
	assert_eq(beyond.hp, 1000.0)


# --- shield / heal ------------------------------------------------------------------------

func test_shield_reflect() -> void:
	_use([_ab("a", [{"type": "shield", "target": "self", "amount": {"base": 100, "coef": 0}, "duration_s": 8, "reflect_pct": 0.5}])])
	var p := f.player(1, Vector3(10, 0, 10), 500.0)
	var foe := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "a", p.position))
	Combat.deal(f.world, foe, p, {"damage": _dmg(40)}, {})
	assert_eq(p.shield, 60.0)
	assert_eq(foe.hp, 980.0, "half of the 40 absorbed")
	assert_eq(p.hp, 500.0)


func test_reflect_does_not_loop() -> void:
	var a := f.player(1, Vector3(10, 0, 10), 500.0)
	var b := f.dummy(2000, Vector3(11, 0, 10), 500.0)
	a.shield = 100.0
	a.shield_reflect = 1.0
	b.shield = 100.0
	b.shield_reflect = 1.0
	Combat.deal(f.world, b, a, {"damage": _dmg(40)}, {})
	assert_eq(a.shield, 60.0)
	assert_eq(b.shield, 60.0, "the reflected damage was absorbed once and went no further")
	assert_eq(a.hp, 500.0)


func test_heal_bounce() -> void:
	_use([_ab("a", [{"type": "heal", "target": "ally_or_self", "amount": {"base": 100, "coef": 0}, "bounce": {"count": 1, "radius": 10, "pct": 0.5}}])])
	var p := f.player(1, Vector3(10, 0, 10), 500.0)
	var healed := f.player(2, Vector3(12, 0, 10), 500.0)
	var hurt := f.player(3, Vector3(16, 0, 10), 500.0)
	var other := f.player(4, Vector3(18, 0, 10), 500.0)
	var far := f.player(5, Vector3(50, 0, 50), 500.0)
	for e: PlayerState in [healed, hurt, other, far]:
		e.hp = 100.0
	hurt.hp = 20.0
	assert_true(Combat.try_cast(f.world, p, "a", healed.position))
	assert_eq(healed.hp, 200.0)
	assert_eq(hurt.hp, 70.0, "the most hurt ally in range gets half")
	assert_eq(other.hp, 100.0, "only `count` allies")
	assert_eq(far.hp, 100.0)


# --- damage extras ------------------------------------------------------------------------

func test_damage_execute() -> void:
	_use([_ab("a", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": _dmg(20, {"execute": {"below_pct": 0.25, "mult": 2.5}})}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var healthy := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	var weak := f.dummy(2001, Vector3(10, 0, 11), 1000.0)
	weak.hp = 200.0
	assert_true(Combat.try_cast(f.world, p, "a", healthy.position))
	assert_eq(healthy.hp, 980.0)
	assert_eq(weak.hp, 150.0, "20 x 2.5 below 25 %")


func test_damage_lifesteal_pct() -> void:
	var p := f.player(1, Vector3(10, 0, 10), 500.0)
	p.hp = 100.0
	var t := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	Combat.deal(f.world, p, t, {"damage": _dmg(50, {"lifesteal_pct": 0.3})}, {})
	assert_eq(p.hp, 115.0)


func test_refund_on_kill() -> void:
	_use([_ab("a", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": _dmg(50)}], {"cost": 30, "refund_on_kill": true})])
	var p := f.player(1, Vector3(10, 0, 10), 100.0, 100.0)
	var low := f.dummy(2000, Vector3(11, 0, 10), 40.0)
	assert_true(Combat.try_cast(f.world, p, "a", low.position))
	assert_eq(p.resource, 100.0, "a kill gives the cost back")
	p.cooldowns.clear()
	var tank := f.dummy(2001, Vector3(9, 0, 10), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "a", tank.position))
	assert_eq(p.resource, 70.0)


# --- statuses -----------------------------------------------------------------------------

func test_haste() -> void:
	_use([_ab("a", [{"type": "status", "target": "self", "statuses": [{"kind": "damage_buff", "duration_s": 1, "magnitude": 0.0}]}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	p.add_status(StatusEffect.make("haste", f.world.tick + 300, 0.3), 1)
	assert_true(Combat.try_cast(f.world, p, "a", p.position))
	assert_eq(p.cooldowns["a"], f.world.tick + f.world.ticks(7.0), "10 s x (1 - 0.3)")


func test_vulnerable() -> void:
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var t := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	t.add_status(StatusEffect.make("vulnerable", f.world.tick + 300, 0.15), 1)
	Combat.deal(f.world, p, t, {"damage": _dmg(100)}, {})
	assert_almost_eq(1000.0 - t.hp, 115.0, 0.001)


func test_attack_slow() -> void:
	_use([_ab("a", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": _dmg(1)}])])
	var m := f.dummy(2000, Vector3(11, 0, 10), 100.0)
	m.add_status(StatusEffect.make("attack_slow", f.world.tick + 300, 0.25), 1)
	assert_true(Combat.try_cast(f.world, m, "a", Vector3(10, 0, 10)))
	assert_eq(m.cooldowns["a"], f.world.tick + f.world.ticks(12.5), "recharge x 1.25")


func test_weaken() -> void:
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var foe := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	foe.add_status(StatusEffect.make("weaken", f.world.tick + 300, 0.1), 1)
	Combat.deal(f.world, foe, p, {"damage": _dmg(100)}, {})
	assert_almost_eq(100.0 - p.hp, 90.0, 0.001)


func test_ice_block() -> void:
	_use([_ab("a", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": _dmg(1)}])])
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	var foe := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	p.add_status(StatusEffect.make("ice_block", f.world.tick + 120), 1)
	Combat.deal(f.world, foe, p, {"damage": _dmg(100)}, {})
	assert_eq(p.hp, 100.0, "invulnerable")
	assert_false(Combat.try_cast(f.world, p, "a", foe.position), "and it cannot act")
	assert_eq(p.move_mult(), 0.0)
	f.run(4.5)
	assert_true(Combat.try_cast(f.world, p, "a", foe.position))


func test_status_bits_fit_32() -> void:
	assert_lte(StatusEffect.BIT_KINDS.size(), 32)
	for kind: String in ["bleed", "haste", "vulnerable", "attack_slow", "weaken", "ice_block"]:
		assert_has(StatusEffect.BIT_KINDS, kind)
	for kind: String in ["vulnerable", "attack_slow", "weaken", "bleed"]:
		assert_has(StatusEffect.NEGATIVE, kind)


func test_new_statuses_have_icons_and_details() -> void:
	for kind: String in ["bleed", "haste", "vulnerable", "attack_slow", "weaken", "ice_block"]:
		assert_true(ResourceLoader.exists("res://assets/icons/status/%s.png" % kind), kind)
		assert_ne(tr("DETAIL_ST_" + kind.to_upper()), "DETAIL_ST_" + kind.to_upper(), kind)
	assert_ne(tr("DETAIL_ST_CONTAGION"), "DETAIL_ST_CONTAGION")
	var lines := AbilityDetails.lines(_ab("x", [{"type": "beam", "range": 18, "width": 1.2, "damage": _dmg(35)},
		{"type": "status", "target": "self", "statuses": [{"kind": "haste", "duration_s": 5, "magnitude": 0.3}, {"kind": "ice_block", "duration_s": 4}]},
		{"type": "summon", "monster": "x", "duration_s": 30}]), CombatStats.new(), "mana")
	assert_gt(lines.size(), 2)
