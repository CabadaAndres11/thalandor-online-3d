extends GutTest

var win: CharacterWindow
var balance: Balance


func before_each() -> void:
	balance = Balance.load_from()
	win = CharacterWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	win.theme = theme
	add_child_autofree(win)


func _show(level: int, spent := {}) -> PlayerProgress:
	var pr := PlayerProgress.from_dict({"level": level, "xp": 30, "attributes": spent})
	win.show_for("Ana", "warrior", pr, Progression.preview_stats("warrior", pr, balance), balance)
	return pr


func test_free_points_and_plus_buttons() -> void:
	_show(5)
	assert_eq(win.free_points(), 20)
	watch_signals(win)
	win.press_plus("strength")
	assert_signal_emitted_with_parameters(win, "attribute_spent", ["strength"])
	for a: String in PlayerProgress.ATTRIBUTES:
		assert_true(win.plus_enabled(a), a)


func test_no_free_points_disables_the_plus_buttons() -> void:
	_show(2, {"strength": 5})
	assert_eq(win.free_points(), 0)
	watch_signals(win)
	for a: String in PlayerProgress.ATTRIBUTES:
		assert_false(win.plus_enabled(a), a)
	win.press_plus("strength")
	assert_signal_not_emitted(win, "attribute_spent")


func test_shows_class_level_and_the_total_of_each_attribute() -> void:
	_show(11, {"strength": 4})
	assert_eq(win.level_text(), tr("CHAR_LEVEL") % 11)
	assert_eq(win.attribute_value("strength"), 4 + 20, "spent plus 2 automatic points per level")
	assert_eq(win.attribute_value("stamina"), 20)
	assert_eq(win.attribute_value("intellect"), 20)


func test_stat_rows_show_the_computed_stats() -> void:
	_show(1)
	var rows := win.stat_rows()
	assert_gt(rows.size(), 8)
	var hp: Array = rows.filter(func(r: Array) -> bool: return r[0] == tr("STAT_ROW_HP"))[0]
	assert_eq(hp[1], "200")
	var armor: Array = rows.filter(func(r: Array) -> bool: return r[0] == tr("STAT_ROW_ARMOR"))[0]
	assert_eq(armor[1], "40")


func test_stats_follow_the_progress() -> void:
	_show(5, {"stamina": 20})
	var hp: Array = win.stat_rows().filter(func(r: Array) -> bool: return r[0] == tr("STAT_ROW_HP"))[0]
	assert_eq(hp[1], str(200 + 10 * (20 + 8)))


func test_window_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	_show(60, {"strength": 100, "agility": 100, "intellect": 100, "stamina": 100, "spirit": 100})
	await wait_process_frames(2)
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "panel %s" % r)
	assert_gt(r.size.x, 400.0, "laid out")


func test_every_text_key_is_translated() -> void:
	for key: String in ["CHAR_TITLE", "CHAR_LEVEL", "CHAR_XP", "CHAR_FREE_POINTS", "CHAR_ATTRIBUTES", "CHAR_STATS", "CHAR_HINT",
			"ATTR_STRENGTH", "ATTR_AGILITY", "ATTR_INTELLECT", "ATTR_STAMINA", "ATTR_SPIRIT",
			"ATTR_STRENGTH_DESC", "ATTR_AGILITY_DESC", "ATTR_INTELLECT_DESC", "ATTR_STAMINA_DESC", "ATTR_SPIRIT_DESC",
			"STAT_ROW_HP", "STAT_ROW_RESOURCE", "STAT_ROW_ATTACK", "STAT_ROW_SPELL", "STAT_ROW_ARMOR", "STAT_ROW_CRIT",
			"STAT_ROW_CRIT_DAMAGE", "STAT_ROW_DODGE", "STAT_ROW_BLOCK", "STAT_ROW_SPEED", "STAT_ROW_COOLDOWN",
			"STAT_ROW_LIFESTEAL", "STAT_ROW_REGEN", "CHAR_RECOMMENDED", "EQUIP_EMPTY", "EQUIP_HEAD", "EQUIP_CHEST",
			"EQUIP_HANDS", "EQUIP_FEET", "EQUIP_MAIN", "EQUIP_OFFHAND", "EQUIP_RING_1", "EQUIP_RING_2", "EQUIP_NECK",
			"EQUIP_SHOULDERS", "EQUIP_LEGS"]:
		assert_ne(tr(key), key, key)


func test_stat_text_covers_every_modifier_stat() -> void:
	for stat: String in Progression.FLAT.keys() + Progression.PERCENT.keys():
		assert_ne(tr(StatText.key_of(stat)), StatText.key_of(stat), stat)
	assert_eq(StatText.describe({"stat": "attack_power_pct", "value": 0.03}), "+3 % poder de ataque")
	assert_eq(StatText.describe({"stat": "damage_taken_pct", "value": -0.02}), "-2 % daño recibido")
	assert_eq(StatText.describe({"stat": "armor_add", "value": 15}), "+15 armadura")
	assert_eq(StatText.describe({"stat": "hp_regen_add", "value": 0.6}), "+0.6 vida por segundo")
	assert_eq(StatText.describe({"stat": "crit_add", "value": 0.01}), "+1 % crítico")


func test_eleven_slots() -> void:
	_show(1)
	assert_true(win.has_model())
	assert_eq(win.slot_ids().size(), 11)
	for id: String in Inventory.SLOTS:
		assert_has(win.slot_ids(), id)


func test_slots_show_the_equipment_and_unequip_on_right_click() -> void:
	var pr := PlayerProgress.from_dict({"level": 3})
	var inv := Inventory.starter("warrior", ItemDB.load_default())
	win.show_for("Ana", "warrior", pr, Progression.preview_stats("warrior", pr, balance, inv), balance, {}, inv)
	assert_eq(win.slot_item("main").base_id, "sword_t1")
	assert_null(win.slot_item("head"))
	watch_signals(win)
	win.right_click_slot("main")
	assert_signal_emitted_with_parameters(win, "unequip_requested", ["main"])
	win.right_click_slot("head")
	assert_signal_emit_count(win, "unequip_requested", 1, "an empty slot does nothing")


func test_main_attributes_of_the_class_are_in_gold() -> void:
	_show(1)
	assert_eq(win.recommended_attributes(), ["strength", "stamina"])
	assert_eq(win.attribute_color("strength"), HoloTheme.ACCENT)
	assert_eq(win.attribute_color("stamina"), HoloTheme.ACCENT)
	assert_eq(win.attribute_color("spirit"), HoloTheme.TEXT)
	var pr := PlayerProgress.new()
	win.show_for("Bea", "mage", pr, Progression.preview_stats("mage", pr, balance), balance)
	assert_eq(win.attribute_color("strength"), HoloTheme.TEXT)
	assert_eq(win.attribute_color("intellect"), HoloTheme.ACCENT)


func test_the_model_stays_fixed() -> void:
	_show(1)
	assert_false(win.model_turns())


func test_the_panel_has_a_moving_glow_that_ignores_the_mouse() -> void:
	var shine := win.find_child("Shine", true, false) as ColorRect
	assert_not_null(shine)
	assert_eq(shine.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(shine.material is ShaderMaterial)


func test_the_holo_theme_brings_its_font() -> void:
	var theme := Theme.new()
	HoloTheme.apply(theme)
	assert_not_null(theme.default_font)


## 2026-11-27: the eye shows whether the helmet is drawn and asks to toggle it.
func test_eye_toggles_the_helmet() -> void:
	var inv := Inventory.new()
	inv.equipment["head"] = ItemRoll.new_item("warrior_head_t1", 1)
	var pr := PlayerProgress.from_dict({"level": 5})
	win.show_for("Ana", "warrior", pr, Progression.preview_stats("warrior", pr, balance), balance, {}, inv)
	assert_false(win.head_hidden())
	watch_signals(win)
	win.press_eye()
	assert_signal_emitted(win, "head_visibility_toggled")
	inv.hide_head = true # the host answers
	win.show_for("Ana", "warrior", pr, Progression.preview_stats("warrior", pr, balance), balance, {}, inv)
	assert_true(win.head_hidden())
	assert_true(win.eye_button.tooltip_text != "")
