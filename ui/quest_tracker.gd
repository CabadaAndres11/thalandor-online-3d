class_name QuestTracker
extends PanelContainer
## The tracked quest in the HUD (Plan 8.2), under the minimap: its name, the step and the
## objective counts. Hidden when nothing is tracked.

var _name: Label
var _step: Label
var _lines: Label


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	var s := HoloTheme.panel_style(8)
	s.bg_color.a = 0.55
	add_theme_stylebox_override("panel", s)
	custom_minimum_size = Vector2(240, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color("#ffd27a"))
	_name.add_theme_font_size_override("font_size", 16)
	box.add_child(_name)
	_step = Label.new()
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.custom_minimum_size = Vector2(224, 0)
	_step.add_theme_font_size_override("font_size", 13)
	box.add_child(_step)
	_lines = Label.new()
	_lines.add_theme_font_size_override("font_size", 14)
	box.add_child(_lines)


func refresh(log: QuestLog, quests: QuestDB, bag: Inventory) -> void:
	var id := log.tracked
	var q := quests.quest(id)
	visible = id != "" and not q.is_empty() and log.is_active(id)
	if not visible:
		return
	_name.text = tr(str(q.name))
	_step.text = QuestText.step_text(log, quests, id)
	_lines.text = "\n".join(QuestText.objective_lines(log, quests, id, bag))


func text() -> String:
	return "\n".join([_name.text, _step.text, _lines.text])
