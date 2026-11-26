extends GutTest
## Villagers that walk their routes (Plan 8.3a): where a walker is depends only on the host's
## clock, so every client draws it in the same place without any network traffic.

const ROUTE := [Vector2(0, 0), Vector2(4, 0), Vector2(4, 3)]


func test_same_position_for_same_time() -> void:
	var a := WalkerPath.at(ROUTE, 1.2, 3.0, true, 17.25)
	var b := WalkerPath.at(ROUTE, 1.2, 3.0, true, 17.25)
	assert_eq(a, b)


func test_walks_between_points() -> void:
	var s := WalkerPath.at(ROUTE, 2.0, 0.0, true, 1.0)
	assert_almost_eq(s.position.x, 2.0 + 0.5, 0.01, "2 m along the first leg (cell centres)")
	assert_true(s.moving)
	assert_almost_eq(s.facing, PI / 2.0, 0.01, "facing +x")


func test_pauses_at_points() -> void:
	# 4 m at 2 m/s: at the second point after 2 s, then 3 s still.
	var at := WalkerPath.at(ROUTE, 2.0, 3.0, true, 2.5)
	var later := WalkerPath.at(ROUTE, 2.0, 3.0, true, 4.5)
	assert_false(at.moving)
	assert_eq(at.position, later.position)
	assert_true(WalkerPath.at(ROUTE, 2.0, 3.0, true, 5.5).moving, "walking again")


func test_loop_and_back() -> void:
	var length := WalkerPath.cycle_s(ROUTE, 1.0, 0.0, true)
	assert_almost_eq(length, 4.0 + 3.0 + 5.0, 0.01, "a loop closes back to the first point")
	var start := WalkerPath.at(ROUTE, 1.0, 0.0, true, 0.0)
	assert_eq(WalkerPath.at(ROUTE, 1.0, 0.0, true, length).position, start.position)
	assert_almost_eq(WalkerPath.cycle_s(ROUTE, 1.0, 0.0, false), 14.0, 0.01, "there and back")
	var back := WalkerPath.at(ROUTE, 1.0, 0.0, false, 9.0) # 7 m out, then 2 m back
	assert_almost_eq(back.position.z, 1.0 + 0.5, 0.01)


func test_bad_route_reported() -> void:
	var z := ZoneLayout.from_dict("t", {"size": [20, 20], "blocks": [[5, 5]],
		"walkers": [{"npc": "brann", "route": [[1, 1], [5, 5]]}, {"npc": "brann", "route": [[1, 1], [40, 2]]}]})
	var all := "\n".join(z.errors)
	assert_string_contains(all, "(5, 5)")
	assert_string_contains(all, "(40, 2)")


func test_walkers_drawn() -> void:
	var g := GameSession.new()
	add_child_autofree(g)
	var z := ZoneLayout.from_dict("t", {"size": [20, 20], "npcs": [],
		"walkers": [{"npc": "brann", "route": [[1, 1], [5, 1]]}, {"npc": "merchant", "route": [[2, 2], [2, 6]]}]})
	g.place_walkers(z)
	assert_eq(g.walker_count(), 2)
	g.move_walkers(3.0)
	assert_ne(g.walker_avatar(0).position, Vector3(1.5, 0, 1.5), "it moved")
