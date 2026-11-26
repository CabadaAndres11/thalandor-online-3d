extends GutTest
## Plan 8.3d: the monsters a quest needs are red dots on the maps; the dummy glows; houses
## hiding you open; the level-up glow.


func test_target_monsters() -> void:
	var quests := QuestDB.load_dir("res://tests/data/quests/")
	var log := QuestLog.new()
	log.active["q_train"] = {"step": 0, "counts": [0, 0, 0]}
	assert_eq(QuestText.target_monsters(log, quests), ["hunter_wolf"])
	log.active["q_train"].counts = [2, 1, 0]
	assert_eq(QuestText.target_monsters(log, quests), [], "done with them")


func test_foe_mark_is_red() -> void:
	assert_true(MapMarks.COLORS.has("foe"))
	assert_gt(MapMarks.COLORS.foe.r, 0.8)


func test_quest_glow() -> void:
	var a := MonsterAvatar.new()
	add_child_autofree(a)
	a.setup(MonsterDB.load_default().get_type("training_dummy"))
	assert_eq(a.monster_type, "training_dummy")
	a.set_quest_glow(true)
	assert_true(a.quest_glow_visible())
	a.set_quest_glow(false)
	assert_false(a.quest_glow_visible())


func test_house_opens_when_it_hides_you() -> void:
	var z := ZoneLayout.load_variant("aldea", "vispera")
	var view := ZoneView.new()
	add_child_autofree(view)
	view.layout = z
	var h: Dictionary = z.houses.filter(func(x: Dictionary) -> bool: return x.id == "house_small")[0]
	var cells: Array = h.cells
	var c: Vector2i = cells[0]
	# You stand just north of the house; the camera is south of it, so the house is between.
	var you := Vector3(c.x + 0.5, 0, float(h.at.y) - 1.5) if int(h.rot) == 0 else Vector3(c.x + 0.5, 0, float(h.at.y) + 1.5)
	var cam := Vector3(you.x, 10, you.z + (8.0 if int(h.rot) == 0 else -8.0))
	assert_has(view.occluders(cam, you), int(h.index))
	assert_eq(view.occluders(Vector3(you.x, 10, you.z - 8.0 if int(h.rot) == 0 else you.z + 8.0), you), [], "nothing between")


func test_level_up_glow() -> void:
	var fx := CombatFX.new()
	add_child_autofree(fx)
	fx._level_glow(Vector3(2, 0, 2))
	assert_not_null(fx.get_node_or_null("LevelGlow"))
