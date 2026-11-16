class_name Main
extends Node
## Application root: title → "Tus personajes" (create, delete, export, import, play,
## join) → a running game; wires the HUD (chat, pause menu, dialogs, debug overlay)
## to the network sessions.

const ERROR_KEYS := {
	"version": "ERR_VERSION",
	"full": "ERR_FULL",
	"name": "ERR_NAME",
	"host_left": "ERR_HOST_LEFT",
	"timeout": "ERR_TIMEOUT",
	"failed": "ERR_CONNECT",
}

var settings: SettingsStore
var settings_path: String = SettingsStore.DEFAULT_PATH
var characters_dir: String = CharacterStore.DEFAULT_DIR
## Network for new games ("" = GameSession's default / command line). Tests use ENet
## so they never reach the Internet.
var net_mode: String = ""
var store: CharacterStore
var game: GameSession
var title: TitleScreen
var select_screen: CharacterSelectScreen
var create_screen: CharacterCreateScreen
var chat: ChatBox
var combat_hud: CombatHud
var party_frames: PartyFrames
var downed_overlay: DownedOverlay
var pause_menu: PauseMenu
var abilities_window: AbilitiesWindow
var class_choice_window: ClassChoiceWindow
var abilities: AbilityDB
var dialog: MessageDialog
var debug_overlay: DebugOverlay
var status_label: Label

var _ui: CanvasLayer
var _file_dialog: FileDialog
## What the open dialog / file picker is for: {"action": "delete"|"export"|"import"|
## "import_rename", "id", "path"}; {} when nothing is pending.
var _pending: Dictionary = {}
## The saved character being played (null in games started without one).
var _playing: CharacterData = null


func _ready() -> void:
	InputSetup.ensure_actions()
	settings = SettingsStore.load_from(settings_path)
	store = CharacterStore.new(characters_dir)
	abilities = AbilityDB.load_default()
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var theme := Theme.new()
	theme.default_font_size = 20

	title = TitleScreen.new()
	title.theme = theme
	title.play_requested.connect(_show_select)
	title.quit_requested.connect(_quit)
	_add_screen(title)

	select_screen = CharacterSelectScreen.new()
	select_screen.theme = theme
	select_screen.play_requested.connect(_on_select_play)
	select_screen.join_requested.connect(_on_select_join)
	select_screen.create_requested.connect(_show_create)
	select_screen.delete_requested.connect(_on_select_delete)
	select_screen.export_requested.connect(_on_select_export)
	select_screen.import_requested.connect(_on_select_import)
	select_screen.back_requested.connect(_show_title)
	_add_screen(select_screen)

	create_screen = CharacterCreateScreen.new()
	create_screen.theme = theme
	create_screen.create_requested.connect(_on_create_requested)
	create_screen.back_requested.connect(_show_select)
	_add_screen(create_screen)

	combat_hud = CombatHud.new()
	combat_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_hud.visible = false
	_ui.add_child(combat_hud)

	party_frames = PartyFrames.new()
	party_frames.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_frames.visible = false
	_ui.add_child(party_frames)

	downed_overlay = DownedOverlay.new()
	downed_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	downed_overlay.visible = false
	_ui.add_child(downed_overlay)

	chat = ChatBox.new()
	chat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat.visible = false
	chat.message_submitted.connect(_on_chat_submitted)
	chat.typing_changed.connect(_on_typing_changed)
	_ui.add_child(chat)

	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.position.y = 24
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.visible = false
	_ui.add_child(status_label)

	debug_overlay = DebugOverlay.new()
	_ui.add_child(debug_overlay)

	abilities_window = AbilitiesWindow.new()
	abilities_window.theme = theme
	abilities_window.bar_changed.connect(_on_bar_changed)
	_ui.add_child(abilities_window)

	class_choice_window = ClassChoiceWindow.new()
	class_choice_window.theme = theme
	class_choice_window.class_confirmed.connect(_on_class_confirmed)
	class_choice_window.visibility_changed.connect(_update_input_block)
	_ui.add_child(class_choice_window)

	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.leave_requested.connect(_leave_game)
	pause_menu.open_group_requested.connect(_on_open_group)
	_ui.add_child(pause_menu)

	dialog = MessageDialog.new()
	dialog.theme = theme
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.answered.connect(_on_dialog_answered)
	dialog.text_answered.connect(_on_dialog_text)
	_ui.add_child(dialog)

	_file_dialog = FileDialog.new()
	_file_dialog.use_native_dialog = true
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json"])
	_file_dialog.file_selected.connect(_on_file_selected)
	_file_dialog.canceled.connect(_on_file_canceled)
	add_child(_file_dialog)
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or chat.is_typing() or dialog.visible:
		return
	if event.is_action_pressed("menu"):
		if class_choice_window.visible:
			class_choice_window.visible = false
		elif abilities_window.visible:
			abilities_window.visible = false
		else:
			pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not pause_menu.visible and not abilities_window.visible \
			and not class_choice_window.visible and game.client != null:
		_on_interact() # no set_input_as_handled: holding E also revives
	elif event.is_action_pressed("abilities_window") and not pause_menu.visible and not class_choice_window.visible:
		if abilities_window.visible:
			abilities_window.visible = false
		else:
			abilities_window.show_for(game.client.class_id, game.client.bar, abilities)
		get_viewport().set_input_as_handled()


## E next to an NPC: a villager by Brann chooses a class; anyone else hears him.
func _on_interact() -> void:
	var r := game.interaction()
	match str(r.action):
		NpcInteraction.CHOOSE_CLASS:
			class_choice_window.show_for(game.client.appearance)
		NpcInteraction.TALK:
			var npc := NpcDB.load_default().npc(str(r.npc))
			var line := str((npc.get("lines", {}) as Dictionary).get("has_class", ""))
			chat.add_message(tr(str(npc.get("name", ""))), tr(line), false)


func _on_class_confirmed(class_id: String) -> void:
	if game != null and game.client != null:
		game.client.choose_class(class_id)


## The host agreed: this player now has a class. The HUD gets its bar and the saved
## character remembers both.
func _on_class_changed(id: int, class_id: String) -> void:
	if game == null or game.client == null or id != game.client.my_id:
		return
	abilities_window.visible = false
	combat_hud.bind(game.client, game.client.bar, abilities)
	if _playing != null:
		_playing.class_id = class_id
		_playing.bar = game.client.bar.duplicate()
		if store.save(_playing) != OK:
			dialog.show_message(tr(store.last_error))


func in_game() -> bool:
	return game != null


# --- Screens -----------------------------------------------------------------------

func _add_screen(screen: Control) -> void:
	_ui.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_only(screen: Control) -> void:
	for s: Control in [title, select_screen, create_screen]:
		s.visible = s == screen


func _show_title() -> void:
	_show_only(title)


func _show_select() -> void:
	var list := store.load_all()
	select_screen.set_characters(list, settings.last_character_id)
	select_screen.set_code(settings.last_code)
	_show_only(select_screen)
	if not store.skipped_files.is_empty():
		dialog.show_message(tr("ERR_CHAR_SKIPPED") % store.skipped_files.size())


func _show_create() -> void:
	# The name typed in 0.1.x is suggested for the first character.
	create_screen.reset(settings.player_name if store.load_all().is_empty() else "")
	_show_only(create_screen)


func _on_create_requested(char_name: String, appearance: Dictionary) -> void:
	var c := store.create(char_name, CharacterCatalog.DEFAULT_CLASS, appearance)
	if c == null:
		dialog.show_message(tr(store.last_error))
		return
	_remember_character(c.id)
	_show_select()


func _find(id: String) -> CharacterData:
	for c in store.load_all():
		if c.id == id:
			return c
	return null


func _remember_character(id: String) -> void:
	settings.last_character_id = id
	settings.save_to(settings_path)


func _on_select_play(id: String) -> void:
	var c := _find(id)
	if c != null:
		_remember_character(id)
		_playing = c
		_on_play(c.name, c.class_id, c.appearance)


func _on_select_join(id: String, code: String) -> void:
	var c := _find(id)
	if c != null:
		_remember_character(id)
		_playing = c
		_on_join(c.name, code, c.class_id, c.appearance)


func _on_select_delete(id: String) -> void:
	var c := _find(id)
	if c == null:
		return
	_pending = {"action": "delete", "id": id}
	dialog.ask(tr("CONFIRM_DELETE") % c.name)


func _on_select_export(id: String) -> void:
	var c := _find(id)
	if c == null:
		return
	_pending = {"action": "export", "id": id}
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.current_file = "%s.json" % c.name
	_file_dialog.popup_centered_ratio(0.6)


func _on_select_import() -> void:
	_pending = {"action": "import"}
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	var pending := _pending
	_pending = {}
	match pending.get("action", ""):
		"export":
			if store.export_to(pending.id, path) == OK:
				dialog.show_message(tr("EXPORT_DONE"))
			else:
				dialog.show_message(tr("ERR_EXPORT"))
		"import":
			_import(path, "")


func _on_file_canceled() -> void:
	_pending = {}


func _import(path: String, new_name: String) -> void:
	var c := store.import_from(path, new_name)
	if c != null:
		_remember_character(c.id)
		_show_select()
		return
	if store.last_error == "ERR_NAME_TAKEN":
		var original := store.peek(path)
		var shown := new_name if new_name != "" else (original.name if original != null else "")
		_pending = {"action": "import_rename", "path": path}
		dialog.ask_text(tr("IMPORT_NEW_NAME") % shown, shown)
		return
	dialog.show_message(tr(store.last_error))


func _on_dialog_answered(yes: bool) -> void:
	var pending := _pending
	_pending = {}
	if pending.get("action", "") == "delete" and yes:
		var deleted := store.delete(pending.id)
		_show_select()
		if not deleted:
			dialog.show_message(tr("ERR_DELETE"))


func _on_dialog_text(text: String) -> void:
	var pending := _pending
	_pending = {}
	if pending.get("action", "") == "import_rename" and text != "":
		_import(pending.path, text)


func _quit() -> void:
	get_tree().quit()


# --- Game --------------------------------------------------------------------------

func _on_play(player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}) -> void:
	_start_game()
	game.start_host(player_name, class_id, appearance)
	_attach_client()


func _on_join(player_name: String, code: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}) -> void:
	settings.last_code = code
	settings.save_to(settings_path)
	if GroupCode.decode(code) == "":
		dialog.show_message(tr("ERR_BAD_CODE"))
		return
	_start_game()
	if game.join(code, player_name, class_id, appearance) != OK:
		var key := game.last_error
		_leave_game()
		dialog.show_message(tr(key))
		return
	_attach_client()
	status_label.text = tr("CONNECTING")
	status_label.visible = true


func _on_open_group() -> void:
	var code := game.open_group()
	if code != "":
		_on_group_opened(code)
	elif game.last_error == "":
		pause_menu.show_opening() # WebRTC: the code arrives with group_opened
	else:
		_on_group_failed(game.last_error)


func _on_group_opened(code: String) -> void:
	pause_menu.show_code(code)


func _on_group_failed(error_key: String) -> void:
	pause_menu.cancel_opening()
	dialog.show_message(tr(error_key))


func _on_chat_submitted(text: String) -> void:
	if game != null and game.client != null:
		game.client.send_chat(text)


func _on_typing_changed(_is_typing: bool) -> void:
	_update_input_block()


## No movement or attacks while typing in the chat or with a menu or dialog open
## (a click on a menu button must not attack).
func _update_input_block() -> void:
	if game != null:
		game.input_blocked = chat.is_typing() or pause_menu.visible or dialog.visible or abilities_window.visible \
			or class_choice_window.visible


func _process(_delta: float) -> void:
	_update_input_block()


func _on_resume() -> void:
	pause_menu.visible = false


func _start_game() -> void:
	game = GameSession.new()
	game.name = "Game"
	if net_mode != "":
		game.net_mode = net_mode
	add_child(game)
	game.session_ended.connect(_on_session_ended)
	if _playing != null:
		game.character_bar = _playing.bar.duplicate()
	game.group_opened.connect(_on_group_opened)
	game.group_failed.connect(_on_group_failed)
	_show_only(null)
	chat.visible = true
	pause_menu.reset()


func _attach_client() -> void:
	var client := game.client
	client.welcomed.connect(_on_welcomed)
	client.rejected.connect(_on_rejected)
	client.chat_received.connect(chat.add_message)
	client.combat_event.connect(_on_game_event)
	client.class_changed.connect(_on_class_changed)
	debug_overlay.client = client
	debug_overlay.net_label = game.net_label()
	combat_hud.bind(client, client.bar, abilities)
	combat_hud.visible = true
	party_frames.bind(client)
	party_frames.visible = true
	downed_overlay.bind(client)
	downed_overlay.visible = true
	pause_menu.set_can_open_group(game.is_hosting())


## A new bar from the K window: the host, the HUD and the saved character get it.
func _on_bar_changed(bar: Array) -> void:
	if game == null or game.client == null:
		return
	game.client.send_bar(bar)
	combat_hud.bind(game.client, game.client.bar, abilities)
	if _playing != null:
		_playing.bar = game.client.bar.duplicate()
		if store.save(_playing) != OK:
			dialog.show_message(tr(store.last_error))


## Game-wide announcements in the chat (everyone gets the same events).
func _on_game_event(ev: Array) -> void:
	if ev.size() >= 2 and str(ev[0]) == "boss_down":
		var def := MonsterDB.load_default().get_type(str(ev[1]))
		chat.add_message("", tr("CHAT_BOSS_DOWN") % tr(str(def.get("name", ""))), true)


func _on_welcomed(_id: int) -> void:
	status_label.visible = false


func _on_rejected(reason: String, host_version: String) -> void:
	var text := tr(ERROR_KEYS.get(reason, "ERR_CONNECT"))
	if reason == "version":
		text = text % [host_version, GameSession.game_version()]
	_leave_game()
	dialog.show_message(text)


func _on_session_ended(reason: String) -> void:
	_leave_game()
	dialog.show_message(tr(ERROR_KEYS.get(reason, "ERR_CONNECT")))


## Ends the game (if any) and goes back to the character list.
func _leave_game() -> void:
	if game != null:
		game.leave()
		game.queue_free()
		game = null
	debug_overlay.client = null
	_playing = null
	abilities_window.visible = false
	class_choice_window.visible = false
	combat_hud.unbind()
	combat_hud.visible = false
	party_frames.unbind()
	party_frames.visible = false
	downed_overlay.unbind()
	downed_overlay.visible = false
	chat.cancel()
	chat.visible = false
	status_label.visible = false
	pause_menu.reset()
	_show_select()
