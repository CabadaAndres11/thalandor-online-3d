class_name VoxFile
extends RefCounted
## A MagicaVoxel .vox model (first SIZE/XYZI pair, plus the RGBA palette).
## Coordinates are converted to Godot's Y-up axes: MagicaVoxel (x, y, z) -> (x, z, y).

const MAGIC := "VOX "
const PALETTE_SIZE := 256

## Size in voxels (Godot axes).
var size: Vector3i = Vector3i.ZERO
## [x, y, z, palette index] per solid voxel (Godot axes).
var voxels: Array = []
## Colors by palette index; index 0 is empty space.
var palette: PackedColorArray = PackedColorArray()


## Returns null when the bytes are not a valid .vox file (never raises engine errors).
static func parse(bytes: PackedByteArray) -> VoxFile:
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return null
	# MAIN chunk header at offset 8; its children follow its (empty) content.
	if _chunk_id(bytes, 8) != "MAIN":
		return null
	var main_content := bytes.decode_u32(12)
	var main_children := bytes.decode_u32(16)
	var pos := 20 + main_content
	var end := pos + main_children
	if end > bytes.size():
		return null
	var vox := VoxFile.new()
	var has_size := false
	var has_voxels := false
	var palette_set := false
	while pos + 12 <= end:
		var id := _chunk_id(bytes, pos)
		var content_size := bytes.decode_u32(pos + 4)
		var children_size := bytes.decode_u32(pos + 8)
		var content := pos + 12
		var next := content + content_size + children_size
		if next > end:
			return null
		match id:
			"SIZE":
				if content_size < 12 or has_size:
					pos = next
					continue
				vox.size = Vector3i(bytes.decode_u32(content), bytes.decode_u32(content + 8), bytes.decode_u32(content + 4))
				has_size = true
			"XYZI":
				if has_voxels:
					pos = next
					continue
				if not has_size or content_size < 4:
					return null
				var count := bytes.decode_u32(content)
				if 4 + count * 4 > content_size:
					return null
				for i in count:
					var o := content + 4 + i * 4
					var x := bytes[o]
					var y := bytes[o + 1]
					var z := bytes[o + 2]
					# Godot axes: (x, z, y); size is already converted.
					if x >= vox.size.x or z >= vox.size.y or y >= vox.size.z:
						return null
					vox.voxels.append([x, z, y, bytes[o + 3]])
				has_voxels = true
			"RGBA":
				if content_size >= PALETTE_SIZE * 4:
					vox.palette = _read_palette(bytes, content)
					palette_set = true
		pos = next
	if not has_size or not has_voxels:
		return null
	if not palette_set:
		vox.palette = _default_palette()
	return vox


static func load_file(path: String) -> VoxFile:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_bytes(path))


static func _chunk_id(bytes: PackedByteArray, at: int) -> String:
	return bytes.slice(at, at + 4).get_string_from_ascii()


## RGBA entry i is the color of palette index i + 1.
static func _read_palette(bytes: PackedByteArray, at: int) -> PackedColorArray:
	var p := PackedColorArray()
	p.resize(PALETTE_SIZE)
	for i in PALETTE_SIZE - 1:
		var o := at + i * 4
		p[i + 1] = Color8(bytes[o], bytes[o + 1], bytes[o + 2], bytes[o + 3])
	return p


## Neutral grey for every index (our pieces always carry their own palette).
static func _default_palette() -> PackedColorArray:
	var p := PackedColorArray()
	p.resize(PALETTE_SIZE)
	p.fill(Color(0.6, 0.6, 0.6))
	p[0] = Color(0, 0, 0, 0)
	return p
