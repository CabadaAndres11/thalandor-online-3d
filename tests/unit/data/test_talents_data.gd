extends GutTest

var db: TalentDB


func before_each() -> void:
	db = TalentDB.load_default()


## Plan 8.3g: seven closed rings of 10, 20 ... 70 nodes around the start.
func test_tree_is_281_nodes_in_7_rings() -> void:
	assert_eq(db.ids().size(), 281)
	assert_eq(db.rings(), 7)
	for r in range(1, 8):
		assert_eq(db.count(r), 10 * r, "ring %d" % r)


func test_every_class_has_a_route() -> void:
	for c: String in ["warrior", "cleric", "mage", "archer", "assassin"]:
		var route: Array = db.route(c)
		assert_eq(route.size(), 100, c)
		assert_true(db.node(route[0]).links.has(db.start_id()), c + " starts next to the centre")
	assert_eq(db.route("nope"), [])


func test_links_symmetric() -> void:
	for id: String in db.ids():
		for other: String in db.node(id).links:
			assert_true(db.ids().has(other), "%s links to unknown %s" % [id, other])
			assert_true(db.node(other).links.has(id), "%s -> %s is not symmetric" % [id, other])


func test_graph_connected() -> void:
	var seen := {db.start_id(): true}
	var queue := [db.start_id()]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		for n: String in db.node(cur).links:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	assert_eq(seen.size(), db.ids().size())


func test_keystones_on_rings_4_and_7() -> void:
	for ring in [4, 7]:
		var keys := db.ids().filter(func(id: String) -> bool:
			return db.node(id).kind == "keystone" and int(db.node(id).ring) == ring)
		assert_eq(keys.size(), 5, "ring %d" % ring)


func test_every_mod_is_a_known_stat() -> void:
	for id: String in db.ids():
		for m: Dictionary in db.node(id).mods:
			assert_eq(m.type, "stat")
			var stat := str(m.stat)
			assert_true(Progression.FLAT.has(stat) or Progression.PERCENT.has(stat), "%s: unknown stat %s" % [id, stat])
			assert_true(m.value is float or m.value is int)


func test_positions_inside_unit_circle() -> void:
	for id: String in db.ids():
		var n := db.node(id)
		assert_true(Vector2(float(n.x), float(n.y)).length() < 1.0, id)


func test_ids_and_kinds() -> void:
	assert_eq(db.node("start").kind, "start")
	assert_eq(db.node("r1_0").kind, "minor")
	assert_eq(db.node("r2_2").kind, "notable")
	assert_eq(db.node("r4_0").kind, "keystone")
	assert_eq(db.node("r1_0").dir, "might")
	assert_eq(db.node("r1_6").dir, "bastion")
	assert_eq(db.node("r1_0").icon, "crit") # might's pool cycles from the ring and index
	assert_eq(db.node("r7_0").kind, "keystone")
