class_name InputReader
extends RefCounted
## Converts keyboard/mouse input into simulation input.
## Camera convention: yaw 0 = camera on +Z looking toward -Z (screen-up = world -Z).


## raw: x = right, y = up on screen (W = +y). Returns a world XZ direction, length <= 1.
static func camera_relative_move(raw: Vector2, camera_yaw: float) -> Vector2:
	var up := Vector2(-sin(camera_yaw), -cos(camera_yaw))
	var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
	return (right * raw.x + up * raw.y).limit_length(1.0)


## Intersection of a ray with the horizontal plane y = ground_y, or null if it never hits.
static func ground_point(origin: Vector3, direction: Vector3, ground_y: float = 0.0) -> Variant:
	if direction.y >= -0.00001:
		return null
	var t := (ground_y - origin.y) / direction.y
	if t < 0.0:
		return null
	return origin + direction * t


## Current WASD state as a screen-space vector (x = right, y = up).
static func read_raw() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_down", "move_up")
