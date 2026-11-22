extends GutTest
## The loading screen between zones (Plan 8.1).


func test_shows_the_zone_name_and_covers_the_screen() -> void:
	var o := LoadingOverlay.new()
	add_child_autofree(o)
	o.show_zone("ZONE_ALDEA")
	assert_true(o.visible)
	assert_eq(o.title.text, tr("ZONE_ALDEA"))
	o.hide_overlay()
	assert_false(o.visible)
