class_name DialogueWindow
extends Control
## A conversation with an NPC (Plan 8.2): a wide stone panel at the bottom of the screen
## with who speaks and the line appearing letter by letter. E, space or a click completes
## the line or moves on; the choices (1-4) show only where the dialogue has them. It walks a
## DialogueRunner and reports what Main sends to the host: flags set, actions, the end.

signal finished(dialogue_id: String)
signal action(name: String, arg: String)
signal flags_set(flags: Array)
signal closed()

const LETTERS_PER_S := 40.0
const WIDTH := 900.0
const MARGIN_BOTTOM := 24.0
const MAX_CHOICES := 4

var _runner: DialogueRunner
var _npc_name: String = ""
var _player_name: String = ""
var _epithet: String = ""
var _full: String = ""
var _shown: float = 0.0
var _sent_flags: Array = []
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label
var _choices_box: VBoxContainer


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", StoneTheme.panel(20))
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", StoneTheme.GOLD)
	_speaker.add_theme_font_size_override("font_size", 24)
	box.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 40.0, 56)
	_text.add_theme_font_size_override("font_size", 22)
	box.add_child(_text)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 4)
	box.add_child(_choices_box)
	_hint = Label.new()
	_hint.text = tr("UI_DIALOGUE_CONTINUE")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", StoneTheme.TEXT_DIM)
	_hint.add_theme_font_size_override("font_size", 16)
	box.add_child(_hint)


func show_for(runner: DialogueRunner, npc_name: String, player_name: String, epithet: String) -> void:
	_runner = runner
	_npc_name = npc_name
	_player_name = player_name
	_epithet = epithet
	_sent_flags.clear()
	visible = true
	_show_current()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_place()


func _place() -> void:
	if _panel == null:
		return
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.position = Vector2((size.x - sz.x) / 2.0, size.y - sz.y - MARGIN_BOTTOM)


func _process(delta: float) -> void:
	if visible:
		advance_time(delta)


func advance_time(delta: float) -> void:
	if _shown < _full.length():
		_shown = minf(_full.length(), _shown + delta * LETTERS_PER_S)
		_text.text = _full.left(int(_shown))


func _speaker_name(who: String) -> String:
	if who == "player":
		return _player_name
	var npc := NpcDB.load_default().npc(who)
	return tr(str(npc.get("name", who))) if not npc.is_empty() else _npc_name


func _show_current() -> void:
	_report_flags()
	for c: Node in _choices_box.get_children():
		c.queue_free()
		_choices_box.remove_child(c)
	if _runner == null or _runner.finished():
		_finish()
		return
	var line := _runner.current_line()
	if not line.is_empty():
		_speaker.text = _speaker_name(str(line[0]))
		_full = DialogueRunner.format(str(line[1]), _player_name, _epithet)
		_shown = 0.0
		_text.text = ""
		_hint.visible = true
	else:
		_shown = float(_full.length())
		_text.text = _full
		_hint.visible = false
		var shown := _runner.choices()
		for i in mini(MAX_CHOICES, shown.size()):
			var b := Button.new()
			b.text = "%d. %s" % [i + 1, DialogueRunner.format(str(shown[i].text), _player_name, _epithet)]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(press_choice.bind(i + 1))
			_choices_box.add_child(b)
	_place()


func _report_flags() -> void:
	if _runner == null:
		return
	var fresh: Array = _runner.set_flags().filter(func(f: String) -> bool: return not f in _sent_flags)
	if not fresh.is_empty():
		_sent_flags.append_array(fresh)
		flags_set.emit(fresh)


## E, space or a click: completes the line, or moves to the next one.
func press_continue() -> void:
	if not visible or _runner == null or _runner.current_line().is_empty():
		return
	if _shown < _full.length():
		_shown = float(_full.length())
		_text.text = _full
		return
	_runner.advance()
	_show_current()


## Choice 1-4 as shown.
func press_choice(n: int) -> void:
	if not visible or _runner == null or not _runner.current_line().is_empty():
		return
	var picked := _runner.choose(n - 1)
	if picked.is_empty():
		return
	var act := str(picked.action)
	if act != "":
		var parts := act.split(":", true, 1)
		action.emit(parts[0], parts[1] if parts.size() > 1 else "")
	_show_current()


func _finish() -> void:
	var id := _runner.id if _runner != null else ""
	_runner = null
	visible = false
	finished.emit(id)


## Closed before its end (damage, Esc, leaving): nothing is reported as said.
func interrupt() -> void:
	if not visible:
		return
	_runner = null
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press_continue()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		press_continue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		interrupt()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_4:
			press_choice(k - KEY_1 + 1)
			get_viewport().set_input_as_handled()


# --- Readable state (tests) ---

func speaker_text() -> String:
	return _speaker.text


func shown_text() -> String:
	return _text.text


func choice_texts() -> Array:
	return _choices_box.get_children().map(func(b: Button) -> String: return b.text)


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)
