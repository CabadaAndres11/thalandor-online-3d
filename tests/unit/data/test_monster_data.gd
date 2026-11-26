extends GutTest
## The prologue's bestiary (the night the cult attacks the village) as data.

const ROSTER := ["bandit", "bandit_archer", "bandit_chief", "cult_acolyte", "cult_archer", "cult_inquisitor", "cultist", "heraldo", "marked_boar", "marked_hound", "nhazar", "training_dummy", "vaelthar"]


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
		elif model.begins_with("piece:"):
			var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.PIECES_PATH))
			assert_true(pieces.has(model.trim_prefix("piece:")), t.id + " piece model")
		else:
			assert_true(model.begins_with("humanoid:"), t.id + " model kind")
			for id: String in t.look.pieces:
				assert_false(catalog.piece(id).is_empty(), "%s: piece %s" % [t.id, id])
		for ab: String in t.abilities:
			assert_false(abilities.get_ability(ab).is_empty(), "%s: %s" % [t.id, ab])
		assert_ne(tr(str(t.name)), str(t.name), t.id + " name translated")


func test_map_spawns_exist() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/arena.json"))
	for s: Dictionary in map.spawns:
		assert_has(ROSTER, s.type)
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/cult_acolyte.json"))
	assert_has(ROSTER, boss.summon.type)


func test_summon_only_monsters_are_not_on_the_map() -> void:
	var only := _types().filter(func(t: Dictionary) -> bool: return t.get("summon_only", false)).map(func(t: Dictionary) -> String: return t.id)
	assert_eq(only, ["hunter_wolf"])
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones/arena.json"))
	for sp: Dictionary in map.spawns:
		assert_does_not_have(only, sp.type)


## Plan 8.3b: the bandits are plain people, not the cult, and their avatars build.
func test_bandits_are_not_cult() -> void:
	for id: String in ["bandit", "bandit_archer", "bandit_chief"]:
		var t := MonsterDB.load_default().get_type(id)
		assert_false(t.is_empty(), id)
		for piece: String in t.look.pieces:
			assert_false(piece.begins_with("cult_") or piece.begins_with("acolyte_") or piece.begins_with("inquisitor_") or piece.begins_with("mask_"), "%s wears %s" % [id, piece])
		var a := MonsterAvatar.new()
		add_child_autofree(a)
		a.setup(t)
		assert_gt(a.find_children("*", "MeshInstance3D", true, false).size(), 0, id + " has a body")
	assert_eq(MonsterDB.load_default().get_type("bandit_chief").abilities[0], "bandit_chief_smash", "the chief's heavy blow is announced")
