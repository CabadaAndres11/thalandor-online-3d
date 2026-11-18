extends GutTest
## The full class kits from data/abilities (levels 3–20 actives and the 4 passives).
## Every hero here has 20 attack and spell power (class stats).

const CLASSES := ["warrior", "cleric", "mage", "archer", "assassin"]

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()


func _hero(class_id: String, id: int, pos: Vector3) -> PlayerState:
	var p := f.world.add_player(id, pos)
	ClassRules.setup_player(p, class_id)
	p.level = 50 # may cast every ability; passives and stats stay those of level 1
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	p.resource_def["decay_per_s"] = 0.0
	return p


func _target(pos: Vector3, hp := 1000.0) -> CombatEntity:
	var d := f.dummy(1000 + f.world.monsters.size() + f.world.entities().size(), pos, hp)
	d.stats.dodge_chance = 0.0
	return d


func _db() -> AbilityDB:
	return f.world.abilities


func _status(e: CombatEntity, kind: String) -> StatusEffect:
	for s: StatusEffect in e.statuses:
		if s.kind == kind:
			return s
	return null


# --- Shape of the kits ----------------------------------------------------------------

func test_every_class_has_7_actives_4_passives() -> void:
	for c: String in CLASSES:
		var all := _db().class_abilities(c).filter(func(a: Dictionary) -> bool: return not a.has("upgrade")) # the level 50 upgrades have their own tests
		var usable := all.filter(func(a: Dictionary) -> bool: return a.get("kind") != "passive")
		var passives := all.filter(func(a: Dictionary) -> bool: return a.get("kind") == "passive")
		assert_eq(usable.size(), 9 if c == "assassin" else 7, c + ": basic, secondary and the actives")
		assert_eq(passives.size(), 4, c + ": 4 passives")
		assert_eq(_db().actives(c).map(func(id: String) -> int: return int(_db().get_ability(id).level)),
			[1, 3, 6, 10, 15, 20, 30] if c == "assassin" else [1, 3, 6, 10, 20], c + " active levels")
		assert_eq(passives.map(func(a: Dictionary) -> int: return int(a.level)), [5, 15, 25, 35], c + " passive levels")
		for a: Dictionary in passives:
			assert_false((a.get("passive", []) as Array).is_empty(), str(a.id) + " has modifiers")


func test_active_cooldowns_and_costs_in_range() -> void:
	for c: String in CLASSES:
		for id: String in _db().actives(c):
			var a := _db().get_ability(id)
			var lvl := int(a.level)
			if lvl == 1:
				continue
			var cd := float(a.cooldown_s)
			if c == "assassin":
				assert_between(cd, 6.0, 60.0, id + " cooldown (the assassin kit is built on short ones)")
				continue
			if lvl <= 10:
				assert_between(cd, 8.0, 20.0, id + " cooldown")
			else:
				assert_between(cd, 25.0, 60.0, id + " cooldown")
			var max_res := float(CharacterCatalog.load_default().class_def(c).resource.max)
			assert_between(float(a.cost) / max_res, 0.15, 0.35, id + " cost")


func test_all_ability_files_validate() -> void:
	assert_eq(_db().validate(true), [] as Array[String])


func test_every_ability_has_its_icon() -> void:
	for c: String in CLASSES:
		for a: Dictionary in _db().class_abilities(c):
			assert_true(ResourceLoader.exists(CombatHud.ICON_DIR % a.icon), str(a.id) + " icon " + str(a.icon))


func test_passives_come_from_data_by_level() -> void:
	var low := _hero("warrior", 1, Vector3(5, 0, 5))
	assert_eq(low.passives, [], "level 1: none yet")
	var p := f.world.add_player(2, Vector3(9, 0, 5))
	p.progress.level = 35
	ClassRules.setup_player(p, "warrior")
	assert_almost_eq(p.stats.armor, low.stats.armor * 1.10, 0.001, "Piel endurecida")
	for hook: String in ["rage_decay_mult", "block_generates_rage", "on_crit_heal_pct"]:
		assert_false(Passives.has_hook(p, hook).is_empty(), hook)
	var m := f.world.add_player(3, Vector3(13, 0, 5))
	m.progress.level = 5
	ClassRules.setup_player(m, "mage")
	assert_almost_eq(m.stats.max_resource, (160.0 + 2.0 * 20.0) * 1.10, 0.001, "Mente arcana at level 5 (+20 auto intellect)")
	assert_true(Passives.has_hook(m, "spell_power_after_no_damage_s").is_empty(), "Concentración is level 15")
	var a := f.world.add_player(4, Vector3(17, 0, 5))
	a.progress.level = 35
	ClassRules.setup_player(a, "assassin")
	assert_eq(Passives.has_hook(a, "bonus_vs_status").get("statuses"), ["stun", "root"], "Oportunista")
	assert_eq(int(Passives.has_hook(a, "after_dodge_combo").get("combo")), 2)


# --- Warrior ---------------------------------------------------------------------------

func test_warrior_full_kit() -> void:
	# Grito de guerra: +damage to the group around for 8 s.
	var w := _hero("warrior", 1, Vector3(5, 0, 5))
	var ally := _hero("cleric", 2, Vector3(8, 0, 5))
	assert_true(Combat.try_cast(f.world, w, "warrior_battle_cry", w.position))
	assert_true(w.has_status("damage_buff"))
	assert_true(ally.has_status("damage_buff"), "an ally 3 m away")
	assert_eq(_status(w, "damage_buff").end_tick, f.world.tick + f.world.ticks(8.0))
	# Torbellino: area of 3 m around.
	var w2 := _hero("warrior", 3, Vector3(30, 0, 5))
	var front := _target(Vector3(30, 0, 7))
	var back := _target(Vector3(30, 0, 3))
	var far := _target(Vector3(30, 0, 10))
	assert_true(Combat.try_cast(f.world, w2, "warrior_whirlwind", w2.position))
	assert_almost_eq(1000.0 - front.hp, 18 + 0.8 * 20, 0.01)
	assert_almost_eq(1000.0 - back.hp, 18 + 0.8 * 20, 0.01, "all around, not just in front")
	assert_eq(far.hp, 1000.0)
	# Provocar: enemies around must attack the warrior.
	var w3 := _hero("warrior", 4, Vector3(5, 0, 30))
	var m := _target(Vector3(8, 0, 30))
	assert_true(Combat.try_cast(f.world, w3, "warrior_taunt", w3.position))
	assert_true(m.has_status("taunted"))
	# Muro de escudo: -50 % damage taken for 6 s.
	var w4 := _hero("warrior", 5, Vector3(30, 0, 30))
	assert_true(Combat.try_cast(f.world, w4, "warrior_shield_wall", w4.position))
	assert_almost_eq(w4.status_magnitude("damage_reduction"), 0.5, 0.001)
	f.run(5.8)
	assert_true(w4.has_status("damage_reduction"))
	f.run(0.4)
	assert_false(w4.has_status("damage_reduction"), "6 s")


# --- Cleric ----------------------------------------------------------------------------

func test_cleric_full_kit() -> void:
	# Renovar: healing over time on the ally under the cursor.
	var c := _hero("cleric", 1, Vector3(5, 0, 5))
	var ally := _hero("warrior", 2, Vector3(9, 0, 5))
	ally.hp = 100.0
	assert_true(Combat.try_cast(f.world, c, "cleric_renew", ally.position))
	assert_eq(ally.hp, 100.0, "not at once")
	f.run(6.5)
	assert_almost_eq(ally.hp, 100.0 + 30 + 1.2 * 20, 0.01)
	# Nova sagrada: damage around and healing to allies around.
	var c2 := _hero("cleric", 3, Vector3(30, 0, 5))
	var friend := _hero("archer", 4, Vector3(32, 0, 5))
	friend.hp = 50.0
	var foe := _target(Vector3(30, 0, 7))
	assert_true(Combat.try_cast(f.world, c2, "cleric_holy_nova", c2.position))
	assert_almost_eq(1000.0 - foe.hp, 15 + 0.7 * 20, 0.01)
	assert_almost_eq(friend.hp, 50.0 + 15 + 0.6 * 20, 0.01)
	# Purificar: removes negative statuses from an ally.
	var c3 := _hero("cleric", 5, Vector3(5, 0, 30))
	var sick := _hero("mage", 6, Vector3(8, 0, 30))
	Combat.apply_status(f.world, foe, sick, {"kind": "poison", "duration_s": 10, "magnitude": 1, "every_s": 1})
	assert_true(Combat.try_cast(f.world, c3, "cleric_purify", sick.position))
	assert_false(sick.has_status("poison"))
	# Resurrección: raises a downed ally from afar; 60 s cooldown.
	var c4 := _hero("cleric", 7, Vector3(30, 0, 30))
	var down := _hero("assassin", 8, Vector3(30, 0, 45))
	down.hp = 0.0
	down.life = CombatEntity.DOWNED
	assert_true(Combat.try_cast(f.world, c4, "cleric_resurrection", down.position))
	assert_eq(down.life, CombatEntity.ALIVE)
	assert_eq(float(_db().get_ability("cleric_resurrection").cooldown_s), 60.0)


# --- Mage ------------------------------------------------------------------------------

func test_mage_full_kit() -> void:
	# Nova de escarcha: freezes enemies around for 2 s.
	var m := _hero("mage", 1, Vector3(5, 0, 5))
	var near := _target(Vector3(5, 0, 7))
	assert_true(Combat.try_cast(f.world, m, "mage_frost_nova", m.position))
	assert_true(near.has_status("freeze"))
	f.run(2.2)
	assert_false(near.has_status("freeze"), "2 s")
	# Barrera de maná: a shield on herself.
	var m2 := _hero("mage", 2, Vector3(30, 0, 5))
	assert_true(Combat.try_cast(f.world, m2, "mage_mana_barrier", Vector3(50, 0, 50)))
	assert_almost_eq(m2.shield, 50 + 1.2 * 20, 0.01)
	# Bola de fuego: a projectile that explodes in 2.5 m.
	var m3 := _hero("mage", 3, Vector3(5, 0, 30))
	var hit := _target(Vector3(5, 0, 36))
	var side := _target(Vector3(7, 0, 36))
	assert_true(Combat.try_cast(f.world, m3, "mage_fireball", hit.position))
	f.run(2.2) # 1.2 s of casting, then the flight
	assert_almost_eq(1000.0 - side.hp, 15 + 0.6 * 20, 0.01, "caught by the explosion")
	assert_almost_eq(1000.0 - hit.hp, 30 + 1.3 * 20 + 15 + 0.6 * 20, 0.01, "hit and explosion")
	assert_eq(_db().get_ability("mage_fireball").effects[0].damage.element, "fire", "Ignición reads it")
	# Descarga de escarcha: a projectile that slows.
	var m4 := _hero("mage", 4, Vector3(30, 0, 30))
	var slowed := _target(Vector3(30, 0, 36))
	assert_true(Combat.try_cast(f.world, m4, "mage_frostbolt", slowed.position))
	f.run(2.0) # 1 s of casting, then the flight
	assert_almost_eq(1000.0 - slowed.hp, 35 + 1.4 * 20, 0.01)
	assert_true(slowed.has_status("slow"))


# --- Archer ----------------------------------------------------------------------------

func test_archer_full_kit() -> void:
	# Red: roots an enemy for 3 s (needs one under the cursor).
	var a := _hero("archer", 1, Vector3(5, 0, 5))
	var netted := _target(Vector3(5, 0, 12))
	assert_false(Combat.try_cast(f.world, a, "archer_net", Vector3(15, 0, 15)), "nobody there")
	assert_true(Combat.try_cast(f.world, a, "archer_net", netted.position))
	assert_eq(_status(netted, "root").end_tick, f.world.tick + f.world.ticks(3.0))
	# Lluvia de flechas: 3 pulses in 3 m at the cursor after 0.4 s.
	var a2 := _hero("archer", 2, Vector3(30, 0, 5))
	var rained := _target(Vector3(30, 0, 13))
	assert_true(Combat.try_cast(f.world, a2, "archer_arrow_rain", Vector3(31, 0, 13)))
	f.run(0.3)
	assert_eq(rained.hp, 1000.0, "it waits")
	f.run(2.0)
	assert_almost_eq(1000.0 - rained.hp, 3 * (10 + 0.5 * 20), 0.01)
	# Trampa explosiva: armed after a moment, explodes when stepped on.
	var a3 := _hero("archer", 3, Vector3(5, 0, 30))
	var walker := _target(Vector3(5, 0, 36))
	assert_true(Combat.try_cast(f.world, a3, "archer_explosive_trap", walker.position))
	f.run(0.5)
	assert_eq(walker.hp, 1000.0, "not armed yet")
	f.run(1.0)
	assert_almost_eq(1000.0 - walker.hp, 40 + 1.2 * 20, 0.01)
	# Marca: the target takes +15 % damage.
	var a4 := _hero("archer", 4, Vector3(30, 0, 30))
	var marked := _target(Vector3(30, 0, 40))
	assert_true(Combat.try_cast(f.world, a4, "archer_mark", marked.position))
	assert_almost_eq(marked.status_magnitude("mark"), 0.15, 0.001)


# --- Assassin --------------------------------------------------------------------------

func test_assassin_full_kit() -> void:
	# Sigilo: out of combat, stealth with a short cooldown.
	var s := _hero("assassin", 1, Vector3(5, 0, 5))
	var t0 := f.world.tick
	assert_true(Combat.try_cast(f.world, s, "assassin_stealth", s.position))
	assert_true(s.has_status("stealth"))
	assert_eq(int(s.cooldowns["assassin_stealth"]), t0 + f.world.ticks(float(_db().get_ability("assassin_stealth").cooldown_s)))
	# In combat it vanishes: leaves combat, with the long cooldown.
	var s2 := _hero("assassin", 2, Vector3(30, 0, 5))
	s2.last_combat_tick = f.world.tick
	assert_true(s2.in_combat(f.world))
	assert_true(Combat.try_cast(f.world, s2, "assassin_stealth", s2.position))
	assert_true(s2.has_status("stealth"))
	assert_false(s2.in_combat(f.world), "vanished")
	assert_eq(int(s2.cooldowns["assassin_stealth"]),
		f.world.tick + f.world.ticks(float(_db().get_ability("assassin_stealth").combat_cooldown_s)))
	assert_gt(float(_db().get_ability("assassin_stealth").combat_cooldown_s), float(_db().get_ability("assassin_stealth").cooldown_s))
	# Abanico de cuchillas: area around and a combo point per enemy hit.
	var s3 := _hero("assassin", 3, Vector3(5, 0, 30))
	for pos: Vector3 in [Vector3(5, 0, 32), Vector3(7, 0, 30), Vector3(5, 0, 28)]:
		_target(pos)
	assert_true(Combat.try_cast(f.world, s3, "assassin_blade_fan", s3.position))
	assert_eq(s3.combo, 3)
	# Veneno: for 30 s hits apply a poison that stacks up to 5.
	var s4 := _hero("assassin", 4, Vector3(30, 0, 30))
	var victim := _target(Vector3(30, 0, 31.5))
	assert_true(Combat.try_cast(f.world, s4, "assassin_poison", s4.position))
	assert_eq(_status(s4, "envenom").end_tick, f.world.tick + f.world.ticks(30.0))
	for i in 6:
		s4.resource = s4.stats.max_resource
		assert_true(Combat.try_cast(f.world, s4, "assassin_stab", victim.position))
		f.run(0.6)
	assert_eq(_status(victim, "poison").stacks, 5, "capped at 5")


func test_mage_cast_time_waits_and_moving_cancels_it() -> void:
	var m := _hero("mage", 1, Vector3(5, 0, 5))
	m.level = 10
	var foe := _target(Vector3(5, 0, 11))
	var mana := m.resource
	assert_true(Combat.try_cast(f.world, m, "mage_fireball", foe.position))
	assert_true(Combat.channeling(f.world, m.id), "busy casting")
	f.run(0.6)
	assert_eq(foe.hp, 1000.0, "nothing lands before the cast ends")
	m.position += Vector3(1, 0, 0) # moves: the cast breaks
	f.run(1.0)
	assert_eq(foe.hp, 1000.0, "interrupted")
	assert_almost_eq(m.resource, mana, 0.01, "an interrupted cast costs nothing")
	assert_false(m.cooldowns.has("mage_fireball"), "and has no cooldown")
