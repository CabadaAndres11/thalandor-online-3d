class_name Movement
extends RefCounted
## Pure, deterministic player movement with circle-vs-grid collision.

const MIN_AIM_DISTANCE := 0.01


static func apply(state: PlayerState, input: PlayerInput, dt: float, balance: Balance, map: CollisionMap) -> void:
	var dir := input.move.limit_length(1.0)
	var delta := dir * balance.move_speed * dt
	var radius := balance.player_radius
	var steps := maxi(1, ceili(delta.length() / (radius * 0.5)))
	var step := delta / float(steps)
	var x := state.position.x
	var z := state.position.z
	for i in steps:
		if step.x != 0.0:
			x = _resolve_x(x + step.x, z, step.x, radius, map)
		if step.y != 0.0:
			z = _resolve_z(x, z + step.y, step.y, radius, map)
	state.position = Vector3(x, state.position.y, z)
	state.aim = input.aim
	var to_aim := Vector2(input.aim.x - x, input.aim.z - z)
	if to_aim.length() > MIN_AIM_DISTANCE:
		state.facing = atan2(to_aim.x, to_aim.y)


static func _resolve_x(x: float, z: float, dx: float, r: float, map: CollisionMap) -> float:
	for cz in range(floori(z - r), floori(z + r) + 1):
		for cx in range(floori(x - r), floori(x + r) + 1):
			if not map.is_solid(Vector2i(cx, cz)):
				continue
			var off_z := z - clampf(z, cz, cz + 1)
			if absf(off_z) >= r:
				continue
			var reach := sqrt(r * r - off_z * off_z)
			if dx > 0.0 and x + reach > cx and x < cx + 1:
				x = cx - reach
			elif dx < 0.0 and x - reach < cx + 1 and x > cx:
				x = cx + 1 + reach
	return x


static func _resolve_z(x: float, z: float, dz: float, r: float, map: CollisionMap) -> float:
	for cx in range(floori(x - r), floori(x + r) + 1):
		for cz in range(floori(z - r), floori(z + r) + 1):
			if not map.is_solid(Vector2i(cx, cz)):
				continue
			var off_x := x - clampf(x, cx, cx + 1)
			if absf(off_x) >= r:
				continue
			var reach := sqrt(r * r - off_x * off_x)
			if dz > 0.0 and z + reach > cz and z < cz + 1:
				z = cz - reach
			elif dz < 0.0 and z - reach < cz + 1 and z > cz:
				z = cz + 1 + reach
	return z
