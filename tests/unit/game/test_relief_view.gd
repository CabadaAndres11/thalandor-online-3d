extends GutTest
## Everything stands on the relief (Plan 8.3d): the ground mesh, pieces, NPCs and players.

const HILL := {"kind": "hill", "at": [20, 20], "radius": 10, "height": 3}


func _layout() -> ZoneLayout:
	return ZoneLayout.from_dict("t", {"size": [40, 40], "entries": {"default": [2, 2]}, "relief": [HILL], "margin": "none",
		"pieces": [{"id": "rock_small", "at": [20, 20], "rot": 0}],
		"npcs": [{"id": "panadero", "at": [22, 20], "facing": 0}]})


func test_ground_mesh_follows_relief() -> void:
	var view := ZoneView.new()
	add_child_autofree(view)
	view.build(_layout())
	var top := -INF
	for n: Node in view.get_children():
		if n is MeshInstance3D and str(n.name).begins_with("Ground_"):
			var faces := ((n as MeshInstance3D).mesh as ArrayMesh).get_faces()
			for v: Vector3 in faces:
				top = maxf(top, v.y)
	assert_almost_eq(top, 3.0, 0.1, "the hill's top is in the ground mesh")


func test_piece_and_npc_on_the_hill() -> void:
	var view := ZoneView.new()
	add_child_autofree(view)
	var z := _layout()
	view.build(z)
	var p: Dictionary = z.pieces.filter(func(x: Dictionary) -> bool: return x.id == "rock_small")[0]
	assert_almost_eq(view.piece_transform(p).origin.y, z.height_at(20.5, 20.5), 0.05, "the rock sits on the hill")
	var game := GameSession.new()
	add_child_autofree(game)
	game.zone_view = view
	assert_almost_eq(game.ground_y(22.5, 20.5), z.height_at(22.5, 20.5), 0.001)
	var ev := game.lifted(["gold", 1, 5, Vector3(20.5, 0, 20.5)])
	assert_almost_eq((ev[3] as Vector3).y, 3.0, 0.01, "loot and effects are drawn on the ground")
