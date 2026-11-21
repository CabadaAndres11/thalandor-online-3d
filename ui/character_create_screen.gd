class_name CharacterCreateScreen
extends Control
## "Crear personaje": name and appearance, one ◀ ▶ row
## per option (colors show a swatch), with a live preview that can be turned by
## dragging. Options come from CharacterCatalog (data/characters/). Everyone starts
## as a villager: the class is chosen in the game, talking to Brann.

signal create_requested(char_name: String, appearance: Dictionary)
signal back_requested()

const LABEL_KEYS := {
	"race": "APPEAR_RACE", "body": "APPEAR_BODY", "skin": "APPEAR_SKIN", "eyes": "APPEAR_EYES", "marks": "APPEAR_MARKS",
	"hair_style": "APPEAR_HAIR_STYLE", "hair_color": "APPEAR_HAIR_COLOR", "beard": "APPEAR_BEARD",
}

var name_edit: LineEdit
var create_button: Button
var random_button: Button
var back_button: Button
var preview: CharacterPreview

var _catalog: CharacterCatalog
var _index: Dictionary = {} # kind -> option index
var _value_labels: Dictionary = {} # kind -> Label
var _swatches: Dictionary = {} # kind -> ColorRect
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_catalog = CharacterCatalog.load_default()
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
	left.custom_minimum_size.x = 600
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var title := Label.new()
	title.text = tr("CREATE_TITLE")
	title.add_theme_font_size_override("font_size", 36)
	left.add_child(title)

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
	note.custom_minimum_size.y = 52
	note.modulate = Color(1, 1, 1, 0.75)
	left.add_child(note)

	for kind: String in CharacterCatalog.KINDS:
		left.add_child(_option_row(kind))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	left.add_child(buttons)
	random_button = _button(buttons, "BTN_RANDOM", _on_random)
	create_button = _button(buttons, "BTN_CREATE", _on_create)
	back_button = _button(buttons, "BTN_BACK", back_requested.emit)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_child(right)
	preview = CharacterPreview.new()
	preview.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(preview)
	var hint := Label.new()
	hint.text = tr("PREVIEW_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	right.add_child(hint)
	reset("")


## Fresh form: default appearance, `default_name` already written.
func reset(default_name: String) -> void:
	name_edit.text = default_name
	for kind: String in CharacterCatalog.KINDS:
		_index[kind] = 0
	_rng.randomize()
	_on_name_changed(default_name)
	_update()


func next_option(kind: String) -> void:
	_step(kind, 1)


func prev_option(kind: String) -> void:
	_step(kind, -1)


func current_appearance() -> Dictionary:
	var app := {}
	for kind: String in CharacterCatalog.KINDS:
		app[kind] = _catalog.options(kind)[_index[kind]].id
	return app


func _step(kind: String, delta: int) -> void:
	var n := _catalog.options(kind).size()
	_index[kind] = posmod(int(_index[kind]) + delta, n)
	_update()


func _update() -> void:
	for kind: String in CharacterCatalog.KINDS:
		var o: Dictionary = _catalog.options(kind)[_index[kind]]
		var label: Label = _value_labels[kind]
		var swatch: ColorRect = _swatches[kind]
		if o.has("color"):
			swatch.color = Color(str(o.color))
			swatch.modulate.a = 1.0
			label.text = "%d / %d" % [int(_index[kind]) + 1, _catalog.options(kind).size()]
		else:
			swatch.modulate.a = 0.0 # keeps its space so the arrows line up
			label.text = tr(str(o.get("name", o.id)))
	preview.show_character(CharacterCatalog.DEFAULT_CLASS, current_appearance())


func _option_row(kind: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_caption(LABEL_KEYS[kind]))
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(44, 38)
	prev.pressed.connect(prev_option.bind(kind))
	row.add_child(prev)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(38, 30)
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
	next.custom_minimum_size = Vector2(44, 38)
	next.pressed.connect(next_option.bind(kind))
	row.add_child(next)
	return row


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
	var app := _catalog.random_appearance(_rng)
	for kind: String in CharacterCatalog.KINDS:
		var list := _catalog.options(kind)
		for i in list.size():
			if list[i].id == app[kind]:
				_index[kind] = i
	_update()


func _on_create() -> void:
	if not create_button.disabled:
		create_requested.emit(name_edit.text.strip_edges(), current_appearance())
