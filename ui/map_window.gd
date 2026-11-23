class_name MapWindow
extends Control
## The zone map (M, Plan 8.1.1): the whole zone, no scroll, with you, your party, the
## NPCs, the ways out (named) and the dungeon doors, and a legend.

const MAX_MAP := Vector2(980, 560)

var title: Label
var _panel: PanelContainer
var _canvas: Control
var _texture: Texture2D
var _marks: Array = []


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	_panel.mouse_filter = MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	title = HoloTheme.title("", 26)
	box.add_child(title)
	_canvas = Control.new()
	_canvas.draw.connect(_draw_map)
	box.add_child(_canvas)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 18)
	box.add_child(legend)
	for pair: Array in MapMarks.LEGEND:
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var kind: String = pair[0]
		dot.draw.connect(func() -> void: MapMarks.draw(dot, {"kind": kind, "yaw": PI}, Vector2(8, 8), 5.0))
		legend.add_child(dot)
		var l := Label.new()
		l.text = tr(pair[1])
		l.add_theme_font_size_override("font_size", 15)
		legend.add_child(l)


## Fills the map (zone picture, marks, zone name key).
func refresh(texture: Texture2D, marks: Array, zone_name: String) -> void:
	_texture = texture
	_marks = marks
	title.text = tr(zone_name)
	if texture != null:
		var s := Vector2(texture.get_size())
		_canvas.custom_minimum_size = s * minf(MAX_MAP.x / s.x, MAX_MAP.y / s.y)
	_canvas.queue_redraw()
	_place()


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _place() -> void:
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_panel.position = (view - size) / 2.0


func _draw_map() -> void:
	if _texture == null:
		return
	var area := Rect2(Vector2.ZERO, _canvas.size)
	_canvas.draw_texture_rect(_texture, area, false)
	var per_cell := _canvas.size.x / (_texture.get_size().x / float(ZoneMapImage.PX))
	for m: Dictionary in _marks:
		var at: Vector2 = (m.cell as Vector2) * per_cell
		MapMarks.draw(_canvas, m, at, 6.0)
		if str(m.label) != "" and m.kind != "self":
			var w := HoloTheme.font().get_string_size(str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var pos := at + Vector2(9, 5) if at.x + 9 + w <= _canvas.size.x else at + Vector2(-9 - w, 5) # inside the map
			_canvas.draw_string(HoloTheme.font(), pos, str(m.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HoloTheme.TEXT)
