extends SceneTree
## Second game process for tests/integration/test_two_processes.gd. Boots the real main
## scene headless, joins with the group code (like "Unirse a un amigo"), walks right,
## chats, then reports what it sees as JSON in user://<out> and leaves.
## User args: --code=ABCD-EFGH --out=<file name> --name=<player> [--lag=<ms> --loss=<pct>]

const SETTINGS := "user://test_guest_settings.json"
const JOIN_TIMEOUT_S := 20.0 # the village takes longer to build since Plan 8.3d (relief, more houses)
const WALK_S := 2.0
const CHAT_TEXT := "hola desde el invitado"
## Everyone stands still this long before the report, so positions have settled.
const SETTLE_S := 3.0
## Stay connected after writing the report so the host can compare positions.
const LINGER_S := 1.0
const QUIT_DELAY_S := 0.5


class ErrorRecorder:
	extends Logger
	var errors: Array = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array:
		_mutex.lock()
		var copy := errors.duplicate()
		_mutex.unlock()
		return copy


var _recorder := ErrorRecorder.new()
var _args: Dictionary = {}
var _main: Main
var _phase: String = "booting"
var _t: float = 0.0
var _guest_start: Vector3 = Vector3.ZERO
var _chat: Array = []
var _end_reason: String = ""


func _initialize() -> void:
	OS.add_logger(_recorder)
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	_main = load("res://game/main.tscn").instantiate()
	_main.settings_path = SETTINGS
	# Main's _ready runs once the tree starts; join on the first frame, like a player.
	root.add_child(_main)


func _process(delta: float) -> bool:
	_t += delta
	match _phase:
		"booting":
			_main._on_join(str(_args.get("name", "Invitado")), str(_args.get("code", "")),
				str(_args.get("class", "archer")), {"hair_style": "hair_ponytail"})
			if _main.game == null:
				_finish("join_failed")
			else:
				_main.game.client.chat_received.connect(_on_chat)
				_main.game.client.disconnected.connect(_on_disconnected)
				_next("joining")
		"joining":
			if _main.game == null:
				_finish("disconnected")
			elif _main.game.client.status == ClientSession.Status.IN_GAME:
				var client := _main.game.client
				_guest_start = client.render_state(client.my_id).get("position", Vector3.ZERO)
				Input.action_press("move_right")
				_next("walking")
			elif _t > JOIN_TIMEOUT_S:
				_finish("join_timeout")
		"walking":
			if _main.game == null:
				_finish("disconnected")
			elif _t > WALK_S:
				Input.action_release("move_right")
				_main.game.client.send_chat(CHAT_TEXT)
				_next("settling")
		"settling":
			if _main.game == null:
				_finish("disconnected")
			elif _t > SETTLE_S:
				_finish("ok")
		"lingering":
			if _t > LINGER_S:
				if _main.game != null:
					_main._leave_game()
				_next("quitting")
		"quitting":
			if _t > QUIT_DELAY_S:
				return true
	return false


func _next(phase: String) -> void:
	_phase = phase
	_t = 0.0


func _finish(result: String) -> void:
	var report := {"result": result, "errors": _recorder.take(), "chat": _chat,
		"phase": _phase, "end_reason": _end_reason}
	if _main.game != null and _main.game.client != null:
		var client := _main.game.client
		var positions := {}
		var names := {}
		for id: int in client.roster:
			names[str(id)] = client.roster[id].name
			var state := client.render_state(id)
			if not state.is_empty():
				positions[str(id)] = _arr(state.position)
		report.merge({"my_id": client.my_id, "roster": names, "positions": positions,
			"guest_start": _arr(_guest_start), "ping_ms": client.ping_ms()})
	# Write then rename, so the host never reads a half-written file.
	var out := "user://" + str(_args.get("out", "guest_report.json"))
	var tmp := out + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(out))
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	_next("lingering" if result == "ok" else "quitting")


func _on_chat(author: String, text: String, _is_system: bool) -> void:
	_chat.append([author, text])


static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _on_disconnected(reason: String) -> void:
	_end_reason = reason
