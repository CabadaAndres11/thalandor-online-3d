class_name CharacterSelectScreen
extends Control
## "Tus personajes": the player's characters (up to 8) on a stone panel at the left,
## the selected one standing in the menu scene (look_changed), and the actions: create,
## delete, export, import, and in the bottom-right corner play, join a friend with a code
## and back.

signal play_requested(id: String)
signal join_requested(id: String, code: String)
signal create_requested()
signal delete_requested(id: String)
signal export_requested(id: String)
signal import_requested()
signal back_requested()
## The character to show in the scene changed (a HumanRig look; {} = nobody).
signal look_changed(look: Dictionary)

var slot_buttons: Array[Button] = []
var create_button: Button
var delete_button: Button
var export_button: Button
var import_button: Button
var play_button: Button
var join_button: Button
var back_button: Button
var code_edit: LineEdit

var _characters: Array[CharacterData] = []
var _selected: String = ""
var _empty_label: Label
var _group := ButtonGroup.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StoneTheme.panel(16))
	panel.set_anchors_preset(PRESET_TOP_LEFT)
	panel.offset_left = 24
	panel.offset_right = 24 + 460
	panel.offset_top = 24
	add_child(panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	panel.add_child(left)
	left.add_child(StoneTheme.title(tr("CHARS_TITLE"), 34))
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
	right.add_theme_constant_override("separation", 10)
	right.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -40 - 380
	right.offset_right = -40
	right.offset_top = -40 - 200
	right.offset_bottom = -40
	add_child(right)
	play_button = _button(right, "BTN_PLAY", _on_play)
	StoneTheme.primary_button(play_button)
	play_button.custom_minimum_size.y = 72
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
	MenuFx.decorate(play_button, MenuFx.CALL)
	MenuFx.decorate_tree(self)
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
			var race := tr(str(catalog.option("race", str(slot_char.appearance.get("race", "human"))).get("name", "")))
			b.text = tr("CHAR_SLOT") % [slot_char.name, race, tr(str(catalog.class_def(slot_char.class_id).get("name", ""))), slot_char.progress.level]
			b.set_pressed_no_signal(slot_char.id == _selected)
	_empty_label.visible = _characters.is_empty()
	var has := _selected != ""
	for b: Button in [play_button, join_button, delete_button, export_button]:
		b.disabled = not has
	var chosen := _current()
	if chosen != null and not chosen.tutorial_done:
		join_button.disabled = true # playing with friends opens after the village tutorial
		join_button.tooltip_text = tr("GROUP_LOCKED_TUTORIAL")
	else:
		join_button.tooltip_text = ""
	var full := _characters.size() >= CharacterStore.MAX_CHARACTERS
	create_button.disabled = full
	import_button.disabled = full
	var c := _current()
	look_changed.emit(catalog.resolve(c.class_id, c.appearance, "", c.inventory.visible_bases()) if c != null else {}) # as last equipped


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
