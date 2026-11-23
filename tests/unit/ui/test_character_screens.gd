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
	for b: Button in [s.play_button, s.delete_button, s.export_button]:
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


## Plan 8.1.1: joining a friend happens in the game (pause menu), not here.
func test_select_screen_has_no_join() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	assert_false("join_button" in s)
	assert_false(s.has_signal("join_requested"))


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
	var n := CharacterCatalog.load_default().options_for("hair_style", "human").size()
	var seen := {}
	for i in n:
		c.next_option("hair_style")
		seen[c.current_appearance().hair_style] = true
	assert_eq(c.current_appearance().hair_style, start, "a full round of the human styles")
	assert_eq(seen.size(), n)
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
	watch_signals(s)
	s.set_characters(list, list[0].id)
	var look: Dictionary = get_signal_parameters(s, "look_changed")[0]
	var ids: Array = look.pieces.map(func(p: Dictionary) -> String: return p.id)
	assert_has(ids, "w_greatsword_t2", "the weapon in hand")
	assert_has(ids, "warrior_chest_t1", "the armour worn")


func test_leave_menu_says_log_out() -> void:
	assert_eq(TranslationServer.translate("MENU_LEAVE"), "Cerrar sesión")


func test_changing_race_fixes_invalid_options() -> void:
	var c := CharacterCreateScreen.new()
	_host(c)
	c.reset("Lyra")
	c.next_option("beard") # a human beard
	assert_ne(c.current_appearance().beard, "none")
	while c.current_appearance().race != "lizard":
		c.next_option("race")
	var app := c.current_appearance()
	var catalog := CharacterCatalog.load_default()
	assert_eq(app.beard, "none")
	assert_eq(catalog.sanitize_appearance(app), app)
	assert_true(str(app.hair_style).begins_with("crest_"))


# --- Over the altar scene (Plan 7) ---------------------------------------------------

func test_select_row_shows_race() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	var list := _chars(1)
	list[0].appearance = CharacterCatalog.load_default().sanitize_appearance({"race": "elf"})
	s.set_characters(list, list[0].id)
	assert_true(s.slot_buttons[0].text.contains(tr("RACE_ELF")), s.slot_buttons[0].text)


func test_select_without_characters_shows_nobody() -> void:
	var s := CharacterSelectScreen.new()
	_host(s)
	watch_signals(s)
	s.set_characters([] as Array[CharacterData], "")
	assert_eq(get_signal_parameters(s, "look_changed")[0], {})


func test_race_row_first_with_description() -> void:
	var c := CreateScreenHelper.make(self)
	assert_eq(c.row_kinds()[0], "race")
	assert_eq(c.race_desc.text, tr("RACE_HUMAN_DESC"))
	c.next_option("race")
	assert_eq(c.race_desc.text, tr("RACE_ELF_DESC"))


func test_random_respects_race() -> void:
	var c := CreateScreenHelper.make(self)
	var catalog := CharacterCatalog.load_default()
	for i in 30:
		c.random_button.pressed.emit()
		assert_eq(catalog.sanitize_appearance(c.current_appearance()), c.current_appearance())


func test_create_emits_race() -> void:
	var c := CreateScreenHelper.make(self)
	watch_signals(c)
	while c.current_appearance().race != "dwarf":
		c.next_option("race")
	c.create_button.pressed.emit()
	assert_eq(get_signal_parameters(c, "create_requested")[1].race, "dwarf")


func test_create_emits_look_changed() -> void:
	var c := CreateScreenHelper.make(self)
	watch_signals(c)
	c.next_option("race")
	var look: Dictionary = get_signal_parameters(c, "look_changed")[0]
	assert_eq(look.race, "elf")


func test_screens_have_no_opaque_background() -> void:
	for screen: Control in [CharacterSelectScreen.new(), CharacterCreateScreen.new()]:
		_host(screen)
		var opaque := screen.find_children("*", "ColorRect", true, false).filter(func(r: ColorRect) -> bool:
			return r.color.a > 0.9 and r.anchor_right == 1.0 and r.anchor_bottom == 1.0)
		assert_eq(opaque.size(), 0)
		assert_eq(screen.find_children("*", "CharacterPreview", true, false).size(), 0, "the hero stands in the scene")


class CreateScreenHelper:
	static func make(t: GutTest) -> CharacterCreateScreen:
		var root := Control.new()
		root.size = SCREEN
		t.add_child_autofree(root)
		var c := CharacterCreateScreen.new()
		root.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.reset("Lyra")
		return c
