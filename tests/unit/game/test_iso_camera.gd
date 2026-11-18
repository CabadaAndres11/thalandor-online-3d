extends GutTest

var cam: IsoCamera


func before_each() -> void:
	cam = IsoCamera.new()
	add_child_autofree(cam)
	cam.follow(Vector3(10, 0, 10))


func test_f9_toggles_between_isometric_and_third_person() -> void:
	assert_eq(cam.mode, IsoCamera.Mode.ISOMETRIC)
	var iso_height := cam.global_position.y
	cam.toggle_mode()
	assert_eq(cam.mode, IsoCamera.Mode.THIRD_PERSON)
	assert_lt(cam.global_position.y, iso_height, "lower")
	assert_lt(cam.global_position.distance_to(Vector3(10, 0, 10)), 12.0, "closer")
	cam.toggle_mode()
	assert_eq(cam.mode, IsoCamera.Mode.ISOMETRIC)
	assert_almost_eq(cam.pitch_deg, 55.0, 0.01)
	assert_almost_eq(cam.yaw_deg, 45.0, 0.01)


func test_the_third_person_camera_turns_but_the_isometric_one_does_not() -> void:
	cam.turn(0.5)
	assert_almost_eq(cam.yaw_deg, 45.0, 0.01, "isometric stays on its corner")
	cam.toggle_mode()
	cam.turn(0.5)
	assert_ne(cam.yaw_deg, 45.0)


func test_each_mode_keeps_its_own_zoom() -> void:
	cam.zoom(2)
	var iso := cam.distance
	cam.toggle_mode()
	assert_ne(cam.distance, iso)
	cam.zoom(1)
	var third := cam.distance
	cam.toggle_mode()
	assert_eq(cam.distance, iso)
	cam.toggle_mode()
	assert_eq(cam.distance, third)


func test_the_camera_keys_are_registered() -> void:
	InputSetup.ensure_actions()
	for a: String in ["toggle_camera", "camera_left", "camera_right"]:
		assert_true(InputMap.has_action(a), a)
