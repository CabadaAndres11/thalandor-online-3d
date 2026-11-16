extends GutTest


func _world(spawns: Array) -> SimWorld:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"respawn_point": [20, 20], "spawns": spawns})
	var b := Balance.load_from()
	return SimWorld.new(b, map, 3)


func _monsters(w: SimWorld) -> Array:
	return w.monsters.values().filter(func(m: CombatEntity) -> bool: return m.is_alive())


func test_map_reads_spawns_and_respawn_point() -> void:
	var w := _world([{"type": "marked_hound", "at": [30, 10], "count": 3, "radius": 2, "respawn_s": 5}])
	assert_eq(w.map.respawn_point(), Vector3(20.5, 0, 20.5))
	assert_eq(w.map.spawns.size(), 1)


func test_spawns_count_on_first_tick() -> void:
	var w := _world([{"type": "marked_hound", "at": [30, 10], "count": 3, "radius": 2, "respawn_s": 5}])
	w.step({})
	assert_eq(_monsters(w).size(), 3)
	for m: MonsterState in _monsters(w):
		assert_lt(Effects.flat(m.position).distance_to(Vector2(30.5, 10.5)), 2.6)
		assert_gte(m.id, 1000)


func test_spawner_respawns_after_timer() -> void:
	var w := _world([{"type": "marked_hound", "at": [30, 10], "count": 1, "radius": 0, "respawn_s": 2}])
	w.step({})
	var m: MonsterState = _monsters(w)[0]
	Damage.apply(m, {"amount": 9999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	assert_false(m.is_alive())
	for i in w.ticks(1.0):
		w.step({})
	assert_eq(_monsters(w).size(), 0, "still waiting")
	for i in w.ticks(1.5):
		w.step({})
	assert_eq(_monsters(w).size(), 1, "back after respawn_s")
	assert_false(w.monsters.has(m.id), "the corpse was removed")


func test_group_scaling_at_spawn_and_rescale_on_join_leave() -> void:
	var w := _world([{"type": "marked_hound", "at": [30, 10], "count": 1, "radius": 0, "respawn_s": 5}])
	w.add_player(1, Vector3(1, 0, 1))
	w.add_player(2, Vector3(2, 0, 2))
	w.step({})
	var m: MonsterState = _monsters(w)[0]
	var base := m.base_max_hp
	assert_almost_eq(m.stats.max_hp, base * 1.75, 0.01, "2 players: × (1 + 0.75)")
	m.hp = m.stats.max_hp / 2.0
	w.add_player(3, Vector3(3, 0, 3))
	assert_almost_eq(m.stats.max_hp, base * 2.5, 0.01)
	assert_almost_eq(m.hp, base * 2.5 / 2.0, 0.01, "keeps the same fraction")
	w.remove_player(3)
	w.remove_player(2)
	assert_almost_eq(m.stats.max_hp, base, 0.01)
	assert_almost_eq(m.hp, base / 2.0, 0.01)
