extends GutTest
## Dialogues (Plan 8.2): linear lines, choices only where they matter, flags the host can
## check, and which dialogue an NPC opens for each player.

const DIALOGUES := "res://tests/data/dialogues/"
const QUESTS := "res://tests/data/quests/"

var quests: QuestDB


func before_each() -> void:
	DialogueRunner.dir = DIALOGUES
	quests = QuestDB.load_dir(QUESTS)


func after_each() -> void:
	DialogueRunner.dir = DialogueRunner.DIR


func _log(flags: Array = []) -> QuestLog:
	var l := QuestLog.new()
	l.flags = flags.duplicate()
	return l


func test_linear_then_choices() -> void:
	var r := DialogueRunner.load_id("d_test")
	r.start(_log())
	assert_eq(r.current_line(), ["brann", "ITEM_Q_PAQUETE"])
	assert_true(r.advance())
	assert_eq(r.current_line(), ["player", "ITEM_Q_COLMILLO"])
	assert_true(r.advance())
	assert_false(r.advance(), "the choices come next")
	assert_eq(r.choices().size(), 2, "the if_flags choice is hidden")
	assert_false(r.finished())


func test_choose_flags_and_back() -> void:
	var r := DialogueRunner.load_id("d_test")
	r.start(_log())
	while r.advance():
		pass
	var picked := r.choose(0)
	assert_eq(picked.flags, ["pregunto"])
	assert_eq(r.current_line(), ["brann", "ITEM_Q_PAQUETE"])
	assert_false(r.advance())
	assert_eq(r.set_flags(), ["pregunto", "sabe_culto"])
	assert_eq(r.choices().size(), 1, "the once choice is gone when coming back")
	var last := r.choose(0)
	assert_eq(last.action, "accept")
	assert_true(r.finished())


func test_once_hidden_when_its_flags_are_set() -> void:
	var r := DialogueRunner.load_id("d_test")
	r.start(_log(["pregunto"]))
	while r.advance():
		pass
	assert_eq(r.choices().size(), 1)


func test_if_flags_shows_choice() -> void:
	var r := DialogueRunner.load_id("d_test")
	r.start(_log(["visto"]))
	while r.advance():
		pass
	assert_eq(r.choices().size(), 3)


func test_offered_flags() -> void:
	assert_eq(DialogueRunner.offered_flags("d_test", _log()), ["pregunto", "sabe_culto"])
	var with_visto := DialogueRunner.offered_flags("d_test", _log(["visto"]))
	assert_true("secreto_ok" in with_visto)
	assert_eq(DialogueRunner.offered_flags("nope", _log()), [])


func test_missing_dialogue() -> void:
	assert_null(DialogueRunner.load_id("nope"))


func test_format() -> void:
	var t := DialogueRunner.format_text("Hola, {nombre}. Te llaman {apodo}.", "Aren", "Thal An Dor")
	assert_eq(t, "Hola, Aren. Te llaman Thal An Dor.")
	assert_eq(DialogueRunner.format_text("{apodo}", "Aren", ""), "")


func test_pick_priority() -> void:
	var l := _log()
	l.active = {"q_collect": {"step": 1, "counts": []}}
	var got := NpcTalk.pick("brann", l, 5, "warrior", quests)
	assert_eq(got.kind, "turn_in")
	assert_eq(got.quest, "q_collect")


func test_pick_offer_and_talk_objective() -> void:
	var got := NpcTalk.pick("brann", _log(), 5, "warrior", quests)
	assert_eq(got.kind, "offer")
	var l := _log()
	l.active = {"q_one": {"step": 1, "counts": [0]}}
	got = NpcTalk.pick("brann", l, 5, "warrior", quests)
	assert_eq([got.kind, got.dialogue, got.quest], ["talk", "d_test", "q_one"])


func test_two_players_differ() -> void:
	var a := _log()
	var b := _log()
	b.active = {"q_collect": {"step": 1, "counts": []}}
	assert_eq(NpcTalk.mark("brann", a, 5, "warrior", quests), "!")
	assert_eq(NpcTalk.mark("brann", b, 5, "warrior", quests), "?")
	assert_eq(NpcTalk.mark("merchant", a, 5, "warrior", quests), "")


func test_grey_mark_for_level() -> void:
	var q := QuestDB.new()
	q.add({"id": "q_lvl", "giver": "brann", "requires": {"level": 10}, "steps": [{"objectives": []}]})
	assert_eq(NpcTalk.mark("brann", _log(), 5, "warrior", q), "!grey")
	assert_eq(NpcTalk.pick("brann", _log(), 5, "warrior", q).kind, "greet")


func test_npc_talk_when() -> void:
	var npc := {"id": "x", "talk": [
		{"when": {"quest": "q_one", "state": "done"}, "dialogue": "after"},
		{"when": {"flags": ["visto"]}, "dialogue": "seen"},
		{"dialogue": "always"}]}
	var l := _log()
	assert_eq(NpcTalk.talk_entry(npc, l, quests), "always")
	l.flags = ["visto"]
	assert_eq(NpcTalk.talk_entry(npc, l, quests), "seen")
	l.done = ["q_one"]
	assert_eq(NpcTalk.talk_entry(npc, l, quests), "after")


func test_all_dialogues_valid() -> void:
	var errors := DialogueRunner.validate_dir(DialogueRunner.DIR)
	assert_eq(errors, [] as Array[String], "\n".join(errors))
	assert_eq(DialogueRunner.validate_dir(DIALOGUES), [] as Array[String])
