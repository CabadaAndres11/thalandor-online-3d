extends GutTest
## Allied summons: a monster of data/monsters on the players' team that follows its owner
## and fights for them.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	var list: Array = [{"id": "call", "class": "test", "kind": "active", "cost": 0, "cooldown_s": 1, "gcd": false, "range": 0,
		"effects": [{"type": "summon", "monster": "marked_hound", "duration_s": 30, "max": 1}]}]
	for id: String in MonsterDB.load_default().get_type("marked_hound").abilities:
		list.append(AbilityDB.load_default().get_ability(id))
	f.world.abilities = AbilityDB.from_list(list)


func _call(p: PlayerState) -> MonsterState:
	p.cooldowns.clear()
	assert_true(Combat.try_cast(f.world, p, "call", p.position))
	for m: CombatEntity in f.world.monsters.values():
		if m is MonsterState and (m as MonsterState).summoned_by == p.id:
			return m
	return null


func _steps(n: int) -> void:
	for i in n:
		f.world.step({})


func _summon() -> Array:
	var p := f.player(1, Vector3(10, 0, 10), 100.0)
	p.level = 7
	return [p, _call(p)]


func test_summon_is_an_ally_of_the_owners_level() -> void:
	var s := _summon()
	var m: MonsterState = s[1]
	assert_not_null(m)
	assert_eq(m.team, CombatEntity.TEAM_PLAYERS)
	assert_eq(m.summoned_by, 1)
	assert_eq(m.level, 7)
	assert_gt(m.despawn_tick, f.world.tick)
	assert_eq(m.hp, m.stats.max_hp)


func test_summon_follows_and_attacks() -> void:
	var s := _summon()
	var p: PlayerState = s[0]
	var m: MonsterState = s[1]
	p.position = Vector3(30, 0, 10)
	_steps(150)
	assert_lt(Effects.flat(m.position).distance_to(Effects.flat(p.position)), 5.0, "it caught up with its owner")
	var foe := f.dummy(2000, Vector3(33, 0, 10), 1000.0)
	p.last_target_id = foe.id
	_steps(90)
	assert_lt(foe.hp, 1000.0, "it attacks what the owner last hit")
	assert_eq(m.target_id, foe.id)


func test_summon_attacks_whoever_attacks_the_owner() -> void:
	var s := _summon()
	var p: PlayerState = s[0]
	var foe := f.dummy(2000, Vector3(13, 0, 10), 1000.0)
	foe.target_id = p.id
	_steps(90)
	assert_lt(foe.hp, 1000.0)


func test_summon_teleports_when_left_far_behind() -> void:
	var s := _summon()
	var p: PlayerState = s[0]
	var m: MonsterState = s[1]
	p.position = Vector3(55, 0, 55)
	_steps(2)
	assert_lt(Effects.flat(m.position).distance_to(Effects.flat(p.position)), 3.0)


func test_summon_gives_no_xp() -> void:
	var s := _summon()
	var p: PlayerState = s[0]
	var m: MonsterState = s[1]
	var before := p.progress.xp
	m.hp = 0.0
	f.world.on_zero_hp(m)
	assert_eq(p.progress.xp, before)
	assert_false(p.progress_dirty)


func test_summon_does_not_scale_group_health() -> void:
	var s := _summon()
	var m: MonsterState = s[1]
	var hp := m.stats.max_hp
	f.player(2, Vector3(12, 0, 10), 100.0)
	assert_eq(m.stats.max_hp, hp)
	f.world.set_arena_level(30)
	assert_eq(m.level, 7, "the arena level does not touch it")


func test_summon_gone_when_owner_dies() -> void:
	var s := _summon()
	var p: PlayerState = s[0]
	var m: MonsterState = s[1]
	f.player(2, Vector3(12, 0, 10), 100.0)
	p.hp = 0.0
	f.world.on_zero_hp(p)
	assert_false(f.world.monsters.has(m.id))
	assert_true(f.world.events.any(func(e: Array) -> bool: return e[0] == "summon_end"))


func test_summon_gone_when_time_is_up() -> void:
	var s := _summon()
	var m: MonsterState = s[1]
	_steps(31 * 30)
	assert_false(f.world.monsters.has(m.id))


func test_only_one_summon() -> void:
	var s := _summon()
	var first: MonsterState = s[1]
	var second := _call(s[0])
	assert_false(f.world.monsters.has(first.id), "the first one left")
	assert_true(f.world.monsters.has(second.id))
	var count := f.world.monsters.values().filter(func(e: CombatEntity) -> bool: return (e as MonsterState).summoned_by == 1).size()
	assert_eq(count, 1)


func test_enemy_can_target_summon() -> void:
	var s := _summon()
	var m: MonsterState = s[1]
	(s[0] as PlayerState).position = Vector3(55, 0, 55)
	m.position = Vector3(30, 0, 30)
	var foe := MonsterDB.load_default().make("cultist", f.world.next_monster_id(), Vector3(33, 0, 30), f.world)
	f.world.add_entity(foe)
	m.target_id = 0
	foe.add_threat(m.id, 5.0)
	_steps(30)
	assert_eq(foe.target_id, m.id, "the monster fights the summon")


func test_enemy_aggro_sees_a_summon() -> void:
	var s := _summon()
	var m: MonsterState = s[1]
	(s[0] as PlayerState).position = Vector3(38, 0, 38)
	m.position = Vector3(30, 0, 30)
	var foe := MonsterDB.load_default().make("cultist", f.world.next_monster_id(), Vector3(34, 0, 30), f.world)
	f.world.add_entity(foe)
	_steps(5)
	assert_true(foe.threat.has(m.id), "the cultist noticed the hound")



func test_summon_rows_carry_the_ally_flag() -> void:
	var rows := [[1000, "marked_hound", Vector3(1, 0, 1), 0.0, 10.0, 10.0, 0, 0, 3, 7]]
	var m := Protocol.decode(Protocol.snapshot(1, [], rows))
	assert_eq(m.monsters[0][8], 3, "elite and ally bits both survive")
	var c := ClientSession.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [5, 5], "blocks": []}), "0", "Ana", "warrior")
	c.my_id = 1
	c.status = ClientSession.Status.IN_GAME
	c._on_snapshot(5, [], m.monsters)
	assert_true(c.monsters[1000].ally)
	assert_true(c.monsters[1000].elite)


func test_ally_avatar_has_a_green_bar() -> void:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type("marked_hound"), false, 1.3, true)
	var enemy := MonsterAvatar.new()
	add_child_autofree(enemy)
	enemy.setup(MonsterDB.load_default().get_type("marked_hound"), false, 1.3, false)
	assert_ne(a.bar.fill_color(), enemy.bar.fill_color())
