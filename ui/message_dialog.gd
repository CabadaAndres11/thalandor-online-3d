class_name MessageDialog
extends Control
## Centered modal dialog in three modes:
## show_message (OK), ask (Yes/No -> answered) and ask_text (text field ->
## text_answered, "" when cancelled).

signal closed()
signal answered(yes: bool)
signal text_answered(text: String)

enum Mode { MESSAGE, ASK, ASK_TEXT }

var ok_button: Button
var yes_button: Button
var no_button: Button
var accept_button: Button
var cancel_button: Button
var text_edit: LineEdit

var _label: Label
var _mode: Mode = Mode.MESSAGE


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(460, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	text_edit = LineEdit.new()
	text_edit.max_length = HostSession.NAME_MAX
	text_edit.text_submitted.connect(_on_text_submitted)
	box.add_child(text_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	ok_button = _button(row, "BTN_OK", _on_ok)
	yes_button = _button(row, "BTN_YES", _on_yes)
	no_button = _button(row, "BTN_NO", _on_no)
	accept_button = _button(row, "BTN_OK", _on_accept)
	cancel_button = _button(row, "BTN_CANCEL", _on_cancel)


func show_message(text: String) -> void:
	_open(Mode.MESSAGE, text)


func ask(text: String) -> void:
	_open(Mode.ASK, text)


func ask_text(text: String, default_text: String) -> void:
	_open(Mode.ASK_TEXT, text)
	text_edit.text = default_text
	text_edit.grab_focus.call_deferred()


func message() -> String:
	return _label.text


func _open(mode: Mode, text: String) -> void:
	_mode = mode
	_label.text = text
	ok_button.visible = mode == Mode.MESSAGE
	yes_button.visible = mode == Mode.ASK
	no_button.visible = mode == Mode.ASK
	text_edit.visible = mode == Mode.ASK_TEXT
	accept_button.visible = mode == Mode.ASK_TEXT
	cancel_button.visible = mode == Mode.ASK_TEXT
	visible = true


func _button(parent: Node, key: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size.x = 140
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _on_ok() -> void:
	visible = false
	closed.emit()


func _on_yes() -> void:
	visible = false
	answered.emit(true)


func _on_no() -> void:
	visible = false
	answered.emit(false)


func _on_accept() -> void:
	visible = false
	text_answered.emit(text_edit.text.strip_edges())


func _on_cancel() -> void:
	visible = false
	text_answered.emit("")


func _on_text_submitted(_t: String) -> void:
	if _mode == Mode.ASK_TEXT and visible:
		_on_accept()
