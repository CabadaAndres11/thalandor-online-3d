extends GutTest
## QuestLog (Plan 8.2): a character's quests, saved in its file and sanitized on load.

var db: QuestDB


func before_each() -> void:
	db = QuestDB.load_dir("res://tests/data/quests/")


func _log() -> QuestLog:
	var l := QuestLog.new()
	l.active = {"q_one": {"step": 1, "counts": [0]}}
	l.done = ["q_old"]
	l.flags = ["vio_lobos"]
	l.marks = ["tutorial_done"]
	l.tracked = "q_one"
	return l


func test_round_trip() -> void:
	db.add({"id": "q_old", "steps": [{"objectives": []}]})
	var back := QuestLog.from_dict(_log().to_dict(), db)
	assert_eq(back.active, {"q_one": {"step": 1, "counts": [0]}})
	assert_eq(back.done, ["q_old"])
	assert_eq(back.flags, ["vio_lobos"])
	assert_eq(back.marks, ["tutorial_done"])
	assert_eq(back.tracked, "q_one")
	assert_true(back.is_active("q_one"))
	assert_true(back.is_done("q_old"))
	assert_true(back.has_flag("vio_lobos"))


func test_sanitize_unknown() -> void:
	var d := {
		"active": {"nope": {"step": 0, "counts": [1]}, "q_one": {"step": 0, "counts": [-4]}},
		"done": ["nope", 3], "flags": ["ok", 5, ""], "marks": [], "tracked": "nope",
	}
	var l := QuestLog.from_dict(d, db)
	assert_false(l.is_active("nope"))
	assert_eq(l.active.q_one.counts, [0])
	assert_eq(l.done, [])
	assert_eq(l.flags, ["ok"])
	assert_eq(l.tracked, "")


func test_sanitize_step_and_counts() -> void:
	var l := QuestLog.from_dict({"active": {"q_one": {"step": 7, "counts": []}}}, db)
	assert_false(l.is_active("q_one"), "a step past the end drops the quest")
	l = QuestLog.from_dict({"active": {"q_one": {"step": 0, "counts": [99, 4]}}}, db)
	assert_eq(l.active.q_one.counts, [3], "clamped to count, one per objective")


func test_garbage() -> void:
	assert_true(QuestLog.from_dict("x", db).active.is_empty())
	assert_true(QuestLog.from_dict({"active": 5, "done": "a"}, db).done.is_empty())


func test_character_v6_migration() -> void:
	var v5 := {"version": 5, "id": "abc", "name": "Aren", "class_id": "warrior", "progress": {"level": 3},
		"place": {"zone": "aldea", "at": []}, "tutorial_done": false}
	var c := CharacterData.from_dict(v5, CharacterCatalog.load_default())
	assert_eq(CharacterData.VERSION, 7)
	assert_true(c.quests.active.is_empty())
	assert_eq(c.to_dict().version, 7)


func test_character_saves_quests() -> void:
	var c := CharacterData.new()
	c.id = "abc"
	c.name = "Aren"
	c.quests.flags = ["vio_lobos"]
	c.quests.marks = ["tutorial_done"]
	var back := CharacterData.from_dict(c.to_dict(), CharacterCatalog.load_default())
	assert_eq(back.quests.flags, ["vio_lobos"])
	assert_true(back.tutorial_done, "a story mark tutorial_done unlocks group play")


func test_ready_to_turn_in_is_kept() -> void:
	var l := QuestLog.from_dict({"active": {"q_one": {"step": 2, "counts": [5]}}}, db)
	assert_true(l.is_active("q_one"), "all steps done: waiting to be turned in")
	assert_eq(l.active.q_one.counts, [])
