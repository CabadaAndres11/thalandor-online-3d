extends GutTest
## The zone map image shared by the map (M) and the minimap (Plan 8.1.1).


func test_image_size_and_ground_colours() -> void:
	var z := ZoneLayout.load_id("aldea")
	var img := ZoneMapImage.make(z)
	assert_eq(img.get_size(), z.size * ZoneMapImage.PX)
	# A road cell of the village (the east road at z 48) away from pieces.
	var c: Color = img.get_pixel(80 * ZoneMapImage.PX + 1, 48 * ZoneMapImage.PX + 1)
	var road: Color = ZoneView.GROUND.road
	assert_almost_eq(c.r, road.r, 0.12)
	assert_almost_eq(c.g, road.g, 0.12)
	assert_almost_eq(c.b, road.b, 0.12)


func test_markers() -> void:
	var z := ZoneLayout.load_id("palacio")
	var marks := ZoneMapImage.markers(z, null)
	var dungeon := marks.filter(func(m: Dictionary) -> bool: return m.kind == "dungeon")
	assert_eq(dungeon.size(), 1, "the crypt is under the palace (Plan 8.3b)")
	assert_eq(dungeon[0].label, tr("ZONE_CRIPTA_PRUEBA"))
	var forest := ZoneMapImage.markers(ZoneLayout.load_id("bosque"), null)
	assert_eq(forest.filter(func(m: Dictionary) -> bool: return m.kind == "dungeon").size(), 0)
	assert_eq(forest.filter(func(m: Dictionary) -> bool: return m.kind == "exit").size(), 2, "to the village and the road")
	var village := ZoneMapImage.markers(ZoneLayout.load_id("aldea"), null)
	var verrin := village.filter(func(m: Dictionary) -> bool: return m.kind == "npc" and m.label == tr("NPC_VERRIN"))
	assert_eq(verrin.size(), 1)
	assert_eq(Vector2(verrin[0].cell), Vector2(78.5, 44.5))


## Plan 8.1.2: the edge band is drawn as forest on the map.
func test_band_drawn_as_forest() -> void:
	var z := ZoneLayout.load_id("aldea")
	var img := ZoneMapImage.make(z)
	var c: Color = img.get_pixel(2 * ZoneMapImage.PX + 1, 2 * ZoneMapImage.PX + 1)
	assert_almost_eq(c.g, ZoneMapImage.TREE.g, 0.05)
