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


## Plan 8.1.1: the bigger village houses leave every NPC and every house inside reachable,
## and no house stands on a road or on another piece; in the three moments (Plan 8.3a).
func _village(variant: String) -> ZoneLayout:
	return ZoneLayout.load_variant("aldea", variant)


func test_village_npcs_and_houses_reachable() -> void:
	for v: String in ["", "vispera", "asalto"]:
		_village_reachable(_village(v))
	var eve := _village("vispera")
	var brann: Dictionary = eve.npcs.filter(func(n: Dictionary) -> bool: return n.id == "brann")[0]
	assert_lt(Vector2(float(brann.at[0]), float(brann.at[1])).distance_to(Vector2(eve.entries.default)), 8.0, "Brann by the forge on the eve")


func _village_reachable(z: ZoneLayout) -> void:
	var map := z.collision()
	var reach := _reach(map, z.entries.default)
	for n: Dictionary in z.npcs:
		var c := Vector2i(int(n.at[0]), int(n.at[1]))
		assert_false(map.is_solid(c), "%s stands free" % n.id)
		assert_true(reach.has(c), "%s reachable" % n.id)
	assert_gte(z.houses.size(), 17, "14 houses, the forge, its shed and the barn (Plan 8.3d)")
	for h: Dictionary in z.houses:
		for c: Vector2i in h.cells:
			if not map.is_solid(c):
				assert_true(reach.has(c), "%s %d inside %s" % [h.id, h.index, c])
	for t: Array in z.torches:
		assert_false(map.is_solid(Vector2i(int(t[0]), int(t[1]))), "torch %s" % [t])


func test_houses_do_not_overlap_roads_or_pieces() -> void:
	for v: String in ["", "vispera", "asalto"]:
		_no_overlaps(_village(v))


func _no_overlaps(z: ZoneLayout) -> void:
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
	var z := ZoneLayout.load_id("palacio") # the crypt is under the palace now (Plan 8.3b)
	var door: Rect2i = z.exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba")[0].area
	var around := door.grow(ZoneLayout.EXIT_CLEAR)
	var hiding := z.pieces.filter(func(p: Dictionary) -> bool:
		return p.id in ["tree_oak", "tree_pine", "bush", "rock_small", "stump", "palace_column", "brazier"] and around.has_point(p.at))
	assert_eq(hiding, [], "nothing hides the crypt's gate")
	var map := z.collision()
	var free := 0
	for x in range(door.position.x, door.end.x):
		free += 0 if map.is_solid(Vector2i(x, door.end.y)) else 1
	assert_gt(free, 0, "the gate can be walked up to")


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
	var door: Rect2i = z.exits.filter(func(e: Dictionary) -> bool: return e.to == "camino")[0].area
	var near := false
	for c: Vector2i in seen:
		near = near or door.grow(2).has_point(c)
	assert_true(near, "the road leads to the way east (Plan 8.3b)")


## Plan 8.1.2: the world's names (the user's).
func test_zone_names() -> void:
	assert_eq(tr("ZONE_ALDEA"), "Aldea de Aelhest")
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


# --- Plan 8.3a: the village in three moments and the trail in the forest ---

func _ids_of(z: ZoneLayout) -> Array:
	return z.pieces.map(func(p: Dictionary) -> String: return str(p.id))


func test_village_moments() -> void:
	var ruins := _village("")
	assert_has(_ids_of(ruins), "house_burnt_small")
	assert_has(_ids_of(ruins), "army_tent")
	assert_does_not_have(_ids_of(ruins), "house_small")
	var npc_ids := ruins.npcs.map(func(n: Dictionary) -> String: return str(n.id))
	for id: String in ["verrin", "anciana_cantora", "panadero", "cazador"]:
		assert_has(npc_ids, id)
	for id: String in ["brann", "merchant", "mira"]:
		assert_does_not_have(npc_ids, id)
	assert_gt(ruins.walkers.size(), 2, "villagers walk the ruins")
	for v: String in ["vispera", "asalto"]:
		var z := _village(v)
		assert_eq(z.errors, [], v)
		assert_eq(z.variant, v)
		assert_has(_ids_of(z), "house_small", v)
		assert_does_not_have(_ids_of(z), "house_burnt_small", v)
		assert_does_not_have(_ids_of(z), "grave", v)
		assert_eq(z.entries.default, Vector2i(31, 35), v + " starts in the forge house")
	var eve := _village("vispera")
	assert_eq(eve.ambience, "atardecer")
	for id: String in ["mira_casa", "colina", "plaza"]:
		assert_true(eve.quest_points.has(id), id)
	assert_has(_ids_of(eve), "bonfire")
	assert_eq(eve.spawns.map(func(s: Dictionary) -> String: return str(s.type)), ["training_dummy"])
	assert_eq(eve.hordes, [], "nothing to fight on the eve")
	var night := _village("asalto")
	assert_eq(night.ambience, "noche_fuego")
	for id: String in ["alarma", "tras_mira", "puerta"]:
		assert_true(night.quest_points.has(id), id)
	assert_eq(night.spawns.map(func(s: Dictionary) -> String: return str(s.type)), ["heraldo"])
	for h: Dictionary in night.hordes:
		assert_lte(int(h.levels[1]), 2, "assault monsters are level 1-2")


## Review point 2: dying in the assault puts you back somewhere safe, far from every horde.
func test_assault_respawn_is_safe() -> void:
	var z := _village("asalto")
	var map := z.collision()
	assert_false(map.is_solid(z.respawn))
	var at := Vector2(z.respawn) + Vector2(0.5, 0.5)
	for h: Dictionary in z.hordes:
		var a: Array = h.area
		var r := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		var nearest := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
		assert_gt(at.distance_to(nearest), 15.0, "respawn far from %s" % [a])
	for s: Dictionary in z.spawns:
		assert_gt(at.distance_to(Vector2(float(s.at[0]), float(s.at[1]))), 15.0, "respawn far from %s" % s.type)


## Points reached during the assault are out of the monsters' sight, so a scene never waits on a fight.
func test_assault_scene_points_are_out_of_reach() -> void:
	var z := _village("asalto")
	for id: String in ["tras_mira", "puerta"]:
		var at := Vector2(z.quest_points[id].at)
		for s: Dictionary in z.spawns:
			var aggro := float(MonsterDB.load_default().get_type(str(s.type)).get("aggro_range", 8))
			assert_gt(at.distance_to(Vector2(float(s.at[0]), float(s.at[1]))), aggro + 3.0, "%s far from %s" % [id, s.type])


func test_walker_routes_are_valid_in_every_moment() -> void:
	for v: String in ["", "vispera", "asalto"]:
		assert_eq(_village(v).errors, [], "walkers of " + v)


func test_forest_trail() -> void:
	var z := ZoneLayout.load_id("bosque")
	var map := z.collision()
	var reach := _reach(map, z.entries.default)
	for id: String in ["campamento", "mascara", "huellas_carro", "rio"]:
		assert_true(z.quest_points.has(id), id)
		var c: Vector2i = z.quest_points[id].at
		assert_true(reach.has(c), id + " reachable")
		for h: Dictionary in z.hordes:
			var a: Array = h.area
			var r := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
			var p := Vector2(c)
			var nearest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			assert_gt(p.distance_to(nearest), 12.0, "%s away from the hunting grounds" % id)
	assert_false(z.quest_points.has("claro"), "the old clearing is gone")
	assert_has(_ids_of(z), "camp_ruined")
	assert_has(_ids_of(z), "river_bank")


# --- Plan 8.3b: the road, the capital and the palace ---

func test_new_zones() -> void:
	for id: String in ["camino", "capital", "palacio"]:
		var z := ZoneLayout.load_id(id)
		assert_not_null(z, id)
		assert_eq(z.errors, [], id)
	for id: String in ["capital", "palacio"]:
		var z := ZoneLayout.load_id(id)
		assert_true(z.safe, id + " is safe")
		assert_eq(z.hordes, [], id + " has no hordes")
		assert_eq(z.spawns, [], id + " has no monsters")
	var npcs := ZoneLayout.load_id("capital").npcs.map(func(n: Dictionary) -> String: return str(n.id))
	assert_has(npcs, "merchant", "the merchant is back")
	assert_has(npcs, "maese_corwin")
	var hall := ZoneLayout.load_id("palacio").npcs.map(func(n: Dictionary) -> String: return str(n.id))
	for id: String in ["rey", "oriel", "lord_maren"]:
		assert_has(hall, id)
	assert_true(ZoneLayout.load_id("camino").quest_points.has("emboscada"))
	assert_true(ZoneLayout.load_id("capital").quest_points.has("puerta_capital"))
	assert_true(ZoneLayout.load_id("palacio").quest_points.has("salon_trono"))


func test_road_level_band() -> void:
	var z := ZoneLayout.load_id("camino")
	assert_eq(z.levels, Vector2i(4, 8))
	for h: Dictionary in z.hordes:
		assert_gte(int(h.levels[0]), 4)
		assert_lte(int(h.levels[1]), 8)


## Review point 5: the bandits wait out of sight of the ambush point, so its scene comes first.
func test_ambush_is_out_of_reach() -> void:
	var z := ZoneLayout.load_id("camino")
	var at := Vector2(z.quest_points.emboscada.at)
	assert_eq(z.spawns.size(), 3)
	for s: Dictionary in z.spawns:
		var aggro := float(MonsterDB.load_default().get_type(str(s.type)).get("aggro_range", 8))
		var d := at.distance_to(Vector2(float(s.at[0]), float(s.at[1]))) - float(s.get("radius", 0.0))
		assert_gt(d, aggro + 3.0, "%s waits out of reach" % s.type)


## Review point 1: the crypt leads back to the palace; the forest has no crypt any more.
func test_crypt_leads_to_palace() -> void:
	var crypt := ZoneLayout.load_id("cripta_prueba")
	assert_eq(str(crypt.exits[0].to), "palacio")
	assert_eq(str(crypt.exits[0].entry), "from_cripta")
	assert_true(ZoneLayout.load_id("palacio").entries.has("from_cripta"))
	var forest := ZoneLayout.load_id("bosque")
	assert_eq(forest.exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba").size(), 0)
	var gate: Dictionary = ZoneLayout.load_id("palacio").exits.filter(func(e: Dictionary) -> bool: return e.to == "cripta_prueba")[0]
	assert_eq(gate.requires.flags, ["cripta_abierta"])
	assert_eq(str(gate.gate.closed), "stairs_down_closed")


func test_capital_walkers_valid() -> void:
	var z := ZoneLayout.load_id("capital")
	assert_gt(z.walkers.size(), 5, "people walk the capital")
	assert_eq(z.errors, [])


# --- Plan 8.3d: the new village ---

func test_village_houses() -> void:
	for v: String in ["vispera", "asalto"]:
		var z := _village(v)
		var designs := {}
		var homes := 0
		for p: Dictionary in z.pieces:
			if str(p.id) in ["house_small", "house_timber", "house_log", "house_stone", "house_large"]:
				designs[str(p.id)] = true
				homes += 1
		assert_gte(designs.size(), 5, v + ": four designs and the big house")
		assert_gte(homes, 12, v + ": twelve houses or more")
		assert_has(_ids_of(z), "barn", v)
	var ruins := _village("")
	assert_has(_ids_of(ruins), "house_burnt_timber")
	var cows := ruins.walkers.filter(func(w: Dictionary) -> bool: return str(w.get("model", "")) == "piece:cow")
	assert_gte(cows.size(), 3, "cows on the ranch")


## Review point 5: the cows stay in their paddock.
func test_cows_stay_in_the_paddock() -> void:
	var paddock := Rect2i(63, 73, 21, 9)
	for v: String in ["", "vispera", "asalto"]:
		for w: Dictionary in _village(v).walkers:
			if str(w.get("model", "")) != "piece:cow":
				continue
			for pt: Array in w.route:
				assert_true(paddock.has_point(Vector2i(int(pt[0]), int(pt[1]))), "%s: cow at %s" % [v, pt])


func test_scene_points_have_no_glow() -> void:
	var scene_points := {"aldea": ["colina", "plaza", "alarma", "tras_mira", "puerta"], "bosque": ["rio"], "camino": ["emboscada"],
		"capital": ["puerta_capital"], "palacio": ["salon_trono"]}
	for zid: String in scene_points:
		for v: String in (["", "vispera", "asalto"] if zid == "aldea" else [""]):
			var z := ZoneLayout.load_variant(zid, v) if v != "" else ZoneLayout.load_id(zid)
			for id: String in scene_points[zid]:
				if z.quest_points.has(id):
					assert_eq(str(z.quest_points[id].look), "", "%s %s: %s has no glow" % [zid, v, id])


func test_village_relief() -> void:
	var z := _village("")
	assert_gt(z.height_at(20.5, 22.5), 2.0, "the hill")
	assert_lt(z.height_at(18.5, 70.5), -0.5, "the river's hollow")
	var map := z.collision()
	var reach := _reach(map, z.entries.default)
	assert_true(reach.has(Vector2i(20, 24)), "up the hill to the graves")
