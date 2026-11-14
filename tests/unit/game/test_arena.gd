extends GutTest

var layout := {"size": [6, 5], "spawn": [1, 1], "blocks": [[3, 2, 2], [4, 4, 1]]}


func test_arena_collision_matches_layout() -> void:
	var arena: Arena = autofree(Arena.new())
	var map := arena.build(layout)
	assert_true(map.is_solid(Vector2i(3, 2)))
	assert_true(map.is_solid(Vector2i(4, 4)))
	assert_false(map.is_solid(Vector2i(0, 0)))
	assert_eq(map.size, Vector2i(6, 5))


func test_gridmap_has_floor_and_stacked_blocks() -> void:
	var arena: Arena = autofree(Arena.new())
	arena.build(layout)
	var grid := arena.grid
	assert_eq(grid.get_cell_item(Vector3i(0, -1, 0)), Arena.ITEM_FLOOR)
	assert_eq(grid.get_cell_item(Vector3i(5, -1, 4)), Arena.ITEM_FLOOR)
	assert_ne(grid.get_cell_item(Vector3i(3, 0, 2)), GridMap.INVALID_CELL_ITEM)
	assert_ne(grid.get_cell_item(Vector3i(3, 1, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(3, 2, 2)), GridMap.INVALID_CELL_ITEM)
	assert_eq(grid.get_cell_item(Vector3i(0, 0, 0)), GridMap.INVALID_CELL_ITEM)


func test_real_arena_builds() -> void:
	var arena: Arena = autofree(Arena.new())
	var map := arena.build(Arena.load_layout())
	assert_eq(map.size, Vector2i(40, 40))
