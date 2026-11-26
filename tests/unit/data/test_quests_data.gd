extends GutTest
## Quest data (Plan 8.2): every reference in data/quests/ exists, so a typo fails here and
## not in a game.

const BAD := "res://tests/data/quests_bad/"
const ZONES := "res://tests/data/zones/"


func _validate(db: QuestDB, zones := "res://data/zones/") -> Array[String]:
	return db.validate(NpcDB.load_default(), MonsterDB.load_default(), ItemDB.load_default(), zones,
		"res://data/dialogues/", "res://data/cutscenes/")


func test_every_quest_is_valid() -> void:
	var errors := _validate(QuestDB.load_dir(QuestDB.DIR))
	assert_eq(errors, [] as Array[String], "\n".join(errors))


func test_broken_refs_reported() -> void:
	var errors := "\n".join(_validate(QuestDB.load_dir(BAD), ZONES))
	for bit in ["nadie", "lobo", "q_nada", "no_point", "no_dialogue", "no_scene", "no_item", "NO_SUCH_TEXT"]:
		assert_string_contains(errors, bit)


func test_unknown_objective_type() -> void:
	assert_string_contains("\n".join(_validate(QuestDB.load_dir(BAD), ZONES)), "bailar")


func test_normalized_objectives() -> void:
	var db := QuestDB.load_dir(BAD)
	var o: Dictionary = db.quest("q_broken").steps[0].objectives[3]
	assert_eq(int(o.count), 1, "count defaults to 1")
	assert_eq(db.by_turn_in("brann"), ["q_broken"])
	assert_eq(db.by_giver("nadie"), ["q_broken"])
	assert_eq(db.ids(), ["q_broken"])
	assert_true(db.quest("nope").is_empty())
