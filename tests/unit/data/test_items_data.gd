extends GutTest
## data/items: everything names what exists and every text is translated.


func test_validate_is_clean() -> void:
	assert_eq(ItemDB.load_default().validate(), [] as Array[String])


func test_every_class_has_a_starter_kit_it_can_use() -> void:
	var db := ItemDB.load_default()
	for c: String in ["villager", "warrior", "cleric", "mage", "archer", "assassin"]:
		var kit := db.starter(c)
		assert_false(kit.is_empty(), c)
		for id: String in kit:
			assert_true(db.can_use(c, id), "%s %s" % [c, id])


func test_tier_one_is_complete() -> void:
	var db := ItemDB.load_default()
	var count := 0
	for id: String in db.base_ids():
		var b := db.base(id)
		if int(b.get("tier", 0)) == 1 and b.slot in ["head", "shoulders", "chest", "hands", "legs", "feet"]:
			count += 1
	assert_eq(count, 30, "5 class sets × 6 slots")


func test_every_base_has_model() -> void:
	var db := ItemDB.load_default()
	var cat := CharacterCatalog.load_default()
	for id: String in db.base_ids():
		var b := db.base(id)
		if b.slot in ["consumable", "neck", "ring"]:
			continue
		var look: Array = b.get("look", [])
		assert_false(look.is_empty(), id + " has a model")
		for piece: String in look + (b.get("look_offhand", []) as Array):
			assert_false(cat.piece(piece).is_empty(), "%s: piece %s exists" % [id, piece])


func test_each_boss_has_its_unique() -> void:
	var db := ItemDB.load_default()
	assert_eq(db.unique_for("cult_acolyte"), "unique_acolyte")
	assert_eq(db.unique_for("vaelthar"), "unique_vaelthar")
	assert_eq(db.unique_for("nhazar"), "unique_nhazar")
	assert_eq(db.unique_for("cultist"), "")
	assert_false(db.bases_for(10).has("unique_vaelthar"), "uniques never drop from the common tables")
