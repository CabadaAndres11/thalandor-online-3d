extends GutTest


func _map(blocks: Array) -> CollisionMap:
	return CollisionMap.from_layout({"size": [20, 20], "spawn": [1, 1], "blocks": blocks})


func test_straight_path_on_open_ground() -> void:
	var pf := Pathfinder.new(_map([]))
	var path := pf.path(Vector3(2.5, 0, 2.5), Vector3(8.5, 0, 2.5))
	assert_false(path.is_empty())
	assert_eq(path[path.size() - 1], Vector2(8.5, 2.5))


func test_path_around_blocks() -> void:
	var wall := []
	for z in range(0, 15):
		wall.append([10, z, 1])
	var pf := Pathfinder.new(_map(wall))
	var path := pf.path(Vector3(5.5, 0, 5.5), Vector3(15.5, 0, 5.5))
	assert_false(path.is_empty())
	var went_around := false
	for p: Vector2 in path:
		assert_false(_map(wall).is_solid(Vector2i(floori(p.x), floori(p.y))), "never through a block")
		if p.y >= 15.0:
			went_around = true
	assert_true(went_around, "goes around the end of the wall")


func test_no_path_returns_empty() -> void:
	var box := []
	for i in range(8, 13):
		box.append([i, 8, 1])
		box.append([i, 12, 1])
		box.append([8, i, 1])
		box.append([12, i, 1])
	var pf := Pathfinder.new(_map(box))
	assert_true(pf.path(Vector3(2.5, 0, 2.5), Vector3(10.5, 0, 10.5)).is_empty())


func test_no_corner_cutting() -> void:
	var pf := Pathfinder.new(_map([[5, 4, 1], [4, 5, 1]]))
	var path := pf.path(Vector3(4.5, 0, 4.5), Vector3(5.5, 0, 5.5))
	assert_true(path.is_empty() or path.size() > 1, "cannot squeeze diagonally between two blocks")
