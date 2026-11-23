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
		"pieces": [{"id": "rock_large", "at": [2, 2], "rot": 90}],
		"scatter": [{"area": [0, 0, 29, 30], "pieces": ["tree_oak", "tree_pine"], "density": 0.2, "seed": 4}]})


func test_pieces_of_a_kind_share_a_node_per_chunk() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	var z := _forest()
	view.build(z)
	var oaks := z.pieces.filter(func(p: Dictionary) -> bool: return p.id == "tree_oak").size()
	assert_gt(oaks, 20)
	oaks += z.margin_pieces.filter(func(p: Dictionary) -> bool: return p.id == "tree_oak").size()
	var total := 0
	for mm: MultiMeshInstance3D in view.find_children("tree_oak#*", "MultiMeshInstance3D", true, false):
		if not "~" in mm.name:
			total += mm.multimesh.instance_count
	assert_eq(total, oaks, "every oak drawn once")
	assert_lt(view.find_children("tree_oak#*", "MultiMeshInstance3D", true, false).size(), oaks, "shared nodes")


func test_terrain_meshes_per_kind() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_forest())
	for kind: String in ["grass", "road", "water"]:
		assert_false(view.find_children("Ground_" + kind + "#*", "", true, false).is_empty(), kind)


func test_rotated_piece_sits_on_its_footprint() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	var z := _forest()
	view.build(z)
	var mm := view.find_child("rock_large#0,0", true, false) as MultiMeshInstance3D
	# (the headless renderer keeps no multimesh transforms: check the one it is given)
	var aabb := view.piece_transform(z.pieces[0]) * mm.multimesh.mesh.get_aabb()
	var cells := z.footprint("rock_large", Vector2i(2, 2), 90)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector2i in cells:
		lo = lo.min(Vector2(c.x, c.y))
		hi = hi.max(Vector2(c.x + 1, c.y + 1))
	var mid := (lo + hi) / 2.0
	assert_almost_eq(aabb.get_center().x, mid.x, 0.6, "turned onto its footprint (x)")
	assert_almost_eq(aabb.get_center().z, mid.y, 0.6, "turned onto its footprint (z)")


func test_frees_cleanly() -> void:
	var view := ZoneView.new()
	add_child(view)
	view.build(_forest())
	view.free()
	assert_true(true)


# --- Chunks, draw ranges and shadows (Plan 8.1.1) ---------------------------------------

func _two_trees() -> ZoneLayout:
	return ZoneLayout.from_dict("c", {"size": [40, 40], "pieces": [
		{"id": "tree_oak", "at": [2, 2]}, {"id": "tree_oak", "at": [30, 30]}, {"id": "bush", "at": [5, 5]}]})


func test_pieces_are_split_by_chunk() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_two_trees())
	assert_not_null(view.find_child("tree_oak#0,0", true, false))
	assert_not_null(view.find_child("tree_oak#1,1", true, false))
	assert_eq((view.find_child("tree_oak#0,0", true, false) as MultiMeshInstance3D).multimesh.instance_count, 1)


func test_visibility_range_from_data() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_two_trees())
	var bush := view.find_child("bush#0,0", true, false) as GeometryInstance3D
	assert_eq(bush.visibility_range_end, 55.0)
	var near := view.find_child("tree_oak#0,0", true, false) as GeometryInstance3D
	assert_eq(near.visibility_range_end, ZoneView.LOD_NEAR)
	var far := view.find_child("tree_oak#0,0~far", true, false) as GeometryInstance3D
	assert_eq(far.visibility_range_begin, ZoneView.LOD_NEAR)
	assert_eq(far.visibility_range_end, 90.0)


func test_shadows_by_quality() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_two_trees(), GraphicsQuality.HIGH)
	var bush := view.find_child("bush#0,0", true, false) as GeometryInstance3D
	assert_eq(bush.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_null(view.find_child("bush#0,0~shadow", true, false), "small pieces cast no shadow")
	var tree := view.find_child("tree_oak#0,0", true, false) as GeometryInstance3D
	assert_eq(tree.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the detailed mesh casts none")
	var proxy := view.find_child("tree_oak#0,0~shadow", true, false) as GeometryInstance3D
	assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_true(proxy.visible)
	view.set_quality(GraphicsQuality.LOW)
	assert_false(proxy.visible, "no piece shadows at low")
	view.set_quality(GraphicsQuality.MEDIUM)
	assert_true(proxy.visible)


func test_ground_split_by_chunk() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_two_trees())
	assert_not_null(view.find_child("Ground_grass#2,2", true, false))
	assert_not_null(view.find_child("Ground_grass#0,0", true, false))


# --- Staged build (Plan 8.1.1) ----------------------------------------------------------

func _names(n: Node) -> Array:
	var out := []
	for c: Node in n.find_children("*", "", true, false):
		var line := str(n.get_path_to(c))
		if c is MultiMeshInstance3D:
			line += ":%d" % (c as MultiMeshInstance3D).multimesh.instance_count
		out.append(line)
	out.sort()
	return out


func test_steps_build_same_scene_as_build() -> void:
	var a: ZoneView = add_child_autofree(ZoneView.new())
	a.build(_forest())
	var b: ZoneView = add_child_autofree(ZoneView.new())
	var steps := b.build_steps(_forest(), GraphicsQuality.MEDIUM)
	assert_gt(steps.size(), 3, "several steps")
	for s: Callable in steps:
		s.call()
	assert_eq(_names(b), _names(a))


# --- Houses that open (Plan 8.1.1) ------------------------------------------------------

func _village() -> ZoneLayout:
	return ZoneLayout.from_dict("v", {"size": [40, 40], "pieces": [
		{"id": "house_small", "at": [2, 2]}, {"id": "house_forge", "at": [20, 20], "rot": 90}]})


func test_houses_are_house_views() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_village())
	var h := view.find_child("house_0", true, false) as HouseView
	assert_not_null(h)
	for part: String in ["Floor", "Walls", "WallsCut", "Roof"]:
		assert_not_null(h.get_node_or_null(part), part)
	assert_null(view.find_child("house_small#0,0", true, false), "not drawn as a multimesh")


func test_open_house_hides_roof_and_cuts_walls() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_village())
	var h0 := view.find_child("house_0", true, false) as HouseView
	var h1 := view.find_child("house_1", true, false) as HouseView
	assert_false(h0.open)
	assert_true(h0.get_node("Walls").visible)
	assert_false(h0.get_node("WallsCut").visible)
	view.open_house(0)
	h0._process(HouseView.FADE_S + 0.05)
	assert_true(h0.open)
	assert_false(h0.get_node("Roof").visible, "roof gone after the fade")
	assert_true(h0.get_node("WallsCut").visible)
	assert_false(h0.get_node("Walls").visible)
	assert_false(h1.open, "the other house stays closed")
	view.open_house(-1)
	h0._process(HouseView.FADE_S + 0.05)
	assert_false(h0.open)
	assert_true(h0.get_node("Roof").visible)
	assert_true(h0.get_node("Walls").visible)


func test_forge_has_a_light() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_village())
	var forge := view.find_child("house_1", true, false) as HouseView
	assert_false(forge.find_children("*", "OmniLight3D", true, false).is_empty())


# --- Zone edges (Plan 8.1.1) ------------------------------------------------------------

func test_signpost_label_text() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(ZoneLayout.load_id("aldea"))
	var labels := view.find_children("*", "Label3D", true, false)
	assert_eq(labels.size(), 1)
	assert_eq((labels[0] as Label3D).text, tr("ZONE_BOSQUE"))
	assert_not_null(view.find_child("ExitGlow_0", true, false))


func test_margin_drawn() -> void:
	var view: ZoneView = add_child_autofree(ZoneView.new())
	view.build(_edge())
	assert_false(view.find_children("tree_*#-1,*", "MultiMeshInstance3D", true, false).is_empty(), "trees west of the map")


func _edge() -> ZoneLayout:
	return ZoneLayout.from_dict("e", {"size": [40, 30], "entries": {"default": [5, 5]}})
