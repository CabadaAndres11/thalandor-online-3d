class_name ClassChoiceWindow
extends Control
## Brann's training: the villager picks one of the five classes. Each shows its name,
## description and resource, and the character as they would look in it. Confirming
## is final (the window says so). Esc closes it without choosing (handled by Main).

signal class_confirmed(class_id: String)

const RESOURCE_KEYS := {"rage": "RES_RAGE", "mana": "RES_MANA", "focus": "RES_FOCUS", "energy": "RES_ENERGY"}

var confirm_button: Button
var preview: CharacterPreview

var _panel: PanelContainer
var _buttons: Dictionary = {} # class id -> Button
var _name: Label
var _desc: Label
var _resource: Label
var _appearance: Dictionary = {}
var _selected: String = ""


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	style.border_color = Color("#8a6d2f")
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title := Label.new()
	title.text = tr("CLASS_CHOICE_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var group := ButtonGroup.new()
	for c: Dictionary in CharacterCatalog.load_default().selectable_classes():
		var b := Button.new()
		b.text = tr(str(c.name))
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(120, 36)
		b.pressed.connect(select.bind(str(c.id)))
		row.add_child(b)
		_buttons[str(c.id)] = b

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	preview = CharacterPreview.new()
	preview.custom_minimum_size = Vector2(240, 320)
	body.add_child(preview)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(380, 0)
	info.add_theme_constant_override("separation", 8)
	body.add_child(info)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	info.add_child(_name)
	_resource = Label.new()
	_resource.modulate = Color(1, 1, 1, 0.75)
	info.add_child(_resource)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(380, 150)
	info.add_child(_desc)
	var warning := Label.new()
	warning.text = tr("CLASS_CHOICE_WARNING")
	warning.add_theme_color_override("font_color", Color("#ffd27a"))
	info.add_child(warning)
	confirm_button = Button.new()
	confirm_button.text = tr("CLASS_CHOICE_CONFIRM")
	confirm_button.custom_minimum_size = Vector2(160, 40)
	confirm_button.pressed.connect(_on_confirm)
	info.add_child(confirm_button)


## Opens the window for a character with this appearance (shown in each class).
func show_for(appearance: Dictionary) -> void:
	_appearance = appearance.duplicate()
	visible = true
	select(class_ids()[0])


func select(id: String) -> void:
	if not _buttons.has(id):
		return
	_selected = id
	for k: String in _buttons:
		(_buttons[k] as Button).set_pressed_no_signal(k == id)
	var def := CharacterCatalog.load_default().class_def(id)
	_name.text = tr(str(def.get("name", id)))
	_desc.text = tr(str(def.get("desc", "")))
	var kind := str((def.get("resource", {}) as Dictionary).get("kind", ""))
	_resource.text = tr(RESOURCE_KEYS.get(kind, "")) if RESOURCE_KEYS.has(kind) else ""
	preview.show_character(id, _appearance)


func selected() -> String:
	return _selected


func class_ids() -> Array:
	return _buttons.keys()


func description_text() -> String:
	return _desc.text


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _on_confirm() -> void:
	if _selected == "":
		return
	visible = false
	class_confirmed.emit(_selected)
