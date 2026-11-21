class_name CharacterCreateScreen
extends Control
## "Crear personaje": name, race and appearance, one ◀ ▶ row per option (colors show a
## swatch), on a stone panel at the left. The character itself stands in the menu scene
## (look_changed) and turns when the empty right side is dragged (turn_requested).
## Options come from CharacterCatalog (data/characters/) and only those of the race
## are offered. Everyone starts as a villager: the class is chosen in the game, with Brann.

signal create_requested(char_name: String, appearance: Dictionary)
signal back_requested()
## The character to show in the scene changed (a HumanRig look).
signal look_changed(look: Dictionary)
## The right side was dragged: turn the character this many degrees.
signal turn_requested(deg: float)

const DRAG_DEG_PER_PX := 0.6
const ROW_HEIGHT := 36

const LABEL_KEYS := {
	"race": "APPEAR_RACE", "body": "APPEAR_BODY", "skin": "APPEAR_SKIN", "eyes": "APPEAR_EYES", "marks": "APPEAR_MARKS",
	"hair_style": "APPEAR_HAIR_STYLE", "hair_color": "APPEAR_HAIR_COLOR", "beard": "APPEAR_BEARD",
}

var name_edit: LineEdit
var create_button: Button
var random_button: Button
var back_button: Button
var race_desc: Label

var _catalog: CharacterCatalog
var _app: Dictionary = {} # the appearance shown (always valid for its race)
var _value_labels: Dictionary = {} # kind -> Label
var _swatches: Dictionary = {} # kind -> ColorRect
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_catalog = CharacterCatalog.load_default()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StoneTheme.panel(16))
	panel.set_anchors_preset(PRESET_LEFT_WIDE)
	panel.offset_left = 24
	panel.offset_right = 24 + 600
	panel.offset_top = 20
	panel.offset_bottom = -20
	add_child(panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	panel.add_child(left)
	left.add_child(StoneTheme.title(tr("CREATE_TITLE"), 34))

	var name_row := HBoxContainer.new()
	left.add_child(name_row)
	name_row.add_child(_caption("NAME_FIELD"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = tr("NAME_PLACEHOLDER")
	name_edit.max_length = HostSession.NAME_MAX
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)

	var note := Label.new()
	note.text = tr("CLASS_VILLAGER_DESC")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 18)
	note.modulate = Color(1, 1, 1, 0.7)
	left.add_child(note)

	for kind: String in CharacterCatalog.KINDS:
		left.add_child(_option_row(kind))
		if kind == "race":
			race_desc = Label.new()
			race_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			race_desc.add_theme_font_size_override("font_size", 18)
			race_desc.add_theme_color_override("font_color", StoneTheme.GOLD)
			left.add_child(race_desc)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	left.add_child(buttons)
	random_button = _button(buttons, "BTN_RANDOM", _on_random)
	create_button = _button(buttons, "BTN_CREATE", _on_create)
	back_button = _button(buttons, "BTN_BACK", back_requested.emit)

	# The empty right side: dragging it turns the character in the scene.
	var drag := Control.new()
	drag.name = "TurnArea"
	drag.set_anchors_preset(PRESET_FULL_RECT)
	drag.offset_left = 24 + 600 + 20
	drag.mouse_filter = MOUSE_FILTER_STOP
	drag.gui_input.connect(_on_drag_input)
	add_child(drag)
	var hint := Label.new()
	hint.text = tr("PREVIEW_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.set_anchors_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.offset_bottom = -24
	drag.add_child(hint)
	reset("")


## Fresh form: default appearance, `default_name` already written.
func reset(default_name: String) -> void:
	name_edit.text = default_name
	_app = _catalog.default_appearance()
	_rng.randomize()
	_on_name_changed(default_name)
	_update()


func next_option(kind: String) -> void:
	_step(kind, 1)


func prev_option(kind: String) -> void:
	_step(kind, -1)


func current_appearance() -> Dictionary:
	return _app.duplicate()


func _step(kind: String, delta: int) -> void:
	var list := _catalog.options_for(kind, str(_app.race))
	_app[kind] = list[posmod(_index_of(list, str(_app[kind])) + delta, list.size())].id
	if kind == "race":
		_app = _catalog.sanitize_appearance(_app) # what the new race cannot wear goes back to its first option
	_update()


static func _index_of(list: Array, id: String) -> int:
	for i in list.size():
		if list[i].id == id:
			return i
	return 0


func _update() -> void:
	for kind: String in CharacterCatalog.KINDS:
		var list := _catalog.options_for(kind, str(_app.race))
		var i := _index_of(list, str(_app[kind]))
		var o: Dictionary = list[i]
		var label: Label = _value_labels[kind]
		var swatch: ColorRect = _swatches[kind]
		if o.has("color"):
			swatch.color = Color(str(o.color))
			swatch.modulate.a = 1.0
			label.text = "%d / %d" % [i + 1, list.size()]
		else:
			swatch.modulate.a = 0.0 # keeps its space so the arrows line up
			label.text = tr(str(o.get("name", o.id)))
	race_desc.text = tr(str(_catalog.race_def(str(_app.race)).get("desc", "")))
	look_changed.emit(_catalog.resolve(CharacterCatalog.DEFAULT_CLASS, current_appearance()))


func _option_row(kind: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_caption(LABEL_KEYS[kind]))
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(44, ROW_HEIGHT)
	prev.pressed.connect(prev_option.bind(kind))
	row.add_child(prev)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(36, 26)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(swatch)
	_swatches[kind] = swatch
	var value := Label.new()
	value.custom_minimum_size.x = 180
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	_value_labels[kind] = value
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(44, ROW_HEIGHT)
	next.pressed.connect(next_option.bind(kind))
	row.add_child(next)
	return row


## The kinds of the option rows, top to bottom.
func row_kinds() -> Array:
	return _value_labels.keys()


func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		turn_requested.emit((event as InputEventMouseMotion).relative.x * DRAG_DEG_PER_PX)


func _caption(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.custom_minimum_size.x = 170
	return l


func _button(parent: Node, key: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(150, 44)
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _on_name_changed(_text: String) -> void:
	create_button.disabled = not HostSession.is_valid_name(name_edit.text.strip_edges())


func _on_random() -> void:
	_app = _catalog.random_appearance(_rng)
	_update()


func _on_create() -> void:
	if not create_button.disabled:
		create_requested.emit(name_edit.text.strip_edges(), current_appearance())
