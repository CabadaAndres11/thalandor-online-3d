extends GutTest
## Task 13: the orc king boss (phases by health, telegraphed jump, goblin calls,
## death announcement and respawn).


func _fixture() -> CombatFixture:
	var f := CombatFixture.new([], Vector2i(48, 48))
	f.world.abilities = AbilityDB.load_default()
	return f


func _boss(f: CombatFixture, pos := Vector3(20, 0, 20)) -> MonsterState:
	var m := MonsterDB.load_default().make("orc_king", f.world.next_monster_id(), pos, f.world)
	m.facing = 0.0
	f.world.add_entity(m)
	return m


func _step(f: CombatFixture) -> void:
	f.world.events.clear()
	f.world.step({})
	f.log.append_array(f.world.events)


func _steps(f: CombatFixture, seconds: float) -> void:
	for i in f.world.ticks(seconds):
		_step(f)


func _events(f: CombatFixture, kind: String) -> Array:
	return f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == kind)


func _goblins(f: CombatFixture) -> Array:
	return f.world.monsters.values().filter(func(m: CombatEntity) -> bool: return m.type_id == "goblin" and m.is_alive())


func test_boss_data() -> void:
	var d := MonsterDB.load_default().get_type("orc_king")
	assert_eq(d.behavior, "boss")
	assert_true(bool(d.get("boss", false)))
	assert_eq(d.get("name"), "MON_ORC_KING")
	for ab: String in d.abilities + [d.jump.ability]:
		assert_true(AbilityDB.load_default().has(ab), ab)


func test_boss_phases_by_hp() -> void:
	assert_eq(MonsterAI.phase_for(1.0), 1)
	assert_eq(MonsterAI.phase_for(0.67), 1)
	assert_eq(MonsterAI.phase_for(0.66), 2)
	assert_eq(MonsterAI.phase_for(0.34), 2)
	assert_eq(MonsterAI.phase_for(0.33), 3)
	assert_eq(MonsterAI.phase_for(0.0), 3)
	var f := _fixture()
	var boss := _boss(f)
	f.player(1, Vector3(20, 0, 22), 5000.0)
	_steps(f, 0.2)
	assert_eq(boss.phase, 1)
	boss.hp = boss.stats.max_hp * 0.6
	_steps(f, 0.1)
	assert_eq(boss.phase, 2)
	boss.hp = boss.stats.max_hp * 0.3
	_steps(f, 0.1)
	assert_eq(boss.phase, 3)
	var phases := _events(f, "boss_phase").map(func(ev: Array) -> int: return int(ev[2]))
	assert_eq(phases, [2, 3], "each new phase is announced")


func test_phase_1_only_cleaves() -> void:
	var f := _fixture()
	var boss := _boss(f)
	var p := f.player(1, Vector3(20, 0, 27), 5000.0) # 7 m: in jump range
	_steps(f, 3.0)
	assert_eq(_events(f, "telegraph").size(), 0, "no jumps in phase 1")
	assert_lt(p.hp, 5000.0, "it walks up and cleaves")
	assert_eq(boss.phase, 1)


func test_boss_jump_telegraph_then_damage() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 27), 5000.0)
	for i in f.world.ticks(2.0):
		_step(f)
		if not _events(f, "telegraph").is_empty():
			break
	var tele := _events(f, "telegraph")
	assert_eq(tele.size(), 1, "the landing spot is warned")
	var ev: Array = tele[0]
	assert_almost_eq(float(ev[3]), 4.0, 0.001, "4 m area")
	assert_almost_eq(Effects.flat(ev[2]).distance_to(Effects.flat(p.position)), 0.0, 0.01, "on the player")
	var fire_tick: int = ev[4]
	assert_eq(fire_tick - f.world.tick + 1, f.world.ticks(1.2), "warned 1.2 s ahead")
	var landing: Vector3 = ev[2]
	while f.world.tick < fire_tick - 1:
		_step(f)
	assert_eq(p.hp, 5000.0, "nothing before the impact")
	_steps(f, 0.2)
	assert_lt(p.hp, 5000.0, "the landing hurts whoever stayed")
	assert_lt(Effects.flat(boss.position).distance_to(Effects.flat(landing)), 0.5, "it lands there")


func test_boss_jump_can_be_dodged() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.6
	var p := f.player(1, Vector3(20, 0, 27), 5000.0)
	for i in f.world.ticks(2.0):
		_step(f)
		if not _events(f, "telegraph").is_empty():
			break
	p.position = Vector3(27, 0, 27) # out of the 4 m circle
	_steps(f, 1.3)
	var hits := _events(f, "hit").filter(func(e: Array) -> bool: return int(e[1]) == p.id)
	assert_eq(hits.size(), 0)


func test_boss_summons_goblins() -> void:
	var f := _fixture()
	var boss := _boss(f)
	boss.hp = boss.stats.max_hp * 0.3
	var p := f.player(1, Vector3(20, 0, 22), 50000.0)
	_steps(f, 0.2)
	var first := _goblins(f)
	assert_eq(first.size(), 3, "it calls 3 goblins when phase 3 starts")
	for g: MonsterState in first:
		assert_true(g.threat.has(p.id), "the goblins join the fight")
		assert_lt(Effects.flat(g.position).distance_to(Effects.flat(boss.position)), 4.0)
		assert_eq(g.spawn_index, -1, "they do not respawn")
	_steps(f, 15.0)
	assert_eq(_goblins(f).size() <= 3, true, "no new call before 20 s")
	_steps(f, 5.5)
	assert_gt(f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == "spawned" and str(ev[2]) == "goblin").size(), 3,
		"another call after 20 s")


func test_boss_death_announced_and_respawns() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"respawn_point": [20, 20], "spawns": [
			{"type": "orc_king", "at": [30, 30], "count": 1, "radius": 0, "respawn_s": 30, "elite_chance": 1.0}]})
	var b := Balance.load_from()
	b.boss_respawn_s = 3.0
	var w := SimWorld.new(b, map, 3)
	w.step({})
	var boss: MonsterState = w.monsters.values()[0]
	assert_false(boss.elite, "bosses are never elite")
	Damage.apply(boss, {"amount": 999999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	var downs := w.events.filter(func(ev: Array) -> bool: return str(ev[0]) == "boss_down")
	assert_eq(downs.size(), 1)
	assert_eq(downs[0][1], "orc_king")
	for i in w.ticks(2.5):
		w.step({})
	assert_eq(w.monsters.values().filter(func(m: CombatEntity) -> bool: return m.is_alive()).size(), 0,
		"boss_respawn_s, not the point's respawn_s")
	for i in w.ticks(3.0):
		w.step({})
	assert_eq(w.monsters.values().filter(func(m: CombatEntity) -> bool: return m.is_alive() and m.type_id == "orc_king").size(), 1)
