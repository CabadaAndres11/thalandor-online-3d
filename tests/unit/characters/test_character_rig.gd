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


## A piece on the head (scale 0.1) must keep its real size: one voxel = 0.1 model units.
func test_head_piece_compensates_head_scale() -> void:
	var rig := CharacterRig.build(_mage_look())
	add_child_autofree(rig)
	var hat := rig.piece_node("hat_mage")
	var head := rig.part("head")
	assert_almost_eq((head.scale * hat.scale).x, 1.0, 0.0001)
	assert_almost_eq(hat.position, Vector3(-7, 8, -7), Vector3.ONE * 0.0001)
