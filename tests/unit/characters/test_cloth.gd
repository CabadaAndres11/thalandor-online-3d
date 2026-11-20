extends GutTest
## Plan 6.4.3: robes and skirts follow the legs, capes sway behind (a vertex shader; these
## tests check the parameters HumanRig feeds it and its CPU twin, HumanRig.cloth_deform).


func _rig(class_id: String, gear: Array = []) -> HumanRig:
	var rig := HumanRig.build(CharacterCatalog.load_default().resolve(class_id, {}, "", gear))
	rig.auto_update = false
	add_child_autofree(rig)
	rig.update(0.016)
	return rig


func _gear(main: String, chest: String) -> Array:
	return [main, "", "", "", chest, "", "", ""]


func test_long_pieces_wear_the_cloth_material_and_short_ones_do_not() -> void:
	var rig := _rig("mage")
	assert_eq(rig.cloth_mode("outfit_mage"), HumanRig.CLOTH_SKIRT, "the mage's robe")
	assert_true(rig.piece_node("outfit_mage").get_surface_override_material(0) is ShaderMaterial)
	assert_eq(rig.cloth_mode("hat_mage"), HumanRig.CLOTH_NONE)
	var warrior := _rig("warrior", _gear("sword_t1", "warrior_chest_t3"))
	assert_eq(warrior.cloth_mode("warrior_chest_t3_cape"), HumanRig.CLOTH_CAPE)
	assert_eq(warrior.cloth_mode("warrior_chest_t3_skirt"), HumanRig.CLOTH_SKIRT)


func test_the_skirt_follows_each_leg() -> void:
	var rig := _rig("mage")
	rig.set_moving_speed(4.0, 5.0)
	# Walk until the left leg is well forward.
	for i in 200:
		rig.update(1.0 / 60.0)
		if rig.part("leg_left").rotation.x < -0.5:
			break
	var p := rig.cloth_params("outfit_mage")
	assert_lt(float(p.ang_l), -0.3, "the left leg is forward in the skirt's frame")
	assert_gt(float(p.ang_r), float(p.ang_l), "the right one is not")
	var left_hem := Vector3((p.hip_l as Vector3).x, float(p.waist_y) - float(p.span), 0.0)
	var right_hem := Vector3((p.hip_r as Vector3).x, float(p.waist_y) - float(p.span), 0.0)
	assert_gt(HumanRig.cloth_deform(left_hem, p).z, 0.2 * float(p.span), "the left hem swings forward with the leg")
	assert_lt(HumanRig.cloth_deform(right_hem, p).z, HumanRig.cloth_deform(left_hem, p).z, "the right side less")
	var chest := Vector3(0.0, float(p.waist_y) + 0.5, 0.3)
	assert_eq(HumanRig.cloth_deform(chest, p), chest, "above the waist nothing moves")


func test_the_cape_flies_back_when_running_and_settles() -> void:
	var rig := _rig("warrior", _gear("sword_t1", "warrior_chest_t3"))
	var tip := func() -> Vector3:
		var p := rig.cloth_params("warrior_chest_t3_cape")
		return HumanRig.cloth_deform(Vector3((p.anchor as Vector3).x, (p.anchor as Vector3).y - float(p.span), (p.anchor as Vector3).z), p)
	var still: Vector3 = tip.call()
	rig.set_moving_speed(5.0, 5.0)
	for i in 90:
		rig.update(1.0 / 60.0)
	var running: Vector3 = tip.call()
	assert_lt(running.z, still.z - 0.15 * float(rig.cloth_params("warrior_chest_t3_cape").span), "the cape flies back")
	rig.set_moving_speed(0.0, 5.0)
	for i in 240:
		rig.update(1.0 / 60.0)
	assert_almost_eq((tip.call() as Vector3).z, still.z, 0.08 * float(rig.cloth_params("warrior_chest_t3_cape").span), "and hangs again")


func test_cult_robes_follow_the_legs_too() -> void:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type("cultist"))
	var rig := a.body.get_child(0) as HumanRig
	assert_eq(rig.cloth_mode("cult_robe"), HumanRig.CLOTH_SKIRT)


func test_a_long_frame_does_not_fling_the_cape() -> void:
	var rig := _rig("warrior", _gear("sword_t1", "warrior_chest_t3"))
	rig.set_moving_speed(5.0, 5.0)
	for i in 6:
		rig.update(0.25) # a hitch (a load, a shader compile)
		var drape := float(rig.cloth_params("warrior_chest_t3_cape").drape)
		assert_between(drape, -0.2, 1.0, "frame %d: the cape stays sane (%f)" % [i, drape])


func test_the_hit_flash_bends_with_the_cloth() -> void:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type("cultist"))
	a.react_to_hit()
	var rig := a.body.get_child(0) as HumanRig
	var robe := rig.piece_node("cult_robe")
	assert_true(robe.material_overlay is ShaderMaterial, "the flash on a robe is cloth too")
	assert_false(rig.piece_node("cult_hood").material_overlay is ShaderMaterial, "a rigid piece keeps the plain flash")
