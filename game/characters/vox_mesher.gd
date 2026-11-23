class_name VoxMesher
extends RefCounted
## Turns a VoxFile into a mesh: one quad per voxel side whose neighbour is empty, with
## per-vertex colors. Some palette indices are "tintable": they take a color chosen by
## the character (hair, class colors) instead of their palette color.

const VOXEL_SIZE := 0.1
const TINT_TROUSERS := 247
const TINT_SKIN := 248
const TINT_EYES := 249
const TINT_HAIR := 250
const TINT_PRIMARY := 251
const TINT_SECONDARY := 252
## Voxels of this index glow: drawn unshaded (eyes, runes, acid).
const GLOW := 253
## Never drawn: it only hides the faces of the voxels beside it (the inside of a hollow shell,
## such as a boss's huge head, whose inner surface is never seen).
const HIDDEN := 254
## Tone indices: a darker (shade) and a lighter (light) version of each tint, for
## folds, edges and highlights painted into the voxels.
const SHADE_OF := {247: 227, 248: 228, 249: 229, 250: 230, 251: 231, 252: 232}
const LIGHT_OF := {247: 217, 248: 218, 249: 219, 250: 220, 251: 221, 252: 222}
const TONE_SHADE := 0.28
const TONE_LIGHT := 0.18
## Subtle texture tones (tint - 40 and tint - 50): two or three tones mixed per voxel.
const TEX_DARK_OF := {247: 207, 248: 208, 249: 209, 250: 210, 251: 211, 252: 212}
const TEX_LIGHT_OF := {247: 197, 248: 198, 249: 199, 250: 200, 251: 201, 252: 202}
const TONE_TEX_DARK := 0.1
const TONE_TEX_LIGHT := 0.08
## Vertex ambient occlusion: color factor by how open a face corner is (0 = an inner
## corner closed on both sides, 3 = open).
const AO_LEVELS := [0.6, 0.74, 0.88, 1.0]

## Side normal -> the 4 corners of that side of the unit cube, counterclockwise around
## the normal; they are emitted reversed (Godot front faces are clockwise).
const SIDES := [
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D
static var _glow_material: StandardMaterial3D


## Equal faces side by side (same plane, colour and corner shading) are merged into one
## rectangle (greedy meshing, Plan 8.1.1): the same look with far fewer triangles.
static func build(vox: VoxFile, tints: Dictionary) -> ArrayMesh:
	return _build(vox, tints, true)


## One quad per visible voxel side (the old mesher; tests compare against it).
static func build_unmerged(vox: VoxFile, tints: Dictionary) -> ArrayMesh:
	return _build(vox, tints, false)


## Triangles of a mesh, over all its surfaces.
static func triangle_count(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


static func _build(vox: VoxFile, tints: Dictionary, merge: bool) -> ArrayMesh:
	var solid := {}
	for v: Array in vox.voxels:
		solid[Vector3i(v[0], v[1], v[2])] = true
	# Two surfaces: lit voxels, and glowing ones (index GLOW) drawn unshaded.
	var lit := _new_surface()
	var glow := _new_surface()
	# Faces waiting to be merged: Vector3i(side, slice, glow) -> {Vector2i(u, v): colour}.
	var planes := {}
	for v: Array in vox.voxels:
		var cell := Vector3i(v[0], v[1], v[2])
		var index: int = v[3]
		if index == HIDDEN:
			continue
		var color := _color(index, tints, vox.palette)
		var is_glow := index == GLOW
		var s: Dictionary = glow if is_glow else lit
		for si in SIDES.size():
			var normal: Vector3i = SIDES[si][0]
			if solid.has(cell + normal):
				continue
			var cols: Array = []
			for corner: Vector3 in SIDES[si][1]:
				var c := color
				if not is_glow:
					var f: float = AO_LEVELS[_openness(solid, cell, normal, corner)]
					c = Color(color.r * f, color.g * f, color.b * f, color.a)
				cols.append(c)
			if merge:
				var a := _axis(normal)
				var key := Vector3i(si, cell[a], int(is_glow))
				if not planes.has(key):
					planes[key] = {}
				(planes[key] as Dictionary)[Vector2i(cell[(a + 1) % 3], cell[(a + 2) % 3])] = cols
			else:
				_emit(s, si, cell, Vector2i.ONE, cols)
	for key: Vector3i in planes:
		_merge_plane(glow if key.z == 1 else lit, key.x, key.y, planes[key])
	var mesh := ArrayMesh.new()
	for pair: Array in [[lit, material()], [glow, glow_material()]]:
		var s: Dictionary = pair[0]
		if (s.verts as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_INDEX] = s.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	return mesh


## A coarse copy: each factor³ block with any voxel becomes one voxel of its most common
## colour (Plan 8.1.1: shadow casters and far pieces). Its mesh is drawn `factor` times bigger.
static func downsample(vox: VoxFile, factor: int) -> VoxFile:
	var counts := {} # block -> {index: n}
	for v: Array in vox.voxels:
		var b := Vector3i(floori(v[0] / float(factor)), floori(v[1] / float(factor)), floori(v[2] / float(factor)))
		if not counts.has(b):
			counts[b] = {}
		var c: Dictionary = counts[b]
		c[v[3]] = int(c.get(v[3], 0)) + 1
	var out := VoxFile.new()
	out.palette = vox.palette
	out.size = Vector3i(ceili(vox.size.x / float(factor)), ceili(vox.size.y / float(factor)), ceili(vox.size.z / float(factor)))
	for b: Vector3i in counts:
		var c: Dictionary = counts[b]
		var best := -1
		for index: int in c:
			if best == -1 or int(c[index]) > int(c[best]) or (c[index] == c[best] and index == GLOW):
				best = index
		out.voxels.append([b.x, b.y, b.z, best])
	return out


static func _axis(normal: Vector3i) -> int:
	return 0 if normal.x != 0 else (1 if normal.y != 0 else 2)


## Greedy rectangles over one plane of faces (side `si`, layer `slice`): faces with the
## same 4 corner colours merge, along u only if their colour does not change along u
## (and the same for v), so the stretched shading looks exactly as before.
static func _merge_plane(s: Dictionary, si: int, slice: int, faces: Dictionary) -> void:
	var a := _axis(SIDES[si][0])
	var corners: Array = SIDES[si][1]
	var done := {}
	var cells := faces.keys()
	cells.sort()
	for start: Vector2i in cells:
		if done.has(start):
			continue
		var col: Array = faces[start]
		var along_u := _flat_along(corners, col, (a + 1) % 3)
		var along_v := _flat_along(corners, col, (a + 2) % 3)
		var du := 1
		while along_u and not done.has(start + Vector2i(du, 0)) and faces.get(start + Vector2i(du, 0)) == col:
			du += 1
		var dv := 1
		var grow := along_v
		while grow:
			for i in du:
				var c := start + Vector2i(i, dv)
				if done.has(c) or faces.get(c) != col:
					grow = false
					break
			if grow:
				dv += 1
		for i in du:
			for j in dv:
				done[start + Vector2i(i, j)] = true
		var cell := Vector3i.ZERO
		cell[a] = slice
		cell[(a + 1) % 3] = start.x
		cell[(a + 2) % 3] = start.y
		_emit(s, si, cell, Vector2i(du, dv), col)


## True if the corner colours do not change along `axis` (corners at 0 and 1 on that
## axis, the other coordinates equal, have the same colour).
static func _flat_along(corners: Array, cols: Array, axis: int) -> bool:
	for i in corners.size():
		for j in corners.size():
			var ci: Vector3 = corners[i]
			var cj: Vector3 = corners[j]
			if i < j and ci[axis] != cj[axis]:
				var di := ci
				di[axis] = cj[axis]
				if di == cj and cols[i] != cols[j]:
					return false
	return true


## One quad on side `si` of the voxel `cell`, stretched to `span` voxels along the side's
## in-plane axes (u = axis + 1, v = axis + 2), with a colour per corner.
static func _emit(s: Dictionary, si: int, cell: Vector3i, span: Vector2i, cols: Array) -> void:
	var a := _axis(SIDES[si][0])
	var u := (a + 1) % 3
	var w := (a + 2) % 3
	var base: int = (s.verts as PackedVector3Array).size()
	var k := 0
	for corner: Vector3 in SIDES[si][1]:
		var p := Vector3(cell)
		p[a] += corner[a]
		p[u] += corner[u] * span.x
		p[w] += corner[w] * span.y
		s.verts.append(p * VOXEL_SIZE)
		s.normals.append(Vector3(SIDES[si][0]))
		s.colors.append(cols[k])
		k += 1
	s.indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


static func _color(index: int, tints: Dictionary, palette: PackedColorArray) -> Color:
	if tints.has(index):
		return tints[index]
	for base: int in SHADE_OF:
		if SHADE_OF[base] == index and tints.has(base):
			return (tints[base] as Color).darkened(TONE_SHADE)
		if LIGHT_OF[base] == index and tints.has(base):
			return (tints[base] as Color).lightened(TONE_LIGHT)
		if TEX_DARK_OF[base] == index and tints.has(base):
			return (tints[base] as Color).darkened(TONE_TEX_DARK)
		if TEX_LIGHT_OF[base] == index and tints.has(base):
			return (tints[base] as Color).lightened(TONE_TEX_LIGHT)
	return palette[index]


## How open the corner of a face is (0..3): the two voxels beside it and the one
## diagonal to it, in the layer the face looks into.
static func _openness(solid: Dictionary, cell: Vector3i, normal: Vector3i, corner: Vector3) -> int:
	var axis := 0 if normal.x != 0 else (1 if normal.y != 0 else 2)
	var t1 := (axis + 1) % 3
	var t2 := (axis + 2) % 3
	var d1 := Vector3i.ZERO
	var d2 := Vector3i.ZERO
	d1[t1] = 1 if corner[t1] > 0.5 else -1
	d2[t2] = 1 if corner[t2] > 0.5 else -1
	var front := cell + normal
	var s1 := solid.has(front + d1)
	var s2 := solid.has(front + d2)
	if s1 and s2:
		return 0
	return 3 - int(s1) - int(s2) - int(solid.has(front + d1 + d2))


static func _new_surface() -> Dictionary:
	return {"verts": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array()}


## Unshaded material for glowing voxels (eyes, runes): full color whatever the light.
static func glow_material() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
		_glow_material.vertex_color_is_srgb = true
	return _glow_material


## Mesh of the .vox at `path` with these tints, built once; null if the file is invalid.
static func cached(path: String, tints: Dictionary) -> ArrayMesh:
	var key := path + str(tints)
	if _cache.has(key):
		return _cache[key]
	var vox := VoxFile.load_file(path)
	if vox == null:
		return null
	var mesh := build(vox, tints)
	_cache[key] = mesh
	return mesh


static func clear_cache() -> void:
	_cache.clear()


## Shared material: lit, colored by the vertex colors (authored in sRGB).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
	return _material
