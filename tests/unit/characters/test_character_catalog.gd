extends GutTest

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func test_all_kinds_have_expected_counts() -> void:
	var expected := {"body": 2, "skin": 8, "eyes": 7, "hair_style": 8, "hair_color": 11, "beard": 5}
	for kind: String in expected:
		assert_eq(catalog.options(kind).size(), expected[kind], kind)


func test_five_classes_with_ids() -> void:
	var ids := catalog.classes().map(func(c: Dictionary) -> String: return c.id)
	assert_eq(ids, ["warrior", "cleric", "mage", "archer", "assassin"])
	assert_eq(CharacterCatalog.DEFAULT_CLASS, "warrior")


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
		assert_false(catalog.piece(id).is_empty(), id)


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
		for beard: Dictionary in catalog.options("beard"):
			var look := catalog.resolve("warrior", {"hair_style": hair.id, "beard": beard.id})
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
	var hands := {"warrior": "hand_right", "cleric": "hand_right", "mage": "hand_right", "archer": "hand_left", "assassin": "hand_right"}
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
	assert_eq(catalog.sanitize_class("druid"), "warrior")
	assert_eq(catalog.sanitize_class(42), "warrior")
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
	assert_eq(app.keys().size(), 6)
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
