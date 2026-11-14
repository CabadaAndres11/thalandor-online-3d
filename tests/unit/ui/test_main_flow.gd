extends GutTest

const SETTINGS := "user://test_main_settings.json"

var main: Main


func before_each() -> void:
	main = Main.new()
	main.settings_path = SETTINGS
	add_child_autofree(main)


func after_each() -> void:
	Input.action_release("move_up")
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func _own_pos() -> Vector3:
	return main.game.client.render_state(main.game.client.my_id).get("position", Vector3.INF)


func test_play_starts_solo_game() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(5)
	assert_true(main.in_game())
	assert_false(main.title.visible)
	assert_eq(main.game.client.status, ClientSession.Status.IN_GAME)
	await wait_until(func() -> bool: return main.game.avatar_count() == 1, 3.0)
	assert_eq(main.game.avatar_count(), 1)


func test_typing_blocks_movement() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(5)
	main.chat.open_input()
	assert_true(main.game.input_blocked)
	var before := _own_pos()
	Input.action_press("move_up")
	await wait_physics_frames(10)
	assert_almost_eq(_own_pos().distance_to(before), 0.0, 0.0001, "no movement while typing")
	main.chat.submit("")
	assert_false(main.game.input_blocked)
	await wait_physics_frames(10)
	assert_gt(_own_pos().distance_to(before), 0.5, "moves again after closing the chat")


func test_bad_code_shows_error_without_connecting() -> void:
	main._on_join("Prueba", "OOOO-0000")
	assert_false(main.in_game())
	assert_true(main.dialog.visible)
	assert_eq(main.dialog.message(), tr("ERR_BAD_CODE"))


func test_version_rejection_shows_both_versions() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(2)
	main._on_rejected("version", "9.9.9")
	assert_false(main.in_game())
	assert_true(main.dialog.message().contains("9.9.9"))
	assert_true(main.dialog.message().contains(GameSession.game_version()))


func test_code_is_remembered() -> void:
	main._on_join("Andrés", "OOOO-0000")
	var saved := SettingsStore.load_from(SETTINGS)
	assert_eq(saved.last_code, "OOOO-0000")


func test_leave_returns_to_title() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(3)
	main._leave_to_title()
	assert_false(main.in_game())
	assert_true(main.title.visible)
	assert_false(main.chat.visible)
