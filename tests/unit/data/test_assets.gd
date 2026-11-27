extends GutTest
## All the art is made by the project's own scripts: no third-party model packs.


func _files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_files(dir.path_join(sub), out)


func test_no_kenney_left() -> void:
	var files: Array = []
	_files("res://assets", files)
	for f: String in files:
		assert_false(f.ends_with(".glb") or f.ends_with(".glb.import"), f)
		assert_false(f.contains("characters/base/") or f.contains("characters/layers/"), f)
		assert_false(f.ends_with("character.gdshader"), f)
	assert_false(FileAccess.file_exists("res://tools/art/extract_layers.mjs"))
	assert_false(FileAccess.file_exists("res://tools/art/paint_outfits.mjs"))
	assert_false(FileAccess.get_file_as_string("res://CREDITS.md").contains("Kenney"))


func test_every_v2_piece_file_exists() -> void:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(CharacterCatalog.PIECES_V2))
	assert_true(table is Dictionary and not (table as Dictionary).is_empty(), "the v2 table has pieces")
	for id: String in table:
		var e: Dictionary = table[id]
		assert_true(FileAccess.file_exists(str(e.file)), "%s: %s" % [id, e.file])
		assert_not_null(VoxMesher.cached(str(e.file), {}), id)
		# Plan 7 pieces (races, new hair, marks) exist only in v2 and carry their own tag.
		assert_true(not CharacterCatalog.load_default().piece(id).is_empty() or str(e.get("tag", "")) != "", "%s has a v1 entry or its own tag" % id)


func test_every_v2_gear_file_exists() -> void:
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(CharacterCatalog.GEAR_PIECES_V2))
	var v1: Variant = JSON.parse_string(FileAccess.get_file_as_string(CharacterCatalog.GEAR_PIECES_PATH))
	var jewels := (table as Dictionary).keys().filter(func(id: String) -> bool: return id.begins_with("jewel_"))
	assert_eq(jewels.size(), 6, "a ring and an amulet per tier (never worn)")
	# Race variants (Plan 8.1.1: "<id>_lizard") are v2 only, drawn for one race head.
	var races := (table as Dictionary).keys().filter(func(id: String) -> bool: return id.ends_with("_lizard"))
	assert_eq(races.size(), 3, "the assassin head, three tiers")
	# Story characters' own outfits (Plan 8.3e: "mira_*") are v2 only too.
	var outfits := (table as Dictionary).keys().filter(func(id: String) -> bool: return id.begins_with("mira_"))
	assert_eq(outfits.size(), 13, "Mira: cloak, hood, chest, legs, sleeves, forearms, gloves and boots")
	# The nobles' court clothes (2026-11-27) and the spear (no item yet) are v2 only.
	var court := (table as Dictionary).keys().filter(func(id: String) -> bool: return id.begins_with("noble_") or id.begins_with("w_spear_"))
	assert_eq(court.size(), 13, "gown, skirt, doublet, cape, sleeves, cuffs, boots and three spears")
	# Verrin's and the king's own outfits (2026-11-27).
	var story := (table as Dictionary).keys().filter(func(id: String) -> bool: return id.begins_with("verrin_") or id.begins_with("king_"))
	assert_eq(story.size(), 34)
	court.append_array(story)
	assert_eq((table as Dictionary).size() - jewels.size() - races.size() - outfits.size() - court.size(), (v1 as Dictionary).size(), "one v2 piece per v1 gear piece")
	for id: String in table:
		assert_true(FileAccess.file_exists(str(table[id].file)), id)
