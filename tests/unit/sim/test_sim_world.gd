extends GutTest

var balance: Balance
var map: CollisionMap


func before_each() -> void:
	balance = Balance.load_from()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/arena.json"))
	map = CollisionMap.from_layout(data)


func _random_inputs(count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	for i in count:
		var move := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var aim := Vector3(rng.randf_range(0, 40), 0, rng.randf_range(0, 40))
		out.append(PlayerInput.new(i + 1, move, aim))
	return out


func test_world_is_deterministic() -> void:
	var inputs := _random_inputs(200, 1234)
	var a := SimWorld.new(balance, map)
	var b := SimWorld.new(balance, map)
	a.add_player(1, map.spawn_point())
	b.add_player(1, map.spawn_point())
	for input: PlayerInput in inputs:
		a.step({1: input})
		b.step({1: input.duplicate_input()})
	assert_eq(a.players[1].position, b.players[1].position)
	assert_eq(a.players[1].facing, b.players[1].facing)
	assert_eq(a.tick, 200)


func test_player_without_input_stays() -> void:
	var w := SimWorld.new(balance, map)
	w.add_player(1, map.spawn_point())
	w.add_player(2, map.spawn_point() + Vector3(2, 0, 0))
	w.step({1: PlayerInput.new(1, Vector2(1, 0), Vector3.ZERO)})
	assert_ne(w.players[1].position, map.spawn_point())
	assert_eq(w.players[2].position, map.spawn_point() + Vector3(2, 0, 0))


func test_remove_player() -> void:
	var w := SimWorld.new(balance, map)
	w.add_player(3, map.spawn_point())
	w.remove_player(3)
	assert_false(w.players.has(3))


func test_dt_matches_tick_rate() -> void:
	var w := SimWorld.new(balance, map)
	assert_almost_eq(w.dt(), 1.0 / 30.0, 0.000001)


func test_state_clone_is_independent() -> void:
	var s := PlayerState.new()
	s.id = 4
	s.position = Vector3(1, 0, 2)
	var c := s.clone()
	c.position.x = 9
	assert_eq(s.position.x, 1.0)
	assert_eq(c.id, 4)
