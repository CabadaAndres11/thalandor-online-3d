class_name IsoCamera
extends Camera3D
## Isometric follow camera: fixed pitch and yaw, mouse-wheel zoom, F9 toggles
## perspective/orthographic projection.

@export var pitch_deg: float = 55.0
@export var yaw_deg: float = 45.0
@export var distance: float = 18.0
@export var min_distance: float = 10.0
@export var max_distance: float = 30.0
@export var zoom_step: float = 1.5

var _target: Vector3 = Vector3.ZERO


func _ready() -> void:
	fov = 40.0
	far = 200.0
	_apply()


func follow(target: Vector3) -> void:
	_target = target
	_apply()


func yaw() -> float:
	return deg_to_rad(yaw_deg)


func zoom(steps: float) -> void:
	distance = clampf(distance + steps * zoom_step, min_distance, max_distance)
	_apply()


func toggle_projection() -> void:
	projection = PROJECTION_ORTHOGONAL if projection == PROJECTION_PERSPECTIVE else PROJECTION_PERSPECTIVE
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1)
	elif event.is_action_pressed("toggle_projection"):
		toggle_projection()


func _apply() -> void:
	var pitch := deg_to_rad(pitch_deg)
	var y := yaw()
	var offset := Vector3(sin(y) * cos(pitch), sin(pitch), cos(y) * cos(pitch)) * distance
	var eye := _target + offset
	transform = Transform3D(Basis.looking_at(_target - eye, Vector3.UP), eye)
	# Same framing in orthographic mode: visible height at the target distance.
	size = 2.0 * distance * tan(deg_to_rad(fov) / 2.0)
