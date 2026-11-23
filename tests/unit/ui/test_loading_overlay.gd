extends GutTest
## The loading screen between zones (Plan 8.1; minimum time and waits, Plan 8.1.1).


func test_shows_the_zone_name_and_covers_the_screen() -> void:
	var o := LoadingOverlay.new()
	add_child_autofree(o)
	o.show_zone("ZONE_ALDEA")
	assert_true(o.visible)
	assert_eq(o.title.text, tr("ZONE_ALDEA"))
	o.hide_overlay()
	o._process(LoadingOverlay.MIN_SHOW_S + LoadingOverlay.FADE_S + 0.1)
	assert_false(o.visible)


func test_overlay_stays_min_time() -> void:
	var o := LoadingOverlay.new()
	add_child_autofree(o)
	o.show_zone("ZONE_ALDEA")
	o.hide_overlay() # the zone was ready at once
	o._process(0.3)
	assert_true(o.visible, "still shown before 0.6 s")
	o._process(0.35)
	assert_true(o.visible, "fading out")
	o._process(LoadingOverlay.FADE_S)
	assert_false(o.visible)


func test_waits_for_every_reason() -> void:
	var o := LoadingOverlay.new()
	add_child_autofree(o)
	o.show_zone("ZONE_BOSQUE", ["build", "ready"])
	o.done("build")
	o._process(2.0)
	assert_true(o.visible, "the first snapshot has not arrived")
	o.done("ready")
	o._process(LoadingOverlay.FADE_S + 0.01)
	assert_false(o.visible)
