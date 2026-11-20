extends GutTest

const SCREEN := Vector2(1280, 720)


func _host(control: Control) -> Control:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	root.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root


func _chars(n: int) -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	for i in n:
		var c := CharacterData.new()
		c.id = "%016x" % (i + 1)
		c.name = "Personaje %d" % i
		c.class_id = "mage"
		c.appearance = CharacterCatalog.load_default().default_appearance()
		list.append(c)
	return list


func test_select_disables_buttons_without_selection() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	s.set_characters([] as Array[CharacterData], "")
	for b: Button in [s.play_button, s.join_button, s.delete_button, s.export_button]:
		assert_true(b.disabled, b.text)
	assert_false(s.create_button.disabled)
	assert_false(s.import_button.disabled)


func test_create_disabled_at_eight() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	s.set_characters(_chars(8), "")
	assert_true(s.create_button.disabled)
	assert_true(s.import_button.disabled)
	s.set_characters(_chars(7), "")
	assert_false(s.create_button.disabled)


func test_selected_character_is_played() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	var list := _chars(3)
	s.set_characters(list, list[0].id)
	assert_eq(s.selected_id(), list[0].id)
	s.slot_buttons[2].pressed.emit()
	assert_eq(s.selected_id(), list[2].id)
	watch_signals(s)
	s.play_button.pressed.emit()
	assert_signal_emitted_with_parameters(s, "play_requested", [list[2].id])


func test_unknown_selected_id_selects_first() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	var list := _chars(2)
	s.set_characters(list, "gone")
	assert_eq(s.selected_id(), list[0].id)


func test_join_emits_id_and_code() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	var list := _chars(1)
	s.set_characters(list, list[0].id)
	s.set_code("abcd-efgh")
	watch_signals(s)
	s.join_button.pressed.emit()
	assert_signal_emitted_with_parameters(s, "join_requested", [list[0].id, "abcd-efgh"])


func test_create_screen_invalid_name_disables_create() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("")
	assert_true(c.create_button.disabled)
	c.name_edit.text = "Lyra"
	c.name_edit.text_changed.emit("Lyra")
	assert_false(c.create_button.disabled)
	c.name_edit.text = "L"
	c.name_edit.text_changed.emit("L")
	assert_true(c.create_button.disabled)


func test_create_screen_prefills_name() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("Andrés")
	assert_eq(c.name_edit.text, "Andrés")
	assert_false(c.create_button.disabled)


func test_create_screen_arrows_cycle_options() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("Lyra")
	var start: String = c.current_appearance().hair_style
	var seen := {}
	for i in 8:
		c.next_option("hair_style")
		seen[c.current_appearance().hair_style] = true
	assert_eq(c.current_appearance().hair_style, start, "8 presses go round")
	assert_eq(seen.size(), 8)
	c.prev_option("hair_style")
	assert_ne(c.current_appearance().hair_style, start)


func test_random_gives_valid_appearance() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("Lyra")
	var catalog := CharacterCatalog.load_default()
	for i in 5:
		c.random_button.pressed.emit()
		assert_eq(catalog.sanitize_appearance(c.current_appearance()), c.current_appearance())


func test_create_emits_name_and_appearance() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("  Lyra  ")
	c.next_option("beard")
	watch_signals(c)
	c.create_button.pressed.emit()
	var params: Array = get_signal_parameters(c, "create_requested")
	assert_eq(params[0], "Lyra")
	assert_eq(params[1], c.current_appearance())


func test_create_screen_has_no_class_choice() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	assert_false("class_buttons" in c, "the class is chosen in the game, with Brann")
	assert_false(c.has_method("select_class"))


func test_preview_shows_character() -> void:
	var p := CharacterPreview.new()
	_host(p)
	p.show_character("mage", {"hair_style": "hair_long"})
	assert_not_null(p.rig)
	assert_has(p.rig.pieces(), "hat_mage")
	p.show_character("warrior", {})
	assert_has(p.rig.pieces(), "pauldron_left", "replaces the previous character")


func test_select_preview_wears_the_saved_gear() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	var list := _chars(1)
	list[0].class_id = "warrior"
	list[0].progress.level = 30
	list[0].inventory = Inventory.starter("warrior", ItemDB.load_default())
	list[0].inventory.equipment["main"] = ItemRoll.new_item("greatsword_t2", 30)
	list[0].inventory.equipment.erase("offhand")
	s.set_characters(list, list[0].id)
	assert_has(s.preview.rig.pieces(), "w_greatsword_t2", "the weapon in hand")
	assert_has(s.preview.rig.pieces(), "warrior_chest_t1", "the armour worn")


func test_leave_menu_says_log_out() -> void:
	assert_eq(TranslationServer.translate("MENU_LEAVE"), "Cerrar sesión")
