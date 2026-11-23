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
