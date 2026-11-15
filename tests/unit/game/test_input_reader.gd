extends GutTest
## Camera convention: with yaw 0 the camera sits on +Z looking toward -Z, so screen-up
## is world -Z and screen-right is world +X. Yaw rotates the camera around Y.


func test_w_moves_screen_up_with_yaw_0() -> void:
	var m := InputReader.camera_relative_move(Vector2(0, 1), 0.0)
	assert_almost_eq(m.x, 0.0, 0.001)
	assert_almost_eq(m.y, -1.0, 0.001)


func test_w_moves_screen_up() -> void:
	var m := InputReader.camera_relative_move(Vector2(0, 1), deg_to_rad(45.0))
	assert_almost_eq(m.x, -0.707, 0.001)
	assert_almost_eq(m.y, -0.707, 0.001)


func test_d_moves_screen_right() -> void:
	var m := InputReader.camera_relative_move(Vector2(1, 0), deg_to_rad(45.0))
	assert_almost_eq(m.x, 0.707, 0.001)
	assert_almost_eq(m.y, -0.707, 0.001)


func test_diagonal_input_clamped() -> void:
	var m := InputReader.camera_relative_move(Vector2(1, 1), deg_to_rad(45.0))
	assert_almost_eq(m.length(), 1.0, 0.001)


func test_ground_point_hits_plane() -> void:
	var p: Variant = InputReader.ground_point(Vector3(0, 10, 0), Vector3(1, -1, 0).normalized())
	assert_almost_eq((p as Vector3).distance_to(Vector3(10, 0, 0)), 0.0, 0.001)


func test_ground_point_parallel_ray_is_null() -> void:
	assert_null(InputReader.ground_point(Vector3(0, 10, 0), Vector3(1, 0, 0)))


func test_ground_point_upward_ray_is_null() -> void:
	assert_null(InputReader.ground_point(Vector3(0, 10, 0), Vector3(0, 1, 0)))


func test_read_buttons_maps_actions_to_bits() -> void:
	InputSetup.ensure_actions()
	Input.action_press("attack_basic")
	Input.action_press("dodge")
	Input.action_press("slot_3")
	var b := InputReader.read_buttons()
	Input.action_release("attack_basic")
	Input.action_release("dodge")
	Input.action_release("slot_3")
	assert_true(b & PlayerInput.BTN_BASIC != 0, "basic pressed")
	assert_true(b & PlayerInput.BTN_BASIC_HELD != 0, "basic held")
	assert_true(b & PlayerInput.BTN_DODGE != 0)
	assert_true(b & PlayerInput.BTN_SLOT3 != 0)
	assert_eq(b & PlayerInput.BTN_SECONDARY, 0)


func test_default_bindings_include_combat_actions() -> void:
	InputSetup.ensure_actions()
	for action: String in ["attack_basic", "attack_secondary", "slot_1", "slot_2", "slot_3", "slot_4", "dodge", "interact"]:
		assert_true(InputMap.has_action(action), action)
		assert_false(InputMap.action_get_events(action).is_empty(), action)
