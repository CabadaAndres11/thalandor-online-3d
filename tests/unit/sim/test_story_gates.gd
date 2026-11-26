extends GutTest
## Hordes that wait for the story and pieces that go once their quest point is done (Plan 8.3d).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))


func _hero() -> PlayerState:
	return f.world.add_player(1, Vector3(5.5, 0, 5.5))


func _step(seconds: float) -> void:
	for i in f.world.ticks(seconds):
		f.world.step({})


## Review point 3: a log that already has the flag (coming back after the awakening) brings them.
func test_horde_waits_for_flag() -> void:
	var p := _hero()
	f.world.spawner = Spawner.new([{"type": "marked_hound", "at": [30, 30], "count": 2, "radius": 1, "requires": {"flags": ["despertar"]}}],
		[{"area": [20, 20, 6, 6], "monsters": [["cultist", 1]], "levels": [1, 2], "count": 3, "requires": {"flags": ["despertar"]}}])
	_step(1.0)
	assert_eq(f.world.monsters.size(), 0, "nobody before the awakening")
	p.quests.flags.append("despertar")
	_step(1.0)
	assert_eq(f.world.monsters.size(), 5, "they come with the flag")


func test_story_piece_hides_when_point_done() -> void:
	var quests := QuestDB.load_dir("res://tests/data/quests/")
	var log := QuestLog.new()
	assert_false(QuestText.point_done(log, quests, "rubble_spot"), "not started: the rubble is there")
	log.active["q_rubble"] = {"step": 0, "counts": [0, 0]}
	assert_false(QuestText.point_done(log, quests, "rubble_spot"))
	log.active["q_rubble"].counts[0] = 1
	assert_true(QuestText.point_done(log, quests, "rubble_spot"), "moved away")
	var done := QuestLog.new()
	done.done.append("q_rubble")
	assert_true(QuestText.point_done(done, quests, "rubble_spot"), "and gone for good")
	var z := ZoneLayout.from_dict("t", {"size": [20, 20], "entries": {"default": [2, 2]}, "margin": "none",
		"story_pieces": [{"id": "rubble", "at": [8, 8], "point": "rubble_spot"}]})
	var view := ZoneView.new()
	add_child_autofree(view)
	view.layout = z
	view.show_story_pieces(QuestLog.new(), quests)
	assert_true(view.story_piece_shown(0))
	view.show_story_pieces(done, quests)
	assert_false(view.story_piece_shown(0))
