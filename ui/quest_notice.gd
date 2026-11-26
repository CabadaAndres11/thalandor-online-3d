class_name QuestNotice
extends Label
## A short notice at the top centre (Plan 8.2): new quest, objective done, quest completed.

const SHOW_S := 3.0

var _left: float = 0.0


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	position.y = 90
	add_theme_font_size_override("font_size", 26)
	add_theme_color_override("font_color", Color("#ffd27a"))
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 6)


## key: a text with one %s (UI_QUEST_NEW, UI_QUEST_STEP, UI_QUEST_DONE_NOTICE…).
func show_text(key: String, arg: String) -> void:
	var t := tr(key)
	super.set_text(t % arg if t.contains("%s") else t)
	_left = SHOW_S
	visible = true
	modulate.a = 1.0


func advance(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	modulate.a = clampf(_left / 0.5, 0.0, 1.0)
	if _left <= 0.0:
		visible = false


func _process(delta: float) -> void:
	advance(delta)


func text() -> String:
	return get_text()
