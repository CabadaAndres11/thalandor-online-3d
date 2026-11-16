extends GutTest

var db: TalentDB


func before_each() -> void:
	db = TalentDB.load_default()


func test_66_nodes() -> void:
	assert_eq(db.count(1), 46)
	assert_eq(db.count(2), 20)
	assert_eq(db.ids().size(), 66)


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
	assert_eq(seen.size(), 66)


func test_five_keystones_per_ring_on_pure_spokes() -> void:
	for ring in [1, 2]:
		var keys := db.ids().filter(func(id: String) -> bool:
			return db.node(id).kind == "keystone" and int(db.node(id).ring) == ring)
		assert_eq(keys.size(), 5, "ring %d" % ring)
		for k: String in keys:
			assert_true(db.directions().has(db.node(k).dir), k + " sits on a pure spoke")


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
	assert_eq(db.node("might_1").kind, "minor")
	assert_eq(db.node("might_3").kind, "notable")
	assert_eq(db.node("might_key").kind, "keystone")
	assert_eq(db.node("might_6").kind, "keystone")
	assert_eq(db.node("might_celerity_3").kind, "notable")
	assert_eq(int(db.node("might_celerity_5").ring), 2)
	assert_eq(db.node("start").kind, "start")


func test_hybrid_is_sixty_percent_of_each_main_bonus() -> void:
	var m1: Variant = db.node("might_1").mods[0]
	var c1: Variant = db.node("celerity_1").mods[0]
	var h: Variant = db.node("might_celerity_1").mods
	assert_eq(h.size(), 2)
	assert_eq(h[0].stat, m1.stat)
	assert_almost_eq(float(h[0].value), float(m1.value) * 0.6, 0.0001)
	assert_eq(h[1].stat, c1.stat)
	assert_almost_eq(float(h[1].value), float(c1.value) * 0.6, 0.0001)
	var n3: Variant = db.node("might_celerity_3").mods
	assert_almost_eq(float(n3[0].value), float(db.node("might_3").mods[0].value), 0.0001, "the notable keeps 100 %")


func test_ring2_is_one_and_a_half_times() -> void:
	var a: Variant = db.node("bastion_1").mods[0]
	var b: Variant = db.node("bastion_5").mods[0]
	assert_almost_eq(float(b.value), float(a.value) * 1.5, 0.0001)
	var k: Variant = db.node("bastion_key").mods[0]
	assert_almost_eq(float(db.node("bastion_6").mods[0].value), float(k.value) * 1.5, 0.0001)
