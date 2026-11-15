extends GutTest


func _fixture(blocks := []) -> CombatFixture:
	var f := CombatFixture.new(blocks, Vector2i(40, 40))
	f.world.abilities = AbilityDB.load_default()
	return f


func _wolf(f: CombatFixture, pos: Vector3) -> MonsterState:
	var m := MonsterDB.load_default().make("wolf", f.world.next_monster_id(), pos, f.world)
	f.world.add_entity(m)
	return m


func _steps(f: CombatFixture, seconds: float) -> void:
	for i in f.world.ticks(seconds):
		f.log.append_array(f.world.events)
		f.world.events.clear()
		f.world.step({})
	f.log.append_array(f.world.events)


func test_monster_made_from_data() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(30, 0, 30))
	assert_eq(m.type_id, "wolf")
	assert_eq(m.team, CombatEntity.TEAM_MONSTERS)
	assert_eq(m.hp, m.stats.max_hp)
	assert_eq(m.home, Vector3(30, 0, 30))
	assert_eq(m.ai, MonsterState.IDLE)


func test_idle_until_player_in_range() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(30, 0, 30))
	f.player(1, Vector3(5, 0, 5))
	_steps(f, 1.0)
	assert_eq(m.ai, MonsterState.IDLE)
	assert_eq(m.position, Vector3(30, 0, 30))
	f.world.players[1].position = Vector3(25, 0, 30)
	_steps(f, 0.2)
	assert_eq(m.ai, MonsterState.CHASE)
	assert_eq(m.target_id, 1)


func test_ignores_stealthed_and_downed_players() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(30, 0, 30))
	var p := f.player(1, Vector3(26, 0, 30))
	p.add_status(StatusEffect.make("stealth", 100000), 1)
	_steps(f, 0.5)
	assert_eq(m.ai, MonsterState.IDLE, "stealthed")
	p.statuses.clear()
	p.life = CombatEntity.DOWNED
	_steps(f, 0.5)
	assert_eq(m.ai, MonsterState.IDLE, "downed")


func test_chases_and_attacks_in_range() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(30, 0, 30))
	var p := f.player(1, Vector3(24, 0, 30), 500.0)
	_steps(f, 3.0)
	assert_lt(Effects.flat(m.position).distance_to(Effects.flat(p.position)), 2.5, "reached the player")
	assert_lt(p.hp, 500.0, "bit the player")
	var casts := f.events_of("cast").filter(func(ev: Array) -> bool: return ev[1] == m.id)
	assert_gt(casts.size(), 0)


func test_damage_makes_an_idle_monster_chase() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(30, 0, 30))
	var p := f.player(1, Vector3(15, 0, 30))
	Combat.deal(f.world, p, m, {"damage": {"base": 1, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	_steps(f, 0.1)
	assert_eq(m.ai, MonsterState.CHASE)
	assert_eq(m.target_id, 1)


func test_paths_around_blocks_to_reach_player() -> void:
	var wall := []
	for z in range(20, 36):
		wall.append([27, z, 1])
	var f := _fixture(wall)
	var m := _wolf(f, Vector3(30.5, 0, 30.5))
	var p := f.player(1, Vector3(24.5, 0, 30.5), 500.0)
	m.threat[p.id] = 10.0 # already chasing it (e.g. it was shot), the wall hides the player
	_steps(f, 6.0)
	assert_lt(Effects.flat(m.position).distance_to(Effects.flat(p.position)), 2.5, "went around the wall")


## Attention point 5: the player is unreachable: no spinning, no stall; it goes home.
func test_unreachable_target_leashes_home_and_heals() -> void:
	var box := []
	for i in range(8, 13):
		box.append([i, 8, 1])
		box.append([i, 12, 1])
		box.append([8, i, 1])
		box.append([12, i, 1])
	var f := _fixture(box)
	var m := _wolf(f, Vector3(16.5, 0, 10.5))
	var p := f.player(1, Vector3(10.5, 0, 10.5))
	m.threat[p.id] = 10.0
	m.ai = MonsterState.CHASE
	m.hp = 10.0
	_steps(f, 8.0)
	assert_eq(m.ai, MonsterState.IDLE)
	assert_lt(m.position.distance_to(m.home), 1.0)
	assert_eq(m.hp, m.stats.max_hp, "healed on return")
	assert_true(m.threat.is_empty())


func test_leashes_when_dragged_too_far() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(35, 0, 35))
	var p := f.player(1, Vector3(33, 0, 35), 10000.0)
	_steps(f, 0.5)
	p.position = Vector3(5, 0, 5)
	_steps(f, 12.0)
	assert_eq(m.ai, MonsterState.IDLE)
	assert_lt(m.position.distance_to(m.home), 1.0)


func test_sim_tick_time_bounded_with_30_monsters() -> void:
	var f := _fixture()
	for i in 30:
		var m := _wolf(f, Vector3(5 + (i % 6) * 5, 0, 5 + (i / 6) * 6))
		m.threat[1] = 1.0
		m.ai = MonsterState.CHASE
	f.player(1, Vector3(20, 0, 20), 1e9)
	var start := Time.get_ticks_usec()
	_steps(f, 2.0)
	var per_tick_ms := (Time.get_ticks_usec() - start) / 1000.0 / f.world.ticks(2.0)
	gut.p("30 monsters: %.2f ms per tick" % per_tick_ms)
	assert_lt(per_tick_ms, 33.0, "fits in a 30 Hz tick")
