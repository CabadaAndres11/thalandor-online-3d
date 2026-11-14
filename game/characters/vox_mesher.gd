class_name VoxMesher
extends RefCounted
## Turns a VoxFile into a mesh: one quad per voxel side whose neighbour is empty, with
## per-vertex colors. Some palette indices are "tintable": they take a color chosen by
## the character (hair, class colors) instead of their palette color.

const VOXEL_SIZE := 0.1
const TINT_HAIR := 250
const TINT_PRIMARY := 251
const TINT_SECONDARY := 252

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


static func build(vox: VoxFile, tints: Dictionary) -> ArrayMesh:
	var solid := {}
	for v: Array in vox.voxels:
		solid[Vector3i(v[0], v[1], v[2])] = true
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for v: Array in vox.voxels:
		var cell := Vector3i(v[0], v[1], v[2])
		var index: int = v[3]
		var color: Color = tints[index] if tints.has(index) else vox.palette[index]
		for side: Array in SIDES:
			var normal: Vector3i = side[0]
			if solid.has(cell + normal):
				continue
			var base := verts.size()
			for corner: Vector3 in side[1]:
				verts.append((Vector3(cell) + corner) * VOXEL_SIZE)
				normals.append(Vector3(normal))
				colors.append(color)
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh


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
