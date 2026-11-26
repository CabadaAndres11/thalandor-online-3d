extends GutTest
## Quest interface (Plan 8.2): the journal (J), the tracked objective, NPC marks, the turn-in
## window and where the map points; nothing scrolls at 1280×720.

const QUESTS := "res://tests/data/quests/"

var quests: QuestDB
var items: ItemDB


func before_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	quests = QuestDB.load_dir(QUESTS)
	items = ItemDB.load_default()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	return t


func test_journal_no_scroll_and_pages() -> void:
	for i in 20:
		quests.add({"id": "q_many_%02d" % i, "name": "ITEM_Q_PAQUETE", "summary": "ITEM_Q_PAQUETE",
			"steps": [{"text": "ITEM_Q_PAQUETE", "objectives": [{"type": "kill", "monster": "hunter_wolf", "count": 2}]}]})
	var log := QuestLog.new()
	for i in 20:
		log.active["q_many_%02d" % i] = {"step": 0, "counts": [1]}
	var j := QuestJournal.new()
	j.theme = _theme()
	add_child_autofree(j)
	j.show_for(log, quests, items, Inventory.new())
	await get_tree().process_frame
	assert_eq(j.page_count(), 3, "8 quests a page")
	assert_eq(j.list_size(), 8)
	j.next_page()
	j.next_page()
	assert_eq(j.list_size(), 4)
	assert_true(Rect2(0, 0, 1280, 720).encloses(j.panel_rect()), "%s" % j.panel_rect())


func test_journal_details_and_signals() -> void:
	var log := QuestLog.new()
	log.active = {"q_track": {"step": 0, "counts": [3, 0]}}
	log.done = ["q_one"]
	var j := QuestJournal.new()
	j.theme = _theme()
	add_child_autofree(j)
	var bag := Inventory.new()
	j.show_for(log, quests, items, bag)
	j.select("q_track")
	assert_string_contains(j.detail_text(), "3/5")
	watch_signals(j)
	j.press_track()
	assert_signal_emitted_with_parameters(j, "track_requested", ["q_track"])
	j.show_done(true)
	assert_eq(j.list_size(), 1)


func test_tracker_counts() -> void:
	var log := QuestLog.new()
	log.active = {"q_track": {"step": 0, "counts": [3, 1]}}
	log.tracked = "q_track"
	var bag := Inventory.new()
	var tooth := ItemRoll.new_item("q_colmillo", 1)
	bag.add(tooth, items)
	var t := QuestTracker.new()
	add_child_autofree(t)
	t.refresh(log, quests, bag)
	assert_true(t.visible)
	var text := t.text()
	assert_string_contains(text, tr("ITEM_Q_COLMILLO"))
	assert_string_contains(text, "3/5")
	assert_string_contains(text, "1/3")
	log.tracked = ""
	t.refresh(log, quests, bag)
	assert_false(t.visible)


func test_npc_marks() -> void:
	var a := NpcAvatar.new()
	add_child_autofree(a)
	a.setup("brann", Vector3.ZERO, 0.0)
	a.set_mark("!")
	assert_eq(a.mark_text(), "!")
	a.set_mark("?")
	assert_eq(a.mark_text(), "?")
	a.set_mark("")
	assert_eq(a.mark_text(), "")


func test_target_in_other_zone() -> void:
	var log := QuestLog.new()
	log.active = {"q_track": {"step": 0, "counts": [0, 0]}}
	log.tracked = "q_track"
	var aldea := ZoneLayout.load_id("aldea")
	var t := ZoneMapImage.quest_target(aldea, log, quests)
	assert_true(t.has("exit"), "the way out toward the forest")
	var r: Rect2i = aldea.exits[0].area
	assert_eq(t.exit, Vector2(r.position) + Vector2(r.size) / 2.0)


func test_target_point_here() -> void:
	var log := QuestLog.new()
	log.active = {"q_track": {"step": 1, "counts": [0]}}
	log.tracked = "q_track"
	var z := ZoneLayout.from_dict("bosque", {"size": [40, 40], "quest_points": [{"id": "claro", "at": [10, 12], "radius": 2}]})
	assert_eq(ZoneMapImage.quest_target(z, log, quests), {"at": Vector2(10.5, 12.5)})


func test_turn_in_choice() -> void:
	var w := QuestTurnInWindow.new()
	w.theme = _theme()
	add_child_autofree(w)
	w.show_for(quests.quest("q_track"), items)
	await get_tree().process_frame
	assert_false(w.can_confirm(), "a choice first")
	watch_signals(w)
	w.pick(1)
	assert_true(w.can_confirm())
	w.confirm()
	assert_signal_emitted_with_parameters(w, "confirmed", ["warrior_chest_t1"])
	assert_true(Rect2(0, 0, 1280, 720).encloses(w.panel_rect()))


func test_quest_point_visibility() -> void:
	var log := QuestLog.new()
	var points := {"claro": {"at": Vector2i(10, 12), "radius": 2.0, "look": "sparkle"}}
	assert_eq(QuestText.visible_points(points, log, quests, "bosque"), [])
	log.active = {"q_track": {"step": 1, "counts": [0]}}
	assert_eq(QuestText.visible_points(points, log, quests, "bosque"), ["claro"])
	assert_eq(QuestText.visible_points(points, log, quests, "aldea"), [], "another zone")


func test_notice() -> void:
	var n := QuestNotice.new()
	add_child_autofree(n)
	n.show_text("UI_QUEST_NEW", "Lobos")
	assert_true(n.visible)
	assert_string_contains(n.text(), "Lobos")
	n.advance(3.1)
	assert_false(n.visible)
