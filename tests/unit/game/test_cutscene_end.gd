extends GutTest
## A cutscene ends cleanly even when one of its effects was already freed (the assault's
## wake-up froze on a black screen: _end_cutscene stopped on the freed node).


func test_ending_skips_freed_effects() -> void:
	var game: GameSession = add_child_autofree(GameSession.new())
	game.cutscene = CutscenePlayer.new()
	var gone := Node3D.new()
	game.add_child(gone)
	game._scene_fx_nodes.append(gone)
	game._scene_hidden.append(gone)
	gone.free()
	var ended := []
	game.cutscene_ended.connect(func() -> void: ended.append(true))
	game._end_cutscene()
	assert_eq(ended, [true], "the scene ends")
	assert_null(game.cutscene)
	assert_eq(game._scene_fx_nodes, [])
