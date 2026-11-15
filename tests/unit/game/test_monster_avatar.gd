extends GutTest

const DT := 1.0 / 60.0


func _avatar(type_id: String) -> MonsterAvatar:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type(type_id))
	return a


func test_monster_avatar_builds_each_model() -> void:
	for type_id: String in ["wolf", "slime"]:
		var a := _avatar(type_id)
		assert_not_null(a.body, type_id)
		a.apply_state({"position": Vector3(3, 0, 3), "facing": 1.0}, {"hp": 50.0, "max_hp": 60.0, "status_bits": 0}, DT)
		assert_eq(a.position, Vector3(3, 0, 3))
		assert_almost_eq(a.rotation.y, 1.0, 0.0001)


func test_wolf_walks_when_moving() -> void:
	var a := _avatar("wolf")
	var pos := Vector3.ZERO
	for i in 30:
		pos += Vector3(5.0 * DT, 0, 0)
		a.apply_state({"position": pos, "facing": 0.0}, {"hp": 60.0, "max_hp": 60.0, "status_bits": 0}, DT)
	assert_true(a.current_animation() in ["walk", "run"], a.current_animation())


## Tweens are stepped by hand: test frames here can last a quarter of a second.
func test_attack_lunges_and_comes_back() -> void:
	var a := _avatar("wolf")
	var rest := a.body.position
	var t := a.play_attack()
	t.pause()
	t.custom_step(0.1)
	assert_almost_eq(a.body.position.z, rest.z + 0.35, 0.001, "lunging forward")
	t.custom_step(0.2)
	assert_almost_eq(a.body.position.distance_to(rest), 0.0, 0.001, "back in place")


func test_death_falls_over() -> void:
	var a := _avatar("slime")
	var t := a.play_death()
	assert_true(a.dying)
	t.pause()
	t.custom_step(1.0)
	assert_lt(a.body.scale.y, 0.5, "shrunk or fallen")
	assert_null(a.play_attack(), "dead monsters don't attack")


func test_wolf_is_a_voxel_rig_with_moving_legs() -> void:
	var a := _avatar("wolf")
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
	var a := _avatar("wolf")
	var rig := a.body.get_child(0) as BeastRig
	var t := a.play_attack()
	t.pause()
	t.custom_step(0.1)
	assert_ne(rig.part("head").rotation.x, 0.0, "the head snaps down")


func test_new_monster_models_build() -> void:
	var boar := _avatar("boar")
	var rig := boar.body.get_child(0) as BeastRig
	assert_not_null(rig, "the boar is a voxel rig")
	for part: String in ["body", "head", "leg_front_left", "leg_back_right", "tail"]:
		assert_not_null(rig.part(part), "boar " + part)
	var pieces := {"goblin": ["goblin_ears", "goblin_knife"], "skeleton_archer": ["skeleton_bow"]}
	for type_id: String in pieces:
		var a := _avatar(type_id)
		var c := a.body.get_child(0) as CharacterRig
		assert_not_null(c, "%s is a blocky humanoid" % type_id)
		for id: String in pieces[type_id]:
			assert_not_null(c.piece_node(id), "%s: %s" % [type_id, id])
		a.apply_state({"position": Vector3(2, 0, 2), "facing": 0.0}, {"hp": 50.0, "max_hp": 50.0, "status_bits": 0}, DT)
		assert_eq(a.current_animation(), "idle")


func test_humanoid_attack_plays_its_animation() -> void:
	var a := _avatar("skeleton_archer")
	a.play_attack("shoot")
	assert_eq(a.current_animation(), "holding-right-shoot")
	var g := _avatar("goblin")
	g.play_attack("melee")
	assert_eq(g.current_animation(), "attack-melee-right")


func test_elite_is_bigger_with_an_aura() -> void:
	var normal := _avatar("wolf")
	var elite := MonsterAvatar.new()
	add_child_autofree(elite)
	elite.setup(MonsterDB.load_default().get_type("wolf"), true, 1.3)
	assert_almost_eq(elite.body.scale.x, normal.body.scale.x * 1.3, 0.001)
	assert_false(normal.has_aura())
	assert_true(elite.has_aura())
	assert_string_contains(elite.display_name(), tr("MON_WOLF"))
	assert_ne(elite.display_name(), normal.display_name(), "the name says it is an elite")


func test_boss_is_a_big_humanoid_that_leaps() -> void:
	var a := _avatar("orc_king")
	var c := a.body.get_child(0) as CharacterRig
	assert_not_null(c)
	for id: String in ["orc_axe", "orc_tusks", "orc_crown"]:
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
