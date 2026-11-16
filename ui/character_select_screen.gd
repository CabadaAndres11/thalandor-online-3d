class_name CharacterSelectScreen
extends Control
## "Tus personajes": the player's characters (up to 8) on the left, the selected one
## turning on the right, and the actions: create, delete, export, import, play and
## join a friend with a code.

signal play_requested(id: String)
signal join_requested(id: String, code: String)
signal create_requested()
signal delete_requested(id: String)
signal export_requested(id: String)
signal import_requested()
signal back_requested()

var slot_buttons: Array[Button] = []
var create_button: Button
var delete_button: Button
var export_button: Button
var import_button: Button
var play_button: Button
var join_button: Button
var back_button: Button
var code_edit: LineEdit
var preview: CharacterPreview

var _characters: Array[CharacterData] = []
var _selected: String = ""
var _empty_label: Label
var _group := ButtonGroup.new()


func _init() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1d2233")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var title := Label.new()
	title.text = tr("CHARS_TITLE")
	title.add_theme_font_size_override("font_size", 36)
	left.add_child(title)
	for i in CharacterStore.MAX_CHARACTERS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 44
		b.clip_text = true
		b.pressed.connect(_on_slot.bind(i))
		left.add_child(b)
		slot_buttons.append(b)
	_empty_label = Label.new()
	_empty_label.text = tr("CHARS_NONE")
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.modulate = Color(1, 1, 1, 0.7)
	left.add_child(_empty_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	create_button = _button(actions, "BTN_CREATE", create_requested.emit)
	delete_button = _button(actions, "BTN_DELETE", _on_delete)
	export_button = _button(actions, "BTN_EXPORT", _on_export)
	import_button = _button(actions, "BTN_IMPORT", import_requested.emit)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	preview = CharacterPreview.new()
	preview.custom_minimum_size = Vector2(0, 400)
	preview.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(preview)
	play_button = _button(right, "BTN_PLAY", _on_play)
	play_button.custom_minimum_size.y = 48
	var join_row := HBoxContainer.new()
	right.add_child(join_row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = tr("CODE_PLACEHOLDER")
	code_edit.max_length = 12
	code_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	code_edit.text_submitted.connect(_on_code_submitted)
	join_row.add_child(code_edit)
	join_button = _button(join_row, "BTN_JOIN", _on_join)
	back_button = _button(right, "BTN_BACK", back_requested.emit)
	_refresh()


func set_characters(list: Array[CharacterData], selected: String) -> void:
	_characters = list
	_selected = selected
	if not _characters.any(func(c: CharacterData) -> bool: return c.id == _selected):
		_selected = _characters[0].id if not _characters.is_empty() else ""
	_refresh()


func selected_id() -> String:
	return _selected


func set_code(code: String) -> void:
	code_edit.text = code


func _refresh() -> void:
	var catalog := CharacterCatalog.load_default()
	for i in slot_buttons.size():
		var b := slot_buttons[i]
		b.visible = i < _characters.size()
		if b.visible:
			var slot_char := _characters[i]
			b.text = tr("CHAR_SLOT") % [slot_char.name, tr(str(catalog.class_def(slot_char.class_id).get("name", ""))), slot_char.progress.level]
			b.set_pressed_no_signal(slot_char.id == _selected)
	_empty_label.visible = _characters.is_empty()
	var has := _selected != ""
	for b: Button in [play_button, join_button, delete_button, export_button]:
		b.disabled = not has
	var full := _characters.size() >= CharacterStore.MAX_CHARACTERS
	create_button.disabled = full
	import_button.disabled = full
	var c := _current()
	preview.visible = c != null
	if c != null:
		preview.show_character(c.class_id, c.appearance)


func _current() -> CharacterData:
	for c in _characters:
		if c.id == _selected:
			return c
	return null


func _button(parent: Node, key: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size.y = 40
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _on_slot(index: int) -> void:
	if index < _characters.size():
		_selected = _characters[index].id
		_refresh()


func _on_play() -> void:
	if _selected != "":
		play_requested.emit(_selected)


func _on_join() -> void:
	if _selected != "":
		join_requested.emit(_selected, code_edit.text.strip_edges())


func _on_code_submitted(_t: String) -> void:
	_on_join()


func _on_delete() -> void:
	if _selected != "":
		delete_requested.emit(_selected)


func _on_export() -> void:
	if _selected != "":
		export_requested.emit(_selected)
