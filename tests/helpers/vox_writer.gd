class_name VoxWriter
extends RefCounted
## Test helper: builds MagicaVoxel .vox bytes (version 150: MAIN > SIZE, XYZI, RGBA).
## `voxels` are [x, y, z, index] in MagicaVoxel coordinates (Z up); `palette` holds the
## colors for indices 1..n (palette[0] is ignored); empty = no RGBA chunk.


static func build(size: Vector3i, voxels: Array, palette: PackedColorArray = PackedColorArray()) -> PackedByteArray:
	var children := PackedByteArray()
	var size_data := PackedByteArray()
	for v: int in [size.x, size.y, size.z]:
		size_data.append_array(_u32(v))
	children.append_array(chunk("SIZE", size_data))
	var xyzi := _u32(voxels.size())
	for v: Array in voxels:
		xyzi.append_array(PackedByteArray([v[0], v[1], v[2], v[3]]))
	children.append_array(chunk("XYZI", xyzi))
	if not palette.is_empty():
		var rgba := PackedByteArray()
		for i in 256:
			var c := palette[i + 1] if i + 1 < palette.size() else Color.BLACK
			rgba.append_array(PackedByteArray([c.r8, c.g8, c.b8, c.a8]))
		children.append_array(chunk("RGBA", rgba))
	var out := "VOX ".to_ascii_buffer()
	out.append_array(_u32(150))
	out.append_array(chunk("MAIN", PackedByteArray(), children))
	return out


static func chunk(id: String, content: PackedByteArray, children: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := id.to_ascii_buffer()
	out.append_array(_u32(content.size()))
	out.append_array(_u32(children.size()))
	out.append_array(content)
	out.append_array(children)
	return out


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b
