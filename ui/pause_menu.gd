class_name PauseMenu
extends Control
## In-game menu (Esc). The game keeps running underneath (it is online).

signal resume_requested()
signal leave_requested()
signal open_group_requested()
signal options_requested()

var open_group_button: Button
var code_label: Label
var copy_button: Button
var options_button: Button
var _hint: Label
var _code: String = ""
var _lock_hint: String = ""


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("MENU_TITLE")
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := Button.new()
	resume.text = tr("MENU_RESUME")
	resume.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume)

	open_group_button = Button.new()
	open_group_button.text = tr("MENU_OPEN_GROUP")
	open_group_button.pressed.connect(func() -> void: open_group_requested.emit())
	box.add_child(open_group_button)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.visible = false
	box.add_child(_hint)

	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(code_row)
	code_label = Label.new()
	code_label.add_theme_font_size_override("font_size", 40)
	code_label.visible = false
	code_row.add_child(code_label)
	copy_button = Button.new()
	copy_button.text = tr("BTN_COPY")
	copy_button.visible = false
	copy_button.pressed.connect(_on_copy)
	code_row.add_child(copy_button)

	options_button = Button.new()
	options_button.text = tr("MENU_OPTIONS")
	options_button.pressed.connect(func() -> void: options_requested.emit())
	box.add_child(options_button)

	var leave := Button.new()
	leave.text = tr("MENU_LEAVE")
	leave.pressed.connect(func() -> void: leave_requested.emit())
	box.add_child(leave)


## Until the village tutorial is done (Plan 8.1) the group cannot be opened: the button
## is greyed out and the hint says why.
func set_group_locked(locked: bool) -> void:
	open_group_button.disabled = locked
	_lock_hint = tr("GROUP_LOCKED_TUTORIAL") if locked else ""
	if locked:
		_hint.text = _lock_hint
		_hint.visible = true


func lock_hint() -> String:
	return _lock_hint


## Hosts can open their group; guests see a hint instead.
func set_can_open_group(can: bool) -> void:
	open_group_button.visible = can and _code == ""
	_hint.visible = not can or _code != ""
	_hint.text = tr("MENU_CODE_HINT") if can else tr("MENU_GUEST_HINT")


func show_code(code: String) -> void:
	_code = code
	code_label.text = code
	code_label.visible = true
	copy_button.visible = true
	copy_button.text = tr("BTN_COPY")
	open_group_button.visible = false
	_hint.text = tr("MENU_CODE_HINT")
	_hint.visible = true


## While a WebRTC group is opening: the button waits with "Abriendo grupo…".
func show_opening() -> void:
	open_group_button.disabled = true
	open_group_button.text = tr("MENU_OPENING_GROUP")


func cancel_opening() -> void:
	open_group_button.disabled = false
	open_group_button.text = tr("MENU_OPEN_GROUP")


func reset() -> void:
	_code = ""
	cancel_opening()
	code_label.visible = false
	copy_button.visible = false
	visible = false


func _on_copy() -> void:
	DisplayServer.clipboard_set(_code)
	copy_button.text = tr("BTN_COPIED")
