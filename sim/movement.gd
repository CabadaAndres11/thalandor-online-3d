class_name Movement
extends RefCounted
## Pure, deterministic player movement with circle-vs-grid collision.

const MIN_AIM_DISTANCE := 0.01
## Tolerance for "was outside this face before the step" (float rounding).
const FACE_EPSILON := 0.001
## A circle touching a cell side within this distance only grazes it: it does not
## block movement along that side (float rounding leaves tiny overlaps when sliding).
const CONTACT_EPSILON := 0.001


static func apply(state: PlayerState, input: PlayerInput, dt: float, balance: Balance, map: CollisionMap,
		speed_mult: float = 1.0) -> void:
	_start_dodge(state, input, balance, speed_mult)
	if state.dash_ticks > 0:
		# Dodge: a short dash at fixed speed, ignoring the movement keys.
		var per_tick := balance.dodge_distance / float(balance.ticks(balance.dodge_s))
		state.position = move_circle(state.position, state.dash_dir * per_tick, balance.player_radius, map)
		state.dash_ticks -= 1
	else:
		var dir := input.move.limit_length(1.0)
		var delta := dir * balance.move_speed * speed_mult * dt
		state.position = move_circle(state.position, delta, balance.player_radius, map)
	state.aim = input.aim
	var to_aim := Vector2(input.aim.x - state.position.x, input.aim.z - state.position.z)
	if to_aim.length() > MIN_AIM_DISTANCE and not state.lock_facing:
		state.facing = atan2(to_aim.x, to_aim.y)


## Dodge (Space): toward the movement direction, or the aim when standing still.
## Its cooldown is counted in input sequence numbers, the same on the client
## (prediction) and on the host. Can't dodge while rooted, stunned or frozen.
static func _start_dodge(state: PlayerState, input: PlayerInput, balance: Balance, speed_mult: float) -> void:
	if not input.pressed(PlayerInput.BTN_DODGE) or state.dash_ticks > 0 or speed_mult <= 0.0:
		return
	if input.seq < state.dodge_ready_seq:
		return
	var dir := input.move
	if dir.length() < 0.1:
		dir = Vector2(input.aim.x - state.position.x, input.aim.z - state.position.z)
	if dir.length() < 0.01:
		dir = Vector2(sin(state.facing), cos(state.facing))
	state.dash_dir = dir.normalized()
	state.dash_ticks = balance.ticks(balance.dodge_s)
	state.dodge_ready_seq = input.seq + balance.ticks(balance.dodge_cooldown_s)
	state.dodge_started = true


## Moves a circle of `radius` by `delta` (world XZ) with sliding collision against
## solid cells, in sub-steps so it never tunnels. Used by players, dashes, monsters.
static func move_circle(position: Vector3, delta: Vector2, radius: float, map: CollisionMap) -> Vector3:
	var steps := maxi(1, ceili(delta.length() / (radius * 0.5)))
	var step := delta / float(steps)
	var x := position.x
	var z := position.z
	for i in steps:
		if step.x != 0.0:
			x = _resolve_x(x + step.x, z, step.x, radius, map)
		if step.y != 0.0:
			z = _resolve_z(x, z + step.y, step.y, radius, map)
	return Vector3(x, position.y, z)


## Moves along one axis and stops at the face of any solid cell the circle crosses in this
## step. Only faces approached from outside count: a circle grazing a cell's side (it
## overlaps by a rounding error) must not be pushed out of the cell's far face.
static func _resolve_x(x: float, z: float, dx: float, r: float, map: CollisionMap) -> float:
	var prev := x - dx
	for cz in range(floori(z - r), floori(z + r) + 1):
		for cx in range(floori(x - r), floori(x + r) + 1):
			if not map.is_solid(Vector2i(cx, cz)):
				continue
			var off_z := z - clampf(z, cz, cz + 1)
			if absf(off_z) >= r - CONTACT_EPSILON:
				continue
			var reach := sqrt(r * r - off_z * off_z)
			if dx > 0.0 and x + reach > cx and prev + reach <= cx + FACE_EPSILON:
				x = cx - reach
			elif dx < 0.0 and x - reach < cx + 1 and prev - reach >= cx + 1 - FACE_EPSILON:
				x = cx + 1 + reach
	return x


static func _resolve_z(x: float, z: float, dz: float, r: float, map: CollisionMap) -> float:
	var prev := z - dz
	for cx in range(floori(x - r), floori(x + r) + 1):
		for cz in range(floori(z - r), floori(z + r) + 1):
			if not map.is_solid(Vector2i(cx, cz)):
				continue
			var off_x := x - clampf(x, cx, cx + 1)
			if absf(off_x) >= r - CONTACT_EPSILON:
				continue
			var reach := sqrt(r * r - off_x * off_x)
			if dz > 0.0 and z + reach > cz and prev + reach <= cz + FACE_EPSILON:
				z = cz - reach
			elif dz < 0.0 and z - reach < cz + 1 and prev - reach >= cz + 1 - FACE_EPSILON:
				z = cz + 1 + reach
	return z
