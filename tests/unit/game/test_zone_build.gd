extends GutTest
## The zone is built over several frames behind the loading screen (Plan 8.1.1).


func test_new_zone_cancels_unfinished_build() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	game.finish_zone_build()
	game.build_zone(ZoneLayout.load_id("bosque"))
	game.run_build_step()
	game.build_zone(ZoneLayout.load_id("aldea"))
	game.finish_zone_build()
	var zones := game.get_children().filter(func(n: Node) -> bool: return n is ZoneView)
	assert_eq(zones.size(), 1, "one zone drawn")
	assert_eq((zones[0] as ZoneView).layout.id, "aldea")
	assert_not_null((zones[0] as ZoneView).find_child("Environment", true, false), "fully built")


func test_map_is_ready_before_the_first_step() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	game.build_zone(ZoneLayout.load_id("bosque"))
	assert_eq(game.map.zone_id, "bosque", "collision first: the client can move at once")
	assert_true(game.zone_building)


func test_zone_built_emitted_once() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	watch_signals(game)
	game.finish_zone_build()
	assert_signal_emit_count(game, "zone_built", 1)


func test_only_local_player_opens_house() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	game.finish_zone_build()
	var z := game.zone_view.layout
	assert_false(z.houses.is_empty(), "the village has houses")
	var inside: Vector2i = z.houses[0].cells[0]
	game.update_house(Vector3(2.5, 0, 2.5)) # own player outside
	assert_eq(game.zone_view.open_index, -1)
	game.update_house(Vector3(inside.x + 0.5, 0, inside.y + 0.5))
	assert_eq(game.zone_view.open_index, 0)
