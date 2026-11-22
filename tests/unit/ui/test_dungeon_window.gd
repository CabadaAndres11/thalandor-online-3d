extends GutTest
## Choosing a dungeon's level at its door (Plan 8.1).

const SCREEN := Vector2(1280, 720)


func _window() -> DungeonWindow:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	var w := DungeonWindow.new()
	root.add_child(w)
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return w


func test_steps_within_range_and_emits() -> void:
	var w := _window()
	w.open("dungeon_t", "ZONE_TEST_DUNGEON", 15, 30, 20)
	assert_true(w.visible)
	assert_eq(w.level, 20)
	for i in 20:
		w.next_level()
	assert_eq(w.level, 30)
	for i in 30:
		w.prev_level()
	assert_eq(w.level, 15)
	watch_signals(w)
	w.enter_button.pressed.emit()
	assert_signal_emitted_with_parameters(w, "enter_requested", ["dungeon_t", 15])
	assert_false(w.visible)


func test_cancel_closes() -> void:
	var w := _window()
	w.open("dungeon_t", "ZONE_TEST_DUNGEON", 15, 30, 20)
	w.cancel_button.pressed.emit()
	assert_false(w.visible)


func test_fits_1280x720() -> void:
	var w := _window()
	w.open("dungeon_t", "ZONE_TEST_DUNGEON", 15, 30, 20)
	await wait_frames(2)
	var panel := w.get_child(0) as Control
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(panel.get_global_rect()))
