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


## Review fix: a player already inside a house when the houses get built sees it open.
func test_house_opens_when_built_with_the_player_inside() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	var z := ZoneLayout.load_id("aldea")
	game.build_zone(z)
	var inside: Vector2i = z.houses[0].cells[0]
	game.update_house(Vector3(inside.x + 0.5, 0, inside.y + 0.5)) # before the houses step
	game.finish_zone_build()
	var h := game.zone_view.find_child("house_0", true, false) as HouseView
	assert_true(h.open)


## Review fix: a zone change during the first load keeps the monster prewarm.
func test_zone_change_keeps_the_prewarm() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	var total := game.prewarm_left()
	assert_gt(total, 0)
	game.build_zone(ZoneLayout.load_id("bosque"))
	assert_eq(game.prewarm_left(), total, "not dropped by the new zone")
	game.finish_zone_build()
	assert_eq(game.prewarm_left(), 0)


## Review fix: a WebRTC join opens its signaling only once the zone is loaded (an
## unpolled socket would time out while the game loads).
func test_webrtc_signaling_waits_for_the_load() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	game.net_mode = GameSession.NET_WEBRTC
	game.balance.signaling_url = "ws://127.0.0.1:9"
	assert_eq(game.join(GroupCode.encode("127.0.0.1"), "Ana"), OK)
	assert_null(game.join_signaling, "not while loading")
	game.finish_zone_build()
	assert_not_null(game.join_signaling)
	game.leave()
