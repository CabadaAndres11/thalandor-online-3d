extends GutTest
## The mage's level 50 upgrades (Pyromancer, Cryomancer, Arcanist).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String) -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "mage", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	p.stats.hp_regen = 0.0
	p.last_hurt_tick = 1000000000 # Concentración (+10 % spell power) stays off: exact numbers
	return p


func _no_school_crit(p: PlayerState) -> void:
	p.passives = p.passives.filter(func(m: Dictionary) -> bool: return m.get("hook") != "school_crit")


func _foe(id: int, pos: Vector3) -> CombatEntity:
	var d := f.dummy(id, pos, 50000.0)
	d.stats.dodge_chance = 0.0
	return d


func _lost(e: CombatEntity) -> float:
	return 50000.0 - e.hp


# --- Pyromancer --------------------------------------------------------------------------

func test_flame_pillar() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(10, 0, 20))
	var mana := p.resource
	assert_true(Combat.try_cast(f.world, p, "mage_flame_pillar", foe.position))
	assert_eq(p.resource, mana - 35.0)
	assert_eq(p.cooldowns["mage_flame_pillar"], f.world.tick + f.world.ticks(14.0))
	assert_almost_eq(_lost(foe), 8.0 + 0.5 * p.stats.spell_power, 0.01, "the first pulse")
	assert_true(foe.has_status("burn"))
	f.run(5.2)
	assert_eq(f.world.pending_areas.size(), 0, "6 pulses and it is over")


func test_meteor() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(10, 0, 22))
	var edge := _foe(2001, Vector3(10, 0, 26.5))
	var t0 := f.world.tick
	assert_true(Combat.try_cast(f.world, p, "mage_meteor", Vector3(10, 0, 22)))
	assert_eq(p.resource, p.stats.max_resource - 60.0)
	f.run(1.1)
	assert_eq(f.events_of("telegraph").size(), 0, "still casting")
	f.run(0.3)
	assert_gt(f.events_of("telegraph").size(), 0, "the meteor is on its way: the fx sees the ability")
	assert_eq(f.events_of("telegraph")[0][5], "mage_meteor")
	f.run(0.5)
	assert_eq(foe.hp, 50000.0, "still falling")
	f.run(0.5)
	assert_almost_eq(_lost(foe), 50.0 + 2.5 * p.stats.spell_power, 0.01)
	assert_true(foe.has_status("stun"))
	assert_lt(edge.hp, 50000.0, "radius 5")
	assert_eq(p.cooldowns["mage_meteor"], t0 + f.world.ticks(30.0))


func test_flame_wall_is_a_line_across_the_aim() -> void:
	var p := _hero("pyromancer") # at (10, 0, 10), facing the cursor along +Z
	var centre := _foe(2000, Vector3(10, 0, 20))
	var side := _foe(2001, Vector3(14.5, 0, 20)) # 4.5 m along the wall: inside a round 3 m area? no, but in the wall
	var far_side := _foe(2002, Vector3(16.0, 0, 20)) # 6 m: beyond the 5 m half length
	var front := _foe(2003, Vector3(10, 0, 22.5)) # 2.5 m in front of the wall: outside its width
	assert_true(Combat.try_cast(f.world, p, "mage_flame_pillar", Vector3(10, 0, 20)))
	assert_lt(centre.hp, 50000.0)
	assert_lt(side.hp, 50000.0, "the wall is long")
	assert_eq(far_side.hp, 50000.0)
	assert_eq(front.hp, 50000.0, "and thin")
	var area_ev: Array = f.events_of("area")[0]
	assert_eq(area_ev[7].size(), 4, "the fx gets length, width and direction")


func test_combustion() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	var spec := {"base": 100, "coef": 0, "kind": "magic", "can_crit": false}
	var plain: float = Damage.roll(p, foe, spec, f.world).amount
	foe.add_status(StatusEffect.make("burn", f.world.tick + 300, 1.0, 0, 1, 30), 1)
	var burning: float = Damage.roll(p, foe, spec, f.world).amount
	# Combustión (+10 %) and the pyromancer's Frío penetrante (+20 % to the burning, Plan 8.3h)
	assert_almost_eq(burning / plain, 1.1 * 1.2, 0.001)


func test_phoenix() -> void:
	var p := _hero("pyromancer")
	var h := Passives.has_hook(p, "cheat_death")
	assert_eq([h.hp_pct, h.cooldown_s], [0.3, 180.0])
	var foe := _foe(2000, Vector3(11, 0, 10))
	Combat.deal(f.world, foe, p, {"damage": {"base": 99999, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_true(p.is_alive())
	assert_almost_eq(p.hp, p.stats.max_hp * 0.3, 0.01)


func test_fireball_evolution_leaves_flames() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(10, 0, 18))
	assert_true(Combat.try_cast(f.world, p, "mage_fireball", foe.position))
	f.run(6.0)
	var ph := p.stats.spell_power
	assert_almost_eq(_lost(foe), (30.0 + 1.3 * ph) + (15.0 + 0.6 * ph) + 4.0 * (4.0 + 0.25 * ph), 0.05, "hit, blast and 4 pulses of flames")
	f.world.players.clear()
	var plain := _hero("") # no upgrade: the plain fireball
	plain.position = Vector3(30, 0, 10)
	var foe2 := _foe(2001, Vector3(30, 0, 20))
	assert_true(Combat.try_cast(f.world, plain, "mage_fireball", foe2.position))
	f.run(6.0)
	assert_almost_eq(_lost(foe2), (30.0 + 1.3 * ph) + (15.0 + 0.6 * ph), 0.05, "without it, no flames")


# --- Cryomancer --------------------------------------------------------------------------

func test_blizzard() -> void:
	var p := _hero("cryomancer")
	var foe := _foe(2000, Vector3(10, 0, 20))
	assert_true(Combat.try_cast(f.world, p, "mage_blizzard", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 45.0)
	f.run(8.0)
	assert_almost_eq(_lost(foe), (6.0 + 0.4 * p.stats.spell_power) * (1.0 + 7.0 * 1.2), 0.1, "8 pulses; the last 7 hit a slowed target (+20 % from Frío penetrante)")
	assert_almost_eq(foe.status_magnitude("slow"), 0.4, 0.001)
	assert_eq(p.cooldowns["mage_blizzard"], f.world.tick - f.world.ticks(8.0) + f.world.ticks(20.0))


func test_ice_block() -> void:
	var p := _hero("cryomancer")
	p.hp = 10.0
	var foe := _foe(2000, Vector3(11, 0, 10))
	assert_true(Combat.try_cast(f.world, p, "mage_ice_block", p.position))
	assert_eq(p.resource, p.stats.max_resource - 20.0)
	assert_eq(p.gcd_end, 0, "no global cooldown")
	assert_true(p.has_status("ice_block"))
	Combat.deal(f.world, foe, p, {"damage": {"base": 500, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_gt(p.hp, 9.9, "invulnerable")
	assert_false(Combat.try_cast(f.world, p, "mage_blink", Vector3(15, 0, 10)), "and cannot act")
	f.run(4.6)
	var gain := 0.3 * p.stats.max_hp * p.stats.healing_done_mult * p.stats.healing_received_mult
	assert_almost_eq(p.hp - 10.0, gain, 0.5, "30 % of the life in those 4 s")
	assert_false(p.has_status("ice_block"))
	assert_eq(p.cooldowns["mage_ice_block"], f.world.tick - f.world.ticks(4.6) + f.world.ticks(90.0))


func test_chill() -> void:
	var p := _hero("cryomancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	Combat.apply_status(f.world, p, foe, {"kind": "slow", "duration_s": 3, "magnitude": 0.4})
	assert_almost_eq(foe.status_magnitude("attack_slow"), 0.25, 0.001)


func test_frozen_heart() -> void:
	var p := _hero("cryomancer")
	var a := _foe(2000, Vector3(10, 0, 20))
	var b := _foe(2001, Vector3(11, 0, 20))
	p.cooldowns["mage_blink"] = f.world.tick + f.world.ticks(10.0)
	assert_true(Combat.try_cast(f.world, p, "mage_frost_nova", Vector3(10, 0, 20)))
	assert_eq(p.cooldowns["mage_blink"], f.world.tick + f.world.ticks(8.0), "1 s per frozen enemy")
	f.world.players.clear()
	var q := _hero("cryomancer")
	for i in 5:
		_foe(2100 + i, Vector3(10 + i * 0.3, 0, 21))
	q.cooldowns["mage_blink"] = f.world.tick + f.world.ticks(10.0)
	assert_true(Combat.try_cast(f.world, q, "mage_frost_nova", Vector3(10, 0, 21)))
	assert_eq(q.cooldowns["mage_blink"], f.world.tick + f.world.ticks(7.0), "3 s at most")
	assert_true(a.has_status("freeze") and b.has_status("freeze"))


func test_frost_nova_evolution_goes_to_the_cursor() -> void:
	var p := _hero("cryomancer")
	var foe := _foe(2000, Vector3(10, 0, 20)) # 10 m away
	assert_true(Combat.try_cast(f.world, p, "mage_frost_nova", foe.position))
	assert_true(foe.has_status("freeze"), "thrown at the cursor")
	assert_eq(f.world.abilities.resolved("mage_frost_nova", "cryomancer", f.world.upgrades).range, 12)
	f.world.players.clear()
	var plain := _hero("pyromancer")
	var foe2 := _foe(2001, Vector3(10, 0, 22))
	assert_true(Combat.try_cast(f.world, plain, "mage_frost_nova", foe2.position))
	assert_false(foe2.has_status("freeze"), "without it, it is around the mage (4 m)")


# --- Arcanist ----------------------------------------------------------------------------

func test_arcane_missiles() -> void:
	var p := _hero("arcanist")
	_no_school_crit(p)
	var foe := _foe(2000, Vector3(10, 0, 18))
	assert_true(Combat.try_cast(f.world, p, "mage_arcane_missiles", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 40.0)
	assert_true(Combat.channeling(f.world, p.id))
	f.run(3.0)
	var one := 8.0 + 0.6 * p.stats.spell_power
	assert_almost_eq(_lost(foe), one * (5.0 + 0.04 * (0 + 1 + 2 + 3 + 4)), 0.05, "5 missiles, each with one more arcane charge")
	assert_eq(p.cooldowns["mage_arcane_missiles"], f.world.tick - f.world.ticks(3.0) + f.world.ticks(10.0))


func test_arcane_missiles_stop_when_moving() -> void:
	var p := _hero("arcanist")
	_no_school_crit(p)
	var foe := _foe(2000, Vector3(10, 0, 18))
	assert_true(Combat.try_cast(f.world, p, "mage_arcane_missiles", foe.position))
	f.run(0.35)
	p.position += Vector3(1, 0, 0)
	f.run(3.0)
	var shots := 0
	for ev: Array in f.log + f.world.events:
		if ev[0] == "projectile":
			shots += 1
	assert_eq(shots, 2, "only the missiles fired before the move")


func test_arcane_laser_lasts_and_follows_the_cursor() -> void:
	var p := _hero("arcanist")
	_no_school_crit(p)
	var a := _foe(2000, Vector3(10, 0, 14)) # ahead
	var side := _foe(2001, Vector3(20, 0, 10)) # to the +X side of the caster
	var off := _foe(2002, Vector3(13, 0, 20))
	var t0 := f.world.tick
	p.aim = Vector3(10, 0, 20)
	assert_true(Combat.try_cast(f.world, p, "mage_arcane_laser", Vector3(10, 0, 20)))
	assert_eq(p.resource, p.stats.max_resource - 60.0)
	assert_true(Combat.channeling(f.world, p.id), "it is a long channel")
	f.run(0.9)
	assert_eq(_lost(a), 0.0, "1 s of cast time first (Plan 8.3h)")
	f.run(1.1)
	var one := 6.0 + 0.4 * p.stats.spell_power
	assert_gt(_lost(a), one * 3.0, "several pulses already")
	assert_eq(side.hp, 50000.0, "it points where the cursor was")
	p.aim = Vector3(20, 0, 10) # the cursor moves to the side: the laser turns
	var lost_a := _lost(a)
	f.run(1.0)
	assert_eq(_lost(a), lost_a, "it left the first enemy")
	assert_gt(_lost(side), one * 3.0, "and follows the cursor")
	assert_eq(off.hp, 50000.0)
	f.run(2.5)
	assert_false(Combat.channeling(f.world, p.id), "about 5 s in all with the cast")
	assert_eq(p.cooldowns["mage_arcane_laser"], t0 + f.world.ticks(20.0))


func test_arcane_laser_stops_when_the_mage_moves() -> void:
	var p := _hero("arcanist")
	var foe := _foe(2000, Vector3(10, 0, 14))
	p.aim = Vector3(10, 0, 20)
	assert_true(Combat.try_cast(f.world, p, "mage_arcane_laser", Vector3(10, 0, 20)))
	f.run(1.6)
	p.position += Vector3(1, 0, 0)
	var lost := 50000.0 - foe.hp
	f.run(2.0)
	assert_eq(50000.0 - foe.hp, lost, "it only lasts while she stands still")


func test_arcane_charge() -> void:
	var p := _hero("arcanist")
	var h := Passives.has_hook(p, "stacking_school_damage")
	assert_eq([h.school, h.pct, h.max, h.duration_s], ["arcane", 0.04, 5.0, 6.0])


func test_pure_power() -> void:
	var p := _hero("arcanist")
	assert_almost_eq(Passives.school_crit(p, "arcane"), 0.15, 0.0001)
	assert_eq(Passives.school_crit(p, "fire"), 0.0)


func test_blast_evolution_is_instant_and_bigger() -> void:
	var p := _hero("arcanist")
	_no_school_crit(p)
	var near := _foe(2000, Vector3(10, 0, 23.2)) # 3.2 m from the cursor point
	assert_true(Combat.try_cast(f.world, p, "mage_blast", Vector3(10, 0, 20)))
	assert_almost_eq(_lost(near), 26.0 + 1.1 * p.stats.spell_power, 0.01, "no wait, radius 3.5")
	f.world.players.clear()
	var plain := _hero("cryomancer")
	var far := _foe(2001, Vector3(30, 0, 23.2))
	assert_true(Combat.try_cast(f.world, plain, "mage_blast", Vector3(30, 0, 30)))
	f.run(0.2)
	assert_eq(far.hp, 50000.0, "the base blast waits and is smaller")


# --- Shape --------------------------------------------------------------------------------

func test_every_mage_spell_has_a_school() -> void:
	var schools := {"mage_missile": "arcane", "mage_blast": "arcane", "mage_fireball": "fire", "mage_frost_nova": "frost", "mage_frostbolt": "frost"}
	for id: String in schools:
		var e: Dictionary = f.world.abilities.get_ability(id).effects[0]
		assert_eq(e.damage.school, schools[id], id)


func test_three_complete_upgrades_with_texts_and_icons() -> void:
	assert_eq(f.world.upgrades.for_class("mage").size(), 3)
	for id: String in ["pyromancer", "cryomancer", "arcanist"]:
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


func test_ice_block_keeps_the_character_facing_where_it_was() -> void:
	var p := _hero("cryomancer")
	p.facing = 0.0
	p.add_status(StatusEffect.make("ice_block", f.world.tick + 300), 1)
	f.world.step({p.id: PlayerInput.new(1, Vector2.ZERO, Vector3(20, 0, 10), 0)}) # the cursor is to the +X side
	assert_eq(p.facing, 0.0, "it does not follow the cursor")
	p.statuses.clear()
	f.world.step({p.id: PlayerInput.new(2, Vector2.ZERO, Vector3(20, 0, 10), 0)})
	assert_ne(p.facing, 0.0, "it does once the block is over")
