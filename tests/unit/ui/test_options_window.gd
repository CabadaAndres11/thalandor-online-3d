extends GutTest

var win: OptionsWindow
var store: SettingsStore


func before_each() -> void:
	InputSetup.ensure_actions()
	get_tree().root.size = Vector2i(1280, 720)
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child_autofree(root)
	win = OptionsWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 24
	HoloTheme.apply(theme)
	win.theme = theme
	root.add_child(win)
	win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	store = SettingsStore.new()
	win.open(store)


func test_opens_visible() -> void:
	assert_true(win.visible)


func test_window_fits_1280x720_both_tabs() -> void:
	for tab in 2:
		win.show_tab(tab)
		await wait_process_frames(2)
		var r := win.panel_rect()
		assert_true(Rect2(0, 0, 1280, 720).encloses(r), "tab %d: %s" % [tab, r])
		assert_gt(r.size.x, 300.0, "the panel is laid out")
		var stack: Array = [win]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			assert_false(n is ScrollContainer, "no scroll: %s" % n.get_path())
			stack.append_array(n.get_children())


func test_quality_change_edits_store_and_emits() -> void:
	watch_signals(win)
	win.set_quality(GraphicsQuality.LOW)
	assert_eq(store.quality, GraphicsQuality.LOW)
	assert_signal_emitted(win, "settings_changed")


func test_volume_slider_edits_store() -> void:
	watch_signals(win)
	win.set_volume("Music", 0.3)
	assert_almost_eq(float(store.volumes.Music), 0.3, 0.001)
	assert_signal_emitted(win, "settings_changed")


func test_reset_restores_defaults_and_emits() -> void:
	win.set_quality(GraphicsQuality.HIGH)
	win.set_volume("SFX", 0.0)
	watch_signals(win)
	win.press_reset()
	assert_eq(store.quality, GraphicsQuality.MEDIUM)
	assert_almost_eq(float(store.volumes.SFX), 1.0, 0.001)
	assert_signal_emitted(win, "settings_changed")


func test_escape_closes() -> void:
	watch_signals(win)
	var ev := InputEventAction.new()
	ev.action = "menu"
	ev.pressed = true
	win._unhandled_input(ev)
	assert_false(win.visible)
	assert_signal_emitted(win, "closed")


func test_close_button_closes() -> void:
	watch_signals(win)
	win.close_button.pressed.emit()
	assert_false(win.visible)
	assert_signal_emitted(win, "closed")
