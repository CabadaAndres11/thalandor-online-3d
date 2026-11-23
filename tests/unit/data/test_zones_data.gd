extends GutTest
## The zones of the demo (Plan 8.1): they load, their exits lead somewhere real and every
## entry and exit can be walked to from the zone's default entry.


func _ids() -> Array:
	var out := []
	for f: String in DirAccess.get_files_at(ZoneLayout.DIR):
		if f.ends_with(".json") and f != "pieces.json":
			out.append(f.get_basename())
	return out


## Cells reachable from `from` over free cells (4-neighbours).
func _reach(map: CollisionMap, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not seen.has(n) and not map.is_solid(n):
				seen[n] = true
				queue.append(n)
	return seen


func test_demo_zones_exist() -> void:
	for id: String in ["aldea", "bosque", "cripta_prueba", "arena"]:
		assert_has(_ids(), id)


func test_every_zone_loads_without_errors() -> void:
	for id: String in _ids():
		var z := ZoneLayout.load_id(id)
		assert_not_null(z, id)
		assert_eq(z.errors, [], id)
		assert_ne(TranslationServer.translate(z.name), z.name, id + " has a translated name")


func test_exits_lead_to_real_zones_and_entries() -> void:
	for id: String in _ids():
		var z := ZoneLayout.load_id(id)
		for e: Dictionary in z.exits:
			var to := ZoneLayout.load_id(e.to)
			assert_not_null(to, "%s -> %s" % [id, e.to])
			if to != null:
				assert_true(to.entries.has(e.entry), "%s -> %s:%s" % [id, e.to, e.entry])


func test_entries_and_exits_are_reachable() -> void:
	for id: String in _ids():
		var z := ZoneLayout.load_id(id)
		var map := z.collision()
		var reach := _reach(map, z.entries.default)
		for name: String in z.entries:
			assert_true(reach.has(z.entries[name]), "%s: entry %s" % [id, name])
		for e: Dictionary in z.exits:
			var r: Rect2i = e.area
			var any := false
			for x in range(r.position.x, r.end.x):
				for y in range(r.position.y, r.end.y):
					any = any or reach.has(Vector2i(x, y))
			assert_true(any, "%s: exit to %s" % [id, e.to])


func test_hordes_have_room_and_real_monsters() -> void:
	for id: String in _ids():
		var z := ZoneLayout.load_id(id)
		var map := z.collision()
		for h: Dictionary in z.hordes:
			for m: Array in h.monsters:
				assert_false(MonsterDB.load_default().get_type(str(m[0])).is_empty(), "%s: %s" % [id, m[0]])
			var a: Array = h.area
			var free := 0
			for x in range(int(a[0]), int(a[0]) + int(a[2])):
				for y in range(int(a[1]), int(a[1]) + int(a[3])):
					free += 0 if map.is_solid(Vector2i(x, y)) else 1
			assert_gt(free, int(h.count) * 3, "%s: a horde with room to move" % id)


func test_the_game_starts_in_the_village() -> void:
	assert_eq(GameSession.START_ZONE, "aldea")


## Plan 8.1.1: the bigger village houses leave Brann, the merchant and every house inside
## reachable, and no house stands on a road or on another piece.
func test_village_npcs_and_houses_reachable() -> void:
	var z := ZoneLayout.load_id("aldea")
	var map := z.collision()
	var reach := _reach(map, z.entries.default)
	for n: Dictionary in z.npcs:
		var c := Vector2i(int(n.at[0]), int(n.at[1]))
		assert_false(map.is_solid(c), "%s stands free" % n.id)
		assert_true(reach.has(c), "%s reachable" % n.id)
	assert_eq(z.houses.size(), 6)
	for h: Dictionary in z.houses:
		for c: Vector2i in h.cells:
			if not map.is_solid(c):
				assert_true(reach.has(c), "%s %d inside %s" % [h.id, h.index, c])
	for t: Array in z.torches:
		assert_false(map.is_solid(Vector2i(int(t[0]), int(t[1]))), "torch %s" % [t])


func test_houses_do_not_overlap_roads_or_pieces() -> void:
	var z := ZoneLayout.load_id("aldea")
	var road := {}
	for p: Dictionary in z.paths:
		for c: Vector2i in ZoneLayout.path_cells(p):
			road[c] = true
	var owner := {}
	for p: Dictionary in z.pieces:
		for c: Vector2i in z.footprint(p.id, p.at, p.rot):
			assert_false(owner.has(c), "%s overlaps %s at %s" % [p.id, owner.get(c, ""), c])
			owner[c] = p.id
	for h: Dictionary in z.houses:
		for c: Vector2i in z.footprint(h.id, h.at, h.rot) + h.cells:
			assert_false(road.has(c), "%s on the road at %s" % [h.id, c])


## Plan 8.1.1: the crypt can be found: a clearing around its door and a road to it.
func test_crypt_has_clearing() -> void:
	var z := ZoneLayout.load_id("bosque")
	var door: Rect2i = z.exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba")[0].area
	var around := door.grow(ZoneLayout.EXIT_CLEAR)
	for p: Dictionary in z.pieces:
		if p.id in ["tree_oak", "tree_pine", "bush", "rock_small", "stump"]:
			assert_false(around.has_point(p.at), "%s at %s hides the crypt" % [p.id, p.at])


func test_path_reaches_crypt() -> void:
	var z := ZoneLayout.load_id("bosque")
	var road := {}
	for p: Dictionary in z.paths:
		for c: Vector2i in ZoneLayout.path_cells(p):
			road[c] = true
	var from := Vector2i(0, 64)
	assert_true(road.has(from))
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if road.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				queue.append(c + d)
	var door: Rect2i = z.exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba")[0].area
	var near := false
	for c: Vector2i in seen:
		near = near or door.grow(2).has_point(c)
	assert_true(near, "the road leads to the crypt door")


## Plan 8.1.2: the world's names (the user's).
func test_zone_names() -> void:
	assert_eq(tr("ZONE_ALDEA"), "Aelhest")
	assert_eq(tr("ZONE_BOSQUE"), "Bosque de Eldarra")


## Plan 8.1.2: entries, NPCs and hordes are never inside the edge band nor on an exit.
func test_entries_npcs_and_hordes_off_the_band() -> void:
	for id: String in _ids():
		var z := ZoneLayout.load_id(id)
		for name: String in z.entries:
			var c: Vector2i = z.entries[name]
			assert_true(z.walkable(c), "%s: entry %s %s" % [id, name, c])
			for e: Dictionary in z.exits:
				assert_false((e.area as Rect2i).has_point(c), "%s: entry %s on an exit" % [id, name])
		for n: Dictionary in z.npcs:
			assert_true(z.walkable(Vector2i(int(n.at[0]), int(n.at[1]))), "%s: %s" % [id, n.id])
		for h: Dictionary in z.hordes:
			var a: Array = h.area
			for c: Vector2i in [Vector2i(a[0], a[1]), Vector2i(int(a[0]) + int(a[2]) - 1, int(a[1]) + int(a[3]) - 1)]:
				assert_true(z.walkable(c), "%s: horde corner %s" % [id, c])
