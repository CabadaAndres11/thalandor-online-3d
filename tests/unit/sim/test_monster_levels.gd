extends GutTest

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new()


func _cultist(level: int, elite := false) -> MonsterState:
	var m := MonsterDB.load_default().make("cultist", f.world.next_monster_id(), Vector3(15, 0, 15), f.world, level)
	if elite:
		MonsterDB.make_elite(m, f.world.balance)
	Spawner.scale_health(f.world, m, 1.0)
	f.world.add_entity(m)
	return m


func test_level_scales_stats() -> void:
	var m := MonsterDB.load_default().make("cultist", 1500, Vector3.ZERO, f.world, 11)
	assert_eq(m.level, 11)
	assert_almost_eq(m.stats.max_hp, 55.0 * 2.7, 0.01)
	assert_almost_eq(m.base_max_hp, 55.0 * 2.7, 0.01)
	assert_almost_eq(m.hp, 55.0 * 2.7, 0.01)
	assert_almost_eq(m.stats.armor, 5.0 * 1.6, 0.01)
	assert_almost_eq(m.stats.damage_done_mult, 2.15, 0.001)


func test_level_one_is_unchanged() -> void:
	var m := MonsterDB.load_default().make("cultist", 1500, Vector3.ZERO, f.world)
	assert_eq(m.level, 1)
	assert_almost_eq(m.stats.max_hp, 55.0, 0.001)
	assert_almost_eq(m.stats.damage_done_mult, 1.0, 0.001)


func test_boss_is_two_above() -> void:
	f.world.set_arena_level(5)
	assert_eq(f.world.monster_level({}, {"boss": true}), 7)
	assert_eq(f.world.monster_level({}, {}), 5)
	assert_eq(f.world.monster_level({"level_offset": 2}, {}), 7)


func test_set_arena_level_respawns_idle_only() -> void:
	var idle := _cultist(1)
	var busy := _cultist(1)
	busy.add_threat(1, 5.0)
	f.world.set_arena_level(11)
	assert_eq(f.world.arena_level, 11)
	assert_eq(idle.level, 11)
	assert_almost_eq(idle.stats.max_hp, 55.0 * 2.7, 0.01)
	assert_almost_eq(idle.hp, idle.stats.max_hp, 0.01)
	assert_eq(busy.level, 1)
	assert_true(f.world.events.any(func(e: Array) -> bool: return e == ["arena_level", 11]))


func test_arena_level_clamped() -> void:
	f.world.set_arena_level(0)
	assert_eq(f.world.arena_level, 1)
	f.world.set_arena_level(999)
	assert_eq(f.world.arena_level, 60)


func test_elite_keeps_elite_on_rescale() -> void:
	var m := _cultist(1, true)
	f.world.set_arena_level(11)
	assert_true(m.elite)
	assert_almost_eq(m.stats.max_hp, 55.0 * 2.7 * f.world.balance.elite_hp_mult, 0.01)
	assert_almost_eq(m.stats.damage_done_mult, 2.15 * f.world.balance.elite_damage_mult, 0.001)


func test_group_rescale_keeps_level() -> void:
	var m := _cultist(1)
	f.world.set_arena_level(11)
	f.player(1, Vector3(5, 0, 5))
	f.player(2, Vector3(6, 0, 5))
	assert_eq(m.level, 11)
	assert_almost_eq(m.stats.max_hp, 55.0 * 2.7 * (1.0 + f.world.balance.group_hp_scale), 0.01)


func test_spawner_uses_arena_level() -> void:
	f.world.set_arena_level(7)
	var m := MonsterDB.load_default().make("cultist", 1500, Vector3.ZERO, f.world, f.world.monster_level({}, {}))
	assert_eq(m.level, 7)


func test_mitigation_grows_k() -> void:
	var b := f.world.balance
	assert_almost_eq(Damage.mitigation(60.0, b), 0.5, 0.0001)
	assert_almost_eq(Damage.mitigation(60.0, b, 1), 0.5, 0.0001)
	assert_almost_eq(Damage.mitigation(60.0, b, 11), 60.0 / 180.0, 0.0001)


func test_attacker_level_weakens_armor_in_roll() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var m := _cultist(1)
	m.stats.armor = 60.0
	m.stats.dodge_chance = 0.0
	p.stats.crit_chance = 0.0
	var low: float = Damage.roll(p, m, {"base": 100.0, "kind": "physical", "can_crit": false}, f.world).amount
	p.level = 11
	var high: float = Damage.roll(p, m, {"base": 100.0, "kind": "physical", "can_crit": false}, f.world).amount
	assert_almost_eq(low, 50.0, 0.01)
	assert_almost_eq(high, 100.0 * (1.0 - 60.0 / 180.0), 0.01)
