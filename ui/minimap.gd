class_name Minimap
extends Control
## The minimap (Plan 8.1.1): a square under the icon bar, centred on the player and turned
## with the camera (where it looks is up), with an N on the edge and the zone's name.

const SIZE := 180.0
## Cells (metres) across the square.
const SPAN := 44.0

var center: Vector2 = Vector2.ZERO
var zone_label: Label
var _texture: Texture2D
var _marks: Array = []
var _yaw: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE
	zone_label = Label.new()
	zone_label.add_theme_font_size_override("font_size", 15)
	zone_label.add_theme_color_override("font_color", HoloTheme.ACCENT)
	zone_label.add_theme_constant_override("outline_size", 4)
	zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zone_label.position = Vector2(6, 2)
	add_child(zone_label)


## centre: the player's cell; cam_yaw: IsoCamera.yaw().
func refresh(texture: Texture2D, marks: Array, p_center: Vector2, cam_yaw: float, zone_name: String = "") -> void:
	_texture = texture
	_marks = marks
	center = p_center
	_yaw = cam_yaw
	if zone_name != "":
		zone_label.text = tr(zone_name)
	queue_redraw()


## The camera looks along (-sin yaw, -cos yaw) on the ground: turned to screen up.
func map_rotation() -> float:
	var fwd := Vector2(-sin(_yaw), -cos(_yaw))
	return -PI / 2.0 - fwd.angle()


func _draw() -> void:
	var half := Vector2(SIZE, SIZE) / 2.0
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.04, 0.08, 0.16, 0.85))
	if _texture == null:
		return
	var per_cell := SIZE / SPAN
	var turn := map_rotation()
	draw_set_transform(half, turn, Vector2.ONE * per_cell / ZoneMapImage.PX)
	draw_texture(_texture, -center * ZoneMapImage.PX)
	draw_set_transform(Vector2.ZERO)
	for m: Dictionary in _marks:
		var at: Vector2 = half + ((m.cell as Vector2) - center).rotated(turn) * per_cell
		if Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)).grow(-4).has_point(at):
			MapMarks.draw(self, m, at, 4.0 if m.kind != "self" else 5.0, turn)
	# North (map -z) on the edge.
	var north := half + Vector2(0, -1).rotated(turn) * (SIZE / 2.0 - 10.0)
	draw_string(HoloTheme.font(), north + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HoloTheme.ACCENT)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), HoloTheme.BORDER, false, 2.0)
