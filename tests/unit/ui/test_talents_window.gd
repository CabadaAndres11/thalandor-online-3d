extends GutTest

var win: TalentsWindow
var balance: Balance
var db: TalentDB


func before_each() -> void:
	balance = Balance.load_from()
	db = TalentDB.load_default()
	win = TalentsWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	win.theme = theme
	add_child_autofree(win)


func _show(level: int, talents := [], upgrade := "", masteries := {}) -> PlayerProgress:
	var pr := PlayerProgress.from_dict({"level": level, "talents": talents, "upgrade": upgrade, "masteries": masteries})
	win.show_for(pr, db, balance)
	return pr


func test_node_states() -> void:
	_show(10, ["might_1"])
	assert_eq(win.node_state("might_1"), "owned")
	assert_eq(win.node_state("might_2"), "available")
	assert_eq(win.node_state("celerity_1"), "available", "the start touches every spoke")
	assert_eq(win.node_state("might_3"), "locked")
	assert_eq(win.node_state("might_5"), "ring_locked", "the outer ring needs an upgrade")
	_show(10, ["might_1"], "berserker")
	assert_eq(win.node_state("might_5"), "locked", "with an upgrade it is only a matter of reaching it")


func test_select_shows_the_node_description() -> void:
	_show(10)
	win.select("bastion_1")
	assert_string_contains(win.description_text(), StatText.describe({"stat": "armor_pct", "value": 0.04}))
	assert_string_contains(win.description_text(), tr("TALENT_STATE_AVAILABLE"))
	win.select("bastion_2")
	assert_string_contains(win.description_text(), StatText.describe({"stat": "max_hp_pct", "value": 0.03}))
	assert_string_contains(win.description_text(), tr("TALENT_STATE_LOCKED"))
	win.select("bastion_5")
	assert_string_contains(win.description_text(), tr("TALENT_STATE_RING_LOCKED"))
	win.select("bastion_1")
	win.select("nonsense")
	assert_eq(win.selected(), "bastion_1", "an unknown node changes nothing")


func test_buy_button_follows_state_and_points() -> void:
	_show(2)
	win.select("might_1")
	assert_true(win.buy_enabled())
	watch_signals(win)
	win.press_buy()
	assert_signal_emitted_with_parameters(win, "talent_bought", ["might_1"])
	win.select("might_2")
	_show(2, ["might_1"])
	win.select("might_2")
	assert_false(win.buy_enabled(), "no points left")
	_show(10, ["might_1"])
	win.select("might_3")
	assert_false(win.buy_enabled(), "not linked yet")
	win.select("might_1")
	assert_false(win.buy_enabled(), "already owned")


func test_points_label() -> void:
	_show(6, ["might_1", "might_2"])
	assert_eq(win.points_text(), tr("TALENTS_POINTS") % 3)


func test_masteries_appear_when_a_direction_is_complete() -> void:
	_show(10)
	assert_false(win.masteries_visible())
	_show(10, ["might_1", "might_2", "might_3", "might_4", "might_key"])
	assert_true(win.masteries_visible())
	assert_true(win.mastery_enabled("might"))
	assert_false(win.mastery_enabled("celerity"))
	watch_signals(win)
	win.press_mastery("might")
	assert_signal_emitted_with_parameters(win, "mastery_bought", ["might"])
	_show(10, [], "", {"might": 3})
	assert_true(win.masteries_visible(), "ranks already bought stay visible")


func test_window_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	_show(60, ["might_1", "might_2", "might_3", "might_4", "might_key"], "berserker", {"might": 5})
	win.select("might_3")
	await wait_process_frames(2)
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "panel %s" % r)
	assert_gt(r.size.x, 600.0, "laid out")


func test_clicking_the_canvas_selects_the_nearest_node() -> void:
	_show(10)
	var at := win.node_screen_position("might_2")
	win.click_at(at + Vector2(2, 2))
	assert_eq(win.selected(), "might_2")


func test_every_text_key_is_translated() -> void:
	for key: String in ["TALENTS_TITLE", "TALENTS_POINTS", "TALENTS_HINT", "TALENT_BUY", "TALENT_NONE",
			"TALENT_DIR_MIGHT", "TALENT_DIR_CELERITY", "TALENT_DIR_VITALITY", "TALENT_DIR_BASTION", "TALENT_DIR_ARCANE",
			"TALENT_KIND_START", "TALENT_KIND_MINOR", "TALENT_KIND_NOTABLE", "TALENT_KIND_KEYSTONE", "TALENT_RING_OUTER",
			"TALENT_STATE_OWNED", "TALENT_STATE_AVAILABLE", "TALENT_STATE_LOCKED", "TALENT_STATE_RING_LOCKED",
			"MASTERIES_TITLE", "MASTERIES_HINT", "MASTERY_RANK", "MASTERY_BUY"]:
		assert_ne(tr(key), key, key)
