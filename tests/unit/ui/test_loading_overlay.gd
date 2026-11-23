extends GutTest
## The loading screen: a picture of the zone, a tip and a bar (Plan 8.1.2); it waits for
## every reason and shows at least MIN_SHOW_S (Plan 8.1.1).


func _overlay() -> LoadingOverlay:
	var o := LoadingOverlay.new()
	add_child_autofree(o)
	return o


func test_shows_the_zone_name_and_covers_the_screen() -> void:
	var o := _overlay()
	o.show_zone("ZONE_ALDEA")
	assert_true(o.visible)
	assert_eq(o.title.text, tr("ZONE_ALDEA"))
	o.hide_overlay()
	o._process(LoadingOverlay.MIN_SHOW_S + LoadingOverlay.FADE_S + 0.1)
	assert_false(o.visible)


func test_overlay_stays_min_time() -> void:
	var o := _overlay()
	o.show_zone("ZONE_ALDEA")
	o.hide_overlay() # the zone was ready at once
	o._process(0.3)
	assert_true(o.visible, "still shown before 0.6 s")
	o._process(0.35)
	assert_true(o.visible, "fading out")
	o._process(LoadingOverlay.FADE_S)
	assert_false(o.visible)


func test_waits_for_every_reason() -> void:
	var o := _overlay()
	o.show_zone("ZONE_BOSQUE", ["build", "ready"])
	o.done("build")
	o._process(2.0)
	assert_true(o.visible, "the first snapshot has not arrived")
	o.done("ready")
	o._process(LoadingOverlay.FADE_S + 0.01)
	assert_false(o.visible)


func test_picture_of_the_destination_zone() -> void:
	var o := _overlay()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LoadingOverlay.DATA))
	o.show_zone("ZONE_BOSQUE", ["build"], "bosque")
	assert_has(data.images.bosque, o.image_path)
	assert_not_null(o.picture.texture)
	o.show_zone("ZONE_ARENA", ["build"], "arena")
	assert_has(data.images.default, o.image_path, "a zone without pictures uses the generic ones")


func test_every_picture_exists() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LoadingOverlay.DATA))
	for zone: String in data.images:
		for path: String in data.images[zone]:
			assert_true(ResourceLoader.exists(path), path)


func test_tip_from_the_list_translated() -> void:
	var o := _overlay()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LoadingOverlay.DATA))
	o.show_zone("ZONE_ALDEA", ["build"], "aldea")
	var tips: Array = data.tips.map(func(k: String) -> String: return tr(k))
	assert_has(tips, o.tip.text)
	for k: String in data.tips:
		assert_ne(tr(k), k, k + " translated")


func test_progress_bar() -> void:
	var o := _overlay()
	o.show_zone("ZONE_ALDEA", ["build"], "aldea")
	assert_eq(o.bar.value, 0.0)
	o.set_progress(0.5)
	assert_almost_eq(o.bar.value, 0.5, 0.001)
	o.set_progress(0.3)
	assert_almost_eq(o.bar.value, 0.5, 0.001, "never goes back")
	o.set_progress(2.0)
	assert_almost_eq(o.bar.value, 1.0, 0.001)
