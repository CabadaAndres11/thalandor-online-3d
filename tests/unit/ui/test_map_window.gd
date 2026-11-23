extends GutTest
## The map (M) and the minimap (Plan 8.1.1).


func _tex() -> ImageTexture:
	return ImageTexture.create_from_image(ZoneMapImage.make(ZoneLayout.load_id("bosque")))


func test_map_window_fits_720p() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var w := MapWindow.new()
	add_child_autofree(w)
	w.refresh(_tex(), ZoneMapImage.markers(ZoneLayout.load_id("bosque"), null), "ZONE_BOSQUE")
	w.visible = true
	await wait_process_frames(2)
	var r := w.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), str(r))
	assert_eq(w.title.text, tr("ZONE_BOSQUE"))


func test_minimap_draws_around_the_player() -> void:
	var m := Minimap.new()
	add_child_autofree(m)
	m.refresh(_tex(), [], Vector2(50, 60), deg_to_rad(45.0), "ZONE_BOSQUE")
	assert_eq(m.center, Vector2(50, 60))
	assert_eq(m.size, Vector2(Minimap.SIZE, Minimap.SIZE))
	# Camera yaw 45°: the camera looks towards (-x, -z) on the map; that is up.
	assert_almost_eq(m.map_rotation(), deg_to_rad(45.0), 0.001)
	assert_eq(m.zone_label.text, tr("ZONE_BOSQUE"))
