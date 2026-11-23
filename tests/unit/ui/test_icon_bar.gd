extends GutTest
## The icon bar in the top-right corner (Plan 8.1.1).


func before_each() -> void:
	InputSetup.ensure_actions()


func test_entries_order_and_keys() -> void:
	var bar := IconBar.new()
	add_child_autofree(bar)
	assert_eq(IconBar.ENTRIES, ["character", "inventory", "abilities", "talents", "quests", "map", "menu"])
	var keys := IconBar.ENTRIES.map(func(id: String) -> String: return bar.key_text(id))
	assert_eq(keys, ["C", "I", "K", "T", "J", "M", "Esc"])


func test_click_emits_and_marks() -> void:
	var bar := IconBar.new()
	add_child_autofree(bar)
	watch_signals(bar)
	bar.button("inventory").pressed.emit()
	assert_signal_emitted_with_parameters(bar, "pressed_entry", ["inventory"])
	bar.set_open("inventory", true)
	assert_true(bar.is_open("inventory"))
	bar.set_open("inventory", false)
	assert_false(bar.is_open("inventory"))


func test_quests_disabled() -> void:
	var bar := IconBar.new()
	add_child_autofree(bar)
	assert_true(bar.button("quests").disabled)
	assert_eq(bar.button("quests").tooltip_text, tr("QUESTS_SOON"))
