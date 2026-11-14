extends GutTest

var layout := {"size": [10, 8], "spawn": [5, 4], "blocks": [[2, 3, 1], [7, 1, 2]]}


func test_outside_bounds_is_solid() -> void:
	var map := CollisionMap.from_layout(layout)
	assert_true(map.is_solid(Vector2i(-1, 0)))
	assert_true(map.is_solid(Vector2i(0, -1)))
	assert_true(map.is_solid(Vector2i(10, 0)))
	assert_true(map.is_solid(Vector2i(0, 8)))


func test_blocks_from_layout_are_solid() -> void:
	var map := CollisionMap.from_layout(layout)
	assert_true(map.is_solid(Vector2i(2, 3)))
	assert_true(map.is_solid(Vector2i(7, 1)))
	assert_eq(map.size, Vector2i(10, 8))


func test_floor_cells_are_free() -> void:
	var map := CollisionMap.from_layout(layout)
	assert_false(map.is_solid(Vector2i(0, 0)))
	assert_false(map.is_solid(Vector2i(9, 7)))
	assert_false(map.is_solid(Vector2i(3, 3)))


func test_spawn_point_is_cell_center() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	assert_eq(map.spawn_point(), Vector3(20.5, 0, 20.5))


func test_set_solid_toggles() -> void:
	var map := CollisionMap.from_layout(layout)
	map.set_solid(Vector2i(1, 1), true)
	assert_true(map.is_solid(Vector2i(1, 1)))
	map.set_solid(Vector2i(1, 1), false)
	assert_false(map.is_solid(Vector2i(1, 1)))


func test_real_arena_spawn_area_is_clear() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/test_arena.json"))
	var map := CollisionMap.from_layout(data)
	for x in range(17, 24):
		for z in range(17, 24):
			assert_false(map.is_solid(Vector2i(x, z)), "cell %d,%d near spawn must be free" % [x, z])
