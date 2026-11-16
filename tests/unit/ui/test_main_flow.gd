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
	main._on_create_requested(char_name, appearance)
	for c in main.store.load_all():
		if c.name == char_name:
			if class_id != c.class_id: # tests of classed characters: as if trained by Brann
				c.class_id = class_id
				c.bar = AbilityDB.load_default().default_bar(class_id)
				main.store.save(c)
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
	main._on_create_requested("lyra", {})
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


func test_combat_hud_in_game_only() -> void:
	assert_false(main.combat_hud.visible, "no HUD on the title screen")
	main._on_play("Prueba", "archer")
	await wait_until(func() -> bool: return main.combat_hud.hp_text() != "", 3.0)
	assert_true(main.combat_hud.visible)
	assert_eq(main.combat_hud.slot_ability(0), "archer_shot")
	assert_string_contains(main.combat_hud.hp_text(), "150")
	main._leave_game()
	assert_false(main.combat_hud.visible)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	main._unhandled_input(ev)


func test_k_toggles_abilities_window_in_game_only() -> void:
	_press("abilities_window")
	assert_false(main.abilities_window.visible, "no window outside the game")
	main._on_play("Prueba", "mage")
	await wait_physics_frames(3)
	_press("abilities_window")
	assert_true(main.abilities_window.visible)
	assert_eq(main.abilities_window.bar(), main.game.client.bar)
	main._process(0.0)
	assert_true(main.game.input_blocked, "no attacks while clicking the window")
	_press("menu")
	assert_false(main.abilities_window.visible, "Esc closes the window first")
	assert_false(main.pause_menu.visible)
	_press("abilities_window")
	_press("abilities_window")
	assert_false(main.abilities_window.visible)


func test_bar_change_sends_set_bar_and_saves() -> void:
	main._show_create()
	var c := _create("Brann", "warrior")
	c.progress.level = 20 # the bar needs unlocked abilities
	main.store.save(c)
	main._on_select_play(c.id)
	await wait_until(func() -> bool: return main.game.client.status == ClientSession.Status.IN_GAME, 3.0)
	_press("abilities_window")
	var new_bar := ["warrior_shield_wall", "warrior_charge", "warrior_taunt", ""]
	main.abilities_window.bar_changed.emit(new_bar)
	await wait_physics_frames(5)
	assert_eq(main.game.host._players[main.game.client.my_id].bar, new_bar, "the host got SET_BAR")
	assert_eq(main.combat_hud.slot_ability(2), "warrior_shield_wall", "the HUD shows the new bar")
	assert_eq(main.store.load_all()[0].bar, new_bar, "saved with the character")
	main._leave_game()
	main._on_select_play(c.id)
	assert_eq(main.game.client.bar, new_bar, "the saved bar is used next time")
	await wait_until(func() -> bool: return main.game.client.status == ClientSession.Status.IN_GAME, 3.0)
	await wait_physics_frames(3)
	assert_eq(main.game.host._players[main.game.client.my_id].bar, new_bar, "and sent in HELLO")


func test_progress_is_saved_with_the_character() -> void:
	main._show_create()
	var c := _create("Brann", "warrior")
	c.progress.level = 7
	c.progress.attributes["strength"] = 3
	main.store.save(c)
	main._on_select_play(c.id)
	await wait_until(func() -> bool: return main.game.client.status == ClientSession.Status.IN_GAME, 3.0)
	assert_eq(main.game.client.progress.level, 7, "the host echoed the saved progress")
	var p: PlayerState = main.game.host.world.players[main.game.client.my_id]
	Xp.award(main.game.host.world, p, 40)
	await wait_physics_frames(3)
	main._leave_game()
	var saved := main.store.load_all()[0]
	assert_eq(saved.progress.level, 7)
	assert_gt(saved.progress.xp, 0, "the experience was written")
	assert_eq(saved.progress.attributes.strength, 3)


func test_boss_death_is_announced_in_chat() -> void:
	main._on_play("Prueba")
	await wait_physics_frames(3)
	main.game.client.combat_event.emit(["boss_down", "guard_beast"])
	var lines := main.chat.visible_lines()
	assert_string_contains(lines[lines.size() - 1], tr("CHAT_BOSS_DOWN") % tr("MON_GUARD_BEAST"))


func test_villager_learns_a_class_from_brann() -> void:
	main._on_play("Prueba")
	await wait_until(func() -> bool: return main.game.avatar_count() == 1, 3.0)
	assert_eq(main.game.client.class_id, "villager")
	assert_eq(main.game.npc_count(), 1, "Brann stands in the arena")
	_press("interact")
	assert_true(main.class_choice_window.visible, "E next to Brann opens the class window")
	assert_true(main.game.input_blocked)
	main.class_choice_window.select("mage")
	main.class_choice_window.confirm_button.pressed.emit()
	await wait_until(func() -> bool: return main.game.client.class_id == "mage", 3.0)
	assert_eq(main.game.client.class_id, "mage")
	var first := AbilityDB.load_default().kind_of("mage", "basic") # slot 0 is the basic attack
	await wait_until(func() -> bool: return main.combat_hud.slot_ability(0) == first, 3.0)
	assert_eq(main.combat_hud.slot_ability(0), first, "the HUD has the mage bar")
	await wait_physics_frames(3)
	assert_has(main.game.player_avatar(main.game.client.my_id).rig.pieces(), "weapon_staff", "the avatar is redressed")
	_press("interact")
	assert_false(main.class_choice_window.visible, "with a class, Brann only talks")


func test_esc_closes_the_class_window() -> void:
	main._on_play("Prueba")
	await wait_until(func() -> bool: return main.game.avatar_count() == 1, 3.0)
	_press("interact")
	assert_true(main.class_choice_window.visible)
	_press("menu")
	assert_false(main.class_choice_window.visible)
	assert_false(main.pause_menu.visible)


func test_class_window_closes_when_downed() -> void:
	main._on_play("Prueba")
	await wait_until(func() -> bool: return main.game.avatar_count() == 1, 3.0)
	_press("interact")
	assert_true(main.class_choice_window.visible)
	main._on_game_event(["downed", main.game.client.my_id])
	assert_false(main.class_choice_window.visible, "knocked down: the window closes")


func test_confirm_out_of_reach_says_why() -> void:
	main._on_play("Prueba")
	await wait_until(func() -> bool: return main.game.avatar_count() == 1, 3.0)
	_press("interact")
	main.game.map.npcs.clear() # as if pushed away from Brann
	main.class_choice_window.select("mage")
	main.class_choice_window.confirm_button.pressed.emit()
	assert_true(main.chat.has_message(tr("CLASS_CHOICE_TOO_FAR")), "the player is told why nothing happened")
