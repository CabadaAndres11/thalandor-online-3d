extends GutTest
## Relief in the zone data (Plan 8.3d): hills, hollows and plateaus; steep steps are cliffs.


func _zone(relief: Array) -> ZoneLayout:
	return ZoneLayout.from_dict("t", {"size": [40, 40], "entries": {"default": [2, 2]}, "relief": relief, "margin": "none"})


func test_hill_height() -> void:
	var z := _zone([{"kind": "hill", "at": [20, 20], "radius": 10, "height": 3}])
	assert_almost_eq(z.height_at(20.5, 20.5), 3.0, 0.001, "the top")
	assert_almost_eq(z.height_at(30.5, 20.5), 0.0, 0.001, "the foot")
	var last := 3.0
	for d in range(1, 10):
		var h := z.height_at(20.5 + d, 20.5)
		assert_lte(h, last, "it falls all the way down")
		last = h
	var hollow := _zone([{"kind": "hollow", "at": [20, 20], "radius": 6, "height": -1.5}])
	assert_almost_eq(hollow.height_at(20.5, 20.5), -1.5, 0.001)


func test_gentle_hill_has_no_cliffs() -> void:
	var z := _zone([{"kind": "hill", "at": [20, 20], "radius": 12, "height": 3}])
	assert_eq(z.cliff_cells(), [], "a gentle hill is walked up")


func test_plateau_reached_by_slope() -> void:
	var sloped := _zone([{"kind": "plateau", "area": [15, 15, 10, 10], "height": 2.0, "slope": 6}])
	assert_eq(sloped.cliff_cells(), [], "up the slope")
	var sheer := _zone([{"kind": "plateau", "area": [15, 15, 10, 10], "height": 2.0, "slope": 0}])
	var map := sheer.collision()
	assert_true(map.is_solid(Vector2i(14, 20)), "below the edge")
	assert_true(map.is_solid(Vector2i(15, 20)), "on the edge")
	assert_false(map.is_solid(Vector2i(20, 20)), "on top it is free")
	assert_false(map.is_solid(Vector2i(5, 5)), "the plain is free")


func test_flat_zone_unchanged() -> void:
	var z := _zone([])
	assert_eq(z.height_at(10.0, 10.0), 0.0)
	assert_eq(z.cliff_cells(), [])
	assert_eq(z.corner_height(Vector2i(3, 3)), 0.0)
