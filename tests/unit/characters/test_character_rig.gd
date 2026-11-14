extends GutTest

const LAYERS := "res://assets/characters/layers/"
const PIECES := "res://assets/characters/pieces/"


func _mage_look() -> Dictionary:
	return {
		"skin_color": Color("#e8b996"), "eyes_color": Color("#4678c8"), "hair_color": Color("#784628"),
		"hair_layer": LAYERS + "hair_short.png", "beard_layer": LAYERS + "beard_full.png",
		"outfit_layer": LAYERS + "outfit_mage.png",
		"primary": Color("#5b3f9e"), "secondary": Color("#e8b23a"),
		"body_scale": {},
		"pieces": [
			{"id": "hat_mage", "file": PIECES + "hat_mage.vox", "part": "head", "offset": [-7, 8, -7]},
		],
	}


func test_rig_has_six_parts_and_attached_pieces() -> void:
	var rig := CharacterRig.build(_mage_look())
	add_child_autofree(rig)
	for part_name: String in CharacterRig.PARTS:
		assert_not_null(rig.part(part_name), part_name)
	var hat := rig.piece_node("hat_mage")
	assert_not_null(hat, "hat attached")
	assert_eq(hat.get_parent(), rig.part("head"), "hat is a child of the head")
	assert_eq(rig.pieces(), ["hat_mage"])


func test_parts_use_the_layered_shader() -> void:
	var rig := CharacterRig.build(_mage_look())
	add_child_autofree(rig)
	var mesh := rig.part("torso") as MeshInstance3D
	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	assert_not_null(mat)
	assert_eq(mat.get_shader_parameter("hair_color"), Color("#784628"))
	assert_not_null(mat.get_shader_parameter("outfit_tex"))


func test_model_is_about_1_8_m_tall() -> void:
	var rig := CharacterRig.build(_mage_look())
	add_child_autofree(rig)
	assert_almost_eq(rig.scale.y, CharacterRig.MODEL_SCALE, 0.0001)
	assert_almost_eq(2.7 * CharacterRig.MODEL_SCALE, 1.8, 0.01)


func test_builds_every_class_body_and_hair_style_without_errors() -> void:
	var catalog := CharacterCatalog.load_default()
	for c: Dictionary in catalog.classes():
		for body: Dictionary in catalog.options("body"):
			for hair: Dictionary in catalog.options("hair_style"):
				var rig := CharacterRig.create(c.id, {"body": body.id, "hair_style": hair.id}, catalog)
				assert_not_null(rig.part("head"), "%s %s %s" % [c.id, body.id, hair.id])
				rig.free()


func test_hood_hides_long_hair() -> void:
	var rig := CharacterRig.create("archer", {"hair_style": "hair_long"})
	add_child_autofree(rig)
	assert_has(rig.pieces(), "hood_archer")
	assert_does_not_have(rig.pieces(), "hair_long")


func test_warrior_shows_long_hair() -> void:
	var rig := CharacterRig.create("warrior", {"hair_style": "hair_long"})
	add_child_autofree(rig)
	assert_has(rig.pieces(), "hair_long", "no headgear hides the warrior's hair")


func test_robust_body_scales_torso_but_not_the_head() -> void:
	var slim := CharacterRig.create("warrior", {"body": "slim"})
	var robust := CharacterRig.create("warrior", {"body": "robust"})
	add_child_autofree(slim)
	add_child_autofree(robust)
	assert_gt(robust.part("torso").scale.x, slim.part("torso").scale.x)
	# The head and arms are children of the torso: their world size must not grow
	# with the torso (only the arms' own factor applies).
	assert_almost_eq(robust.part("head").global_transform.basis.get_scale().x,
		slim.part("head").global_transform.basis.get_scale().x, 0.0001)


## A piece on the head (scale 0.1) must keep its real size: one voxel = 0.1 model units.
func test_head_piece_compensates_head_scale() -> void:
	var rig := CharacterRig.build(_mage_look())
	add_child_autofree(rig)
	var hat := rig.piece_node("hat_mage")
	var head := rig.part("head")
	assert_almost_eq((head.scale * hat.scale).x, 1.0, 0.0001)
	assert_almost_eq(hat.position, Vector3(-7, 8, -7), Vector3.ONE * 0.0001)
