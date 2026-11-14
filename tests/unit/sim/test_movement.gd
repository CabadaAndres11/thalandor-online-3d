extends GutTest

var balance: Balance
var open_map: CollisionMap


func before_each() -> void:
	balance = Balance.load_from()
	open_map = CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})


func _state_at(pos: Vector3) -> PlayerState:
	var s := PlayerState.new()
	s.position = pos
	return s


func _run(state: PlayerState, move: Vector2, seconds: float, map: CollisionMap, aim := Vector3.ZERO) -> void:
	var ticks := int(round(seconds * balance.tick_rate))
	for i in ticks:
		Movement.apply(state, PlayerInput.new(i + 1, move, aim), balance.dt(), balance, map)


func test_moves_at_move_speed() -> void:
	var s := _state_at(Vector3(10.5, 0, 20.5))
	_run(s, Vector2(1, 0), 1.0, open_map)
	assert_almost_eq(s.position.x, 15.5, 0.01)
	assert_almost_eq(s.position.z, 20.5, 0.0001)


func test_diagonal_is_normalized() -> void:
	var start := Vector3(10.5, 0, 10.5)
	var s := _state_at(start)
	_run(s, Vector2(1, 1), 1.0, open_map)
	assert_almost_eq(s.position.distance_to(start), 5.0, 0.01)


func test_cannot_enter_solid_cell() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [0, 0], "blocks": [[15, 20, 1]]})
	var s := _state_at(Vector3(12.5, 0, 20.5))
	for i in 60:
		Movement.apply(s, PlayerInput.new(i + 1, Vector2(1, 0), Vector3.ZERO), balance.dt(), balance, map)
		assert_true(s.position.x + balance.player_radius <= 15.0 + 0.0001, "circle edge entered the block")
	assert_almost_eq(s.position.x, 15.0 - balance.player_radius, 0.01)


func test_slides_along_wall() -> void:
	var blocks := []
	for z in 40:
		blocks.append([15, z, 1])
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [0, 0], "blocks": blocks})
	var s := _state_at(Vector3(14.0, 0, 10.5))
	_run(s, Vector2(1, 1), 1.0, map)
	assert_almost_eq(s.position.x, 15.0 - balance.player_radius, 0.01)
	assert_gt(s.position.z, 12.5)


## Regression: grazing a block's side while moving along it, float rounding made the
## other axis think it was inside the block and pushed the player out of its far face
## (a 1-2 m jump back), cell after cell.
func test_never_jumps_further_than_a_step() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20],
		"blocks": [[26, 15, 3], [26, 16, 3], [14, 14, 1], [15, 14, 1]]})
	var max_step := balance.move_speed * balance.dt() + 0.0001
	var worst := 0.0
	var deepest := 0.0
	for start: Vector3 in [Vector3(20.5, 0, 20.5), Vector3(25.3, 0, 18.2), Vector3(27.1, 0, 13.4),
			Vector3(16.5, 0, 16.0), Vector3(13.2, 0, 12.7)]:
		for angle in range(0, 360, 15):
			var move := Vector2.from_angle(deg_to_rad(angle))
			var s := _state_at(start)
			for i in 90:
				var before := s.position
				Movement.apply(s, PlayerInput.new(i + 1, move, Vector3.ZERO), balance.dt(), balance, map)
				worst = maxf(worst, before.distance_to(s.position))
				deepest = maxf(deepest, _penetration(s.position, map))
	assert_lte(worst, max_step, "largest single-tick displacement")
	assert_lte(deepest, 0.002, "deepest overlap with a solid cell")


## How far the player's circle at `pos` overlaps the nearest solid cell (0 = none).
func _penetration(pos: Vector3, map: CollisionMap) -> float:
	var r := balance.player_radius
	var deepest := 0.0
	for cz in range(floori(pos.z - r) - 1, floori(pos.z + r) + 2):
		for cx in range(floori(pos.x - r) - 1, floori(pos.x + r) + 2):
			if map.is_solid(Vector2i(cx, cz)):
				var nearest := Vector2(clampf(pos.x, cx, cx + 1), clampf(pos.z, cz, cz + 1))
				deepest = maxf(deepest, r - nearest.distance_to(Vector2(pos.x, pos.z)))
	return deepest


func test_grazing_a_wall_side_keeps_moving_along_it() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [[26, 15, 3], [26, 16, 3]]})
	# Touching the blocks' west face (with rounding noise), walking north-east.
	var s := _state_at(Vector3(26.0 - balance.player_radius + 0.0000004, 0, 16.9))
	var move := Vector2(1, -1).normalized()
	for i in 30:
		var before_z := s.position.z
		Movement.apply(s, PlayerInput.new(i + 1, move, Vector3.ZERO), balance.dt(), balance, map)
		assert_true(s.position.z <= before_z, "never pushed backwards (tick %d: %f -> %f)" % [i, before_z, s.position.z])


## Regression: walking diagonally against a straight wall (it looks diagonal under the
## isometric camera) must slide along it. Touching the wall, float rounding left a
## tiny overlap with the next wall cell, so the player stopped at every block joint.
## Tried from many start offsets (different roundings), all four wall sides.
func test_slides_along_walls_from_any_start() -> void:
	var cells := []
	for i in 40:
		cells.append([20, i, 1]) # wall perpendicular to X (column x = 20)
		cells.append([i, 20, 1]) # wall perpendicular to Z (row z = 20)
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [0, 0], "blocks": cells})
	var cases := [
		# start (before the wall), diagonal move into it, axis that must advance
		[Vector3(17.0, 0, 3.0), Vector2(1, 1), "z"], # left of column, sliding +z
		[Vector3(17.0, 0, 15.0), Vector2(1, -1), "z"], # sliding -z
		[Vector3(23.0, 0, 3.0), Vector2(-1, 1), "z"], # right of column
		[Vector3(3.0, 0, 17.0), Vector2(1, 1), "x"], # above row, sliding +x
		[Vector3(15.0, 0, 23.0), Vector2(-1, -1), "x"], # below row, sliding -x
	]
	for c: Array in cases:
		for k in 25:
			var start: Vector3 = c[0] + Vector3(k * 0.0137, 0, k * 0.0071)
			var s := _state_at(start)
			_run(s, (c[1] as Vector2).normalized(), 1.5, map)
			var advanced := absf(s.position.z - start.z) if c[2] == "z" else absf(s.position.x - start.x)
			# Free sliding covers 5 m/s * 0.707 * 1.5 s ≈ 5.3 m; stuck stops near the first joint.
			assert_gt(advanced, 4.5, "slid along the wall from %s moving %s" % [start, c[1]])


func test_large_step_does_not_tunnel() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [0, 0], "blocks": [[15, 20, 1]]})
	var s := _state_at(Vector3(14.0, 0, 20.5))
	Movement.apply(s, PlayerInput.new(1, Vector2(1, 0), Vector3.ZERO), 0.5, balance, map)
	assert_lt(s.position.x, 15.0)


func test_stays_inside_map_border() -> void:
	var s := _state_at(Vector3(0.5, 0, 0.5))
	_run(s, Vector2(-1, -1), 1.0, open_map)
	assert_almost_eq(s.position.x, balance.player_radius, 0.01)
	assert_almost_eq(s.position.z, balance.player_radius, 0.01)


func test_faces_aim_point() -> void:
	var s := _state_at(Vector3(10, 0, 10))
	Movement.apply(s, PlayerInput.new(1, Vector2.ZERO, Vector3(15, 0, 10)), balance.dt(), balance, open_map)
	assert_almost_eq(s.facing, PI / 2.0, 0.0001)
	assert_eq(s.aim, Vector3(15, 0, 10))
	Movement.apply(s, PlayerInput.new(2, Vector2.ZERO, Vector3(10, 0, 15)), balance.dt(), balance, open_map)
	assert_almost_eq(s.facing, 0.0, 0.0001)


func test_keeps_facing_when_aim_is_on_player() -> void:
	var s := _state_at(Vector3(10, 0, 10))
	s.facing = 1.0
	Movement.apply(s, PlayerInput.new(1, Vector2.ZERO, Vector3(10.001, 0, 10)), balance.dt(), balance, open_map)
	assert_almost_eq(s.facing, 1.0, 0.0001)


func test_long_move_vector_is_clamped() -> void:
	var s := _state_at(Vector3(10.5, 0, 20.5))
	_run(s, Vector2(10, 0), 1.0, open_map)
	assert_almost_eq(s.position.x, 15.5, 0.01)
