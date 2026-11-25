extends GutTest
## Quest points and zone variants (Plan 8.2): a variant adds, removes or replaces things of
## its base zone, for the story moments played alone.

const DIR := "res://tests/data/zones/"


func _zone() -> ZoneLayout:
	return ZoneLayout.load_path(DIR + "zone_q.json", DIR + "pieces.json")


func test_quest_points_loaded() -> void:
	var z := _zone()
	assert_true(z.quest_points.has("claro"))
	assert_eq(z.quest_points.claro.at, Vector2i(15, 12))
	assert_eq(float(z.quest_points.claro.radius), 3.0)
	assert_eq(str(z.quest_points.claro.look), "sparkle")
	assert_true(z.collision().quest_points.has("claro"))


func test_variant_adds_and_removes() -> void:
	var base := _zone()
	assert_true(base.has_variant("noche"))
	var v := base.apply_variant("noche")
	assert_eq(v.variant, "noche")
	assert_eq(v.ambience, "mazmorra_noche")
	var ats := v.pieces.map(func(p: Dictionary) -> Vector2i: return p.at)
	assert_true(Vector2i(20, 10) in ats, "added")
	assert_false(Vector2i(10, 5) in ats, "removed")
	assert_true(Vector2i(5, 5) in ats, "kept")
	assert_eq(v.npcs.map(func(n: Dictionary) -> String: return n.id), ["merchant"])
	assert_true(v.quest_points.has("claro") and v.quest_points.has("plaza"))
	assert_eq(base.ambience, "exterior_dia", "the base does not change")
	assert_eq(base.npcs.size(), 1)
	assert_eq(base.variant, "")


func test_unknown_variant() -> void:
	var z := _zone()
	assert_false(z.has_variant("nada"))
	assert_null(z.apply_variant("nada"))


func test_no_respawn_horde() -> void:
	var v := _zone().apply_variant("noche")
	var w := SimWorld.new(Balance.load_from(), v.collision(), 3)
	w.add_player(1, Vector3(2.5, 0, 2.5))
	w.step({})
	var killed := 0
	for e: CombatEntity in w.entities():
		if e is MonsterState:
			e.hp = 0.0
			w.on_zero_hp(e)
			killed += 1
	assert_eq(killed, 2)
	for i in w.ticks(60.0):
		w.step({})
	var alive := w.entities().filter(func(e: CombatEntity) -> bool: return e is MonsterState and e.is_alive())
	assert_eq(alive.size(), 0)
