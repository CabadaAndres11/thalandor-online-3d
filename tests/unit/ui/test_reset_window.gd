extends GutTest
## The trainer's window (Plan 8.3b): the price in sight, and buttons off with the reason.

var w: ResetWindow
var b: Balance


func before_each() -> void:
	w = ResetWindow.new()
	add_child_autofree(w)
	b = Balance.load_from()


func _progress(level: int, spent_attrs: bool, talents: bool) -> PlayerProgress:
	var pr := PlayerProgress.new()
	pr.level = level
	if spent_attrs:
		pr.attributes["strength"] = 1
	if talents:
		pr.talents.append("might_1")
	return pr


func test_reset_window_states() -> void:
	w.show_for(_progress(10, true, true), 500, b)
	assert_true(w.visible)
	assert_false(w.attributes_button.disabled)
	assert_false(w.talents_button.disabled)
	assert_string_contains(w.attributes_button.text, "200")
	w.show_for(_progress(10, true, true), 50, b)
	assert_true(w.attributes_button.disabled, "no gold")
	assert_true(w.talents_button.disabled)
	assert_eq(w.reason(), tr("UI_RESET_NO_GOLD"))
	w.show_for(_progress(10, false, true), 500, b)
	assert_true(w.attributes_button.disabled, "nothing spent")
	assert_false(w.talents_button.disabled)


func test_pressing_asks_and_closes() -> void:
	watch_signals(w)
	w.show_for(_progress(10, true, true), 500, b)
	w.talents_button.pressed.emit()
	assert_signal_emitted_with_parameters(w, "reset_requested", ["talents"])
	assert_false(w.visible)
