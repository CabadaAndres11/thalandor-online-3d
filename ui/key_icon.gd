class_name KeyIcon
extends Control
## The icon of the key or mouse button an action is bound to, small enough for a slot:
## a keycap with its letter, a wide keycap with the space symbol, or a mouse with the
## pressed button lit. Numbers are not drawn here (a slot shows only its number).

const KEYCAP := Color(0.1, 0.17, 0.3, 0.92)
const EDGE := Color(0.55, 0.8, 1.0, 0.9)
const LIT := Color(1.0, 0.82, 0.4)

var kind: String = "key" # key, space, mouse_left, mouse_right, mouse_middle
var text: String = ""


## {"kind", "text"} for what an action is bound to (the first binding).
static func describe(action: String) -> Dictionary:
	var events: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	for ev: InputEvent in events:
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return {"kind": "mouse_left", "text": ""}
				MOUSE_BUTTON_RIGHT:
					return {"kind": "mouse_right", "text": ""}
				_:
					return {"kind": "mouse_middle", "text": ""}
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if code == KEY_SPACE:
				return {"kind": "space", "text": ""}
			return {"kind": "key", "text": OS.get_keycode_string(code)}
	return {"kind": "key", "text": "?"}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func show_action(action: String) -> void:
	var d := describe(action)
	kind = d.kind
	text = d.text
	custom_minimum_size = size_for(kind, text)
	size = custom_minimum_size
	queue_redraw()


static func size_for(k: String, t: String) -> Vector2:
	match k:
		"space":
			return Vector2(34, 14)
		"mouse_left", "mouse_right", "mouse_middle":
			return Vector2(15, 20)
	return Vector2(maxf(16.0, 8.0 * float(t.length()) + 8.0), 16)


func _draw() -> void:
	match kind:
		"mouse_left", "mouse_right", "mouse_middle":
			_draw_mouse()
		"space":
			_draw_cap()
			var c := size / 2.0
			var col := EDGE
			draw_polyline(PackedVector2Array([Vector2(c.x - 9, c.y - 2), Vector2(c.x - 9, c.y + 2),
				Vector2(c.x + 9, c.y + 2), Vector2(c.x + 9, c.y - 2)]), col, 1.6) # the space symbol
		_:
			_draw_cap()
			var font := get_theme_default_font()
			var fs := 11
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_cap() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = KEYCAP
	s.border_color = EDGE
	s.set_border_width_all(1)
	s.border_width_bottom = 2 # the thickness of a keycap
	s.set_corner_radius_all(3)
	draw_style_box(s, Rect2(Vector2.ZERO, size))


func _draw_mouse() -> void:
	var body := StyleBoxFlat.new()
	body.bg_color = KEYCAP
	body.border_color = EDGE
	body.set_border_width_all(1)
	body.set_corner_radius_all(6)
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var half := size.x / 2.0
	var top := size.y * 0.5
	match kind:
		"mouse_left":
			draw_rect(Rect2(1, 1, half - 1, top - 1), LIT)
		"mouse_right":
			draw_rect(Rect2(half, 1, half - 1, top - 1), LIT)
		_:
			draw_rect(Rect2(half - 1.5, 2, 3, top - 3), LIT)
	draw_line(Vector2(half, 1), Vector2(half, top), EDGE, 1.0)
	draw_line(Vector2(1, top), Vector2(size.x - 1, top), EDGE, 1.0)
