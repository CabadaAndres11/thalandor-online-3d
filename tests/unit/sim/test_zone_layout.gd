extends GutTest
## Zones as data (Plan 8.1): pieces with footprints, scatter, paths, water, exits.

const DIR := "res://tests/data/zones/"


func _small() -> ZoneLayout:
	return ZoneLayout.load_path(DIR + "test_small.json", DIR + "pieces.json")


func test_loads_and_builds_collision() -> void:
	var z := _small()
	assert_not_null(z)
	assert_eq(z.size, Vector2i(30, 20))
	assert_eq(z.levels, Vector2i(3, 7))
	var map := z.collision()
	assert_true(map.is_solid(Vector2i(5, 5)), "the hut")
	assert_true(map.is_solid(Vector2i(6, 5)), "its second cell")
	assert_false(map.is_solid(Vector2i(12, 12)), "a bridge does not block")
	assert_eq(map.spawn_point(), Vector3(2.5, 0, 2.5))
	assert_eq(map.respawn_point(), Vector3(2.5, 0, 3.5))
	assert_eq(map.hordes.size(), 1)
	assert_eq(map.npcs.size(), 1)
	assert_eq(map.zone_id, "test_small")


func test_rotated_footprint() -> void:
	var map := _small().collision()
	assert_true(map.is_solid(Vector2i(10, 5)))
	assert_true(map.is_solid(Vector2i(10, 6)), "turned 90°: (1, 0) becomes (0, 1)")
	assert_false(map.is_solid(Vector2i(11, 5)))


func test_scatter_skips_paths_and_is_deterministic() -> void:
	var a := _small()
	var b := _small()
	var trees := a.pieces.filter(func(p: Dictionary) -> bool: return p.id == "tree")
	assert_gt(trees.size(), 20)
	assert_eq(trees, b.pieces.filter(func(p: Dictionary) -> bool: return p.id == "tree"))
	for t: Dictionary in trees:
		assert_ne((t.at as Vector2i).y, 15, "no tree on the road")


func test_water_is_solid() -> void:
	assert_true(_small().collision().is_solid(Vector2i(27, 8)))


func test_old_blocks_still_work() -> void:
	var z := ZoneLayout.load_path("res://data/zones/arena.json")
	assert_not_null(z)
	assert_true(z.collision().is_solid(Vector2i(14, 14)))
	assert_eq(z.collision().spawns.size(), 9)


func test_unknown_piece_errors_with_its_name() -> void:
	var z := ZoneLayout.from_dict("bad", {"size": [5, 5], "pieces": [{"id": "dragon_statue", "at": [1, 1]}]}, DIR + "pieces.json")
	assert_eq(z.errors, ["unknown piece dragon_statue"])
	assert_false(z.collision().is_solid(Vector2i(1, 1)))


func test_exit_at_and_entry_default() -> void:
	var z := _small()
	assert_eq(z.exit_at(Vector3(23.5, 0, 1.5)).to, "bosque")
	assert_eq(z.exit_at(Vector3(2.5, 0, 2.5)), {})
	assert_eq(z.entry("from_east"), Vector3(22.5, 0, 2.5))
	assert_eq(z.entry("nowhere"), Vector3(2.5, 0, 2.5))


func test_unknown_zone_is_null() -> void:
	assert_null(ZoneLayout.load_id("no_such_zone"))
