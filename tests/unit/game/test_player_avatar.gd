extends GutTest

const DT := 1.0 / 60.0

var avatar: PlayerAvatar


func before_each() -> void:
	avatar = PlayerAvatar.new()
	add_child_autofree(avatar)
	avatar.setup("Ana", 0, "warrior", {})
	avatar.move_speed = 5.0


func _state(pos: Vector3, facing := 0.0) -> Dictionary:
	return {"position": pos, "aim": pos, "facing": facing}


## Feeds `frames` render frames moving at `speed` m/s along X.
func _walk(frames: int, speed: float, start := Vector3.ZERO) -> Vector3:
	var pos := start
	for i in frames:
		pos += Vector3(speed * DT, 0, 0)
		avatar.apply_state(_state(pos), DT)
	return pos


func test_builds_a_character_rig() -> void:
	assert_true(avatar.rig is HumanRig)
	assert_not_null(avatar.rig)
	assert_has(avatar.rig.pieces(), "weapon_sword")
	assert_has(avatar.rig.pieces(), "pauldron_left")


func test_idle_when_still() -> void:
	for i in 30:
		avatar.apply_state(_state(Vector3(1, 0, 1)), DT)
	assert_eq(avatar.rig.current_animation(), "idle")


func test_walk_when_moving_at_move_speed() -> void:
	_walk(30, 5.0)
	assert_eq(avatar.rig.current_animation(), "walk")


func test_walk_speed_scale_matches_velocity() -> void:
	_walk(60, 2.5)
	assert_almost_eq(avatar.rig.walk_rate(), 0.5, 0.05)


## The own player's position only changes on physics ticks (30/s) while frames are
## drawn at 60/s: half the frames see no movement. That must not flicker to idle.
func test_steady_walk_at_physics_rate_does_not_flicker() -> void:
	var pos := Vector3.ZERO
	for i in 60:
		if i % 2 == 0:
			pos += Vector3(5.0 * 2 * DT, 0, 0)
		avatar.apply_state(_state(pos), DT)
		if i > 10:
			assert_eq(avatar.rig.current_animation(), "walk", "frame %d" % i)


func test_stops_walking_after_stopping() -> void:
	var pos := _walk(30, 5.0)
	for i in 30:
		avatar.apply_state(_state(pos), DT)
	assert_eq(avatar.rig.current_animation(), "idle")


func test_empty_state_keeps_idle() -> void:
	for i in 10:
		avatar.apply_state({}, DT)
	assert_eq(avatar.rig.current_animation(), "idle")


## A first state far from the origin, or a spawn jump, is not walking.
func test_teleport_jump_is_not_walking() -> void:
	avatar.apply_state(_state(Vector3(0, 0, 0)), DT)
	avatar.apply_state(_state(Vector3(3, 0, 0)), DT)
	for i in 5:
		avatar.apply_state(_state(Vector3(3, 0, 0)), DT)
	assert_eq(avatar.rig.current_animation(), "idle")


func test_faces_state_facing() -> void:
	avatar.apply_state(_state(Vector3.ZERO, 1.2), DT)
	assert_almost_eq(avatar.rotation.y, 1.2, 0.0001)


func test_action_animation_plays_then_walk_resumes() -> void:
	avatar.play_action("melee")
	assert_eq(avatar.rig.current_animation(), "melee")
	_walk(3, 5.0)
	assert_eq(avatar.rig.current_animation(), "melee", "walking does not cut the swing")
	_walk(120, 5.0)
	assert_eq(avatar.rig.current_animation(), "walk", "back to walking once it ended")


func test_dead_stays_down_until_alive_again() -> void:
	avatar.play_action("die")
	_walk(200, 0.0)
	assert_eq(avatar.rig.current_animation(), "die")
	avatar.set_health(100.0, 100.0, true)
	_walk(5, 0.0)
	assert_eq(avatar.rig.current_animation(), "idle")


func test_downed_stays_down_and_does_not_walk() -> void:
	avatar.play_action("downed")
	_walk(200, 5.0)
	assert_eq(avatar.rig.current_animation(), "downed")
	avatar.set_health(100.0, 100.0, true)
	_walk(5, 0.0)
	assert_eq(avatar.rig.current_animation(), "idle")


func test_unknown_action_is_ignored() -> void:
	avatar.play_action("teleport_to_moon")
	assert_eq(avatar.rig.current_animation(), "idle")
