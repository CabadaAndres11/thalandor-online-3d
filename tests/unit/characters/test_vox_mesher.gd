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


func test_two_adjacent_voxels_have_10_faces() -> void:
	var arrays := _arrays(VoxMesher.build(_vox([[0, 0, 0, 1], [1, 0, 0, 1]]), {}))
	assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 10 * 6)


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
