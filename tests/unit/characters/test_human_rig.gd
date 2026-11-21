extends GutTest

const PIECES := "res://assets/characters/pieces/"


func _look(body_scale: Dictionary = {}) -> Dictionary:
	return {
		"skin_color": Color("#e8b996"), "eyes_color": Color("#3d7cc9"), "hair_color": Color("#784628"),
		"voxel_hair_color": Color("#663b22"),
		"primary": Color("#5b3f9e"), "secondary": Color("#e8b23a"), "trousers": Color("#3a2e5a"),
		"body_scale": body_scale,
		"pieces": [{"id": "hat_mage", "file": PIECES + "hat_mage.vox", "part": "head", "offset": [-4, 5, -4]}],
	}


func _colors(mi: MeshInstance3D) -> Array:
	var out := []
	var mesh := mi.mesh as ArrayMesh
	for s in mesh.get_surface_count():
		out.append_array(Array(mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]))
	return out


## Vertex colors are stored with 8 bits per channel.
func _has_color(colors: Array, c: Color) -> bool:
	return colors.any(func(x: Color) -> bool:
		return absf(x.r - c.r) < 0.004 and absf(x.g - c.g) < 0.004 and absf(x.b - c.b) < 0.004)


func test_builds_all_parts() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	for part_name: String in HumanRig.PARTS:
		assert_not_null(rig.part(part_name), part_name)
		assert_not_null(rig.part_mesh(part_name), part_name + " mesh")
	assert_eq(rig.part("head").get_parent(), rig.part("torso"), "head hangs from the torso")
	assert_eq(rig.part("hand_right").get_parent(), rig.part("forearm_right"), "hand hangs from the forearm")


func test_tints_skin_and_eyes() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	var colors := _colors(rig.part_mesh("head"))
	assert_true(_has_color(colors, Color("#e8b996")), "skin tint")
	assert_true(_has_color(colors, Color("#3d7cc9")), "eyes tint")
	assert_true(_has_color(_colors(rig.part_mesh("torso")), Color("#5b3f9e")), "shirt in the primary color")
	assert_true(_has_color(_colors(rig.part_mesh("leg_left")), Color("#3a2e5a")), "trousers in their own color")
	var plain := _look()
	plain.erase("trousers")
	var rig2 := HumanRig.build(plain)
	add_child_autofree(rig2)
	assert_true(_has_color(_colors(rig2.part_mesh("leg_left")), Color("#5b3f9e").darkened(HumanRig.TROUSERS_DARKEN)), "default: a darker primary")


func test_body_scale_widens_torso() -> void:
	var slim := HumanRig.build(_look())
	var robust := HumanRig.build(_look({"torso": [1.15, 1, 1.12], "arm": [1.12, 1, 1.12], "leg": [1.08, 1, 1.08]}))
	add_child_autofree(slim)
	add_child_autofree(robust)
	assert_almost_eq(robust.part_mesh("torso").get_parent().scale.x, 1.15, 0.001)
	assert_gt(robust.part("arm_left").position.x, slim.part("arm_left").position.x, "shoulders move out")
	assert_lt(robust.part("arm_right").position.x, slim.part("arm_right").position.x, "both shoulders")


func test_attaches_pieces_to_their_part() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	var hat := rig.piece_node("hat_mage")
	assert_not_null(hat)
	assert_eq(hat.get_parent(), rig.part("head"))
	assert_eq(rig.pieces(), ["hat_mage"])


func test_each_action_ends() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	for kind: String in ["melee", "shoot", "cast", "dash"]:
		var d := rig.play_action(kind)
		assert_gt(d, 0.0, kind)
		assert_eq(rig.current_action(), kind)
		rig.update(d * 0.5)
		assert_eq(rig.current_action(), kind, kind + " still playing")
		rig.update(d * 0.5 + 0.01)
		assert_eq(rig.current_action(), "idle", kind + " ended")


func test_downed_and_die_stay() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	for kind: String in ["downed", "die"]:
		rig.play_action("idle")
		assert_gt(rig.play_action(kind), 0.0)
		rig.update(5.0)
		assert_eq(rig.current_action(), kind, kind + " stays")
		assert_lt(rig.part("hips").global_position.y, 0.5, kind + " lies on the ground")


func test_actions_move_the_arms() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.update(0.0)
	var rest: Vector3 = rig.part("arm_right").rotation
	rig.play_action("melee")
	rig.update(0.12)
	assert_ne(rig.part("arm_right").rotation, rest, "the sword arm rises")


func test_walk_swings_legs() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.set_moving_speed(5.0, 5.0)
	assert_eq(rig.current_animation(), "walk")
	rig.update(0.1)
	assert_ne(rig.part("leg_left").rotation.x, 0.0)
	rig.set_moving_speed(0.0, 5.0)
	assert_eq(rig.current_animation(), "idle")


func test_no_external_resources() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		assert_false(mi.mesh.resource_path.contains("characters/base"), mi.name)
		for s in mi.get_surface_override_material_count():
			assert_null(mi.get_surface_override_material(s), "no layered shader on " + mi.name)


func test_bow_stays_upright_while_aiming() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.play_action("shoot")
	rig.update(HumanRig.ACTIONS.shoot * 0.5)
	var up := rig.part("hand_left").global_transform.basis.y.normalized()
	assert_gt(up.dot(Vector3.UP), 0.9, "the bow hand holds the bow upright")
	var arm_dir := -rig.part("arm_left").global_transform.basis.y.normalized()
	assert_gt(arm_dir.dot(Vector3.FORWARD * -1.0), 0.9, "the bow arm points forward")


func test_staff_points_up_while_casting() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.play_action("cast")
	for k: float in [0.2, 0.5]:
		rig.update(HumanRig.ACTIONS.cast * 0.15)
		var up := rig.part("hand_right").global_transform.basis.y.normalized()
		assert_gt(up.dot(Vector3.UP), 0.7, "the staff stays upright at %.1f" % k)


func test_limbs_have_elbows_and_knees() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	assert_eq(rig.part("forearm_left").get_parent(), rig.part("arm_left"), "elbow")
	assert_eq(rig.part("hand_left").get_parent(), rig.part("forearm_left"), "wrist")
	assert_eq(rig.part("shin_right").get_parent(), rig.part("leg_right"), "knee")


func test_walk_bends_the_knees() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.set_moving_speed(5.0, 5.0)
	var bent := false
	for i in 20:
		rig.update(0.05)
		if rig.part("shin_left").rotation.x > 0.2:
			bent = true
	assert_true(bent, "the lifted leg bends at the knee")


func test_about_as_tall_as_a_person() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	var top := -INF
	for n: Node in rig.find_children("Mesh", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var aabb := mi.global_transform * mi.get_aabb()
		top = maxf(top, aabb.end.y)
	assert_between(top, 1.65, 1.85, "head top in meters")


func test_staff_rests_tilted_until_casting() -> void:
	var look := _look()
	look["grip"] = "staff"
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	rig.update(0.1)
	var up := rig.part("hand_right").global_transform.basis.y.normalized()
	assert_lt(up.dot(Vector3.UP), 0.6, "the staff leans over at rest")
	assert_gt(up.dot(Vector3.UP), 0.0, "crystal still above the hand")
	rig.play_action("cast")
	rig.update(HumanRig.ACTIONS.cast * 0.4)
	up = rig.part("hand_right").global_transform.basis.y.normalized()
	assert_gt(up.dot(Vector3.UP), 0.7, "upright while casting")


func test_the_bow_is_held_upright_in_front_not_dangling() -> void:
	var look := _look()
	look["grip"] = "bow"
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	rig.set_bow_charging(true)
	rig.update(0.1)
	var up := rig.part("hand_left").global_transform.basis.y.normalized()
	assert_gt(up.dot(Vector3.UP), 0.9, "the bow stands upright")
	var arm_dir := -rig.part("arm_left").global_transform.basis.y.normalized()
	assert_lt(arm_dir.y, 0.9, "the arm is raised forward, not hanging")
	rig.play_action("shoot")
	rig.update(0.01)
	var start := rig.part("arm_left").rotation.x
	assert_almost_eq(start, HumanRig.BOW_ARM, 0.15, "the shot starts from the held pose, no snap")


func test_the_bow_rides_on_the_back_until_a_shot_is_charged() -> void:
	var archer := CharacterCatalog.load_default().resolve("archer", {})
	var rig := HumanRig.build(archer)
	add_child_autofree(rig)
	rig.update(0.1)
	var bow := rig.piece_node("weapon_bow")
	assert_not_null(bow)
	assert_false(rig.bow_in_hand())
	assert_eq(bow.get_parent(), rig.part("torso"), "on the back")
	assert_lt(rig.part("arm_left").rotation.x, 0.5, "the arm is free")
	rig.set_bow_charging(true)
	rig.update(0.1)
	assert_true(rig.bow_in_hand())
	assert_eq(bow.get_parent(), rig.part("hand_left"))
	rig.set_bow_charging(false)
	rig.update(0.1)
	assert_eq(bow.get_parent(), rig.part("torso"), "back again after the shot")


func test_the_archer_has_the_bow_grip() -> void:
	assert_eq(CharacterCatalog.load_default().resolve("archer", {}).get("grip"), "bow")


func test_mage_look_has_the_staff_grip() -> void:
	assert_eq(CharacterCatalog.load_default().resolve("mage", {}).get("grip"), "staff")
	assert_eq(CharacterCatalog.load_default().resolve("warrior", {}).get("grip", ""), "")


## At the players' move speed (5 m/s) the legs take about two full strides a second,
## not four: each stride covers ground like a real jog.
func test_walk_pace_is_natural() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	rig.set_moving_speed(5.0, 5.0)
	var crossings := 0
	var last := 0.0
	for i in 60: # one second
		rig.update(1.0 / 60.0)
		var a := rig.part("leg_left").rotation.x
		if i > 0 and signf(a) != signf(last):
			crossings += 1
		last = a
	assert_between(crossings, 3, 4, "about two strides a second")


func _rig(look := _look()) -> HumanRig:
	var rig := HumanRig.build(look)
	rig.auto_update = false
	add_child_autofree(rig)
	return rig


func test_rig_heavy_and_thrust() -> void:
	var rig := _rig()
	for kind: String in ["heavy", "thrust", "stab"]:
		assert_gt(rig.play_action(kind), 0.0, kind)
		rig.update(5.0)
		assert_eq(rig.current_action(), "idle", kind + " ends")


func test_melee_combo_cycles() -> void:
	var rig := _rig()
	var steps := []
	for i in 4:
		rig.play_action("melee", true)
		steps.append(rig.combo_step())
		rig.update(0.5)
	assert_eq(steps, [0, 1, 2, 0])


func test_melee_combo_resets() -> void:
	var rig := _rig()
	rig.play_action("melee", true)
	rig.update(0.5)
	rig.play_action("melee", true)
	assert_eq(rig.combo_step(), 1)
	rig.update(0.5 + 1.3)
	rig.play_action("melee", true)
	assert_eq(rig.combo_step(), 0, "a pause starts over")


func test_non_combo_action_does_not_advance() -> void:
	var rig := _rig()
	rig.play_action("melee", true)
	rig.update(0.5)
	rig.play_action("melee")
	assert_eq(rig.combo_step(), 0, "only the basic attack chains")


func test_combo_same_duration() -> void:
	var rig := _rig()
	var d := []
	for i in 3:
		d.append(rig.play_action("heavy", true))
		rig.update(0.7)
	assert_eq(d[0], d[1])
	assert_eq(d[1], d[2])


func test_combo_steps_pose_differently() -> void:
	var rig := _rig()
	var poses := []
	for i in 3:
		rig.play_action("melee", true)
		rig.update(HumanRig.ACTIONS.melee * 0.45)
		poses.append([rig.part("arm_right").rotation, rig.part("torso").rotation])
		rig.update(1.0)
		rig.play_action("idle")
		rig._last_combo_time = rig._time # keep the chain going for the test
	assert_ne(poses[0], poses[1])
	assert_ne(poses[1], poses[2])


func test_dagger_combo_hands() -> void:
	var rig := _rig()
	var hands := []
	for i in 3:
		rig.play_action("stab", true)
		hands.append(rig.combo_hands())
		rig.update(0.4)
	assert_eq(hands, [["right"], ["left"], ["right", "left"]])


func test_aura_from_look() -> void:
	var look := _look()
	look["auras"] = [Color("#c07bff")]
	var rig := _rig(look)
	assert_not_null(rig.find_child("Aura", true, false), "tier 3 sets glow around the character")
	assert_null(_rig().find_child("Aura", true, false))


func _top_and_bottom(rig: HumanRig) -> Vector2:
	var top := -INF
	var bottom := INF
	for n: Node in rig.find_children("Mesh", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var aabb := mi.global_transform * mi.get_aabb()
		top = maxf(top, aabb.end.y)
		bottom = minf(bottom, aabb.position.y)
	return Vector2(top, bottom)


func test_look_without_body_is_v1() -> void:
	var rig := HumanRig.build(_look())
	add_child_autofree(rig)
	assert_eq(rig.body, "v1")
	assert_almost_eq(rig.scale.x, 0.36, 0.001)


func test_unknown_body_falls_back_to_v1() -> void:
	var look := _look()
	look["body"] = "v9"
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	assert_eq(rig.body, "v1")


func test_v2_body_is_a_person_tall() -> void:
	var look := _look()
	look["body"] = "v2"
	look["pieces"] = []
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	assert_eq(rig.body, "v2")
	assert_almost_eq(rig.scale.x, 0.18, 0.001)
	var tb := _top_and_bottom(rig)
	assert_between(tb.x, 1.70, 1.85, "head top in meters")
	assert_almost_eq(tb.y, 0.0, 0.03, "feet on the ground")
	for p: String in HumanRig.PARTS:
		assert_not_null(rig.part(p), p)
		assert_not_null(rig.part_mesh(p).mesh, p)


func test_piece_voxel_scale() -> void:
	var look := _look()
	look["body"] = "v2"
	look["pieces"] = [{"id": "hat_mage", "file": PIECES + "hat_mage.vox", "part": "head", "offset": [-4, 5, -4], "voxel_scale": 2.0}]
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	var node := rig.piece_node("hat_mage")
	assert_almost_eq(node.scale.x, 2.0, 0.001)
	assert_almost_eq(node.position, Vector3(-8, 10, -8) * VoxMesher.VOXEL_SIZE, Vector3.ONE * 0.001)


func _class_rig(class_id: String) -> HumanRig:
	var rig := HumanRig.build(CharacterCatalog.load_default().resolve(class_id, {}))
	add_child_autofree(rig)
	rig.update(0.1)
	return rig


func test_v2_classes_hold_v2_weapons() -> void:
	for class_id: String in ["villager", "warrior", "cleric", "mage", "archer", "assassin"]:
		var look := CharacterCatalog.load_default().resolve(class_id, {})
		for p: Dictionary in look.pieces:
			if str(p.id).begins_with("weapon_"):
				assert_string_contains(str(p.file), "/pieces_v2/", "%s %s" % [class_id, p.id])
				assert_false(p.has("voxel_scale"), "%s %s" % [class_id, p.id])


func test_v2_sword_runs_through_the_fist() -> void:
	var rig := _class_rig("warrior")
	var sword := rig.piece_node("weapon_sword")
	var hand := rig.part_mesh("hand_right")
	var fist := hand.global_transform * hand.get_aabb()
	var blade := sword.global_transform * sword.get_aabb()
	assert_true(blade.intersects(fist), "the grip is inside the fist")
	assert_gt(blade.size.length(), fist.size.length() * 2.5, "a long blade")


func test_bow_rides_on_the_back_v2() -> void:
	var rig := _class_rig("archer")
	var bow := rig.piece_node("weapon_bow")
	assert_eq(bow.get_parent(), rig.part("torso"), "on the back")
	assert_almost_eq(bow.scale.length(), Vector3.ONE.length(), 0.01, "a v2 bow is drawn at its size")
	rig.set_bow_charging(true)
	rig.update(0.1)
	assert_eq(bow.get_parent(), rig.part("hand_left"))
	var up := rig.part("hand_left").global_transform.basis.y.normalized()
	assert_gt(up.dot(Vector3.UP), 0.9, "the bow stands upright")


func test_staff_rests_tilted_until_casting_v2() -> void:
	var rig := _class_rig("mage")
	var up := rig.part("hand_right").global_transform.basis.y.normalized()
	assert_lt(up.dot(Vector3.UP), 0.6, "the staff leans over at rest")
	rig.play_action("cast")
	rig.update(HumanRig.ACTIONS.cast * 0.4)
	up = rig.part("hand_right").global_transform.basis.y.normalized()
	assert_gt(up.dot(Vector3.UP), 0.7, "upright while casting")
	var staff := rig.piece_node("weapon_staff")
	var top := (staff.global_transform * staff.get_aabb()).end.y
	assert_gt(top, 1.9, "the crystal rises above the head")


func _v2_look(body_scale: Dictionary = {}) -> Dictionary:
	var look := _look(body_scale)
	look["body"] = "v2"
	look["pieces"] = []
	return look


func test_body_scale_widens_torso_v2() -> void:
	var slim := HumanRig.build(_v2_look())
	var robust := HumanRig.build(_v2_look({"torso": [1.15, 1, 1.12], "arm": [1.12, 1, 1.12], "leg": [1.08, 1, 1.08]}))
	add_child_autofree(slim)
	add_child_autofree(robust)
	assert_gt(robust.part("arm_left").position.x, slim.part("arm_left").position.x, "shoulders move out")
	assert_lt(robust.part("arm_right").position.x, slim.part("arm_right").position.x, "both shoulders")


func test_dagger_combo_hands_v2() -> void:
	var rig := HumanRig.build(_v2_look())
	add_child_autofree(rig)
	var hands := []
	for i in 3:
		rig.play_action("stab", true)
		hands.append(rig.combo_hands())
		rig.update(0.4)
	assert_eq(hands, [["right"], ["left"], ["right", "left"]])


func test_aura_from_look_v2() -> void:
	var look := _v2_look()
	look["auras"] = [Color("#c07bff")]
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	assert_not_null(rig.find_child("Aura", true, false))


func test_blade_down_grip_v2() -> void:
	var look := _v2_look()
	look["grip"] = "blade_down"
	var b := HumanRig.build(look)
	var la := _look()
	la["grip"] = "blade_down"
	var a := HumanRig.build(la)
	add_child_autofree(a)
	add_child_autofree(b)
	a.update(0.1)
	b.update(0.1)
	assert_almost_eq(b.part("hand_right").global_transform.basis.y.normalized().dot(Vector3.UP),
		a.part("hand_right").global_transform.basis.y.normalized().dot(Vector3.UP), 0.05, "same grip angle on both bodies")


func _kit(class_id: String, tier: int) -> Array:
	var cls: String = class_id
	var main: String = {"warrior": "sword", "cleric": "mace", "mage": "staff", "archer": "bow", "assassin": "dagger"}[cls]
	var off: String = {"warrior": "shield", "cleric": "shield", "mage": "orb", "archer": "", "assassin": "dagger"}[cls]
	var gear := []
	for slot: String in Inventory.VISIBLE:
		match slot:
			"main": gear.append("%s_t%d" % [main, tier])
			"offhand": gear.append("%s_t%d" % [off, tier] if off != "" else "")
			_: gear.append("%s_%s_t%d" % [cls, slot, tier] if ItemDB.load_default().base("%s_%s_t%d" % [cls, slot, tier]).size() > 0 else "")
	return gear


func test_gear_is_worn_as_v2() -> void:
	var rig := HumanRig.create("warrior", {}, null, "", _kit("warrior", 3))
	add_child_autofree(rig)
	var node := rig.piece_node("warrior_chest_t3")
	assert_not_null(node)
	assert_almost_eq(node.scale.x, 1.0, 0.001, "a v2 piece, not a scaled v1 one")


func test_full_tier3_kit_builds_for_every_class() -> void:
	for class_id: String in ["warrior", "cleric", "mage", "archer", "assassin"]:
		var look := CharacterCatalog.load_default().resolve(class_id, {}, "", _kit(class_id, 3))
		var rig := HumanRig.build(look)
		add_child_autofree(rig)
		rig.update(0.1)
		for p: Dictionary in look.pieces:
			assert_not_null(rig.piece_node(str(p.id)), "%s %s" % [class_id, p.id])
			assert_false(p.has("voxel_scale"), "%s %s is v2" % [class_id, p.id])


func test_mixed_kit_builds() -> void:
	var gear := _kit("mage", 1)
	gear[Inventory.VISIBLE.find("shoulders")] = "warrior_shoulders_t3"
	gear[Inventory.VISIBLE.find("head")] = "archer_head_t2"
	var rig := HumanRig.create("mage", {}, null, "", gear)
	add_child_autofree(rig)
	assert_not_null(rig.piece_node("warrior_shoulders_t3_l"))
	assert_not_null(rig.piece_node("archer_head_t2"))


func test_robust_body_with_armour() -> void:
	var rig := HumanRig.create("warrior", {"body": "robust"}, null, "", _kit("warrior", 2))
	add_child_autofree(rig)
	var pad := rig.piece_node("warrior_shoulders_t2_l")
	assert_eq(pad.get_parent(), rig.part("arm_left"), "the pauldron rides on its arm")


## Lunges, breathing, the walk bob and falling move the same in metres on both bodies.
func test_pose_motion_is_in_metres_on_both_bodies() -> void:
	var lunge := []
	var bottoms := []
	for look: Dictionary in [_look(), _v2_look()]:
		var rig := HumanRig.build(look)
		add_child_autofree(rig)
		rig.play_action("melee")
		rig.update(HumanRig.ACTIONS.melee * 0.66)
		lunge.append((rig.get_node("Body") as Node3D).global_position.z - rig.global_position.z)
		rig.play_action("die")
		rig.update(HumanRig.ACTIONS.die * 2.0)
		bottoms.append(_top_and_bottom(rig).y)
	assert_almost_eq(lunge[1], lunge[0], 0.01, "same lunge in metres")
	assert_gt(bottoms[1], bottoms[0] - 0.03, "a dead v2 body sinks no deeper than a v1 one (%.3f vs %.3f)" % [bottoms[1], bottoms[0]])


func _gear_rig(main: String, class_id: String = "warrior") -> HumanRig:
	var rig := HumanRig.build(CharacterCatalog.load_default().resolve(class_id, {}, "", [main, "", "", "", "", "", "", ""]))
	rig.auto_update = false
	add_child_autofree(rig)
	rig.update(0.1)
	return rig


## The weapon tip, in the rig's own space, at fraction k of combo step `step` of `kind`.
func _tip_at(rig: HumanRig, kind: String, step: int, k: float) -> Vector3:
	rig.play_action("idle")
	rig._combo_step = step
	rig._action = kind
	rig._action_t = float(HumanRig.ACTIONS[kind]) * k
	rig.update(0.0)
	var pts: Array = rig.weapon_points("right")
	return rig.global_transform.affine_inverse() * (pts[1] as Vector3)


func _combo_reads(main: String, kind: String) -> void:
	var rig := _gear_rig(main)
	var left := signf(rig.part("arm_left").position.x) # the character's left, in rig x
	# Step 1: a side slash toward the left; step 2: toward the right; step 3: downward.
	var a := _tip_at(rig, kind, 0, 0.3)
	var b := _tip_at(rig, kind, 0, 0.55)
	assert_gt((b.x - a.x) * left, 0.4, "%s 1: sweeps to the left" % main)
	assert_lt(absf(b.y - a.y), absf(b.x - a.x), "%s 1: sideways, not down" % main)
	a = _tip_at(rig, kind, 1, 0.3)
	b = _tip_at(rig, kind, 1, 0.55)
	assert_lt((b.x - a.x) * left, -0.4, "%s 2: sweeps to the right" % main)
	assert_lt(absf(b.y - a.y), absf(b.x - a.x), "%s 2: sideways, not down" % main)
	a = _tip_at(rig, kind, 2, 0.3)
	b = _tip_at(rig, kind, 2, 0.55)
	assert_lt(b.y - a.y, -0.6, "%s 3: comes down" % main)
	assert_gt(absf(b.y - a.y), absf(b.x - a.x), "%s 3: down, not sideways" % main)


func test_one_hand_combo_left_right_down() -> void:
	_combo_reads("sword_t1", "melee")


func test_two_hand_combo_left_right_down() -> void:
	_combo_reads("greatsword_t1", "heavy")


func _grip_errors(main: String, kind: String) -> Array:
	var rig := _gear_rig(main)
	var out := [rig.left_grip_error()]
	for step in 3:
		for k: float in [0.3, 0.55]:
			_tip_at(rig, kind, step, k)
			out.append(rig.left_grip_error())
	return out


func test_two_hand_weapons_held_with_both_hands() -> void:
	for pair: Array in [["greatsword_t1", "heavy"], ["great_axe_t2", "heavy"], ["warhammer_t3", "heavy"], ["halberd_t1", "thrust"]]:
		var errs := _grip_errors(pair[0], pair[1])
		for i in errs.size():
			assert_lt(float(errs[i]), 0.06, "%s pose %d: left fist on the grip" % [pair[0], i])


func test_one_hand_weapons_keep_the_left_hand_free() -> void:
	assert_eq(_gear_rig("sword_t1").left_grip_error(), -1.0)


## The largest jump of each fist between two moments 1/1100 of the chain apart: the swing
## itself moves under 2 cm in that time; the old stepped IK made the arms jump ~5 cm.
func _max_jump(main: String, side: String) -> float:
	var rig := _gear_rig(main)
	var worst := 0.0
	for step in 3:
		var prev := Vector3.INF
		for i in 1100:
			_tip_at(rig, "heavy", step, float(i) / 1100.0)
			var p := rig.part("hand_" + side).global_position
			if prev != Vector3.INF:
				worst = maxf(worst, p.distance_to(prev))
			prev = p
	return worst


func test_two_hand_arms_do_not_flicker() -> void:
	for side: String in ["right", "left"]:
		assert_lt(_max_jump("greatsword_t1", side), 0.025, side + " fist moves smoothly")


func _torso_at(rig: HumanRig, kind: String, step: int, k: float) -> Vector3:
	_tip_at(rig, kind, step, k)
	return rig.part("torso").rotation


func test_swings_are_exaggerated() -> void:
	for pair: Array in [["sword_t1", "melee"], ["greatsword_t1", "heavy"]]:
		var rig := _gear_rig(pair[0])
		for step in 2: # side slashes: the torso winds up about 70 degrees, then turns through
			var wound := _torso_at(rig, pair[1], step, 0.3).y
			var hit := _torso_at(rig, pair[1], step, 0.55).y
			assert_gt(absf(wound), 1.1, "%s %d wound up" % [pair[0], step])
			assert_gt(absf(hit - wound), 2.0, "%s %d turns through the blow" % [pair[0], step])
		# The blow from above: leaning far back, then far into it.
		var back := _torso_at(rig, pair[1], 2, 0.3).x
		var into := _torso_at(rig, pair[1], 2, 0.55).x
		assert_gt(into - back, 1.0, "%s blow from above" % pair[0])
		assert_lt(rig._body.position.y, -0.1, "%s sinks into the blow" % pair[0])


## The cultists of the title scene pray in a loop (Plan 7): arms raised over the shoulders.
func test_pray_loops_with_arms_raised() -> void:
	var rig := HumanRig.create("villager", {}, null)
	add_child_autofree(rig)
	rig.auto_update = false
	rig.play_action("pray")
	rig.update(10.0)
	assert_eq(rig.current_action(), "pray")
	for side: String in ["left", "right"]:
		var hand := rig.part_mesh("hand_" + side)
		var shoulder := rig.part("arm_" + side).global_position.y
		assert_gt((hand.global_transform * hand.get_aabb()).get_center().y, shoulder, side + " hand over the shoulder")
