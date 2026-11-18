extends GutTest

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(80, 80))


func _monster(pos := Vector3(20, 0, 20), level := 1) -> MonsterState:
	var m := MonsterDB.load_default().make("cultist", f.world.next_monster_id(), pos, f.world, level)
	f.world.add_entity(m)
	return m


func _kill(m: MonsterState) -> void:
	m.hp = 0.0
	f.world.on_zero_hp(m)


func test_kill_gives_xp_to_near_players() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	var b := f.player(2, Vector3(25, 0, 20))
	_kill(_monster())
	# 8 xp shared by 2: round(8 * 1.1 / 2) = 4 each
	assert_eq(a.progress.xp, 4)
	assert_eq(b.progress.xp, 4)
	assert_true(a.progress_dirty)


func test_far_player_gets_none() -> void:
	var a := f.player(1, Vector3(51, 0, 20))
	_kill(_monster())
	assert_eq(a.progress.xp, 0)
	assert_false(a.progress_dirty)
	var b := f.player(2, Vector3(49.9, 0, 20))
	_kill(_monster())
	assert_gt(b.progress.xp, 0)


func test_downed_player_gets_share() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	a.life = CombatEntity.DOWNED
	_kill(_monster())
	assert_eq(a.progress.xp, 8)


func test_dead_player_gets_none() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	a.life = CombatEntity.DEAD
	_kill(_monster())
	assert_eq(a.progress.xp, 0)


func test_level_up_refills_hp_not_rage() -> void:
	var a := f.player(1, Vector3(21, 0, 20), 100.0, 100.0)
	a.progress.xp = 97
	a.hp = 10.0
	a.resource_kind = "rage"
	a.resource = 5.0
	var mana := f.player(2, Vector3(22, 0, 20), 100.0, 100.0)
	mana.progress.xp = 97
	mana.resource_kind = "mana"
	mana.resource = 5.0
	_kill(_monster())
	assert_eq(a.progress.level, 2)
	assert_eq(a.level, 2)
	assert_eq(a.hp, a.stats.max_hp)
	assert_eq(a.resource, 5.0)
	assert_eq(mana.resource, mana.stats.max_resource)


func test_level_up_event() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	a.progress.xp = 99
	f.world.events.clear()
	_kill(_monster())
	assert_true(f.world.events.any(func(e: Array) -> bool: return e == ["level_up", 1, 2]))


func test_boss_minions_give_none() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	var m := _monster()
	m.summoned_by = 5
	_kill(m)
	assert_eq(a.progress.xp, 0)


func test_boss_gives_ten_times_and_higher_level_gives_more() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	var boss := MonsterDB.load_default().make("guard_beast", f.world.next_monster_id(), Vector3(20, 0, 20), f.world, 3)
	f.world.add_entity(boss)
	_kill(boss)
	assert_gt(a.progress.xp + 100 * (a.progress.level - 1), 100)


func test_low_level_monster_gives_reduced_xp() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	a.progress.level = 13
	_kill(_monster(Vector3(20, 0, 20), 1))
	assert_eq(a.progress.xp, roundi(8.0 * 0.1))


func test_minions_are_marked_when_boss_calls_them() -> void:
	var boss := MonsterDB.load_default().make("guard_beast", f.world.next_monster_id(), Vector3(20, 0, 20), f.world)
	boss.phase = 3
	boss.add_threat(1, 1.0)
	f.world.add_entity(boss)
	MonsterAI._maybe_summon(f.world, boss)
	assert_gt(boss.minions.size(), 0)
	for id: int in boss.minions:
		assert_eq((f.world.entity(id) as MonsterState).summoned_by, boss.id)


func test_level_up_does_not_refill_a_downed_player() -> void:
	var a := f.player(1, Vector3(21, 0, 20))
	f.player(2, Vector3(22, 0, 20))
	a.life = CombatEntity.DOWNED
	a.hp = 0.0
	a.progress.xp = 97
	_kill(_monster())
	assert_eq(a.progress.level, 2, "it still levels up")
	assert_eq(a.hp, 0.0, "but stays on the ground")
