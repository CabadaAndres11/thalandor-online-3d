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
