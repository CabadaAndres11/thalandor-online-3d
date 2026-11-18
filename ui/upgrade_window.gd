class_name UpgradeWindow
extends Control
## Brann's class upgrade (level 50): one column per upgrade of the class (up to three)
## with its description, its two actives, two passives and the evolution of a base
## ability. Picking one is final until Brann resets it. Esc closes (handled by Main).

signal confirmed(id: String)

const COLUMN_WIDTH := 330.0

var confirm_button: Button
## Forced choice (level 50 without an upgrade): Esc does not close it.
var mandatory: bool = false

var _panel: PanelContainer
var _columns: HBoxContainer
var _buttons: Dictionary = {} # upgrade id -> Button
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
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	HoloTheme.add_shine(_panel)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("UPGRADE_TITLE")
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 12)
	box.add_child(_columns)
	var warning := Label.new()
	warning.text = tr("UPGRADE_WARNING")
	warning.add_theme_color_override("font_color", HoloTheme.ACCENT)
	warning.add_theme_font_size_override("font_size", 14)
	box.add_child(warning)
	confirm_button = Button.new()
	confirm_button.text = tr("UPGRADE_CONFIRM")
	confirm_button.custom_minimum_size = Vector2(200, 38)
	confirm_button.pressed.connect(_on_confirm)
	box.add_child(confirm_button)


## Lists the upgrades of a class and opens the window.
func show_for(class_id: String, abilities: AbilityDB, upgrades: UpgradeDB) -> void:
	for c in _columns.get_children():
		_columns.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_selected = ""
	for u: Dictionary in upgrades.for_class(class_id):
		_columns.add_child(_column(u, abilities))
	confirm_button.disabled = true
	visible = true
	var ids := option_ids()
	if not ids.is_empty():
		select(ids[0])


func select(id: String) -> void:
	if not _buttons.has(id):
		return
	_selected = id
	for k: String in _buttons:
		(_buttons[k] as Button).set_pressed_no_signal(k == id)
	confirm_button.disabled = false


func selected() -> String:
	return _selected


func option_ids() -> Array:
	return _buttons.keys()


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _on_confirm() -> void:
	if _selected == "":
		return
	visible = false
	mandatory = false
	confirmed.emit(_selected)


func _column(u: Dictionary, abilities: AbilityDB) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COLUMN_WIDTH
	col.add_theme_constant_override("separation", 5)
	var b := Button.new()
	b.text = tr(str(u.get("name", "")))
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(select.bind(str(u.id)))
	col.add_child(b)
	_buttons[str(u.id)] = b
	col.add_child(_text(tr(str(u.get("desc", ""))), 15, Color(1, 1, 1, 0.85)))
	col.add_child(_text(tr("UPGRADE_ACTIVES"), 14, HoloTheme.SECTION))
	for id: Variant in u.get("actives", []):
		col.add_child(_ability_line(abilities, str(id)))
	col.add_child(_text(tr("UPGRADE_PASSIVES"), 14, HoloTheme.SECTION))
	for id: Variant in u.get("passives", []):
		col.add_child(_ability_line(abilities, str(id)))
	var ev: Dictionary = u.get("evolves", {})
	if not ev.is_empty():
		col.add_child(_text(tr("UPGRADE_EVOLUTION"), 14, HoloTheme.SECTION))
		var target := abilities.get_ability(str(ev.get("ability", "")))
		var line := tr(str(target.get("name", ev.get("ability", ""))))
		if ev.has("desc"):
			line += ": " + tr(str(ev.desc))
		col.add_child(_text(line, 13, Color(1, 1, 1, 0.85)))
	return col


func _ability_line(abilities: AbilityDB, id: String) -> Label:
	var a := abilities.get_ability(id)
	return _text("• %s: %s" % [tr(str(a.get("name", id))), tr(str(a.get("desc", "")))], 13, Color(1, 1, 1, 0.85))


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = COLUMN_WIDTH
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
