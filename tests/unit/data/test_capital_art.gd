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


## 2026-11-27: the wall closes at the corners (towers), no well, no two neighbouring houses
## with the same interior, people at home, children and other races in the streets.
func test_capital_wall_is_closed_at_the_corners() -> void:
	var z := ZoneLayout.load_id("capital")
	var map := z.collision()
	for c: Vector2i in [Vector2i(10, 11), Vector2i(85, 11), Vector2i(10, 67), Vector2i(86, 67)]:
		assert_true(map.is_solid(c), "the corner %s is closed" % c)
	assert_eq(z.pieces.filter(func(p: Dictionary) -> bool: return p.id == "city_tower").size(), 4)
	assert_false(z.pieces.any(func(p: Dictionary) -> bool: return p.id == "well"), "no well")


func test_capital_neighbouring_houses_differ_inside() -> void:
	var z := ZoneLayout.load_id("capital")
	var houses := z.pieces.filter(func(p: Dictionary) -> bool: return str(p.id).begins_with("house_city"))
	for a: Dictionary in houses:
		for b: Dictionary in houses:
			var d: Vector2i = (b.at - a.at).abs()
			if a != b and ((d.y == 0 and d.x <= 10) or (d.x == 0 and d.y <= 9)):
				assert_ne(a.id, b.id, "%s and %s side by side" % [a.at, b.at])


func test_capital_has_people_at_home_children_and_other_races() -> void:
	var z := ZoneLayout.load_id("capital")
	var at_home := 0
	for n: Dictionary in z.npcs:
		if z.house_at(Vector2i(int(n.at[0]), int(n.at[1]))) >= 0:
			at_home += 1
	assert_gte(at_home, 6, "some houses have someone inside")
	var db := NpcDB.load_default()
	var races := {}
	var children := 0
	for w: Dictionary in z.walkers:
		var look: Dictionary = db.npc(str(w.npc)).get("look", {})
		races[str((look.get("appearance", {}) as Dictionary).get("race", "human"))] = true
		if bool(look.get("child", false)):
			children += 1
	assert_eq(races.keys().size(), 5, "every race walks the capital")
	assert_gte(children, 4)
	assert_true(z.errors.is_empty(), str(z.errors))


func test_a_child_is_small() -> void:
	var look := NpcAvatar.look_of(NpcDB.load_default().npc("nino_1").get("look", {}))
	assert_almost_eq(float(look.race_height), NpcAvatar.CHILD_HEIGHT, 0.01)
	assert_eq(look.race_scale.head, NpcAvatar.CHILD_HEAD)
