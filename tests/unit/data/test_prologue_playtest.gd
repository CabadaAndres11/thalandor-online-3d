extends GutTest
## Fixes after the 0.17.1 playtest of the prologue (village, assault and scenes).


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/%s.json" % id))


func _blocked(z: ZoneLayout) -> Dictionary:
	var out := {}
	for p: Dictionary in z.pieces:
		for c: Vector2i in z.footprint(p.id, p.at, p.rot):
			out[c] = p.id
	for h: Dictionary in z.houses:
		for c: Vector2i in z.footprint(h.id, h.at, h.rot) + (h.cells as Array):
			out[c] = h.id
	return out


func test_dummy_stands_outside_the_smithy() -> void:
	var z := ZoneLayout.load_variant("aldea", "vispera")
	var at: Vector2i = Vector2i(z.spawns[0].at[0], z.spawns[0].at[1])
	assert_false(_blocked(z).has(at), "the practice dummy is in the yard, not inside a building")


func test_army_camera_is_not_inside_a_house() -> void:
	var z := ZoneLayout.load_id("aldea")
	var blocked := _blocked(z)
	for key: Dictionary in _scene("prologo_ejercito").tracks[0]:
		var at: Array = key.camera.at
		assert_false(blocked.has(Vector2i(floori(at[0]), floori(at[2]))), "camera at %s" % [at])


func test_wake_up_has_fixed_spots_and_mira_is_dragged() -> void:
	var d := _scene("prologo_despertar")
	assert_eq(str(d.stage), "here")
	assert_true(d.actors.has("raptor"), "a cultist drags Mira away")
	var z := ZoneLayout.load_variant("aldea", "asalto")
	var blocked := _blocked(z)
	for x in [48, 49]:
		for zz in range(8, 31):
			assert_false(blocked.has(Vector2i(x, zz)), "Mira's way out is clear at %d,%d" % [x, zz])


func test_listeners_stand_aside_in_the_old_womans_scene() -> void:
	var d := _scene("prologo_nombre")
	for k: String in ["v1", "v2", "v3"]:
		assert_true(int(d.actors[k].at[1]) <= 46, "%s is not between the camera and her" % k)


func test_the_corral_is_closed() -> void:
	var z := ZoneLayout.load_id("aldea")
	var fence := {}
	for p: Dictionary in z.pieces:
		if p.id == "fence":
			for c: Vector2i in z.footprint(p.id, p.at, p.rot):
				fence[c] = true
	for c: Vector2i in [Vector2i(62, 81), Vector2i(83, 72), Vector2i(83, 81)]:
		assert_true(fence.has(c), "corner %s" % c)


func test_north_hounds_do_not_come_back() -> void:
	var z := ZoneLayout.load_variant("aldea", "asalto")
	for h: Dictionary in z.hordes:
		assert_false(bool(h.get("respawn", true)), str(h.monsters))
