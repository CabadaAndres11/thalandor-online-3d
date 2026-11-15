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
