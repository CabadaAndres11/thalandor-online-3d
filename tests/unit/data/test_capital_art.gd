extends GutTest
## Plan 8.3b: the road, the capital and the palace: pieces, NPCs and the palace's light.

const PIECES := ["city_wall", "city_gate", "house_city", "market_stall", "fountain", "city_lamp", "palace_column",
	"palace_carpet", "throne", "brazier", "crypt_gate_closed", "crypt_gate_open", "caravan_wagon", "horse", "bandit_palisade"]
const NPCS := ["rey", "oriel", "lord_maren", "caravanero", "maese_corwin", "guardia_palacio", "guardia_ciudad",
	"ciudadano_1", "ciudadano_2", "ciudadano_3", "ciudadano_4", "ciudadana_1", "ciudadana_2", "ciudadana_3", "ciudadana_4"]


func test_pieces_exist() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.PIECES_PATH))
	for id: String in PIECES:
		assert_true(table.has(id), id)
		var def: Dictionary = table.get(id, {})
		var files: Array = []
		if def.has("parts"):
			for part: String in def.parts:
				files.append(str(def.parts[part].vox))
		else:
			files.append(str(def.get("vox", "")))
		for f: String in files:
			assert_true(FileAccess.file_exists(f), f)


func test_npc_looks_valid() -> void:
	var catalog := CharacterCatalog.load_default()
	var db := NpcDB.load_default()
	for id: String in NPCS:
		var d := db.npc(id)
		assert_false(d.is_empty(), id)
		assert_ne(tr(str(d.get("name", ""))), str(d.get("name", "")), id + " name")
		assert_ne(tr(str(d.lines.greet)), str(d.lines.greet), id + " greet")
		var look: Dictionary = d.get("look", {})
		assert_eq(catalog.sanitize_class(look.get("class", "")), str(look.get("class", "")), id + " class")
		var clean := catalog.sanitize_appearance(look.get("appearance", {}))
		for k: String in look.get("appearance", {}):
			assert_eq(clean[k], look.appearance[k], "%s %s" % [id, k])
	assert_eq(str(db.npc("maese_corwin").role), "class_trainer", "the resets")


func test_palace_ambience_loads() -> void:
	assert_has(Ambience.ids(), "palacio")
	assert_eq(Ambience.load_id("palacio").id, "palacio")
