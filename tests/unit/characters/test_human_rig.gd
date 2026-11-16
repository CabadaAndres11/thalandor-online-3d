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
