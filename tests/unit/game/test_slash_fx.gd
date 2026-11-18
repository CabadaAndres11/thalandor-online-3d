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


func _dual(class_id := "assassin") -> HumanRig:
	var r := HumanRig.create(class_id, {})
	r.auto_update = false
	add_child_autofree(r)
	return r


func test_the_assassin_holds_a_dagger_in_each_hand() -> void:
	var r := _dual()
	assert_eq(r.weapon_points("right").size(), 2)
	assert_eq(r.weapon_points("left").size(), 2)
	assert_eq(rig.weapon_points("left").size(), 0, "a warrior has one weapon")


func test_each_melee_attack_has_its_own_animation() -> void:
	var r := _dual()
	var seen := {}
	for kind: String in ["melee", "stab_right", "stab_left", "overhead", "spin", "flurry"]:
		r.play_action(kind)
		assert_eq(r.current_action(), kind)
		r.update(r.ACTIONS[kind] * 0.5)
		var sig := []
		for n: String in ["torso", "hips", "arm_right", "arm_left", "leg_left", "leg_right"]:
			sig.append(r.part(n).rotation)
		sig.append(r.get_child(0).rotation if r.get_child_count() > 0 else Vector3.ZERO)
		seen[str(sig)] = true
	assert_eq(seen.size(), 6, "six different poses")


func test_stab_alternates_which_hand_leads() -> void:
	var r := _dual()
	r.play_action("stab_right")
	r.update(0.32 * 0.5)
	var right_arm := r.part("arm_right").rotation.x
	var left_arm := r.part("arm_left").rotation.x
	assert_lt(right_arm, left_arm, "the right arm is the one reaching out")
	r.play_action("stab_left")
	r.update(0.32 * 0.5)
	assert_lt(r.part("arm_left").rotation.x, r.part("arm_right").rotation.x)


func test_a_spin_turns_the_whole_body_and_traces_a_circle() -> void:
	var r := _dual()
	var s := SlashFx.new()
	add_child_autofree(s)
	s.setup(r, Color.WHITE, "right")
	r.play_action("spin")
	var tips: Array[Vector3] = []
	var t := 0.0
	while t < 0.58:
		r.update(1.0 / 60.0)
		s.advance(1.0 / 60.0)
		if not r.weapon_points("right").is_empty():
			tips.append(r.weapon_points("right")[1])
		t += 1.0 / 60.0
	assert_gt(s.sample_count(), 10, "a long ribbon")
	var far := 0.0
	for a: Vector3 in tips:
		for b: Vector3 in tips:
			far = maxf(far, a.distance_to(b))
	assert_gt(far, 0.9, "the weapon goes right around the body")


func test_the_left_hand_has_its_own_cut() -> void:
	var r := _dual()
	var s := SlashFx.new()
	add_child_autofree(s)
	s.setup(r, Color.WHITE, "left")
	r.play_action("stab_left")
	for i in 14:
		r.update(1.0 / 60.0)
		s.advance(1.0 / 60.0)
	assert_gt(s.sample_count(), 2)
