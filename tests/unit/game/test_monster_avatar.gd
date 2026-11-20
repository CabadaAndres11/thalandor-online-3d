extends GutTest

const DT := 1.0 / 60.0


func _avatar(type_id: String) -> MonsterAvatar:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type(type_id))
	return a


func test_monster_avatar_builds_each_model() -> void:
	for type_id: String in ["marked_hound", "cultist"]:
		var a := _avatar(type_id)
		assert_not_null(a.body, type_id)
		a.apply_state({"position": Vector3(3, 0, 3), "facing": 1.0}, {"hp": 50.0, "max_hp": 60.0, "status_bits": 0}, DT)
		assert_eq(a.position, Vector3(3, 0, 3))
		assert_almost_eq(a.rotation.y, 1.0, 0.0001)


func test_wolf_walks_when_moving() -> void:
	var a := _avatar("marked_hound")
	var pos := Vector3.ZERO
	for i in 30:
		pos += Vector3(5.0 * DT, 0, 0)
		a.apply_state({"position": pos, "facing": 0.0}, {"hp": 60.0, "max_hp": 60.0, "status_bits": 0}, DT)
	assert_true(a.current_animation() in ["walk", "run"], a.current_animation())


## Tweens are stepped by hand: test frames here can last a quarter of a second.
func test_attack_lunges_and_comes_back() -> void:
	var a := _avatar("marked_hound")
	var rest := a.body.position
	var t := a.play_attack()
	t.pause()
	t.custom_step(0.1)
	assert_almost_eq(a.body.position.z, rest.z + 0.35, 0.001, "lunging forward")
	t.custom_step(0.2)
	assert_almost_eq(a.body.position.distance_to(rest), 0.0, 0.001, "back in place")


func test_death_dissolves_into_binary_without_deforming() -> void:
	var a := _avatar("marked_hound")
	var scale_before := a.body.scale
	var t := a.play_death()
	assert_true(a.dying)
	assert_eq(a.binary_digit_count(), MonsterAvatar.BINARY_DIGITS)
	t.pause()
	t.custom_step(2.0)
	assert_eq(a.body.scale, scale_before, "no squashing")
	assert_eq(a.body.rotation, Vector3.ZERO, "no tipping over")
	for n: Node in a.body.find_children("*", "GeometryInstance3D", true, false):
		assert_almost_eq((n as GeometryInstance3D).transparency, 1.0, 0.001)
	assert_null(a.play_attack(), "dead monsters don't attack")


func test_wolf_is_a_voxel_rig_with_moving_legs() -> void:
	var a := _avatar("marked_hound")
	var rig := a.body.get_child(0) as BeastRig
	assert_not_null(rig, "wolves are voxel rigs")
	for part: String in ["body", "head", "leg_front_left", "leg_back_right", "tail"]:
		assert_not_null(rig.part(part), part)
	var leg := rig.part("leg_front_left")
	var pos := Vector3.ZERO
	var angles := []
	for i in 20:
		pos += Vector3(5.0 * DT, 0, 0)
		a.apply_state({"position": pos, "facing": 0.0}, {"hp": 60.0, "max_hp": 60.0, "status_bits": 0}, DT)
		angles.append(leg.rotation.x)
	assert_gt(angles.max() - angles.min(), 0.2, "legs swing while walking")


func test_wolf_bite_moves_the_head() -> void:
	var a := _avatar("marked_hound")
	var rig := a.body.get_child(0) as BeastRig
	var t := a.play_attack()
	t.pause()
	t.custom_step(0.1)
	assert_ne(rig.part("head").rotation.x, 0.0, "the head snaps down")


func test_new_monster_models_build() -> void:
	var marked_boar := _avatar("marked_boar")
	var rig := marked_boar.body.get_child(0) as BeastRig
	assert_not_null(rig, "the marked_boar is a voxel rig")
	for part: String in ["body", "head", "leg_front_left", "leg_back_right", "tail"]:
		assert_not_null(rig.part(part), "marked_boar " + part)
	var pieces := {"cultist": ["cult_hood", "cult_robe", "cult_sleeve_left", "cult_sleeve_right", "cult_cuff_left", "cult_cuff_right", "weapon_dagger_right"], "cult_archer": ["cult_hood", "cult_robe", "weapon_bow"]}
	for type_id: String in pieces:
		var a := _avatar(type_id)
		var c := a.body.get_child(0) as HumanRig
		assert_not_null(c, "%s is a voxel humanoid" % type_id)
		for id: String in pieces[type_id]:
			assert_not_null(c.piece_node(id), "%s: %s" % [type_id, id])
		a.apply_state({"position": Vector3(2, 0, 2), "facing": 0.0}, {"hp": 50.0, "max_hp": 50.0, "status_bits": 0}, DT)
		assert_eq(a.current_animation(), "idle")


func test_humanoid_attack_plays_its_animation() -> void:
	var g := _avatar("cultist")
	g.play_attack("melee")
	assert_eq(g.current_animation(), "melee")


func test_elite_is_bigger_with_an_aura() -> void:
	var normal := _avatar("marked_hound")
	var elite := MonsterAvatar.new()
	add_child_autofree(elite)
	elite.setup(MonsterDB.load_default().get_type("marked_hound"), true, 1.3)
	assert_almost_eq(elite.body.scale.x, normal.body.scale.x * 1.3, 0.001)
	assert_false(normal.has_aura())
	assert_true(elite.has_aura())
	assert_string_contains(elite.display_name(), tr("MON_MARKED_HOUND"))
	assert_ne(elite.display_name(), normal.display_name(), "the name says it is an elite")


func test_boss_is_a_big_humanoid_that_leaps() -> void:
	var a := _avatar("cult_acolyte")
	var c := a.body.get_child(0) as HumanRig
	assert_not_null(c)
	for id: String in ["acolyte_hood", "acolyte_robe", "acolyte_claws_left", "acolyte_claws_right"]:
		assert_not_null(c.piece_node(id), id)
	assert_almost_eq(a.body.scale.x, 1.8, 0.001)
	var rest := a.body.position.y
	var t := a.play_leap(1.2)
	t.pause()
	t.custom_step(0.2)
	assert_gt(a.body.position.y, rest + 0.5, "up in the air")
	t.custom_step(1.0)
	assert_gt(a.body.position.y, rest + 2.0, "it stays up until it lands")
	var down := a.land()
	down.pause()
	down.custom_step(0.2)
	assert_almost_eq(a.body.position.y, rest, 0.001, "landed")




func test_monster_level_is_in_its_label() -> void:
	var a := _avatar("cultist")
	a.apply_state({"position": Vector3.ZERO, "facing": 0.0}, {"hp": 55.0, "max_hp": 55.0, "status_bits": 0, "level": 12}, DT)
	assert_eq(a.bar.label_text(), tr("OVERHEAD_LEVEL") % [12, tr("MON_CULTIST")])
	a.apply_state({"position": Vector3.ZERO, "facing": 0.0}, {"hp": 55.0, "max_hp": 55.0, "status_bits": 0, "level": 13}, DT)
	assert_eq(a.bar.label_text(), tr("OVERHEAD_LEVEL") % [13, tr("MON_CULTIST")])


func test_a_hit_flashes_bleeds_and_steps_back() -> void:
	var a := _avatar("marked_hound")
	var rest := a.body.position
	a.react_to_hit(a.position + Vector3(0, 0, -3)) # struck from behind its +Z side... away is +Z
	var flashed := a.body.find_children("*", "GeometryInstance3D", true, false).filter(
		func(n: Node) -> bool: return (n as GeometryInstance3D).material_overlay != null)
	assert_gt(flashed.size(), 0, "white flash")
	assert_eq(a.find_children("*", "CPUParticles3D", false, false).size(), 1, "blood")
	assert_ne(a.body.position, rest, "it is pushed back")
	assert_false(a.dying)


func test_dying_monsters_ignore_hits() -> void:
	var a := _avatar("marked_hound")
	a.play_death()
	a.react_to_hit(Vector3.ZERO)
	assert_eq(a.find_children("*", "CPUParticles3D", false, false).size(), 0)


func test_binary_digits_start_on_the_body_surface() -> void:
	var a := _avatar("cultist")
	a.play_death()
	assert_eq(a.binary_digit_count(), MonsterAvatar.BINARY_DIGITS)
	for l: Label3D in a._binary:
		assert_lt(absf(l.position.x), 1.2, "inside the silhouette's width")
		assert_lt(l.position.y, a._height + 0.5)


func test_vaelthar_floats_with_a_mane_and_tentacles_out_of_the_sleeves() -> void:
	var a := _avatar("vaelthar")
	var c := a.body.get_child(0) as HumanRig
	for id: String in ["vaelthar_mane", "vaelthar_robe", "vaelthar_tentacles_left", "vaelthar_tentacles_right"]:
		assert_not_null(c.piece_node(id), id)
	assert_eq(CharacterCatalog.load_default().piece("vaelthar_tentacles_left").part, "arm_left", "out of the shoulder")
	assert_almost_eq(a.hover_height(), 0.7, 0.001, "off the ground")
	for part: String in ["leg_left", "leg_right", "shin_left", "shin_right"]:
		assert_false(c.part_mesh(part).visible, part + " hidden under the robe")
	for part: String in ["forearm_left", "forearm_right", "hand_left", "hand_right"]:
		assert_false(c.part_mesh(part).visible, part + ": tentacles come out of the sleeve instead")
	assert_not_null(c.piece_node("vaelthar_sleeve_left"), "the sleeve stays, cut at the elbow")
	var lowest := INF
	for i in 40:
		a.apply_state({"position": Vector3.ZERO, "facing": 0.0}, {"hp": 1.0, "max_hp": 1.0}, 0.05)
		lowest = minf(lowest, a.hover_height())
	assert_gt(lowest, 0.55, "it bobs but never touches the ground")
	assert_eq(_avatar("cultist").hover_height(), 0.0, "others stand on the ground")


func test_nhazar_floats_under_a_head_far_bigger_than_its_body() -> void:
	var a := _avatar("nhazar")
	var c := a.body.get_child(0) as HumanRig
	for id: String in ["nhazar_head", "nhazar_collar", "nhazar_chains_left", "nhazar_chains_right", "acolyte_robe"]:
		assert_not_null(c.piece_node(id), id)
	assert_almost_eq(a.hover_height(), 0.8, 0.001)
	var head := c.piece_node("nhazar_head").get_aabb().size.x
	var robe := c.piece_node("acolyte_robe").get_aabb().size.x
	assert_gt(head, robe * 1.5, "the mass is much wider than the body")
	assert_gt(a.bar.position.y, 4.0 * 2.0, "the name floats over the mass")


func test_inquisitor_wears_its_armour_and_holds_its_sword() -> void:
	var a := _avatar("cult_inquisitor")
	var c := a.body.get_child(0) as HumanRig
	for id: String in ["inquisitor_hood", "inquisitor_belt", "inquisitor_pauldron_left", "inquisitor_pauldron_right", "weapon_inquisitor_sword"]:
		assert_not_null(c.piece_node(id), id)
	assert_eq(c.weapon_points("right").size(), 2, "its sword leaves a trail when it swings")
	assert_eq(a.hover_height(), 0.0, "it walks")


func test_cult_humanoids_use_the_v2_body_and_pieces() -> void:
	for type_id: String in ["cultist", "cult_archer", "cult_acolyte", "cult_inquisitor", "vaelthar", "nhazar"]:
		var c := _avatar(type_id).body.get_child(0) as HumanRig
		assert_eq(c.body, "v2", type_id)
		for id: String in c.pieces():
			var mi := c.piece_node(id)
			assert_eq(mi.scale, Vector3.ONE, "%s %s is not a v1 piece blown up" % [type_id, id])


func test_cult_pieces_come_from_the_v2_table() -> void:
	var look := MonsterAvatar.look_of(MonsterDB.load_default().get_type("cult_acolyte"))
	assert_eq(look.body, "v2")
	for p: Dictionary in look.pieces:
		assert_string_contains(str(p.file), "/pieces_v2/", str(p.id))
		assert_false(p.has("voxel_scale"), str(p.id))
