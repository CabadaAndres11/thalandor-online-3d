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


func test_shows_logo() -> void:
	var title := TitleScreen.new()
	_host(title)
	assert_not_null(title.logo.texture)
	assert_eq(title.logo.texture.get_width(), 2000)


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
	var asking := MessageDialog.new()
	var r8 := _host(asking)
	asking.ask_text(TranslationServer.translate("IMPORT_NEW_NAME") % "Nombre-Largo-16c", "Nombre-Largo-16c")
	var client := ClientSession.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [1, 1], "blocks": []}),
		"0.0.0", "Nombre-Largo-16c", "assassin")
	client.my_id = 1
	client.combat[1] = {"hp": 0.0, "max_hp": 160.0, "resource": 100.0, "max_resource": 100.0,
		"life": CombatEntity.DEAD, "status_bits": 0, "combo": 5, "charge": 1.0}
	var hud := CombatHud.new()
	var r9 := _host(hud)
	hud.bind(client, client.bar, AbilityDB.load_default())
	hud.advance(0.0)
	await wait_frames(3)
	for r: Control in [r1, r2, r3, r4, r5, r6, r7, r8, r9]:
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


func test_title_has_options_button() -> void:
	var title := TitleScreen.new()
	_host(title)
	watch_signals(title)
	title.options_button.pressed.emit()
	assert_signal_emitted(title, "options_requested")


func test_pause_menu_has_options_button() -> void:
	var menu := PauseMenu.new()
	_host(menu)
	watch_signals(menu)
	menu.options_button.pressed.emit()
	assert_signal_emitted(menu, "options_requested")


# --- The final title screen (Plan 7) ------------------------------------------------

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func test_play_bottom_left() -> void:
	var title := TitleScreen.new()
	_host(title)
	await wait_frames(2)
	var c := _center(title.play_button)
	assert_lt(c.x, SCREEN.x / 2.0)
	assert_gt(c.y, SCREEN.y * 0.75)
	assert_gte(title.play_button.size.x, 260.0)


func test_icons_top_right_in_order() -> void:
	var title := TitleScreen.new()
	_host(title)
	await wait_frames(2)
	var icons := [title.options_button, title.credits_button, title.quit_button]
	for b: Button in icons:
		assert_lt(_center(b).y, 100.0, b.name)
		assert_gt(_center(b).x, SCREEN.x * 0.75, b.name)
		assert_ne(b.tooltip_text, "", b.name)
		assert_not_null(b.icon, b.name)
	assert_lt(_center(icons[0]).x, _center(icons[1]).x)
	assert_lt(_center(icons[1]).x, _center(icons[2]).x)


func test_each_icon_emits_its_signal() -> void:
	var title := TitleScreen.new()
	_host(title)
	watch_signals(title)
	title.options_button.pressed.emit()
	title.credits_button.pressed.emit()
	title.quit_button.pressed.emit()
	assert_signal_emitted(title, "options_requested")
	assert_signal_emitted(title, "credits_requested")
	assert_signal_emitted(title, "quit_requested")


func test_no_opaque_background() -> void:
	var title := TitleScreen.new()
	_host(title)
	var opaque := title.find_children("*", "ColorRect", true, false).filter(func(r: ColorRect) -> bool:
		return r.color.a > 0.9 and r.anchor_right == 1.0 and r.anchor_bottom == 1.0)
	assert_eq(opaque.size(), 0, "the altar scene shows through")


func test_credits_window_lists_the_licences_and_closes() -> void:
	var w := CreditsWindow.new()
	_host(w)
	watch_signals(w)
	assert_true(w.body.text.contains("Godot"))
	assert_true(w.body.text.contains("Teko"))
	w.close_button.pressed.emit()
	assert_signal_emitted(w, "close_requested")
