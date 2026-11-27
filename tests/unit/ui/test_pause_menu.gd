extends GutTest
## The pause menu (Esc): joining a friend's group from the game (Plan 8.1.1).


func test_pause_join_disabled_empty_or_locked() -> void:
	var m := PauseMenu.new()
	add_child_autofree(m)
	assert_true(m.join_button.disabled, "no code")
	m.join_code_edit.text = "abcd-efgh"
	m.join_code_edit.text_changed.emit("abcd-efgh")
	assert_false(m.join_button.disabled)
	m.set_group_locked(true)
	assert_true(m.join_button.disabled, "before the tutorial")
	m.set_group_locked(false)
	assert_false(m.join_button.disabled)
	m.show_code("WXYZ-1234")
	assert_true(m.join_button.disabled, "own group open")
	watch_signals(m)
	m.reset()
	m.join_code_edit.text = " abcd-efgh "
	m.join_code_edit.text_changed.emit(" abcd-efgh ")
	m.join_button.pressed.emit()
	assert_signal_emitted_with_parameters(m, "join_requested", ["abcd-efgh"])


## 2026-11-27: in an online group, "Abandonar grupo" goes back to playing alone.
func test_leave_group_only_in_a_group() -> void:
	var m := PauseMenu.new()
	add_child_autofree(m)
	m.set_can_open_group(true) # a solo host
	assert_false(m.leave_group_button.visible)
	m.set_can_open_group(false) # a guest in someone's group
	assert_true(m.leave_group_button.visible)
	watch_signals(m)
	m.leave_group_button.pressed.emit()
	assert_signal_emitted(m, "leave_group_requested")
	m.set_can_open_group(true)
	m.show_code("WXYZ-1234") # a host whose group is open
	assert_true(m.leave_group_button.visible)
	m.reset()
	assert_false(m.leave_group_button.visible)
