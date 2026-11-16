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


static func build(vox: VoxFile, tints: Dictionary) -> ArrayMesh:
	var solid := {}
	for v: Array in vox.voxels:
		solid[Vector3i(v[0], v[1], v[2])] = true
	# Two surfaces: lit voxels, and glowing ones (index GLOW) drawn unshaded.
	var lit := _new_surface()
	var glow := _new_surface()
	for v: Array in vox.voxels:
		var cell := Vector3i(v[0], v[1], v[2])
		var index: int = v[3]
		var color: Color = tints[index] if tints.has(index) else vox.palette[index]
		var s: Dictionary = glow if index == GLOW else lit
		for side: Array in SIDES:
			var normal: Vector3i = side[0]
			if solid.has(cell + normal):
				continue
			var base: int = (s.verts as PackedVector3Array).size()
			for corner: Vector3 in side[1]:
				s.verts.append((Vector3(cell) + corner) * VOXEL_SIZE)
				s.normals.append(Vector3(normal))
				s.colors.append(color)
			s.indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
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
