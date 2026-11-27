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
