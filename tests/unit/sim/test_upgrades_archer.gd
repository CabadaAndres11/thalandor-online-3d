extends GutTest
## The archer's level 50 upgrades (Sharpshooter and Hunter) and the hunter's wolf.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(80, 80))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String, pos := Vector3(10, 0, 10)) -> PlayerState:
	var p := f.world.add_player(1, pos)
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "archer", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	return p


func _foe(id: int, pos: Vector3) -> CombatEntity:
	var d := f.dummy(id, pos, 50000.0)
	d.stats.dodge_chance = 0.0
	return d


func _lost(e: CombatEntity) -> float:
	return 50000.0 - e.hp


# --- Sharpshooter ------------------------------------------------------------------------

func test_aimed_shot() -> void:
	var p := _hero("sharpshooter")
	var foe := _foe(2000, Vector3(10, 0, 35))
	assert_true(Combat.try_cast(f.world, p, "archer_aimed_shot", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 40.0)
	assert_eq(p.cooldowns["archer_aimed_shot"], f.world.tick + f.world.ticks(12.0))
	assert_true(Combat.channeling(f.world, p.id))
	f.run(1.4)
	assert_eq(foe.hp, 50000.0, "still aiming")
	f.run(1.5)
	assert_almost_eq(_lost(foe), (40.0 + 2.5 * p.stats.attack_power) * 1.15 * 1.15, 0.01, "plus Alcance letal (25 m) and Paciencia (1.5 s still)")
	assert_false(Combat.channeling(f.world, p.id))


func test_aimed_shot_is_cut_by_moving() -> void:
	var p := _hero("sharpshooter")
	var foe := _foe(2000, Vector3(10, 0, 35))
	assert_true(Combat.try_cast(f.world, p, "archer_aimed_shot", foe.position))
	f.run(0.5)
	p.position += Vector3(1, 0, 0)
	f.run(3.0)
	assert_eq(foe.hp, 50000.0, "no shot")
	assert_eq(f.events_of("channel_end").size(), 1)


func test_burst() -> void:
	var p := _hero("sharpshooter")
	var foe := _foe(2000, Vector3(10, 0, 18)) # 8 m: inside Alcance letal's 10 m
	assert_true(Combat.try_cast(f.world, p, "archer_burst", foe.position))
	assert_eq(p.resource, p.stats.max_resource - 30.0)
	assert_eq(p.cooldowns["archer_burst"], f.world.tick + f.world.ticks(8.0))
	f.run(1.5)
	assert_almost_eq(_lost(foe), 3.0 * (10.0 + 0.8 * p.stats.attack_power), 0.01, "three shots")


func test_weak_point() -> void:
	var p := _hero("sharpshooter")
	assert_almost_eq(p.stats.crit_damage, 0.3, 0.0001)
	var foe := _foe(2000, Vector3(11, 0, 10))
	var spec := {"base": 100, "coef": 0, "kind": "magic", "force_crit": true}
	var r := Damage.roll(p, foe, spec, f.world)
	assert_almost_eq(r.amount, 100.0 * (f.world.balance.crit_multiplier + 0.3), 0.01)


func test_patience() -> void:
	var p := _hero("sharpshooter")
	var h := Passives.has_hook(p, "stationary_damage")
	assert_eq([h.seconds, h.pct], [1.5, 0.15])


func test_shot_evolution_charged_shot_pierces_three() -> void:
	var p := _hero("sharpshooter")
	var foes: Array = []
	for i in 4:
		foes.append(_foe(2000 + i, Vector3(10, 0, 14 + i * 2.0)))
	assert_true(ClassRules.release_charged(f.world, p, "archer_shot", Vector3(10, 0, 40), 1.0))
	f.run(2.0)
	for i in 3:
		assert_lt((foes[i] as CombatEntity).hp, 50000.0, "enemy %d is hit" % i)
	assert_eq((foes[3] as CombatEntity).hp, 50000.0, "it stops after the third")


func test_shot_evolution_needs_80_percent_and_the_upgrade() -> void:
	var p := _hero("sharpshooter")
	var a := _foe(2000, Vector3(10, 0, 14))
	var b := _foe(2001, Vector3(10, 0, 16))
	assert_true(ClassRules.release_charged(f.world, p, "archer_shot", Vector3(10, 0, 40), 0.5))
	f.run(2.0)
	assert_lt(a.hp, 50000.0)
	assert_eq(b.hp, 50000.0, "a half charge does not pierce")
	f.world.players.clear()
	var q := _hero("hunter", Vector3(30, 0, 10))
	var c := _foe(2002, Vector3(30, 0, 14))
	var d := _foe(2003, Vector3(30, 0, 16))
	assert_true(ClassRules.release_charged(f.world, q, "archer_shot", Vector3(30, 0, 40), 1.0))
	f.run(2.0)
	assert_lt(c.hp, 50000.0)
	assert_eq(d.hp, 50000.0, "without the evolution it stops at the first")


# --- Hunter ------------------------------------------------------------------------------

func test_multishot() -> void:
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_multishot", Vector3(10, 0, 30)))
	assert_eq(p.resource, p.stats.max_resource - 35.0)
	assert_eq(p.cooldowns["archer_multishot"], f.world.tick + f.world.ticks(8.0))
	assert_eq(f.world.projectiles.size(), 5)
	var spread := f.world.projectiles.map(func(pr: Projectile) -> float: return absf(rad_to_deg(pr.dir.angle_to(Vector2(0, 1)))))
	spread.sort()
	assert_almost_eq(float(spread[4]), 20.0, 0.1, "a 40 degree fan")
	var foe := _foe(2000, Vector3(10, 0, 17))
	f.run(1.5)
	assert_almost_eq(_lost(foe), 12.0 + 0.8 * p.stats.attack_power, 0.01, "the middle one hits")


func test_companion() -> void:
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_companion", p.position))
	assert_eq(p.resource, p.stats.max_resource - 30.0)
	assert_eq(p.cooldowns["archer_companion"], f.world.tick + f.world.ticks(60.0))
	var wolf := _wolf()
	assert_not_null(wolf)
	assert_eq(wolf.team, CombatEntity.TEAM_PLAYERS)
	assert_eq(wolf.despawn_tick, f.world.tick + f.world.ticks(30.0))
	assert_eq(wolf.level, 50)


func _wolf() -> MonsterState:
	for m: CombatEntity in f.world.monsters.values():
		if m is MonsterState and m.type_id == "hunter_wolf":
			return m
	return null


func test_hunter_wolf_at_level_1() -> void:
	var w := MonsterDB.load_default().make("hunter_wolf", 1500, Vector3.ZERO, f.world, 1)
	assert_eq(w.stats.max_hp, 80.0)
	assert_eq(w.stats.armor, 10.0)
	assert_eq(w.stats.attack_power, 10.0)
	assert_eq(w.def.speed, 6.0)
	var bite := f.world.abilities.get_ability("hunter_wolf_bite")
	assert_eq(bite.cooldown_s, 1.2)
	assert_eq(bite.effects[0].damage.base, 6)
	assert_eq(bite.effects[0].damage.coef, 0.8)
	assert_true(w.def.summon_only)


func test_second_summon_replaces_first() -> void:
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_companion", p.position))
	var first := _wolf()
	p.cooldowns.clear()
	p.gcd_end = 0
	assert_true(Combat.try_cast(f.world, p, "archer_companion", p.position))
	var wolves := f.world.monsters.values().filter(func(m: CombatEntity) -> bool: return m.type_id == "hunter_wolf")
	assert_eq(wolves.size(), 1)
	assert_ne((wolves[0] as CombatEntity).id, first.id)


func test_wolf_follows_and_bites() -> void:
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_companion", p.position))
	var foe := _foe(2000, Vector3(14, 0, 10))
	p.last_target_id = foe.id
	for i in 120:
		f.world.step({})
	assert_lt(foe.hp, 50000.0)


func test_reset_upgrade_removes_wolf() -> void:
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_companion", p.position))
	assert_not_null(_wolf())
	ProgressRequests.clear_upgrade(f.world, p)
	Progression.rebuild(p, f.world)
	assert_null(_wolf())


func test_trapper() -> void:
	f.world.abilities = AbilityDB.load_default()
	var p := _hero("hunter")
	assert_true(Combat.try_cast(f.world, p, "archer_explosive_trap", Vector3(10, 0, 16)))
	assert_eq(f.world.traps[0].rearms, 1)
	f.world.players.clear()
	f.world.traps.clear()
	var q := _hero("sharpshooter")
	assert_true(Combat.try_cast(f.world, q, "archer_explosive_trap", Vector3(10, 0, 16)))
	assert_eq(f.world.traps[0].rearms, 0)


func test_survivor() -> void:
	var a := _hero("sharpshooter")
	var hp := a.stats.max_hp
	var speed := a.stats.move_speed_mult
	f.world.players.clear()
	var b := _hero("hunter")
	assert_almost_eq(b.stats.max_hp, hp * 1.1, 0.01)
	assert_almost_eq(b.stats.move_speed_mult, speed * 1.1, 0.0001)


func test_net_evolution_catches_everyone_around_the_cursor() -> void:
	var p := _hero("hunter")
	var near := [_foe(2000, Vector3(10, 0, 22)), _foe(2001, Vector3(11.5, 0, 22)), _foe(2002, Vector3(10, 0, 24))]
	var far := _foe(2003, Vector3(10, 0, 29))
	assert_true(Combat.try_cast(f.world, p, "archer_net", Vector3(10, 0, 22)))
	for e: CombatEntity in near:
		assert_true(e.has_status("root"))
		assert_eq(e.statuses[0].end_tick, f.world.tick + f.world.ticks(3.0))
	assert_false(far.has_status("root"))
	f.world.players.clear()
	var q := _hero("sharpshooter", Vector3(40, 0, 10))
	var one := _foe(2100, Vector3(40, 0, 22))
	var two := _foe(2101, Vector3(41, 0, 22))
	assert_true(Combat.try_cast(f.world, q, "archer_net", Vector3(40, 0, 22)))
	assert_true(one.has_status("root") != two.has_status("root"), "the base net catches only one")


# --- Look and shape -----------------------------------------------------------------------

func test_crossbow_piece_on_hunter_look() -> void:
	var cat := CharacterCatalog.load_default()
	var ids := func(look: Dictionary) -> Array: return look.pieces.map(func(p: Dictionary) -> String: return p.id)
	assert_has(ids.call(cat.resolve("archer", {}, "hunter")), "weapon_crossbow")
	assert_does_not_have(ids.call(cat.resolve("archer", {}, "hunter")), "weapon_bow")
	assert_has(ids.call(cat.resolve("archer", {}, "sharpshooter")), "weapon_bow")
	assert_has(ids.call(cat.resolve("archer", {}, "")), "weapon_bow")
	var rig := HumanRig.create("archer", {}, null, "hunter")
	add_child_autofree(rig)
	assert_has(rig.pieces(), "weapon_crossbow")
	assert_true(FileAccess.file_exists("res://assets/characters/pieces/weapon_crossbow.vox"))


func test_wolf_is_a_collarless_grey_hound() -> void:
	var d := MonsterDB.load_default().get_type("hunter_wolf")
	assert_eq(d.model, "rig:hunter_wolf")
	assert_ne(d.tint, MonsterDB.load_default().get_type("marked_hound").tint)
	assert_true(FileAccess.file_exists("res://assets/monsters/vox/hunter_wolf.json"))
	assert_ne(tr(str(d.name)), str(d.name))
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(d, false, 1.3, true)
	assert_not_null(a.body)


func test_each_upgrade_is_complete_with_texts_and_icons() -> void:
	for id: String in ["sharpshooter", "hunter"]:
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
