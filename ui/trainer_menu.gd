class_name TrainerMenu
extends Control
## What Brann offers: choose a class, choose a class upgrade, reset attributes, talents
## or the upgrade, and (for the host player) the arena level, picked with a - / +
## selector. It only reports the choice; Main confirms resets and talks to the host.

signal chosen(option: String)
signal arena_level_confirmed(level: int)

const ARENA_MIN := 1
const ARENA_MAX := 60

var _panel: PanelContainer
var _options_box: VBoxContainer
var _arena_box: VBoxContainer
var _value_label: Label
var _buttons: Dictionary = {} # option -> Button
var _arena: int = 1


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
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(18))
	HoloTheme.add_shine(_panel)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("TRAINER_TITLE")
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	box.add_child(_options_box)
	var prompt := Label.new()
	prompt.text = tr("TRAINER_PROMPT")
	prompt.modulate = Color(1, 1, 1, 0.8)
	_options_box.add_child(prompt)

	_arena_box = VBoxContainer.new()
	_arena_box.add_theme_constant_override("separation", 8)
	box.add_child(_arena_box)
	var arena_title := Label.new()
	arena_title.text = tr("ARENA_TITLE")
	arena_title.add_theme_font_size_override("font_size", 20)
	_arena_box.add_child(arena_title)
	var arena_desc := Label.new()
	arena_desc.text = tr("ARENA_DESC")
	arena_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arena_desc.custom_minimum_size.x = 380
	_arena_box.add_child(arena_desc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_arena_box.add_child(row)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(56, 44)
	minus.pressed.connect(arena_step.bind(-1))
	row.add_child(minus)
	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 30)
	_value_label.custom_minimum_size.x = 80
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_value_label)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(56, 44)
	plus.pressed.connect(arena_step.bind(1))
	row.add_child(plus)
	var confirm := Button.new()
	confirm.text = tr("ARENA_CONFIRM")
	confirm.pressed.connect(confirm_arena)
	_arena_box.add_child(confirm)

	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	box.add_child(close)


## Opens the menu with these options (ids, in order).
func show_for(options: Array) -> void:
	for b: Button in _buttons.values():
		_options_box.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for o: String in options:
		var b := Button.new()
		b.text = tr("TRAINER_" + o.to_upper())
		b.custom_minimum_size = Vector2(340, 40)
		b.pressed.connect(press.bind(o))
		_options_box.add_child(b)
		_buttons[o] = b
	_options_box.visible = true
	_arena_box.visible = false
	visible = true


## Opens the 1-60 selector with the arena's current level.
func show_arena_selector(current: int) -> void:
	_arena = clampi(current, ARENA_MIN, ARENA_MAX)
	_value_label.text = str(_arena)
	_options_box.visible = false
	_arena_box.visible = true
	visible = true


func press(option: String) -> void:
	if _buttons.has(option):
		chosen.emit(option)


func arena_step(delta: int) -> void:
	_arena = clampi(_arena + delta, ARENA_MIN, ARENA_MAX)
	_value_label.text = str(_arena)


func confirm_arena() -> void:
	visible = false
	arena_level_confirmed.emit(_arena)


func option_ids() -> Array:
	return _buttons.keys()


func option_text(option: String) -> String:
	return (_buttons[option] as Button).text if _buttons.has(option) else ""


func arena_value() -> int:
	return _arena


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
