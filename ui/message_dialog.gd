class_name MessageDialog
extends Control
## Simple centered message with an OK button (connection errors, version mismatch…).

signal closed()

var _label: Label


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
	var ok := Button.new()
	ok.text = tr("BTN_OK")
	ok.size_flags_horizontal = SIZE_SHRINK_CENTER
	ok.custom_minimum_size.x = 140
	ok.pressed.connect(_on_ok)
	box.add_child(ok)


func show_message(text: String) -> void:
	_label.text = text
	visible = true


func message() -> String:
	return _label.text


func _on_ok() -> void:
	visible = false
	closed.emit()
