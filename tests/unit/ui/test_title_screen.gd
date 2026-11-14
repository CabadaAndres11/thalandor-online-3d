extends GutTest

const SCREEN := Vector2(1280, 720)


func _host(control: Control) -> Control:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root


func test_title_buttons_disabled_for_invalid_name() -> void:
	var title := TitleScreen.new()
	_host(title)
	title.set_defaults("", "")
	assert_true(title.play_button.disabled)
	assert_true(title.join_button.disabled)
	title.name_edit.text = "Andrés"
	title.name_edit.text_changed.emit("Andrés")
	assert_false(title.play_button.disabled)
	assert_false(title.join_button.disabled)


func test_play_emits_trimmed_name() -> void:
	var title := TitleScreen.new()
	_host(title)
	title.set_defaults("  Ana  ", "")
	watch_signals(title)
	title.play_button.pressed.emit()
	assert_signal_emitted_with_parameters(title, "play_requested", ["Ana"])


func test_join_emits_code() -> void:
	var title := TitleScreen.new()
	_host(title)
	title.set_defaults("Ana", "abcd-efgh")
	watch_signals(title)
	title.join_button.pressed.emit()
	assert_signal_emitted_with_parameters(title, "join_requested", ["Ana", "abcd-efgh"])


func test_shows_version() -> void:
	var title := TitleScreen.new()
	_host(title)
	assert_true(title.version_label.text.contains(GameSession.game_version()))


func _assert_fits(root: Control) -> void:
	var screen := Rect2(Vector2.ZERO, SCREEN)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		assert_false(n is ScrollContainer, "no ScrollContainer allowed: %s" % n.get_path())
		if n is Control and (n as Control).is_visible_in_tree():
			var r := (n as Control).get_global_rect()
			assert_true(screen.grow(0.5).encloses(r), "%s %s out of 1280x720" % [n.get_path(), r])
		stack.append_array(n.get_children())


func test_all_ui_fits_1280x720() -> void:
	var title := TitleScreen.new()
	var r1 := _host(title)
	var menu := PauseMenu.new()
	var r2 := _host(menu)
	menu.set_can_open_group(true)
	menu.show()
	menu.show_code("ABCD-EFGH")
	var chat := ChatBox.new()
	var r3 := _host(chat)
	for i in 8:
		chat.add_message("Nombre-Largo-16c", "x".repeat(120), false)
	chat.open_input()
	var dialog := MessageDialog.new()
	var r4 := _host(dialog)
	dialog.show_message(TranslationServer.translate("ERR_CONNECT"))
	var debug := DebugOverlay.new()
	var r5 := _host(debug)
	debug.show()
	await wait_frames(3)
	for r: Control in [r1, r2, r3, r4, r5]:
		_assert_fits(r)
