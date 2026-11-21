extends GutTest
## Races on the shared v2 body (Plan 7): height, proportions, pieces and heads.

const RACES := ["human", "elf", "dwarf", "ogre", "lizard"]

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func _rig(race: String, body: String = "slim", class_id: String = "warrior") -> HumanRig:
	var rig := HumanRig.create(class_id, {"race": race, "body": body}, catalog)
	add_child_autofree(rig)
	return rig


func _voxel_m(rig: HumanRig) -> float:
	return VoxMesher.VOXEL_SIZE * rig.scale.y


func test_dwarf_shorter_than_human_and_elf() -> void:
	var dwarf := _rig("dwarf").height()
	assert_lt(dwarf, _rig("human").height())
	assert_lt(dwarf, _rig("elf").height())
	assert_lt(_rig("human").height(), _rig("elf").height())


func test_ogre_taller_than_human() -> void:
	assert_gt(_rig("ogre").height(), _rig("human").height() * 1.2)


func test_human_height_unchanged() -> void:
	assert_between(_rig("human").height(), 1.65, 1.85)


func test_feet_on_ground_every_race() -> void:
	for race: String in RACES:
		var rig := _rig(race)
		var low := INF
		for shin: String in ["shin_left", "shin_right"]:
			var mi := rig.part_mesh(shin)
			low = minf(low, (mi.global_transform * mi.get_aabb()).position.y)
		assert_between(low, -_voxel_m(rig) * 1.5, _voxel_m(rig) * 1.5, race + " feet on the ground")


func test_pieces_scale_with_race_part() -> void:
	var rig := _rig("ogre")
	var look := catalog.resolve("warrior", {"race": "ogre"})
	var race_scale: Dictionary = look.race_scale
	var checked := 0
	for p: Dictionary in look.pieces:
		var node := rig.piece_node(p.id)
		var group := str(HumanRig.SCALE_GROUP.get(p.part, "head" if p.part == "head" else ""))
		if node == null or not race_scale.has(group):
			continue
		var f: Array = race_scale[group]
		var vs := float(p.get("voxel_scale", 1.0))
		assert_almost_eq(node.scale.x, vs * float(f[0]), 0.001, p.id)
		checked += 1
	assert_gt(checked, 0)


func test_body_scale_still_does_not_scale_pieces() -> void:
	var rig := _rig("human", "robust")
	for p: Dictionary in catalog.resolve("warrior", {"body": "robust"}).pieces:
		var node := rig.piece_node(p.id)
		if node != null and p.part != "head":
			assert_almost_eq(node.scale.x, float(p.get("voxel_scale", 1.0)), 0.001, p.id)


func test_custom_head_replaces_mesh() -> void:
	var look := catalog.resolve("warrior", {})
	var human := HumanRig.build(look)
	add_child_autofree(human)
	look.head_file = "res://assets/characters/vox_v2/human_v2_torso.vox"
	var other := HumanRig.build(look)
	add_child_autofree(other)
	assert_ne(other.part_mesh("head").mesh, human.part_mesh("head").mesh)


func test_overhead_above_the_head() -> void:
	for race: String in RACES:
		var rig := _rig(race)
		assert_gt(rig.overhead_height(), rig.height() + 0.3, race)


# --- Equipment on race heads (Plan 7, Task 5) ------------------------------------------

func _head_gear_ids() -> Array:
	var ids: Array = []
	var gear: Variant = JSON.parse_string(FileAccess.get_file_as_string(CharacterCatalog.GEAR_PIECES_V2))
	for id: String in gear:
		if gear[id].part == "head":
			ids.append(id)
	for id: String in ["hat_mage", "hood_archer", "helm_templar", "mask_assassin"]:
		ids.append(id)
	return ids


func test_every_head_piece_attaches_to_every_race() -> void:
	var ids := _head_gear_ids()
	assert_gt(ids.size(), 18)
	for race: String in RACES:
		var look := catalog.resolve("villager", {"race": race})
		for id: String in ids:
			look.pieces.append(catalog.piece_entry(id))
		var rig := HumanRig.build(look)
		add_child_autofree(rig)
		for id: String in ids:
			assert_not_null(rig.piece_node(id), "%s on %s" % [id, race])


func test_closed_headgear_hides_elf_ears() -> void:
	var hooded: Array = catalog.resolve("archer", {"race": "elf"}).pieces.map(func(p: Dictionary) -> String: return p.id)
	assert_does_not_have(hooded, "ears_elf")
	var hatted: Array = catalog.resolve("mage", {"race": "elf"}).pieces.map(func(p: Dictionary) -> String: return p.id)
	assert_has(hatted, "ears_elf", "the mage hat leaves the ears out")


func test_tail_never_hidden() -> void:
	for cls: String in ["archer", "warrior", "mage", "cleric", "assassin"]:
		var ids: Array = catalog.resolve(cls, {"race": "lizard"}).pieces.map(func(p: Dictionary) -> String: return p.id)
		assert_has(ids, "tail_lizard", cls)


func test_piece_fit_overrides_head_fit() -> void:
	var ogre := catalog.race_def("ogre")
	ogre["piece_fit"] = {"hat_mage": {"scale": 1.4, "offset": [0, 3, 0]}}
	var look := catalog.resolve("mage", {"race": "ogre"})
	ogre.erase("piece_fit")
	var hat: Dictionary = look.pieces.filter(func(p: Dictionary) -> bool: return p.id == "hat_mage")[0]
	assert_eq(float(hat.fit.scale), 1.4)
	var rig := HumanRig.build(look)
	add_child_autofree(rig)
	var plain := _rig("ogre", "slim", "mage")
	assert_almost_eq(rig.piece_node("hat_mage").scale.x / plain.piece_node("hat_mage").scale.x,
		1.4 / float(catalog.race_def("ogre").head_fit.scale), 0.001)
