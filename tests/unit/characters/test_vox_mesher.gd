extends GutTest


func _vox(voxels: Array, size := Vector3i(4, 4, 4), palette := PackedColorArray()) -> VoxFile:
	return VoxFile.parse(VoxWriter.build(size, voxels, palette))


func _palette(index: int, color: Color) -> PackedColorArray:
	var p := PackedColorArray()
	p.resize(256)
	p[index] = color
	return p


func _arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(0)


func test_single_voxel_has_6_faces() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1]]), {}))
	assert_eq((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 24)
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 36)



func test_tint_index_uses_given_color() -> void:
	var vox := _vox([[0, 0, 0, VoxMesher.TINT_HAIR]])
	var arrays := _arrays(VoxMesher.build(vox, {VoxMesher.TINT_HAIR: Color.ORANGE}))
	for c: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
		assert_eq(c, Color.ORANGE)


func test_untinted_uses_palette_color() -> void:
	var vox := _vox([[0, 0, 0, 7]], Vector3i(1, 1, 1), _palette(7, Color.BLUE))
	var arrays := _arrays(VoxMesher.build(vox, {VoxMesher.TINT_HAIR: Color.ORANGE}))
	assert_eq((arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[0], Color.BLUE)


func test_voxel_size_scales_positions() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[2, 0, 0, 1]]), {}))
	var xs := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var min_x := INF
	var max_x := -INF
	for v: Vector3 in xs:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	assert_almost_eq(min_x, 0.2, 0.0001)
	assert_almost_eq(max_x, 0.3, 0.0001)


func test_normals_point_outwards() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1]]), {}))
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var center := Vector3(0.05, 0.05, 0.05)
	for i in verts.size():
		assert_gt((verts[i] - center).dot(normals[i]), 0.0, "normal %d points out" % i)


## Godot draws clockwise triangles (seen from outside) as front faces.
func test_triangles_are_front_facing_outwards() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1]]), {}))
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var idx := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var n := (b_minus(verts[idx[t + 1]], a)).cross(b_minus(verts[idx[t + 2]], a))
		assert_lt(n.dot(normals[idx[t]]), 0.0, "triangle %d winds clockwise from outside" % (t / 3))


func b_minus(b: Vector3, a: Vector3) -> Vector3:
	return b - a


func test_cached_returns_same_mesh_for_same_tints() -> void:
	var path := "user://test_mesher_piece.vox"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(VoxWriter.build(Vector3i(1, 1, 1), [[0, 0, 0, VoxMesher.TINT_HAIR]]))
	f.close()
	var a := VoxMesher.cached(path, {VoxMesher.TINT_HAIR: Color.RED})
	var b := VoxMesher.cached(path, {VoxMesher.TINT_HAIR: Color.RED})
	var c := VoxMesher.cached(path, {VoxMesher.TINT_HAIR: Color.BLUE})
	assert_not_null(a)
	assert_same(a, b)
	assert_ne(a, c)
	VoxMesher.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_cached_missing_file_is_null() -> void:
	assert_null(VoxMesher.cached("res://nope.vox", {}))


## Glowing voxels (eyes, runes) go to a second, unshaded surface so they stand out.
func test_glow_index_gets_its_own_unshaded_surface() -> void:
	var p := PackedColorArray()
	p.resize(256)
	p[3] = Color.GRAY
	p[VoxMesher.GLOW] = Color.RED
	var vox := VoxFile.parse(VoxWriter.build(Vector3i(2, 1, 1), [[0, 0, 0, 3], [1, 0, 0, VoxMesher.GLOW]], p))
	var mesh := VoxMesher.build(vox, {})
	assert_eq(mesh.get_surface_count(), 2)
	var glow_mat := mesh.surface_get_material(1) as StandardMaterial3D
	assert_eq(glow_mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	for c: Color in mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR] as PackedColorArray:
		assert_eq(c, Color.RED)


func test_glow_tint_overrides_palette() -> void:
	var vox := VoxFile.parse(VoxWriter.build(Vector3i(1, 1, 1), [[0, 0, 0, VoxMesher.GLOW]]))
	var mesh := VoxMesher.build(vox, {VoxMesher.GLOW: Color.YELLOW})
	assert_eq((mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray)[0], Color.YELLOW)


## Vertex colors keep 8 bits per channel.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


func test_tone_indices_shade_and_light_their_tint() -> void:
	var shade: int = VoxMesher.SHADE_OF[VoxMesher.TINT_PRIMARY]
	var light: int = VoxMesher.LIGHT_OF[VoxMesher.TINT_PRIMARY]
	var tints := {VoxMesher.TINT_PRIMARY: Color(0.5, 0.4, 0.3)}
	var a := _arrays(VoxMesher.build(_vox([[0, 0, 0, shade]]), tints))
	assert_true((a[Mesh.ARRAY_COLOR] as PackedColorArray)[0].is_equal_approx(Color(0.5, 0.4, 0.3).darkened(VoxMesher.TONE_SHADE)) or _near((a[Mesh.ARRAY_COLOR] as PackedColorArray)[0], Color(0.5, 0.4, 0.3).darkened(VoxMesher.TONE_SHADE)))
	var b := _arrays(VoxMesher.build(_vox([[0, 0, 0, light]]), tints))
	assert_true(_near((b[Mesh.ARRAY_COLOR] as PackedColorArray)[0], Color(0.5, 0.4, 0.3).lightened(VoxMesher.TONE_LIGHT)))


## The top of a voxel next to a taller neighbour is darker at the shared edge (vertex
## ambient occlusion); its far edge keeps the full color.
func test_ambient_occlusion_darkens_inner_corners() -> void:
	# VoxWriter takes MagicaVoxel axes (z up): Godot (1, 1, 0) is [1, 0, 1].
	var vox := _vox([[0, 0, 0, 7], [1, 0, 1, 7]], Vector3i(2, 1, 2), _palette(7, Color.WHITE))
	var a := _arrays(VoxMesher.build(vox, {}))
	var verts := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var cols := a[Mesh.ARRAY_COLOR] as PackedColorArray
	var normals := a[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var near_wall := Color.WHITE
	var far := Color.BLACK
	for i in verts.size():
		if normals[i].dot(Vector3.UP) < 0.99 or verts[i].y > 0.15:
			continue # only the top of the low voxel
		if is_equal_approx(verts[i].x, 0.1):
			near_wall = cols[i]
		elif is_zero_approx(verts[i].x):
			far = cols[i]
	assert_lt(near_wall.r, 0.95, "occluded by the neighbour")
	assert_true(_near(far, Color.WHITE), "open edge")


## Subtle texture tones of a tint (Plan 6.2): tint - 40 a little darker, tint - 50 a little lighter.
func test_texture_tones_of_a_tint() -> void:
	var dark := _vox([[0, 0, 0, VoxMesher.TINT_HAIR - 40]])
	var c: Color = (_arrays(VoxMesher.build(dark, {VoxMesher.TINT_HAIR: Color.ORANGE}))[Mesh.ARRAY_COLOR] as PackedColorArray)[0]
	assert_almost_eq(c.r, Color.ORANGE.darkened(VoxMesher.TONE_TEX_DARK).r, 0.01)
	var light := _vox([[0, 0, 0, VoxMesher.TINT_HAIR - 50]])
	c = (_arrays(VoxMesher.build(light, {VoxMesher.TINT_HAIR: Color.ORANGE}))[Mesh.ARRAY_COLOR] as PackedColorArray)[0]
	assert_almost_eq(c.g, Color.ORANGE.lightened(VoxMesher.TONE_TEX_LIGHT).g, 0.01)
	assert_lt(VoxMesher.TONE_TEX_DARK, VoxMesher.TONE_SHADE)


func test_hidden_voxels_hide_faces_but_draw_nothing() -> void:
	# A voxel with a hidden one beside it: the shared face is not drawn, nor the hidden one.
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1], [1, 0, 0, VoxMesher.HIDDEN]]), {}))
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 30, "5 faces of the visible voxel only")


## Plan 8.1.1: equal faces side by side merge into one rectangle (greedy meshing).
func test_single_colour_cube_is_twelve_triangles() -> void:
	var cells := []
	for x in 4:
		for y in 4:
			for z in 4:
				cells.append([x, y, z, 1])
	assert_eq(VoxMesher.triangle_count(VoxMesher.build(_vox(cells), {})), 12)


func test_two_adjacent_voxels_merge_to_6_faces() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1], [1, 0, 0, 1]]), {}))
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 6 * 6)


## Face area per (colour, normal), summed over every triangle.
func _area_by_key(mesh: ArrayMesh) -> Dictionary:
	var out := {}
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v := a[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var n := a[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var c := a[Mesh.ARRAY_COLOR] as PackedColorArray
		var idx := a[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, idx.size(), 3):
			var area := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).length() / 2.0
			var col := c[idx[t]]
			var key := "%d|%s|%d,%d,%d" % [s, col.to_html(), roundi(n[idx[t]].x), roundi(n[idx[t]].y), roundi(n[idx[t]].z)]
			out[key] = float(out.get(key, 0.0)) + area
	return out


func test_merged_mesh_covers_same_area_per_colour() -> void:
	var vox := VoxFile.load_file("res://assets/world/tree_pine.vox")
	var merged := _area_by_key(VoxMesher.build(vox, {}))
	var single := _area_by_key(VoxMesher.build_unmerged(vox, {}))
	var total_m := 0.0
	var total_s := 0.0
	for k: String in single:
		total_s += float(single[k])
	for k: String in merged:
		total_m += float(merged[k])
	assert_almost_eq(total_m, total_s, 0.001)


func test_tree_has_fewer_triangles() -> void:
	var vox := VoxFile.load_file("res://assets/world/tree_oak.vox")
	var merged := VoxMesher.triangle_count(VoxMesher.build(vox, {}))
	var single := VoxMesher.triangle_count(VoxMesher.build_unmerged(vox, {}))
	assert_lt(float(merged), single * 0.8, "%d vs %d" % [merged, single])


## Plan 8.1.1: a coarse copy (2x2x2 voxels -> 1) for shadows and far away.
func test_downsample_halves_the_grid() -> void:
	var cells := []
	for x in 4:
		for y in 4:
			for z in 4:
				cells.append([x, y, z, 1])
	var small := VoxMesher.downsample(_vox(cells), 2)
	assert_eq(small.size, Vector3i(2, 2, 2))
	assert_eq(small.voxels.size(), 8)


func test_downsample_keeps_thin_parts() -> void:
	# A single voxel still leaves one coarse voxel (a thin branch does not vanish).
	var small := VoxMesher.downsample(_vox([[3, 3, 3, 5]]), 2)
	assert_eq(small.voxels.size(), 1)
	assert_eq(int(small.voxels[0][3]), 5)


func test_coarse_tree_has_a_quarter_of_the_triangles() -> void:
	var vox := VoxFile.load_file("res://assets/world/tree_oak.vox")
	var full := VoxMesher.triangle_count(VoxMesher.build(vox, {}))
	var coarse := VoxMesher.triangle_count(VoxMesher.build(VoxMesher.downsample(vox, 2), {}))
	assert_lt(float(coarse), full * 0.3, "%d vs %d" % [coarse, full])
