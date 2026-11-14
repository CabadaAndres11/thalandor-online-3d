extends GutTest

const SCREEN := Vector2(1280, 720)


func _host(control: Control) -> Control:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root


func test_play_opens_characters() -> void:
	var title := TitleScreen.new()
	_host(title)
	watch_signals(title)
	title.play_button.pressed.emit()
	assert_signal_emitted(title, "play_requested")


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
	var select := CharacterSelectScreen.new()
	var r6 := _host(select)
	var list: Array[CharacterData] = []
	for i in CharacterStore.MAX_CHARACTERS:
		var c := CharacterData.new()
		c.id = "%016x" % (i + 1)
		c.name = "Nombre-Largo-16c"
		c.class_id = "assassin"
		list.append(c)
	select.set_characters(list, list[0].id)
	var create := CharacterCreateScreen.new()
	var r7 := _host(create)
	create.reset("Nombre-Largo-16c")
	create.select_class("cleric")
	var asking := MessageDialog.new()
	var r8 := _host(asking)
	asking.ask_text(TranslationServer.translate("IMPORT_NEW_NAME") % "Nombre-Largo-16c", "Nombre-Largo-16c")
	await wait_frames(3)
	for r: Control in [r1, r2, r3, r4, r5, r6, r7, r8]:
		_assert_fits(r)


func test_dialog_ask_answers_yes_or_no() -> void:
	var dialog := MessageDialog.new()
	_host(dialog)
	watch_signals(dialog)
	dialog.ask("¿Seguro?")
	assert_true(dialog.visible)
	dialog.yes_button.pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "answered", [true])
	assert_false(dialog.visible)
	dialog.ask("¿Seguro?")
	dialog.no_button.pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "answered", [false])


func test_dialog_ask_text_returns_text_or_empty() -> void:
	var dialog := MessageDialog.new()
	_host(dialog)
	watch_signals(dialog)
	dialog.ask_text("Otro nombre", "Gemelo")
	assert_eq(dialog.text_edit.text, "Gemelo")
	dialog.text_edit.text = "Gemelo Dos"
	dialog.accept_button.pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "text_answered", ["Gemelo Dos"])
	dialog.ask_text("Otro nombre", "Gemelo")
	dialog.cancel_button.pressed.emit()
	assert_signal_emitted_with_parameters(dialog, "text_answered", [""])
