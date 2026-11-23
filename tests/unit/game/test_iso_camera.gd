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


func test_third_person_keeps_its_zoom_isometric_resets() -> void:
	cam.zoom(2)
	cam.toggle_mode()
	assert_ne(cam.distance, IsoCamera.ISO.distance)
	cam.zoom(1)
	var third := cam.distance
	cam.toggle_mode()
	assert_eq(cam.distance, IsoCamera.ISO.distance, "the isometric view is fixed")
	cam.toggle_mode()
	assert_eq(cam.distance, third)


func test_the_camera_keys_are_registered() -> void:
	InputSetup.ensure_actions()
	for a: String in ["toggle_camera", "camera_left", "camera_right"]:
		assert_true(InputMap.has_action(a), a)


## Plan 8.1.1: the camera never follows past the zone (it would show the void beyond).
func test_camera_clamped() -> void:
	var cam: IsoCamera = add_child_autofree(IsoCamera.new())
	cam.bounds = Rect2(0, 0, 96, 96)
	cam.follow(Vector3(-50, 0, 200))
	assert_eq(cam.target(), Vector3(6, 0, 90))
	cam.bounds = Rect2()
	cam.follow(Vector3(-50, 0, 200))
	assert_eq(cam.target(), Vector3(-50, 0, 200), "no bounds, no limit")


## Plan 8.1.2: the inset follows the edge band of the zone.
func test_camera_inset() -> void:
	var c: IsoCamera = add_child_autofree(IsoCamera.new())
	c.bounds = Rect2(0, 0, 96, 96)
	c.inset = 10.0
	c.follow(Vector3(-50, 0, 200))
	assert_eq(c.target(), Vector3(10, 0, 86))


## Back from third person, the isometric view is always the same fixed view.
func test_isometric_is_fixed_after_third_person() -> void:
	var fresh: IsoCamera = add_child_autofree(IsoCamera.new())
	fresh.follow(Vector3(10, 0, 10))
	cam.zoom(3)
	cam.toggle_mode()
	cam.turn(1.3)
	cam.zoom(-2)
	cam.toggle_mode()
	assert_eq(cam.mode, IsoCamera.Mode.ISOMETRIC)
	assert_true(cam.global_transform.is_equal_approx(fresh.global_transform), "%s vs %s" % [cam.global_transform, fresh.global_transform])
