class_name XpBar
extends Control
## A thin experience bar with "Nivel N · xp / necesaria" over it, under the ability bar.

const FILL := Color("#8a5cd6")

var _bar: ProgressBar
var _label: Label


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 14)
	_bar = ProgressBar.new()
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.12, 0.9)
	_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL
	_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)
	_label = Label.new()
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func set_progress(level: int, xp: int, to_next: int) -> void:
	_bar.value = clampf(float(xp) / float(to_next), 0.0, 1.0) if to_next > 0 else 0.0
	_label.text = tr("XP_BAR_TEXT") % [level, xp, to_next]


func fraction() -> float:
	return _bar.value


func text() -> String:
	return _label.text
