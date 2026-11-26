extends GutTest
## Plan 8.3a: the prologue's world pieces and NPCs are in the data and load.

const PIECES := ["garland", "lantern_post", "feast_table", "bonfire", "house_burnt_small", "house_burnt_large",
	"rubble", "fallen_beam", "grave", "army_tent", "kingdom_banner", "camp_ruined", "cart_tracks", "river_bank",
	"training_dummy"]
const NPCS := ["mira", "verrin", "soldado_reino", "anciana_cantora", "panadero", "cazador",
	"aldeano_anciano_1", "aldeano_anciano_2", "aldeano_anciano_3", "aldeano_anciano_4",
	"aldeana_anciana_1", "aldeana_anciana_2", "aldeana_anciana_3", "aldeano_1", "aldeano_2"]


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


func test_burnt_houses_stand_on_the_healthy_ones_cells() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.PIECES_PATH))
	assert_eq(table.house_burnt_small.footprint, table.house_small.footprint)
	assert_eq(table.house_burnt_large.footprint, table.house_large.footprint)


func test_npc_looks_valid() -> void:
	var catalog := CharacterCatalog.load_default()
	var db := NpcDB.load_default()
	for id: String in NPCS:
		var d := db.npc(id)
		assert_false(d.is_empty(), id)
		assert_ne(tr(str(d.get("name", ""))), str(d.get("name", "")), id + " name")
		assert_ne(tr(str(d.get("lines", {}).get("greet", ""))), str(d.get("lines", {}).get("greet", "")), id + " greet")
		var look: Dictionary = d.get("look", {})
		assert_eq(catalog.sanitize_class(look.get("class", "")), str(look.get("class", "")), id + " class")
		var clean := catalog.sanitize_appearance(look.get("appearance", {}))
		for k: String in look.get("appearance", {}):
			assert_eq(clean[k], look.appearance[k], "%s %s" % [id, k])


func test_the_old_neighbour_is_gone() -> void:
	assert_true(NpcDB.load_default().npc("vecina").is_empty())


func test_dummy_model() -> void:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type("training_dummy"))
	assert_gt(a.find_children("*", "MeshInstance3D", true, false).size(), 0)
