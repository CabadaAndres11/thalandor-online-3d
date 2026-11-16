class_name LockIcon
extends Control
## A small padlock drawn in the top-right corner of its parent (locked abilities).

const SIZE := Vector2(16, 18)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	set_anchors_preset(PRESET_TOP_RIGHT)
	offset_left = -SIZE.x - 4
	offset_right = -4
	offset_top = 4
	offset_bottom = 4 + SIZE.y


func _draw() -> void:
	var gold := Color("#e8c66a")
	draw_arc(Vector2(8, 7), 4.5, PI, TAU, 12, gold, 2.0)
	draw_rect(Rect2(1, 7, 14, 10), gold)
	draw_rect(Rect2(7, 10, 2, 4), Color(0.1, 0.1, 0.12))
