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


# --- Hordes (Plan 8.1) ----------------------------------------------------------------

func _horde_world(horde: Dictionary) -> SimWorld:
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [2, 2], "blocks": []})
	map.hordes = [horde]
	return SimWorld.new(Balance.load_from(), map, 9)


func _kill(w: SimWorld, m: MonsterState) -> void:
	Damage.apply(m, {"amount": 99999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)


func test_horde_fills_to_count_inside_its_area() -> void:
	var w := _horde_world({"area": [10, 10, 20, 10], "monsters": [["marked_hound", 1]], "levels": [5, 9], "count": 12})
	w.step({})
	var list := _monsters(w)
	assert_eq(list.size(), 12)
	for m: MonsterState in list:
		assert_true(Rect2(10, 10, 20, 10).has_point(Effects.flat(m.position)), "inside the area")
		assert_eq(m.horde_index, 0)


func test_horde_respawns_one_by_one_after_respawn_s() -> void:
	var w := _horde_world({"area": [10, 10, 20, 10], "monsters": [["marked_hound", 1]], "levels": [5, 5], "count": 4, "respawn_s": 8})
	w.step({})
	var list := _monsters(w)
	_kill(w, list[0])
	for i in w.ticks(4.0):
		w.step({})
	_kill(w, _monsters(w)[0])
	for i in w.ticks(4.5):
		w.step({})
	assert_eq(_monsters(w).size(), 3, "the first is back after 8 s, the second not yet")
	for i in w.ticks(4.0):
		w.step({})
	assert_eq(_monsters(w).size(), 4)


func test_horde_levels_within_band() -> void:
	var w := _horde_world({"area": [0, 0, 60, 60], "monsters": [["marked_hound", 1]], "levels": [5, 9], "count": 40})
	w.step({})
	var seen := {}
	for m: MonsterState in _monsters(w):
		assert_between(m.level, 5, 9)
		seen[m.level] = true
	assert_gt(seen.size(), 2, "spread over the band")


func test_horde_types_by_weight() -> void:
	var w := _horde_world({"area": [0, 0, 60, 60], "monsters": [["marked_hound", 3], ["marked_boar", 1]], "levels": [5, 5], "count": 400})
	w.step({})
	var hounds := _monsters(w).filter(func(m: MonsterState) -> bool: return m.type_id == "marked_hound").size()
	assert_between(hounds, 260, 340)


func test_horde_in_an_instance_uses_its_level() -> void:
	var w := _horde_world({"area": [0, 0, 60, 60], "monsters": [["marked_hound", 1]], "levels": [5, 9], "count": 10})
	w.instance_level = 30
	w.step({})
	for m: MonsterState in _monsters(w):
		assert_eq(m.level, 30)
