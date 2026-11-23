extends GutTest

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func test_all_kinds_have_expected_counts() -> void:
	var expected := {"race": 5, "body": 2, "skin": 22, "eyes": 9, "hair_style": 21, "hair_color": 16, "beard": 10, "marks": 6}
	for kind: String in expected:
		assert_eq(catalog.options(kind).size(), expected[kind], kind)


func test_classes_villager_first_then_the_five() -> void:
	var ids: Array = catalog.classes().map(func(c: Dictionary) -> String: return c.id)
	assert_eq(ids, ["villager", "warrior", "cleric", "mage", "archer", "assassin"])
	assert_eq(CharacterCatalog.DEFAULT_CLASS, "villager")


func test_villager_not_selectable() -> void:
	var ids: Array = catalog.selectable_classes().map(func(c: Dictionary) -> String: return c.id)
	assert_eq(ids, ["warrior", "cleric", "mage", "archer", "assassin"])
	assert_false(catalog.is_selectable("villager"))
	assert_true(catalog.is_selectable("mage"))
	assert_false(catalog.is_selectable("druid"))


func test_every_referenced_file_exists() -> void:
	for id: String in catalog.piece_ids():
		var piece := catalog.piece(id)
		assert_not_null(VoxFile.load_file(piece.file), "%s: %s" % [id, piece.file])
		assert_has(HumanRig.PARTS, piece.part, id + " part")


func test_every_referenced_piece_is_defined() -> void:
	var ids: Array = []
	for o: Dictionary in catalog.options("hair_style"):
		ids.append_array(o.get("pieces", []))
	for o: Dictionary in catalog.options("beard"):
		if str(o.get("piece", "")) != "":
			ids.append(o.piece)
	for c: Dictionary in catalog.classes():
		if c.get("headgear", "") != "":
			ids.append(c.headgear)
		ids.append_array(c.get("pieces", []))
		ids.append_array(c.get("weapons", []))
	for id: String in ids:
		assert_false(catalog.piece(id).is_empty() and catalog.piece_v2(id).is_empty(), id)


func test_warrior_wears_pauldrons_on_both_arms() -> void:
	var look := catalog.resolve("warrior", {})
	var parts := {}
	for p: Dictionary in look.pieces:
		parts[p.id] = p.part
	assert_eq(parts.get("pauldron_left"), "arm_left")
	assert_eq(parts.get("pauldron_right"), "arm_right")


func _ids(look: Dictionary) -> Array:
	return (look.pieces as Array).map(func(p: Dictionary) -> String: return p.id)


func test_every_appearance_id_resolves() -> void:
	for hair: Dictionary in catalog.options("hair_style"):
		var race: String = hair.get("races", ["human"])[0]
		for beard: Dictionary in catalog.options_for("beard", race):
			var look := catalog.resolve("warrior", {"race": race, "hair_style": hair.id, "beard": beard.id})
			for key: String in look:
				assert_false(key.ends_with("_layer"), key)
			var ids := _ids(look)
			for id: String in hair.get("pieces", []):
				assert_has(ids, id, "%s/%s" % [hair.id, beard.id])
			if beard.id != "none":
				assert_has(ids, "beard_" + str(beard.id), beard.id)


func test_bald_has_no_hair_piece() -> void:
	var ids := _ids(catalog.resolve("warrior", {"hair_style": "bald", "beard": "none"}))
	for id: String in ids:
		assert_false(id.begins_with("hair_") or id.begins_with("beard_"), id)


func test_class_weapon_in_hand() -> void:
	var hands := {"villager": "hand_right", "warrior": "hand_right", "cleric": "hand_right", "mage": "hand_right", "archer": "hand_left", "assassin": "hand_right"}
	for class_id: String in hands:
		var look := catalog.resolve(class_id, {})
		var weapons := (look.pieces as Array).filter(func(p: Dictionary) -> bool: return str(p.id).begins_with("weapon_"))
		assert_gt(weapons.size(), 0, class_id + " has a weapon")
		assert_eq(weapons[0].part, hands[class_id], class_id)


func test_hood_hides_all_hair_but_hat_keeps_the_cap() -> void:
	var app := {"hair_style": "hair_long"}
	var archer := _ids(catalog.resolve("archer", app))
	assert_does_not_have(archer, "hair_bob")
	assert_does_not_have(archer, "hair_long")
	var mage := _ids(catalog.resolve("mage", app))
	assert_has(mage, "hair_bob", "the cap shows under the brim")
	assert_does_not_have(mage, "hair_long", "the hat hides long hair")


func test_every_name_key_is_translated() -> void:
	var keys: Array[String] = []
	for kind: String in CharacterCatalog.KINDS:
		for o: Dictionary in catalog.options(kind):
			if o.has("name"):
				keys.append(o.name)
	for c: Dictionary in catalog.classes():
		keys.append(c.name)
		keys.append(c.desc)
	for k: String in keys:
		assert_ne(TranslationServer.translate(k), k, k)


func test_sanitize_unknown_ids_fall_back_to_defaults() -> void:
	var app := catalog.sanitize_appearance({"skin": "nope", "hair_style": "hair_long", "eyes": 7})
	assert_eq(app.skin, catalog.default_appearance().skin)
	assert_eq(app.hair_style, "hair_long")
	assert_eq(app.eyes, catalog.default_appearance().eyes)
	assert_eq(catalog.sanitize_class("druid"), "villager")
	assert_eq(catalog.sanitize_class(42), "villager")
	assert_eq(catalog.sanitize_class("mage"), "mage")


func test_sanitize_non_dictionary_returns_default() -> void:
	assert_eq(catalog.sanitize_appearance(null), catalog.default_appearance())
	assert_eq(catalog.sanitize_appearance([1, 2]), catalog.default_appearance())


func test_sanitize_drops_extra_keys_and_non_strings() -> void:
	var junk := {}
	for i in 300:
		junk["k%d" % i] = i
	junk["beard"] = 5
	var app := catalog.sanitize_appearance(junk)
	assert_eq(app.keys().size(), CharacterCatalog.KINDS.size())
	for kind: String in CharacterCatalog.KINDS:
		assert_true(app.has(kind), kind)
		assert_false(catalog.option(kind, app[kind]).is_empty(), kind)


func test_random_appearance_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var app := catalog.random_appearance(rng)
		assert_eq(catalog.sanitize_appearance(app), app)


func test_resolve_gives_colors_and_pieces() -> void:
	var look := catalog.resolve("mage", {"skin": "skin_3", "hair_style": "hair_long", "hair_color": "red", "beard": "none"})
	assert_eq(look.skin_color, Color(catalog.option("skin", "skin_3").color))
	assert_eq(look.hair_color, Color(catalog.option("hair_color", "red").color))
	assert_has(_ids(look), "hat_mage")


func test_red_hair_and_eyes_are_options() -> void:
	assert_false(catalog.option("hair_color", "crimson").is_empty())
	assert_false(catalog.option("eyes", "red").is_empty())


## Every weapon passes through its fist (the hand is voxels x -2..1, y -4..0, z -2..1 from
## its pivot), so it is held, not floating in front of it.
func test_weapons_pass_through_the_fist() -> void:
	for id: String in catalog.piece_ids():
		if not id.begins_with("weapon_"):
			continue
		var p := catalog.piece(id)
		var vox := VoxFile.load_file(p.file)
		var o: Array = p.offset
		var inside := false
		for v: Array in vox.voxels:
			var cell := Vector3i(int(o[0]) + v[0], int(o[1]) + v[1], int(o[2]) + v[2])
			if cell.x >= -2 and cell.x <= 1 and cell.y >= -4 and cell.y <= 0 and cell.z >= -2 and cell.z <= 1:
				inside = true
				break
		assert_true(inside, id + " goes through the fist")


func test_cult_sleeves_hang_from_the_arms() -> void:
	assert_eq(catalog.piece("cult_sleeve_left").part, "arm_left")
	assert_eq(catalog.piece("cult_cuff_left").part, "forearm_left")
	assert_eq(catalog.piece("cult_cuff_right").part, "forearm_right")
	assert_true(catalog.piece("cult_mask").is_empty(), "the faceless hood replaces the mask")


func _gear_db() -> ItemDB:
	var db := ItemDB.load_default()
	var fake := ItemDB.load_dir(ItemDB.DIR)
	fake._bases = db._bases.duplicate(true)
	fake._bases["warrior_head_t1"]["look"] = ["helm_templar"]
	fake._bases["greatsword_t1"]["look"] = ["weapon_sword"]
	fake._bases["warrior_chest_t1"]["look"] = ["outfit_warrior"]
	return fake



func test_resolve_from_gear() -> void:
	var cat := CharacterCatalog.load_default()
	var gear := ["greatsword_t1", "", "warrior_head_t1", "", "", "", "", ""]
	var look := cat.resolve("warrior", {"hair_style": "hair_long"}, "", gear, _gear_db())
	var ids := _ids(look)
	assert_has(ids, "helm_templar")
	assert_has(ids, "weapon_sword")
	assert_does_not_have(ids, "hair_long", "the helm hides the hair")
	assert_has(ids, "outfit_villager", "an empty chest shows the base clothes")
	assert_does_not_have(ids, "outfit_warrior", "the class outfit is not used with gear")
	assert_eq(look.grip, "two_hand")


func test_resolve_gear_chest_replaces_base_clothes() -> void:
	var cat := CharacterCatalog.load_default()
	var gear := ["", "", "", "", "warrior_chest_t1", "", "", ""]
	var ids := _ids(cat.resolve("warrior", {}, "", gear, _gear_db()))
	assert_has(ids, "outfit_warrior")
	assert_does_not_have(ids, "outfit_villager")


func test_upgrade_look_ignored_with_gear() -> void:
	var cat := CharacterCatalog.load_default()
	var gear := ["", "", "", "", "", "", "", ""]
	assert_does_not_have(_ids(cat.resolve("cleric", {}, "templar", gear, _gear_db())), "helm_templar")


func test_quiver_always() -> void:
	var cat := CharacterCatalog.load_default()
	assert_has(_ids(cat.resolve("archer", {}, "", ["", "", "", "", "", "", "", ""])), "quiver_back")


func test_without_gear_as_before() -> void:
	var cat := CharacterCatalog.load_default()
	assert_has(_ids(cat.resolve("warrior", {})), "outfit_warrior")


func test_offhand_dagger_uses_the_left_hand_model() -> void:
	var cat := CharacterCatalog.load_default()
	var ids := _ids(cat.resolve("assassin", {}, "", ["dagger_t1", "dagger_t1", "", "", "", "", "", ""]))
	assert_has(ids, "w_dagger_t1")
	assert_has(ids, "w_dagger_t1_left")


func test_tier3_chest_brings_its_aura() -> void:
	var cat := CharacterCatalog.load_default()
	var look := cat.resolve("mage", {}, "", ["", "", "", "", "mage_chest_t3", "", "", ""])
	assert_eq(look.auras, [Color("#c07bff")])
	assert_eq(cat.resolve("mage", {}, "", ["", "", "", "", "mage_chest_t2", "", "", ""]).auras, [])


func test_resolve_gives_the_v2_body() -> void:
	var look := CharacterCatalog.load_default().resolve("warrior", {})
	assert_eq(look.get("body"), "v2")


func test_cult_pieces_have_v2_versions() -> void:
	var cat := CharacterCatalog.load_default()
	assert_false(cat.piece_v2("cult_hood").is_empty(), "the cult's pieces too (Plan 6.4.1)")
	assert_string_contains(str(cat.piece_entry("cult_hood").file), "/pieces_v2/")


func test_a_piece_without_v2_is_drawn_twice_as_big() -> void:
	var cat := CharacterCatalog.load_default()
	var saved: Dictionary = cat._pieces_v2["cult_hood"]
	cat._pieces_v2.erase("cult_hood")
	var e: Dictionary = cat.piece_entry("cult_hood")
	cat._pieces_v2["cult_hood"] = saved
	assert_string_contains(str(e.file), "/pieces/")
	assert_almost_eq(float(e.get("voxel_scale", 1.0)), 2.0, 0.001)


func test_monster_look_is_v2() -> void:
	var type: Dictionary = MonsterDB.load_default().get_type("cultist")
	assert_false(type.is_empty())
	var look := MonsterAvatar.look_of(type)
	assert_eq(look.body, "v2")
	for p: Dictionary in look.get("pieces", []):
		assert_false(p.has("voxel_scale"), str(p.id))


# --- Races (Plan 7) ---------------------------------------------------------------

func test_races_loaded() -> void:
	var ids: Array = catalog.options("race").map(func(o: Dictionary) -> String: return o.id)
	assert_eq(ids, ["human", "elf", "dwarf", "ogre", "lizard"])
	assert_eq(float(catalog.race_def("dwarf").height), 0.8)
	assert_eq(catalog.default_appearance().race, "human")


func test_options_filtered_by_race() -> void:
	var fake := {"id": "x_only_lizard", "races": ["lizard"]}
	catalog._options["hair_style"].append(fake)
	var lizard: Array = catalog.options_for("hair_style", "lizard").map(func(o: Dictionary) -> String: return o.id)
	var human: Array = catalog.options_for("hair_style", "human").map(func(o: Dictionary) -> String: return o.id)
	catalog._options["hair_style"].erase(fake)
	assert_has(lizard, "x_only_lizard")
	assert_does_not_have(human, "x_only_lizard")


func test_sanitize_fixes_options_of_other_race() -> void:
	var app := catalog.sanitize_appearance({"race": "lizard", "hair_style": "short", "skin": "skin_1", "beard": "full"})
	for kind: String in ["hair_style", "skin", "beard"]:
		var valid: Array = catalog.options_for(kind, "lizard").map(func(o: Dictionary) -> String: return o.id)
		assert_has(valid, app[kind], kind)
	assert_eq(app.hair_style, catalog.options_for("hair_style", "lizard")[0].id)


func test_sanitize_missing_race_is_human() -> void:
	var app := catalog.sanitize_appearance({"hair_style": "hair_long"})
	assert_eq(app.race, "human")
	assert_eq(app.marks, "none")
	assert_eq(app.hair_style, "hair_long")


func test_random_is_always_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var races := {}
	for i in 200:
		var app := catalog.random_appearance(rng)
		races[app.race] = true
		assert_eq(catalog.sanitize_appearance(app), app)
	assert_eq(races.size(), 5)


func test_resolve_has_race_keys() -> void:
	var dwarf := catalog.resolve("warrior", {"race": "dwarf"})
	assert_eq(float(dwarf.race_height), 0.8)
	assert_true(dwarf.race_scale is Dictionary)
	var human := catalog.resolve("warrior", {})
	assert_eq(human.head_file, "")
	assert_eq(float(human.race_height), 1.0)
	assert_true(human.head_fit is Dictionary)


func test_new_hair_hidden_by_the_hood() -> void:
	var ids := _ids(catalog.resolve("archer", {"hair_style": "hair_braids"}))
	assert_does_not_have(ids, "hair_braids")
	assert_has(_ids(catalog.resolve("warrior", {"hair_style": "hair_braids"})), "hair_braids")


func test_lizard_wears_a_crest_and_a_tail() -> void:
	var ids := _ids(catalog.resolve("warrior", {"race": "lizard"}))
	assert_has(ids, "crest_fin")
	assert_has(ids, "tail_lizard")
	assert_ne(catalog.resolve("warrior", {"race": "lizard"}).head_file, "")


func test_every_appearance_piece_exists_v1_or_v2() -> void:
	for kind: String in ["hair_style", "beard", "marks"]:
		for o: Dictionary in catalog.options(kind):
			var ids: Array = o.get("pieces", [])
			if str(o.get("piece", "")) != "":
				ids = ids + [o.piece]
			for id: String in ids:
				assert_false(catalog.piece(id).is_empty() and catalog.piece_v2(id).is_empty(), id)
	for r: Dictionary in catalog.options("race"):
		for id: String in catalog.race_def(r.id).get("pieces", []):
			assert_false(catalog.piece_v2(id).is_empty(), id)


## A race added in data/ without, say, its skins would break the create screen.
func test_every_race_has_options_for_every_kind() -> void:
	for r: Dictionary in catalog.options("race"):
		for kind: String in CharacterCatalog.KINDS:
			assert_gt(catalog.options_for(kind, r.id).size(), 0, "%s / %s" % [r.id, kind])


## Plan 8.1.1: a lizard wears the assassin hood and mask drawn for its snout.
func test_lizard_swaps_the_assassin_head_piece() -> void:
	var look := catalog.resolve("assassin", {"race": "lizard"}, "", ["", "", "assassin_head_t1", "", "", "", "", ""], ItemDB.load_default())
	var ids: Array = look.pieces.map(func(e: Dictionary) -> String: return e.id)
	assert_has(ids, "assassin_head_t1_lizard")
	assert_does_not_have(ids, "assassin_head_t1")
	var human := catalog.resolve("assassin", {"race": "human"}, "", ["", "", "assassin_head_t1", "", "", "", "", ""], ItemDB.load_default())
	assert_has(human.pieces.map(func(e: Dictionary) -> String: return e.id), "assassin_head_t1")
