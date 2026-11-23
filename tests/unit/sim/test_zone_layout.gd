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


func test_unknown_monster_and_exit_are_reported_on_load() -> void:
	var z := ZoneLayout.from_dict("bad", {"size": [5, 5],
		"hordes": [{"area": [0, 0, 5, 5], "monsters": [["dragon", 1]], "levels": [1, 1], "count": 1}],
		"spawns": [{"type": "kraken", "at": [1, 1]}],
		"exits": [{"area": [0, 0, 1, 1], "to": "atlantis", "entry": "default"}]}, DIR + "pieces.json")
	assert_has(z.errors, "unknown monster dragon")
	assert_has(z.errors, "unknown monster kraken")
	assert_has(z.warnings, "exit to unknown zone atlantis")


# --- Walkable houses (Plan 8.1.1) -------------------------------------------------------

func _house_zone(id: String, rot: int) -> ZoneLayout:
	return ZoneLayout.from_dict("h", {"size": [30, 30], "pieces": [{"id": id, "at": [12, 12], "rot": rot}]})


func _reach(map: CollisionMap, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and not map.is_solid(n) and n.x >= 0 and n.y >= 0 and n.x < 30 and n.y < 30:
				seen[n] = true
				queue.append(n)
	return seen


func test_house_interior_reachable_from_door_all_rotations() -> void:
	for id: String in ["house_small", "house_large", "house_forge"]:
		for rot: int in [0, 90, 180, 270]:
			var z := _house_zone(id, rot)
			var map := z.collision()
			var reach := _reach(map, Vector2i(0, 0)) # from outside, far from the house
			var h: Dictionary = z.houses[0]
			var walkable := 0
			for c: Vector2i in h.cells:
				if not map.is_solid(c):
					walkable += 1
					assert_true(reach.has(c), "%s rot %d: %s reachable" % [id, rot, c])
			assert_gt(walkable, 9, "%s rot %d walkable inside" % [id, rot])
			for c: Vector2i in h.door:
				assert_false(map.is_solid(c), "%s rot %d door %s" % [id, rot, c])


func test_house_at() -> void:
	var z := _house_zone("house_small", 0)
	assert_eq(z.house_at(Vector2i(14, 14)), 0, "inside")
	assert_eq(z.house_at(Vector2i(12, 12)), -1, "a wall")
	assert_eq(z.house_at(Vector2i(2, 2)), -1, "outside")


func test_nothing_scattered_inside_a_house() -> void:
	var z := ZoneLayout.from_dict("h", {"size": [30, 30], "pieces": [{"id": "house_large", "at": [10, 10]}],
		"scatter": [{"area": [0, 0, 30, 30], "pieces": ["bush", "tree_pine"], "density": 1.0, "seed": 2}]})
	var inside := {}
	for c: Vector2i in z.houses[0].cells:
		inside[c] = true
	for c: Vector2i in z.houses[0].door:
		inside[c] = true
	for p: Dictionary in z.pieces:
		if p.id != "house_large":
			assert_false(inside.has(p.at), "%s at %s" % [p.id, p.at])
