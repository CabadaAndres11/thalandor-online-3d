extends GutTest

var rig: HumanRig
var slash: SlashFx


func before_each() -> void:
	rig = HumanRig.create("warrior", {})
	rig.auto_update = false
	add_child_autofree(rig)
	slash = SlashFx.new()
	add_child_autofree(slash)
	slash.setup(rig, Color.WHITE)


func _swing(seconds: float, step := 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds:
		rig.update(step)
		slash.advance(step)
		t += step


func test_the_weapon_has_a_hand_and_a_tip() -> void:
	var pts := rig.weapon_points()
	assert_eq(pts.size(), 2)
	assert_gt((pts[0] as Vector3).distance_to(pts[1] as Vector3), 0.3, "a blade's length")


func test_nothing_is_drawn_before_the_swing_starts() -> void:
	rig.play_action("melee")
	_swing(0.05)
	assert_eq(slash.phase(), "wait")
	assert_eq(slash.sample_count(), 0)


func test_it_records_the_path_of_the_weapon_and_fades_out() -> void:
	rig.play_action("melee")
	_swing(0.17) # into the swing
	assert_eq(slash.phase(), "record")
	assert_gt(slash.sample_count(), 3, "a trail behind the whole path")
	var first := (slash._samples[0][1] as Vector3)
	var last := (slash._samples[slash.sample_count() - 1][1] as Vector3)
	assert_gt(first.distance_to(last), 0.2, "the tip travels along an arc")
	_swing(0.2)
	assert_eq(slash.phase(), "fade")
	_swing(0.5)
	assert_true(slash.is_queued_for_deletion(), "it cleans up after itself")


func test_it_gives_up_when_nobody_swings() -> void:
	_swing(1.0)
	assert_true(slash.is_queued_for_deletion())


func test_the_texture_is_a_soft_streak() -> void:
	var tex := SlashFx.slash_texture()
	var img := tex.get_image()
	assert_gt(img.get_pixel(64, 55).r, 0.6, "bright core near the tip")
	assert_lt(img.get_pixel(64, 4).r, 0.1, "dark near the hand")
	assert_lt(img.get_pixel(2, 55).r, img.get_pixel(64, 55).r, "tapered ends")


func test_the_whole_body_changes_posture_in_a_melee_swing() -> void:
	var idle := {}
	for n: String in ["torso", "hips", "leg_left", "leg_right", "arm_left", "head"]:
		idle[n] = rig.part(n).rotation
	rig.play_action("melee")
	rig.update(0.45 * 0.5) # mid swing
	for n: String in ["torso", "hips", "leg_left", "leg_right", "arm_left", "head"]:
		assert_ne(rig.part(n).rotation, idle[n], "%s moves" % n)
