extends GutTest

var menu: TrainerMenu


func before_each() -> void:
	menu = TrainerMenu.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	menu.theme = theme
	add_child_autofree(menu)


func test_lists_the_options_it_is_given() -> void:
	menu.show_for(["choose_upgrade", "reset_attributes", "arena_level"])
	assert_true(menu.visible)
	assert_eq(menu.option_ids(), ["choose_upgrade", "reset_attributes", "arena_level"])
	assert_eq(menu.option_text("reset_attributes"), tr("TRAINER_RESET_ATTRIBUTES"))


func test_pressing_an_option_emits_it() -> void:
	menu.show_for(["reset_talents", "reset_upgrade"])
	watch_signals(menu)
	menu.press("reset_upgrade")
	assert_signal_emitted_with_parameters(menu, "chosen", ["reset_upgrade"])
	menu.press("nope")
	assert_signal_emit_count(menu, "chosen", 1)


func test_arena_selector_steps_and_clamps() -> void:
	menu.show_arena_selector(12)
	assert_true(menu.visible)
	assert_eq(menu.arena_value(), 12)
	menu.arena_step(1)
	assert_eq(menu.arena_value(), 13)
	menu.arena_step(-20)
	assert_eq(menu.arena_value(), 1)
	menu.arena_step(500)
	assert_eq(menu.arena_value(), 60)
	menu.show_arena_selector(999)
	assert_eq(menu.arena_value(), 60)


func test_arena_selector_confirms() -> void:
	menu.show_arena_selector(5)
	menu.arena_step(3)
	watch_signals(menu)
	menu.confirm_arena()
	assert_signal_emitted_with_parameters(menu, "arena_level_confirmed", [8])
	assert_false(menu.visible)


func test_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	menu.show_for(["choose_upgrade", "reset_attributes", "reset_talents", "reset_upgrade", "arena_level"])
	await wait_process_frames(2)
	var r := menu.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "menu %s" % r)
	assert_gt(r.size.x, 200.0, "laid out")
	menu.show_arena_selector(30)
	await wait_process_frames(2)
	assert_true(Rect2(0, 0, 1280, 720).encloses(menu.panel_rect()), "selector %s" % menu.panel_rect())


func test_every_text_key_is_translated() -> void:
	for key: String in ["TRAINER_TITLE", "TRAINER_PROMPT", "TRAINER_CHOOSE_CLASS", "TRAINER_CHOOSE_UPGRADE", "TRAINER_RESET_ATTRIBUTES",
			"TRAINER_RESET_TALENTS", "TRAINER_RESET_UPGRADE", "TRAINER_ARENA_LEVEL", "CONFIRM_RESET_ATTRIBUTES",
			"CONFIRM_RESET_TALENTS", "CONFIRM_RESET_UPGRADE", "ARENA_TITLE", "ARENA_DESC", "ARENA_CONFIRM", "ARENA_LEVEL_SET"]:
		assert_ne(tr(key), key, key)
