extends GutTest
## Male and female bodies (Plan 8.3e): the woman's face and chest; the old bodies map over.

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func _ids(look: Dictionary) -> Array:
	return (look.pieces as Array).map(func(p: Dictionary) -> String: return str(p.id))


func test_old_bodies_map_over() -> void:
	assert_eq(catalog.sanitize_appearance({"body": "slim"}).body, "female")
	assert_eq(catalog.sanitize_appearance({"body": "robust"}).body, "male")
	assert_eq(catalog.sanitize_appearance({"body": "female"}).body, "female")
	var c := CharacterData.from_dict({"version": 7, "id": "a", "name": "Ana", "class_id": "villager", "appearance": {"body": "slim"}}, catalog)
	assert_not_null(c)
	if c != null:
		assert_eq(c.appearance.body, "female", "a saved slim character is a woman")


func test_bodies_have_names() -> void:
	for o: Dictionary in catalog.options("body"):
		assert_ne(tr(str(o.name)), str(o.name), str(o.id))
	assert_eq(catalog.options("body").map(func(o: Dictionary) -> String: return str(o.id)), ["male", "female"])


func test_woman_has_her_face_and_chest() -> void:
	var woman := catalog.resolve("villager", {"race": "human", "body": "female"})
	var man := catalog.resolve("villager", {"race": "human", "body": "male"})
	assert_string_contains(str(woman.head_file), "head_female")
	assert_eq(str(man.head_file), "", "a man keeps the body's own head")
	assert_has(_ids(woman), "bust_female")
	assert_does_not_have(_ids(man), "bust_female")
	var ogre := catalog.resolve("villager", {"race": "ogre", "body": "female"})
	assert_string_contains(str(ogre.head_file), "ogre", "the race's head wins")


func test_chest_armour_hides_the_chest() -> void:
	var gear := ["sword_t1", "", "", "", "warrior_chest_t1", "", "", ""]
	var armoured := catalog.resolve("warrior", {"race": "human", "body": "female"}, "", gear)
	assert_does_not_have(_ids(armoured), "bust_female")


func test_npcs_use_the_new_bodies() -> void:
	for f: String in DirAccess.get_files_at("res://data/npcs"):
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/" + f))
		var body := str(d.get("look", {}).get("appearance", {}).get("body", ""))
		assert_true(body in ["male", "female", ""], "%s: %s" % [f, body])
	var mira := NpcAvatar.look_of(NpcDB.load_default().npc("mira").look)
	assert_string_contains(str(mira.head_file), "head_female", "Mira is a woman")
	assert_does_not_have(_ids(mira), "bust_female", "her outfit has its own chest")
