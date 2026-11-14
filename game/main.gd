class_name Main
extends Node
## Application root: switches between the title screen and a running game, and wires
## the HUD (chat, pause menu, dialogs, debug overlay) to the network sessions.

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
var game: GameSession
var title: TitleScreen
var chat: ChatBox
var pause_menu: PauseMenu
var dialog: MessageDialog
var debug_overlay: DebugOverlay
var status_label: Label

var _ui: CanvasLayer


func _ready() -> void:
	InputSetup.ensure_actions()
	settings = SettingsStore.load_from(settings_path)
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var theme := Theme.new()
	theme.default_font_size = 20

	title = TitleScreen.new()
	title.theme = theme
	title.play_requested.connect(_on_play)
	title.join_requested.connect(_on_join)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	_ui.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.set_defaults(settings.player_name, settings.last_code)

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

	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.resume_requested.connect(func() -> void: pause_menu.visible = false)
	pause_menu.leave_requested.connect(_leave_to_title)
	pause_menu.open_group_requested.connect(_on_open_group)
	_ui.add_child(pause_menu)

	dialog = MessageDialog.new()
	dialog.theme = theme
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dialog)


func _unhandled_input(event: InputEvent) -> void:
	if game == null or chat.is_typing() or dialog.visible:
		return
	if event.is_action_pressed("menu"):
		pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()


func in_game() -> bool:
	return game != null


func _on_play(player_name: String) -> void:
	_remember(player_name, settings.last_code)
	_start_game()
	game.start_host(player_name)
	_attach_client()


func _on_join(player_name: String, code: String) -> void:
	_remember(player_name, code)
	if GroupCode.decode(code) == "":
		dialog.show_message(tr("ERR_BAD_CODE"))
		return
	_start_game()
	if game.join(code, player_name) != OK:
		var key := game.last_error
		_leave_to_title()
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
	settings.last_code = code
	settings.save_to(settings_path)
	pause_menu.show_code(code)


func _on_group_failed(error_key: String) -> void:
	pause_menu.cancel_opening()
	dialog.show_message(tr(error_key))


func _on_chat_submitted(text: String) -> void:
	if game != null and game.client != null:
		game.client.send_chat(text)


func _on_typing_changed(is_typing: bool) -> void:
	if game != null:
		game.input_blocked = is_typing


func _start_game() -> void:
	game = GameSession.new()
	game.name = "Game"
	add_child(game)
	game.session_ended.connect(_on_session_ended)
	game.group_opened.connect(_on_group_opened)
	game.group_failed.connect(_on_group_failed)
	title.visible = false
	chat.visible = true
	pause_menu.reset()


func _attach_client() -> void:
	var client := game.client
	client.welcomed.connect(func(_id: int) -> void: status_label.visible = false)
	client.rejected.connect(_on_rejected)
	client.chat_received.connect(chat.add_message)
	debug_overlay.client = client
	debug_overlay.net_label = game.net_label()
	pause_menu.set_can_open_group(game.is_hosting())


func _on_rejected(reason: String, host_version: String) -> void:
	var text := tr(ERROR_KEYS.get(reason, "ERR_CONNECT"))
	if reason == "version":
		text = text % [host_version, GameSession.game_version()]
	_leave_to_title()
	dialog.show_message(text)


func _on_session_ended(reason: String) -> void:
	_leave_to_title()
	dialog.show_message(tr(ERROR_KEYS.get(reason, "ERR_CONNECT")))


func _leave_to_title() -> void:
	if game != null:
		game.leave()
		game.queue_free()
		game = null
	debug_overlay.client = null
	chat.cancel()
	chat.visible = false
	status_label.visible = false
	pause_menu.reset()
	title.visible = true
	title.set_defaults(settings.player_name, settings.last_code)


func _remember(player_name: String, code: String) -> void:
	settings.player_name = player_name
	settings.last_code = code
	settings.save_to(settings_path)
