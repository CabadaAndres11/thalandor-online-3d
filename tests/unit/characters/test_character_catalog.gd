extends GutTest

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func test_all_kinds_have_expected_counts() -> void:
	var expected := {"body": 2, "skin": 8, "eyes": 6, "hair_style": 8, "hair_color": 10, "beard": 5}
	for kind: String in expected:
		assert_eq(catalog.options(kind).size(), expected[kind], kind)


func test_five_classes_with_ids() -> void:
	var ids := catalog.classes().map(func(c: Dictionary) -> String: return c.id)
	assert_eq(ids, ["warrior", "cleric", "mage", "archer", "assassin"])
	assert_eq(CharacterCatalog.DEFAULT_CLASS, "warrior")


func test_every_referenced_file_exists() -> void:
	var paths: Array[String] = []
	for kind: String in ["hair_style", "beard"]:
		for o: Dictionary in catalog.options(kind):
			if o.get("layer", "") != "":
				paths.append(o.layer)
	for c: Dictionary in catalog.classes():
		paths.append(c.outfit)
	for p: String in paths:
		assert_true(ResourceLoader.exists(p), p)
	for id: String in catalog.piece_ids():
		var piece := catalog.piece(id)
		assert_not_null(VoxFile.load_file(piece.file), "%s: %s" % [id, piece.file])
		assert_has(CharacterRig.PARTS, piece.part, id + " part")


func test_every_referenced_piece_is_defined() -> void:
	for o: Dictionary in catalog.options("hair_style"):
		if o.get("piece", "") != "":
			assert_false(catalog.piece(o.piece).is_empty(), o.piece)
	for c: Dictionary in catalog.classes():
		if c.get("headgear", "") != "":
			assert_false(catalog.piece(c.headgear).is_empty(), c.headgear)


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


func test_resolve_gives_colors_layers_and_pieces() -> void:
	var look := catalog.resolve("mage", {"skin": "skin_3", "hair_style": "hair_long", "hair_color": "red", "beard": "none"})
	assert_eq(look.skin_color, Color(catalog.option("skin", "skin_3").color))
	assert_eq(look.hair_color, Color(catalog.option("hair_color", "red").color))
	assert_eq(look.beard_layer, "")
	var ids := (look.pieces as Array).map(func(p: Dictionary) -> String: return p.id)
	assert_has(ids, "hat_mage")
	assert_does_not_have(ids, "hair_long", "the mage hat hides long hair")
