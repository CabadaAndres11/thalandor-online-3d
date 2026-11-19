extends GutTest

var layout := {"size": [6, 5], "spawn": [1, 1], "blocks": [[3, 2, 2], [4, 4, 1]]}


func test_arena_collision_matches_layout() -> void:
	var arena: Arena = autofree(Arena.new())
	var map := arena.build(layout)
	assert_true(map.is_solid(Vector2i(3, 2)))
	assert_true(map.is_solid(Vector2i(4, 4)))
	assert_false(map.is_solid(Vector2i(0, 0)))
	assert_eq(map.size, Vector2i(6, 5))


func test_gridmap_has_floor_and_stacked_blocks() -> void:
	var arena: Arena = autofree(Arena.new())
	arena.build(layout)
	var grid := arena.grid
	assert_eq(grid.get_cell_item(Vector3i(0, -1, 0)), Arena.ITEM_FLOOR)
	assert_eq(grid.get_cell_item(Vector3i(5, -1, 4)), Arena.ITEM_FLOOR)
	assert_ne(grid.get_cell_item(Vector3i(3, 0, 2)), GridMap.INVALID_CELL_ITEM)
	assert_ne(grid.get_cell_item(Vector3i(3, 1, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(3, 2, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM)


func test_real_arena_builds() -> void:
	var arena: Arena = autofree(Arena.new())
	var map := arena.build(Arena.load_layout())
	assert_eq(map.size, Vector2i(48, 48))
	assert_false(map.spawns.is_empty(), "the test arena has monster spawn points")


func test_layout_ambience_is_used() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	var l := layout.duplicate()
	l["ambience"] = "mazmorra_noche"
	arena.build(l)
	assert_eq(arena.ambience_id, "mazmorra_noche")


func test_missing_ambience_defaults() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	arena.build(layout)
	assert_eq(arena.ambience_id, Ambience.DEFAULT_ID)
	assert_eq(arena.quality, GraphicsQuality.MEDIUM)


func test_torches_from_layout() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	var l := layout.duplicate()
	l["torches"] = [[0, 0], [5, 4]]
	var map := arena.build(l)
	assert_eq(arena.torches.size(), 2)
	assert_eq(arena.torches[0].position, Vector3(0.5, 0, 0.5))
	assert_eq(arena.torches[1].position, Vector3(5.5, 0, 4.5))
	assert_false(map.is_solid(Vector2i(0, 0)), "torches are decoration")


func test_set_ambience_rejects_unknown() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	arena.build(layout)
	assert_false(arena.set_ambience("nope"))
	assert_eq(arena.ambience_id, Ambience.DEFAULT_ID)
	assert_true(arena.set_ambience("mazmorra_noche"))
	assert_eq(arena.ambience_id, "mazmorra_noche")


func test_switching_quality_and_ambience_does_not_duplicate_nodes() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	arena.build(layout)
	for q: int in [GraphicsQuality.HIGH, GraphicsQuality.LOW, GraphicsQuality.MEDIUM]:
		arena.set_quality(q)
	arena.set_ambience("mazmorra_noche")
	arena.set_ambience("exterior_dia")
	await wait_process_frames(1)
	var counts := {"sun": 0, "env": 0, "particles": 0}
	for child: Node in arena.get_children():
		if child is DirectionalLight3D:
			counts.sun += 1
		elif child is WorldEnvironment:
			counts.env += 1
		elif child is GPUParticles3D:
			counts.particles += 1
	assert_eq(counts.sun, 1)
	assert_eq(counts.env, 1)
	assert_lte(counts.particles, 1)


func test_quality_reaches_environment_and_torches() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	var l := layout.duplicate()
	l["torches"] = [[0, 0]]
	l["ambience"] = "mazmorra_noche"
	arena.build(l, GraphicsQuality.LOW)
	var env: WorldEnvironment = arena.get_node("Environment")
	assert_false(env.environment.ssao_enabled)
	arena.set_quality(GraphicsQuality.HIGH)
	assert_true(arena.get_node("Environment").environment.ssr_enabled)
	assert_true(arena.torches[0].light.shadow_enabled)


func test_real_arena_has_ambience_and_torches() -> void:
	var arena: Arena = add_child_autofree(Arena.new())
	arena.build(Arena.load_layout())
	assert_eq(arena.ambience_id, "exterior_dia")
	assert_gte(arena.torches.size(), 6)
