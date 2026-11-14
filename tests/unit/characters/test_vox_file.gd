extends GutTest


func _palette_with(index: int, color: Color) -> PackedColorArray:
	var p := PackedColorArray()
	p.resize(256)
	p[index] = color
	return p


func test_parses_size_voxels_and_palette() -> void:
	var bytes := VoxWriter.build(Vector3i(2, 3, 4), [[1, 2, 3, 5]], _palette_with(5, Color.RED))
	var vox := VoxFile.parse(bytes)
	assert_not_null(vox)
	assert_eq(vox.size, Vector3i(2, 4, 3), "MagicaVoxel Z-up size becomes Godot Y-up")
	assert_eq(vox.voxels, [[1, 3, 2, 5]], "voxel (x, y, z) becomes (x, z, y)")
	assert_eq(vox.palette[5], Color.RED)


func test_default_palette_when_no_rgba() -> void:
	var vox := VoxFile.parse(VoxWriter.build(Vector3i(1, 1, 1), [[0, 0, 0, 1]]))
	assert_not_null(vox)
	assert_eq(vox.palette.size(), 256)


func test_rejects_bad_magic() -> void:
	var bytes := VoxWriter.build(Vector3i(1, 1, 1), [[0, 0, 0, 1]])
	bytes[0] = 0x58
	assert_null(VoxFile.parse(bytes))


func test_rejects_truncated_chunk() -> void:
	var bytes := VoxWriter.build(Vector3i(2, 2, 2), [[0, 0, 0, 1], [1, 1, 1, 2]])
	assert_null(VoxFile.parse(bytes.slice(0, bytes.size() - 3)))


func test_rejects_voxel_outside_size() -> void:
	assert_null(VoxFile.parse(VoxWriter.build(Vector3i(2, 2, 2), [[2, 0, 0, 1]])))


func test_rejects_xyzi_count_larger_than_data() -> void:
	var xyzi := PackedByteArray([200, 0, 0, 0, 0, 0, 0, 1]) # claims 200 voxels, has 1
	var size := PackedByteArray([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var children := VoxWriter.chunk("SIZE", size)
	children.append_array(VoxWriter.chunk("XYZI", xyzi))
	var bytes := "VOX ".to_ascii_buffer()
	bytes.append_array(PackedByteArray([150, 0, 0, 0]))
	bytes.append_array(VoxWriter.chunk("MAIN", PackedByteArray(), children))
	assert_null(VoxFile.parse(bytes))


func test_empty_bytes_is_null() -> void:
	assert_null(VoxFile.parse(PackedByteArray()))


func test_missing_file_is_null() -> void:
	assert_null(VoxFile.load_file("res://does/not/exist.vox"))
