extends GutTest

const SETTINGS := "user://test_main_settings.json"
const CHARS := "user://test_main_chars"
const EXPORTS := "user://test_main_exports"

var main: Main


func before_each() -> void:
	main = Main.new()
	main.settings_path = SETTINGS
	main.characters_dir = CHARS
	main.net_mode = GameSession.NET_ENET # never reach the Internet from tests
	add_child_autofree(main)


func after_each() -> void:
	Input.action_release("move_up")
	_clear(CHARS)
	_clear(EXPORTS)
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


func test_leave_returns_to_characters() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(3)
	main._leave_game()
	assert_false(main.in_game())
	assert_true(main.select_screen.visible)
	assert_false(main.title.visible)
	assert_false(main.chat.visible)


func _clear(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for file in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(file))
	DirAccess.remove_absolute(abs)


func _create(char_name: String, class_id: String, appearance := {}) -> CharacterData:
	main._on_create_requested(char_name, class_id, appearance)
	for c in main.store.load_all():
		if c.name == char_name:
			return c
	return null


func test_title_play_opens_characters() -> void:
	main.title.play_requested.emit()
	assert_true(main.select_screen.visible)
	assert_false(main.title.visible)


func test_create_then_play_enters_game_with_that_class() -> void:
	main._show_create()
	var c := _create("Lyra", "archer", {"hair_style": "hair_bun"})
	assert_not_null(c)
	assert_true(main.select_screen.visible, "back to the list after creating")
	assert_eq(main.select_screen.selected_id(), c.id, "the new character is selected")
	main._on_select_play(c.id)
	await wait_physics_frames(5)
	assert_true(main.in_game())
	var me: Dictionary = main.game.client.roster[main.game.client.my_id]
	assert_eq(me.class_id, "archer")
	assert_eq(me.appearance.hair_style, "hair_bun")
	assert_eq(me.name, "Lyra")


func test_create_with_taken_name_shows_error() -> void:
	_create("Lyra", "archer")
	main._show_create()
	main._on_create_requested("lyra", "mage", {})
	assert_true(main.dialog.visible)
	assert_eq(main.dialog.message(), tr("ERR_NAME_TAKEN"))
	assert_true(main.create_screen.visible, "stays on the create screen")


func test_join_from_select_uses_selected_character() -> void:
	var c := _create("Viajera", "cleric")
	main._on_select_join(c.id, GroupCode.encode("127.0.0.1"))
	assert_true(main.in_game())
	assert_eq(main.game.client.class_id, "cleric")
	assert_eq(main.game.client.player_name, "Viajera")
	main._leave_game()


func test_last_character_is_preselected() -> void:
	_create("Uno", "warrior")
	var dos := _create("Dos", "mage")
	main._on_select_play(dos.id)
	await wait_physics_frames(2)
	main._leave_game()
	var again := Main.new()
	again.settings_path = SETTINGS
	again.characters_dir = CHARS
	add_child_autofree(again)
	again._show_select()
	assert_eq(again.select_screen.selected_id(), dos.id)


func test_delete_asks_confirmation() -> void:
	var c := _create("Borrable", "warrior")
	main._on_select_delete(c.id)
	assert_true(main.dialog.visible)
	assert_eq(main.store.load_all().size(), 1, "nothing deleted before answering")
	main.dialog.no_button.pressed.emit()
	assert_eq(main.store.load_all().size(), 1)
	main._on_select_delete(c.id)
	main.dialog.yes_button.pressed.emit()
	assert_eq(main.store.load_all().size(), 0)


func test_cancelled_export_does_nothing() -> void:
	var c := _create("Viajero", "warrior")
	main._on_select_export(c.id)
	main._on_file_canceled()
	assert_false(main.dialog.visible)
	main._on_file_selected(EXPORTS.path_join("x.json"))
	assert_false(FileAccess.file_exists(EXPORTS.path_join("x.json")), "a stale pick does nothing after cancelling")


func test_export_then_import_creates_a_copy_after_asking_a_name() -> void:
	var c := _create("Gemelo", "archer")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORTS))
	var path := EXPORTS.path_join("gemelo.json")
	main._on_select_export(c.id)
	main._on_file_selected(path)
	assert_true(FileAccess.file_exists(path))
	main._on_select_import()
	main._on_file_selected(path)
	assert_true(main.dialog.visible, "the name is taken: asks for another")
	main.dialog.text_edit.text = "Gemelo Dos"
	main.dialog.accept_button.pressed.emit()
	var names := main.store.load_all().map(func(x: CharacterData) -> String: return x.name)
	names.sort()
	assert_eq(names, ["Gemelo", "Gemelo Dos"])


func test_import_invalid_file_shows_error() -> void:
	main._on_select_import()
	main._on_file_selected("user://nope/none.json")
	assert_true(main.dialog.visible)
	assert_eq(main.dialog.message(), tr("ERR_IMPORT_INVALID"))


func test_damaged_files_are_reported() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARS))
	var f := FileAccess.open(CHARS.path_join("roto.json"), FileAccess.WRITE)
	f.store_string("{ roto")
	f.close()
	main._show_select()
	assert_true(main.dialog.visible)
	assert_true(main.dialog.message().contains("1"))
	assert_true(FileAccess.file_exists(CHARS.path_join("roto.json")))


func test_monsters_appear_in_solo_game() -> void:
	main._on_play("Prueba")
	await wait_until(func() -> bool: return main.game != null and main.game.monster_avatar_count() > 0, 3.0)
	assert_gt(main.game.monster_avatar_count(), 0, "the arena's monsters are drawn")
	assert_eq(main.game.monster_avatar_count(), main.game.client.monsters.size())
