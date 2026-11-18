extends GutTest
## The prologue's bestiary (the night the cult attacks the village) as data.

const ROSTER := ["cult_acolyte", "cult_archer", "cultist", "marked_boar", "marked_hound", "nhazar", "vaelthar"]


func _types() -> Array:
	var out := []
	for f: String in DirAccess.get_files_at("res://data/monsters"):
		if f.ends_with(".json"):
			out.append(JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/" + f)))
	return out


func test_prologue_roster() -> void:
	var ids := _types().filter(func(t: Dictionary) -> bool: return not t.get("summon_only", false)).map(func(t: Dictionary) -> String: return t.id)
	ids.sort()
	assert_eq(ids, ROSTER)


func test_every_monster_loads() -> void:
	var abilities := AbilityDB.load_default()
	var catalog := CharacterCatalog.load_default()
	for t: Dictionary in _types():
		var model := str(t.model)
		if model.begins_with("rig:"):
			assert_true(FileAccess.file_exists("res://assets/monsters/vox/%s.json" % model.trim_prefix("rig:")), t.id)
		else:
			assert_true(model.begins_with("humanoid:"), t.id + " model kind")
			for id: String in t.look.pieces:
				assert_false(catalog.piece(id).is_empty(), "%s: piece %s" % [t.id, id])
		for ab: String in t.abilities:
			assert_false(abilities.get_ability(ab).is_empty(), "%s: %s" % [t.id, ab])
		assert_ne(tr(str(t.name)), str(t.name), t.id + " name translated")


func test_map_spawns_exist() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/test_arena.json"))
	for s: Dictionary in map.spawns:
		assert_has(ROSTER, s.type)
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/cult_acolyte.json"))
	assert_has(ROSTER, boss.summon.type)


func test_summon_only_monsters_are_not_on_the_map() -> void:
	var only := _types().filter(func(t: Dictionary) -> bool: return t.get("summon_only", false)).map(func(t: Dictionary) -> String: return t.id)
	assert_eq(only, ["hunter_wolf"])
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/test_arena.json"))
	for sp: Dictionary in map.spawns:
		assert_does_not_have(only, sp.type)
