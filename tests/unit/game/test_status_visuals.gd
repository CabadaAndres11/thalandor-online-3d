extends GutTest
## Status icons above heads and the stealthed (translucent) character.


func _bits(kinds: Array) -> int:
	var bits := 0
	for k: String in kinds:
		bits |= 1 << StatusEffect.BIT_KINDS.find(k)
	return bits


func _player() -> PlayerAvatar:
	var a := PlayerAvatar.new()
	add_child_autofree(a)
	a.setup("Ana", 0, "assassin", {})
	return a


func test_status_icon_shown_and_cleared() -> void:
	var a := _player()
	assert_eq(a.bar.status_kinds(), [])
	a.set_statuses(_bits(["stun", "poison"]))
	assert_eq(a.bar.status_kinds(), ["stun", "poison"])
	for icon: Sprite3D in a.bar.status_icons():
		assert_not_null(icon.texture, "every shown status has its icon")
		assert_true(icon.visible)
	a.set_statuses(_bits(["poison"]))
	assert_eq(a.bar.status_kinds(), ["poison"])
	a.set_statuses(0)
	assert_eq(a.bar.status_kinds(), [])
	assert_true(a.bar.status_icons().all(func(i: Sprite3D) -> bool: return not i.visible))


func test_hidden_statuses_have_no_icon() -> void:
	var a := _player()
	a.set_statuses(_bits(["invulnerable", "stealth"]))
	assert_eq(a.bar.status_kinds(), [], "the dodge's invulnerability and stealth are not icons")


func test_at_most_four_icons() -> void:
	var a := _player()
	a.set_statuses(_bits(["stun", "root", "freeze", "slow", "poison", "burn"]))
	assert_eq(a.bar.status_kinds().size(), OverheadBar.MAX_STATUS_ICONS)


func test_stealth_makes_avatar_translucent() -> void:
	var a := _player()
	var meshes := a.find_children("*", "GeometryInstance3D", true, false).filter(
		func(n: Node) -> bool: return a.rig.is_ancestor_of(n))
	assert_gt(meshes.size(), 0)
	assert_false(a.is_translucent())
	a.set_statuses(_bits(["stealth"]))
	assert_true(a.is_translucent())
	for m: GeometryInstance3D in meshes:
		assert_almost_eq(m.transparency, PlayerAvatar.STEALTH_TRANSPARENCY, 0.001)
	a.set_statuses(0)
	assert_false(a.is_translucent())
	for m: GeometryInstance3D in meshes:
		assert_eq(m.transparency, 0.0)


func test_monster_shows_status_icons() -> void:
	var m := MonsterAvatar.new()
	add_child_autofree(m)
	m.setup(MonsterDB.load_default().get_type("marked_hound"))
	m.apply_state({"position": Vector3.ZERO, "aim": Vector3.ZERO, "facing": 0.0},
		{"hp": 30.0, "max_hp": 60.0, "status_bits": _bits(["root"])}, 0.016)
	assert_eq(m.bar.status_kinds(), ["root"])
