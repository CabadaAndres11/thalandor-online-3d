extends GutTest

var layout := {"size": [6, 5], "spawn": [1, 1], "blocks": [[3, 2, 2], [4, 4, 1]]}


func test_arena_collision_matches_layout() -> void:
	var arena: ZoneView = autofree(ZoneView.new())
	var map := arena.build(ZoneLayout.from_dict("t", layout))
	assert_true(map.is_solid(Vector2i(3, 2)))
	assert_true(map.is_solid(Vector2i(4, 4)))
	assert_false(map.is_solid(Vector2i(0, 0)))
	assert_eq(map.size, Vector2i(6, 5))


func test_old_blocks_are_stacked_in_a_gridmap() -> void:
	var arena: ZoneView = autofree(ZoneView.new())
	arena.build(ZoneLayout.from_dict("t", layout))
	var grid := arena.grid
	assert_ne(grid.get_cell_item(Vector3i(3, 0, 2)), GridMap.INVALID_CELL_ITEM)
	assert_ne(grid.get_cell_item(Vector3i(3, 1, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(3, 2, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM)


func test_real_arena_builds() -> void:
	var arena: ZoneView = autofree(ZoneView.new())
	var map := arena.build(ZoneLayout.load_id("arena"))
	assert_eq(map.size, Vector2i(48, 48))
	assert_false(map.spawns.is_empty(), "the test arena has monster spawn points")


func test_layout_ambience_is_used() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	var l := layout.duplicate()
	l["ambience"] = "mazmorra_noche"
	arena.build(ZoneLayout.from_dict("t", l))
	assert_eq(arena.ambience_id, "mazmorra_noche")


func test_missing_ambience_defaults() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	arena.build(ZoneLayout.from_dict("t", layout))
	assert_eq(arena.ambience_id, Ambience.DEFAULT_ID)
	assert_eq(arena.quality, GraphicsQuality.MEDIUM)


func test_torches_from_layout() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	var l := layout.duplicate()
	l["torches"] = [[0, 0], [5, 4]]
	var map := arena.build(ZoneLayout.from_dict("t", l))
	assert_eq(arena.torches.size(), 2)
	assert_eq(arena.torches[0].position, Vector3(0.5, 0, 0.5))
	assert_eq(arena.torches[1].position, Vector3(5.5, 0, 4.5))
	assert_false(map.is_solid(Vector2i(0, 0)), "torches are decoration")


func test_set_ambience_rejects_unknown() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	arena.build(ZoneLayout.from_dict("t", layout))
	assert_false(arena.set_ambience("nope"))
	assert_eq(arena.ambience_id, Ambience.DEFAULT_ID)
	assert_true(arena.set_ambience("mazmorra_noche"))
	assert_eq(arena.ambience_id, "mazmorra_noche")


func test_switching_quality_and_ambience_does_not_duplicate_nodes() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	arena.build(ZoneLayout.from_dict("t", layout))
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
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	var l := layout.duplicate()
	l["torches"] = [[0, 0]]
	l["ambience"] = "mazmorra_noche"
	arena.build(ZoneLayout.from_dict("t", l), GraphicsQuality.LOW)
	var env: WorldEnvironment = arena.get_node("Environment")
	assert_false(env.environment.ssao_enabled)
	arena.set_quality(GraphicsQuality.HIGH)
	assert_true(arena.get_node("Environment").environment.ssr_enabled)
	assert_true(arena.torches[0].light.shadow_enabled)


func test_real_arena_has_ambience_and_torches() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	arena.build(ZoneLayout.load_id("arena"))
	assert_eq(arena.ambience_id, "exterior_dia")
	assert_gte(arena.torches.size(), 6)


func test_ambience_sets_torch_energy() -> void:
	var arena: ZoneView = add_child_autofree(ZoneView.new())
	var l := layout.duplicate()
	l["torches"] = [[0, 0]]
	arena.build(ZoneLayout.from_dict("t", l))
	assert_almost_eq(arena.torches[0].energy_scale, Ambience.load_id("exterior_dia").torch_energy, 0.001)
	arena.set_ambience("mazmorra_noche")
	assert_almost_eq(arena.torches[0].energy_scale, Ambience.load_id("mazmorra_noche").torch_energy, 0.001)


# --- Zones drawn from data (Plan 8.1) ---------------------------------------------------

func _forest() -> ZoneLayout:
	return ZoneLayout.from_dict("f", {"size": [40, 30], "terrain": {"base": "grass", "areas": [{"kind": "water", "area": [30, 0, 10, 30]}]},
		"paths": [{"points": [[0, 15], [29, 15]], "width": 3, "terrain": "road"}],
		"pieces": [{"id": "house_small", "at": [2, 2], "rot": 90}],
		"scatter": [{"area": [0, 0, 29, 30], "pieces": ["tree_oak", "tree_pine"], "density": 0.2, "seed": 4}]})


func test_one_multimesh_per_piece_kind() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	var z := _forest()
	view.build(z)
	var oaks := z.pieces.filter(func(p: Dictionary) -> bool: return p.id == "tree_oak").size()
	assert_gt(oaks, 20)
	var mm := view.find_children("tree_oak", "MultiMeshInstance3D", true, false)
	assert_eq(mm.size(), 1, "one node for every oak")
	assert_eq((mm[0] as MultiMeshInstance3D).multimesh.instance_count, oaks)
	assert_eq(view.find_children("*", "MultiMeshInstance3D", true, false).size(), 3)


func test_terrain_meshes_per_kind() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_forest())
	for kind: String in ["grass", "road", "water"]:
		assert_not_null(view.find_child("Ground_" + kind, true, false), kind)


func test_rotated_piece_sits_on_its_footprint() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	var z := _forest()
	view.build(z)
	var mm := view.find_child("house_small", true, false) as MultiMeshInstance3D
	# (the headless renderer keeps no multimesh transforms: check the one it is given)
	var aabb := view.piece_transform(z.pieces[0]) * mm.multimesh.mesh.get_aabb()
	var cells := z.footprint("house_small", Vector2i(2, 2), 90)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector2i in cells:
		lo = lo.min(Vector2(c.x, c.y))
		hi = hi.max(Vector2(c.x + 1, c.y + 1))
	assert_almost_eq(aabb.position.x, lo.x, 0.35)
	assert_almost_eq(aabb.end.z, hi.y, 0.35)


func test_frees_cleanly() -> void:
	var view := ZoneView.new()
	add_child(view)
	view.build(_forest())
	view.free()
	assert_true(true)
