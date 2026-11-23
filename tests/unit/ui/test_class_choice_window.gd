extends GutTest

var win: ClassChoiceWindow


func before_each() -> void:
	win = ClassChoiceWindow.new()
	add_child_autofree(win)


func test_window_lists_five_classes() -> void:
	win.show_for({})
	assert_eq(win.class_ids(), ["warrior", "cleric", "mage", "archer", "assassin"])
	assert_true(win.visible)
	assert_eq(win.selected(), "warrior")


func test_selecting_shows_its_description_and_preview() -> void:
	win.show_for({"hair_style": "bob"})
	win.select("archer")
	assert_eq(win.selected(), "archer")
	assert_string_contains(win.description_text(), tr("CLASS_ARCHER_DESC"))
	assert_has(win.preview.rig.pieces(), "w_bow_t1", "the starter bow (Plan 8.1.1)")


func test_confirm_emits() -> void:
	win.show_for({})
	win.select("mage")
	watch_signals(win)
	win.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(win, "class_confirmed", ["mage"])
	assert_false(win.visible)


func test_window_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	win.show_for({})
	for id: String in win.class_ids():
		win.select(id)
		await wait_process_frames(1)
		var r := win.panel_rect()
		assert_true(Rect2(0, 0, 1280, 720).encloses(r), "%s: panel %s" % [id, r])
		assert_gt(r.size.x, 500.0, "laid out")


## Plan 8.1.1: the preview wears the starter kit the host gives that class.
func test_preview_shows_starter_kit() -> void:
	win.show_for({})
	var db := ItemDB.load_default()
	for id: String in win.class_ids():
		var kit := Inventory.starter(id, db).visible_bases()
		assert_eq(win.preview_gear(id), kit, id)
		win.select(id)
		assert_eq(win.preview.gear, kit, id + " rig built with that gear")
