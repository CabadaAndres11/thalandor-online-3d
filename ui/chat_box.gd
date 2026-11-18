class_name ChatBox
extends Control
## Group chat, bottom-left. Enter opens the input and sends; Esc cancels.
## Shows the last 8 messages, which fade out after 10 s (all visible while typing).

signal message_submitted(text: String)
signal typing_changed(is_typing: bool)

const MAX_LINES := 8
const VISIBLE_SECONDS := 10.0
const FADE_SECONDS := 1.0
const WIDTH := 320.0 # ends left of the combat HUD (bottom centre)
const MAX_LINES_PER_MESSAGE := 3
const SYSTEM_COLOR := Color("#f3d36b")

var max_length: int = 120

var column: VBoxContainer
var _lines_box: VBoxContainer
var _input: LineEdit
var _lines: Array = [] # [{"label": Label, "age": float}]


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	column = VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = 16
	column.offset_right = 16 + WIDTH
	column.offset_top = -330
	column.offset_bottom = -16
	column.alignment = BoxContainer.ALIGNMENT_END
	column.grow_vertical = GROW_DIRECTION_BEGIN
	add_child(column)
	_lines_box = VBoxContainer.new()
	_lines_box.mouse_filter = MOUSE_FILTER_IGNORE
	_lines_box.add_theme_constant_override("separation", 2)
	column.add_child(_lines_box)
	_input = LineEdit.new()
	_input.placeholder_text = tr("CHAT_PLACEHOLDER")
	_input.visible = false
	_input.text_submitted.connect(submit)
	_input.gui_input.connect(_on_input_gui)
	column.add_child(_input)


func is_typing() -> bool:
	return _input.visible


func input_max_length() -> int:
	return _input.max_length


func open_input() -> void:
	if is_typing():
		return
	_input.max_length = max_length
	_input.text = ""
	_input.visible = true
	if _input.is_inside_tree():
		_input.grab_focus()
	_refresh_alpha()
	typing_changed.emit(true)


func submit(text: String) -> void:
	var t := text.strip_edges()
	_close()
	if t != "":
		message_submitted.emit(t)


func cancel() -> void:
	_close()


## True if a line with exactly this text is in the chat.
func has_message(text: String) -> bool:
	return _lines.any(func(l: Dictionary) -> bool: return (l.label as Label).text == text)


func add_message(author: String, text: String, is_system: bool) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH
	label.max_lines_visible = MAX_LINES_PER_MESSAGE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_font_size_override("font_size", 15)
	if is_system:
		label.text = text
		label.add_theme_color_override("font_color", SYSTEM_COLOR)
	else:
		label.text = "%s: %s" % [author, text]
	_lines_box.add_child(label)
	_lines.append({"label": label, "age": 0.0})
	while _lines.size() > MAX_LINES:
		var old: Dictionary = _lines.pop_front()
		_lines_box.remove_child(old.label)
		(old.label as Label).free()


func visible_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l: Dictionary in _lines:
		out.append((l.label as Label).text)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not is_typing() and is_visible_in_tree() and event.is_action_pressed("chat"):
		open_input()
		get_viewport().set_input_as_handled()


func _on_input_gui(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel()
		_input.accept_event()


func _process(delta: float) -> void:
	for l: Dictionary in _lines:
		l.age = float(l.age) + delta
	_refresh_alpha()


func _refresh_alpha() -> void:
	for l: Dictionary in _lines:
		var a := 1.0
		if not is_typing():
			a = clampf(1.0 - (float(l.age) - VISIBLE_SECONDS) / FADE_SECONDS, 0.0, 1.0)
		(l.label as Label).modulate.a = a


func _close() -> void:
	if not is_typing():
		return
	_input.visible = false
	_input.release_focus()
	_refresh_alpha()
	typing_changed.emit(false)


func column_rect() -> Rect2:
	return column.get_global_rect()
