class_name DungeonWindow
extends Control
## At a dungeon's door (Plan 8.1): choose the level of its monsters within the offered
## range, then Enter or Cancel. A game window, so it wears HoloTheme.

signal enter_requested(zone_id: String, level: int)

var level: int = 1
var enter_button: Button
var cancel_button: Button
var _zone_id: String = ""
var _min: int = 1
var _max: int = 1
var _title: Label
var _value: Label


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(20))
	panel.set_anchors_preset(PRESET_CENTER)
	panel.grow_horizontal = GROW_DIRECTION_BOTH
	panel.grow_vertical = GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = HoloTheme.title("")
	box.add_child(_title)
	var hint := Label.new()
	hint.text = tr("DUNGEON_LEVEL_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(48, 40)
	prev.pressed.connect(prev_level)
	row.add_child(prev)
	_value = Label.new()
	_value.custom_minimum_size.x = 140
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.add_theme_font_size_override("font_size", 30)
	row.add_child(_value)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(48, 40)
	next.pressed.connect(next_level)
	row.add_child(next)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	enter_button = Button.new()
	enter_button.text = tr("DUNGEON_ENTER")
	enter_button.custom_minimum_size = Vector2(140, 42)
	enter_button.pressed.connect(_on_enter)
	buttons.add_child(enter_button)
	cancel_button = Button.new()
	cancel_button.text = tr("BTN_CANCEL")
	cancel_button.custom_minimum_size = Vector2(140, 42)
	cancel_button.pressed.connect(func() -> void: visible = false)
	buttons.add_child(cancel_button)


func open(zone_id: String, name_key: String, min_level: int, max_level: int, default_level: int) -> void:
	_zone_id = zone_id
	_min = min_level
	_max = maxi(min_level, max_level)
	level = clampi(default_level, _min, _max)
	_title.text = tr(name_key)
	_refresh()
	visible = true


func next_level() -> void:
	level = mini(level + 1, _max)
	_refresh()


func prev_level() -> void:
	level = maxi(level - 1, _min)
	_refresh()


func _refresh() -> void:
	_value.text = tr("LEVEL_SHORT") % level


func _on_enter() -> void:
	visible = false
	enter_requested.emit(_zone_id, level)
