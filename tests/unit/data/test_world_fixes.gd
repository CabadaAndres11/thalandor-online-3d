extends GutTest
## Fixes after the 0.16.0 playtest: bridge, signs, dungeon boss level, capital doors and stalls.


func test_bridge_is_walkable_over_the_water() -> void:
	var bosque := ZoneLayout.load_id("bosque")
	var map := bosque.collision()
	for z in range(100, 108):
		assert_false(map.is_solid(Vector2i(108, z)), "the deck at z=%d" % z)
		assert_true(map.is_solid(Vector2i(112, z)), "the water beside it")


func test_nothing_tall_hides_a_sign() -> void:
	for id: String in ["bosque", "aldea", "camino"]:
		var z := ZoneLayout.load_id(id)
		for m: Dictionary in z.exit_markers:
			var near := 0
			for p: Dictionary in z.pieces + z.margin_pieces:
				if str(p.id) in ZoneLayout.OBSTRUCTIONS and (p.at as Vector2i).distance_to(m.at) < 2.0:
					near += 1
			assert_eq(near, 0, "%s sign at %s" % [id, m.at])


func test_signs_point_out_of_the_zone() -> void:
	var z := ZoneLayout.load_id("bosque")
	for m: Dictionary in z.exit_markers:
		var inward := z.exit_inward(z.exits[int(m.exit)].area)
		var arrow := ZoneLayout.turn(Vector2i(-1, 0), int(m.rot))
		assert_eq(arrow, -inward, "the arrow of %s" % m.to)


func test_capital_doors_face_the_streets() -> void:
	var z := ZoneLayout.load_id("capital")
	for h: Dictionary in z.houses:
		var front: Vector2i = ZoneLayout.turn(Vector2i(0, 1), int(h.rot))
		if h.at.y >= 52:
			assert_eq(front, Vector2i(0, -1), "the south houses look north")
		elif h.at.x < 48:
			assert_eq(front, Vector2i(1, 0), "the west houses look east")
		else:
			assert_eq(front, Vector2i(-1, 0), "the east houses look west")


func test_every_stall_has_a_vendor() -> void:
	var z := ZoneLayout.load_id("capital")
	var stalls := z.pieces.filter(func(p: Dictionary) -> bool: return p.id == "market_stall")
	assert_eq(stalls.size(), 16)
	var vendors := z.npcs.filter(func(n: Dictionary) -> bool: return str(n.id).begins_with("vendedor_"))
	assert_eq(vendors.size(), stalls.size())


func test_dungeon_boss_uses_the_instance_level() -> void:
	var w := SimWorld.new(Balance.load_from(), CollisionMap.from_layout({"size": [8, 8], "spawn": [2, 2], "blocks": []}))
	w.instance_level = 12
	assert_eq(w.monster_level({}, {"boss": true}), 12 + int(w.balance.monster_scaling.get("boss_level_bonus", 2)))
	assert_eq(w.monster_level({}, {}), 12)


func test_ogres_have_no_beard_options() -> void:
	var app: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/appearance.json"))
	for o: Dictionary in app.beard:
		if o.id != "none":
			assert_false("ogre" in o.get("races", ["ogre"]), "beard %s is not for ogres" % o.id)


func test_forest_has_no_old_crypt_entrance() -> void:
	var z := ZoneLayout.load_id("bosque")
	for p: Dictionary in z.pieces:
		assert_ne(str(p.id), "crypt_arch")


func test_capital_fountain_is_centred_on_the_crossing() -> void:
	var z := ZoneLayout.load_id("capital")
	for p: Dictionary in z.pieces:
		if p.id == "fountain":
			# 3×3 cells whose centre is the middle of the road cells (48, 40) are 47..49 and 39..41.
			assert_eq(p.at, Vector2i(47, 39))


func test_palace_dungeon_entrance_has_no_sign_and_guards() -> void:
	var z := ZoneLayout.load_id("palacio")
	for m: Dictionary in z.exit_markers:
		assert_ne(str(m.to), "cripta_prueba", "no sign at the dungeon gate")
	var guards := z.npcs.filter(func(n: Dictionary) -> bool: return str(n.id).begins_with("guardia_cripta_"))
	assert_eq(guards.size(), 2)
	assert_lt(z.height_at(4.5, 38.5), -1.0, "the stairs go down")


## The centre of a placed piece's footprint, in cell coordinates (cell x spans x..x+1).
func _centre(z: ZoneLayout, p: Dictionary) -> Vector2:
	var cells: Array = z.footprint(str(p.id), p.at, p.rot)
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	return sum / cells.size()


func test_palace_nobles_walk_in_pairs_off_the_carpet() -> void:
	var z := ZoneLayout.load_id("palacio")
	assert_false(z.npcs.any(func(n: Dictionary) -> bool: return str(n.id).begins_with("noble_")), "nobles walk, they do not stand")
	var nobles := z.walkers.filter(func(w: Dictionary) -> bool: return str(w.npc).begins_with("noble_"))
	assert_eq(nobles.size(), 6)
	for i in range(0, nobles.size(), 2):
		var a: Dictionary = nobles[i]
		var b: Dictionary = nobles[i + 1]
		assert_eq(a.route.size(), b.route.size(), "a pair walks routes of the same shape")
		for k in a.route.size():
			var d := Vector2(b.route[k][0] - a.route[k][0], b.route[k][1] - a.route[k][1])
			assert_eq(d.length(), 1.0, "%s walks beside %s" % [b.npc, a.npc])
		assert_eq([a.speed, a.pause_s, a.loop], [b.speed, b.pause_s, b.loop], "in step")
	var carpet := {}
	for p: Dictionary in z.pieces:
		if p.id == "palace_carpet":
			for dx in 2:
				for dz in 4:
					carpet[p.at + Vector2i(dx, dz)] = true
	for w: Dictionary in nobles:
		for c: Vector2i in ZoneLayout.path_cells({"points": w.route}):
			assert_false(carpet.has(c), "%s steps on the carpet at %s" % [w.npc, c])


func test_palace_archive_has_oriel_and_no_royal_archivist() -> void:
	var z := ZoneLayout.load_id("palacio")
	assert_false(z.npcs.any(func(n: Dictionary) -> bool: return n.id == "archivista"))
	assert_true(NpcDB.load_default().npc("archivista").is_empty())
	var oriel: Array = z.npcs.filter(func(n: Dictionary) -> bool: return n.id == "oriel")
	assert_eq(oriel.size(), 1)
	assert_true(oriel[0].at[0] >= 31 and oriel[0].at[1] >= 22, "Oriel is in the archive (south-east)")
	var kinds := z.pieces.map(func(p: Dictionary) -> String: return str(p.id))
	for k in ["bookshelf", "bookshelf_double", "reading_desk", "chair", "books_floor", "weapon_rack_a", "weapon_rack_b", "armor_stand_warrior_t1", "armor_stand_mage_t2"]:
		assert_true(k in kinds, k)


func test_palace_throne_and_carpet_are_centred_on_a_dais() -> void:
	var z := ZoneLayout.load_id("palacio")
	for p: Dictionary in z.pieces:
		if p.id == "throne":
			assert_eq(_centre(z, p).x, 20.0, "the throne is on the hall's axis")
			assert_eq(z.height_at(p.at.x + 0.5, p.at.y + 0.5), 1.5, "the throne is up on the dais")
		if p.id == "palace_carpet":
			assert_eq(p.at.x, 19, "the carpet covers x 19..20, centred on 20")
	# Three steps of half a metre down from the dais to the hall.
	assert_eq([z.height_at(20.5, 7.5), z.height_at(20.5, 8.5), z.height_at(20.5, 9.5), z.height_at(20.5, 10.5)], [1.5, 1.0, 0.5, 0.0])
	assert_true(bool(z.piece_def("palace_wall").get("flat", false)), "walls do not rise with the dais")


func test_palace_statues_are_giant_and_face_the_carpet() -> void:
	var z := ZoneLayout.load_id("palacio")
	var n := 0
	for p: Dictionary in z.pieces:
		if not str(p.id).begins_with("statue_warrior"):
			continue
		n += 1
		assert_eq(z.footprint(p.id, p.at, p.rot).size(), 4, "2 × 2 m")
		# A piece faces +Z turned by its rot (ZoneView: -rot degrees about Y).
		var front := Vector2(0, 1).rotated(deg_to_rad(float(p.rot)))
		var to_axis := signf(20.0 - _centre(z, p).x)
		assert_almost_eq(front.x, to_axis, 0.01, "%s at %s faces the carpet" % [p.id, p.at])
	assert_eq(n, 8)


func test_palace_crypt_is_reached_down_stairs_without_walls() -> void:
	var z := ZoneLayout.load_id("palacio")
	var e: Dictionary = z.exits.filter(func(x: Dictionary) -> bool: return x.to == "cripta_prueba")[0]
	assert_eq([e.gate.closed, e.gate.open], ["stairs_down_closed", "stairs_down"])
	# The stairs' pit goes down 2.5 m; the floor round it stays level.
	assert_eq(z.height_at(4.5, 38.5), -2.5)
	assert_eq([z.height_at(4.5, 42.5), z.height_at(1.5, 38.5), z.height_at(8.5, 38.5)], [0.0, 0.0, 0.0])
	var map := z.collision()
	for x in range(3, 7):
		assert_false(map.is_solid(Vector2i(x, 42)), "the way down is free at x %d" % x)
	# No wall left in the crypt room besides the outer ones and the hall's.
	for p: Dictionary in z.pieces:
		if p.id == "palace_wall" and p.rot == 90:
			assert_true(p.at.x in [0, 9, 30, 39], "a wall at %s" % p.at)
	assert_false(z.pieces.any(func(p: Dictionary) -> bool: return p.id in ["brazier", "palace_block"]), "no braziers nor stray blocks")


func test_palace_torches_hang_on_walls() -> void:
	var z := ZoneLayout.load_id("palacio")
	assert_gt(z.torches.size(), 10)
	for t: Variant in z.torches:
		assert_true(t is Dictionary and (t as Dictionary).has("wall"), "every torch is on a wall: %s" % [t])
	var view := ZoneView.new()
	add_child_autofree(view)
	view.layout = z
	view._add_torches([{"at": [15, 1], "wall": 0}])
	var torch: Torch = view.torches[0]
	assert_false(torch.model.visible, "no standing torch")
	assert_almost_eq(torch.position.z, 1.25, 0.01, "the flame burns just off the north wall")


func test_palace_king_and_council_table() -> void:
	var z := ZoneLayout.load_id("palacio")
	var rey: Dictionary = z.npcs.filter(func(n: Dictionary) -> bool: return n.id == "rey")[0]
	assert_eq(float(rey.at[0]) + 0.5, 20.0, "the king stands on the hall's axis")
	var map := z.collision()
	for c: Vector2i in [Vector2i(31, 9), Vector2i(31, 10), Vector2i(32, 9), Vector2i(32, 10)]:
		assert_false(map.is_solid(c), "the council room's door is clear at %s" % c)
	for w: Dictionary in z.walkers:
		for pt: Array in w.route:
			assert_false(pt[0] >= 31, "%s walks in a side room" % w.npc)
