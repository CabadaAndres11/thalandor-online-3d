class_name LoadingOverlay
extends Control
## The short loading screen between zones (Plan 8.1): the zone's name in gold over a dark
## screen, until the first snapshot of the new zone arrives.

var title: Label


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 0.96)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	title = StoneTheme.title("", 56)
	title.set_anchors_preset(PRESET_CENTER)
	title.grow_horizontal = GROW_DIRECTION_BOTH
	title.grow_vertical = GROW_DIRECTION_BOTH
	add_child(title)


func show_zone(name_key: String) -> void:
	title.text = tr(name_key)
	visible = true


func hide_overlay() -> void:
	visible = false
