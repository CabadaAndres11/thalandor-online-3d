class_name IsoCamera
extends Camera3D
## Follow camera with two modes (F9 toggles): isometric (fixed pitch and yaw) and third person
## (low and close; Z/X or the middle mouse button turn it). Mouse-wheel zoom in both.

enum Mode { ISOMETRIC, THIRD_PERSON }

const ISO := {"pitch": 55.0, "distance": 18.0, "min": 10.0, "max": 30.0, "fov": 40.0}
const THIRD := {"pitch": 42.0, "distance": 9.0, "min": 4.0, "max": 16.0, "fov": 65.0}
const TURN_SPEED := 2.2 # rad/s with Z/X
const DRAG_SENSITIVITY := 0.006 # rad/px with the middle button

@export var pitch_deg: float = 55.0
@export var yaw_deg: float = 45.0
@export var distance: float = 18.0
@export var min_distance: float = 10.0
@export var max_distance: float = 30.0
@export var zoom_step: float = 1.5

var mode: Mode = Mode.ISOMETRIC
## The zone (in cells = metres); the followed point stays BOUNDS_INSET inside it so the
## view never reaches the void past the zone's margin (Plan 8.1.1). Empty: no limit.
var bounds: Rect2 = Rect2()
const BOUNDS_INSET := 6.0
## How far inside the bounds the followed point stays (a zone's edge band, Plan 8.1.2).
var inset: float = BOUNDS_INSET
var _target: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _distances: Dictionary = {Mode.ISOMETRIC: 18.0, Mode.THIRD_PERSON: 9.0}
## Closer while talking (Plan 8.2): 1 = the normal distance.
var focus_factor: float = 1.0


func _ready() -> void:
	fov = 40.0
	far = 200.0
	_apply()


func follow(target: Vector3) -> void:
	_target = target
	if bounds.has_area():
		var inner := bounds.grow(-inset)
		_target.x = clampf(target.x, inner.position.x, inner.end.x)
		_target.z = clampf(target.z, inner.position.y, inner.end.y)
	_apply()


## The point the camera looks at (after the bounds).
func target() -> Vector3:
	return _target


func yaw() -> float:
	return deg_to_rad(yaw_deg)


func zoom(steps: float) -> void:
	distance = clampf(distance + steps * zoom_step, min_distance, max_distance)
	_distances[mode] = distance
	_apply()


## Comes a little closer for a conversation (amount 0..1 of the distance taken off), or back.
func focus(on: bool, amount: float = 0.3) -> void:
	focus_factor = 1.0 - amount if on else 1.0
	_apply()


func turn(radians: float) -> void:
	if mode == Mode.THIRD_PERSON:
		yaw_deg = fmod(yaw_deg + rad_to_deg(radians), 360.0)
		_apply()


## Isometric <-> third person. Third person keeps its own zoom; the isometric view is
## always the same fixed view (corner, height and zoom).
func toggle_mode() -> void:
	_distances[mode] = distance
	mode = Mode.THIRD_PERSON if mode == Mode.ISOMETRIC else Mode.ISOMETRIC
	var cfg: Dictionary = ISO if mode == Mode.ISOMETRIC else THIRD
	pitch_deg = cfg.pitch
	min_distance = cfg.min
	max_distance = cfg.max
	distance = _distances[mode]
	fov = cfg.fov
	if mode == Mode.ISOMETRIC:
		yaw_deg = 45.0 # the isometric view always looks from the same corner
		distance = ISO.distance
	_apply()


func _process(delta: float) -> void:
	if mode != Mode.THIRD_PERSON:
		return
	var dir := Input.get_axis("camera_left", "camera_right")
	if dir != 0.0:
		turn(dir * TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1)
	elif event is InputEventMouseMotion and _dragging:
		turn(-(event as InputEventMouseMotion).relative.x * DRAG_SENSITIVITY)
	elif event.is_action_pressed("toggle_camera"):
		toggle_mode()


func _apply() -> void:
	var pitch := deg_to_rad(pitch_deg)
	var y := yaw()
	var offset := Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch)) * distance * focus_factor
	var eye := _target + offset
	# Third person looks a little above the feet so the character sits low on screen.
	var look_at_point := _target + (Vector3(0, 1.2, 0) if mode == Mode.THIRD_PERSON else Vector3.ZERO)
	transform = Transform3D(Basis.looking_at(look_at_point - eye, Vector3.UP), eye)
	size = 2.0 * distance * tan(deg_to_rad(fov) / 2.0)
