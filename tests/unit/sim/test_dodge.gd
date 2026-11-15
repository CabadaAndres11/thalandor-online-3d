extends GutTest

var world: SimWorld
var p: PlayerState
var seq := 0


func before_each() -> void:
	world = SimWorld.new(Balance.load_from(), CollisionMap.from_layout({"size": [30, 30], "spawn": [5, 5], "blocks": []}))
	p = world.add_player(1, Vector3(10, 0, 10))
	p.stats = CombatStats.from_dict({"max_hp": 100})
	p.hp = 100.0
	seq = 0


func _step(move: Vector2, buttons := 0, aim := Vector3(10, 0, 20)) -> void:
	seq += 1
	world.step({1: PlayerInput.new(seq, move, aim, buttons)})


func test_dodge_dash_distance_and_invulnerability() -> void:
	_step(Vector2(1, 0), PlayerInput.BTN_DODGE)
	assert_true(p.has_status("invulnerable"), "invulnerable right away")
	for i in world.ticks(world.balance.dodge_s) - 1:
		_step(Vector2(1, 0))
	assert_almost_eq(p.position.x, 10.0 + world.balance.dodge_distance, 0.05)
	for i in world.ticks(world.balance.dodge_invuln_s):
		_step(Vector2.ZERO)
	assert_false(p.has_status("invulnerable"), "only briefly")


func test_dodge_cooldown() -> void:
	_step(Vector2(1, 0), PlayerInput.BTN_DODGE)
	for i in 10:
		_step(Vector2.ZERO)
	var x := p.position.x
	_step(Vector2(1, 0), PlayerInput.BTN_DODGE)
	for i in 6:
		_step(Vector2.ZERO)
	assert_almost_eq(p.position.x, x + world.balance.move_speed * world.dt(), 0.01, "on cooldown: just a normal step")
	for i in world.ticks(world.balance.dodge_cooldown_s):
		_step(Vector2.ZERO)
	_step(Vector2(1, 0), PlayerInput.BTN_DODGE)
	assert_gt(p.dash_ticks, 0, "ready again")


func test_dodge_toward_aim_when_standing_still() -> void:
	_step(Vector2.ZERO, PlayerInput.BTN_DODGE, Vector3(10, 0, 20))
	for i in world.ticks(world.balance.dodge_s):
		_step(Vector2.ZERO)
	assert_gt(p.position.z, 12.5)


func test_cannot_dodge_while_rooted() -> void:
	p.add_status(StatusEffect.make("root", world.tick + 60), 1)
	_step(Vector2(1, 0), PlayerInput.BTN_DODGE)
	assert_eq(p.dash_ticks, 0)
	assert_eq(p.position.x, 10.0)
