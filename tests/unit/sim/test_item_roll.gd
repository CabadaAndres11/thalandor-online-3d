extends GutTest
## Items and loot rolls (ItemRoll), ported from the 2D prototype.

var db: ItemDB
var rng: RandomNumberGenerator


func before_each() -> void:
	db = ItemDB.load_default()
	rng = RandomNumberGenerator.new()
	rng.seed = 1234


func test_affixes_unique_and_in_range() -> void:
	for i in 50:
		var it := ItemRoll.roll_gear("plate_chest_t1", 30, "epic", rng, db)
		assert_eq(it.affixes.size(), 3)
		var stats := {}
		for a: Dictionary in it.affixes:
			var def := db.affix(a.id)
			assert_false(stats.has(def.stat), "repeated stat")
			stats[def.stat] = true
			var top := ItemRoll.affix_max(def, 30)
			# Whole-number stats round to the nearest unit.
			assert_between(float(a.value), top * 0.6 - 0.5, top + 0.5, str(a))


func test_affix_count_by_rarity() -> void:
	assert_eq(ItemRoll.roll_gear("sword_t1", 5, "common", rng, db).affixes.size(), 0)
	assert_eq(ItemRoll.roll_gear("sword_t1", 5, "uncommon", rng, db).affixes.size(), 1)
	assert_eq(ItemRoll.roll_gear("sword_t1", 5, "rare", rng, db).affixes.size(), 2)


func test_affix_slots_respected() -> void:
	for i in 200:
		var it := ItemRoll.roll_gear("plate_chest_t1", 10, "epic", rng, db)
		for a: Dictionary in it.affixes:
			var slots: Array = db.affix(a.id).get("slots", [])
			assert_true(slots.is_empty() or "chest" in slots, str(a))


func test_rarity_table() -> void:
	var n := 10000
	var common := 0
	for i in n:
		if ItemRoll.roll_rarity("normal", rng, db) == "common":
			common += 1
	assert_almost_eq(common / float(n), 0.55, 0.02)


func test_loot_counts() -> void:
	for i in 100:
		assert_gte(ItemRoll.roll_loot("warrior", 5, "elite", rng, db).items.filter(_gear).size(), 1)
		assert_gte(ItemRoll.roll_loot("warrior", 5, "boss", rng, db).items.filter(_gear).size(), 2)


func _gear(it: Item) -> bool:
	return not db.is_consumable(it.base_id)


func test_usable_share() -> void:
	var usable := 0
	var n := 4000
	for i in n:
		var it := ItemRoll.roll_item_for("mage", 10, "normal", rng, db)
		if db.can_use("mage", it.base_id):
			usable += 1
	# 75 % chosen among usable bases, plus the usable ones of the open pool.
	assert_gte(usable / float(n), 0.75 - 0.02)


func test_rage_no_resource_potion() -> void:
	for i in 3000:
		for it: Item in ItemRoll.roll_loot("warrior", 5, "normal", rng, db).items:
			assert_ne(it.base_id, "potion_resource")


func test_gold_formula() -> void:
	assert_eq(ItemRoll.gold_amount(10, false, 0.0, db), 40)
	assert_eq(ItemRoll.gold_amount(10, true, 0.0, db), 160)


func test_value() -> void:
	var it := Item.new()
	it.base_id = "sword_t1"
	it.level = 1
	it.rarity = "common"
	assert_eq(ItemRoll.value(it, db), 3)
	it.level = 10
	it.rarity = "rare"
	assert_eq(ItemRoll.value(it, db), roundi(3 * pow(10, 1.4) * 4))
	it.base_id = "potion_health"
	assert_eq(ItemRoll.value(it, db), 0)


func test_stat_value_two_hand() -> void:
	var def := {"stat": "attack_power_add", "base": 4, "per_level": 2}
	assert_almost_eq(ItemRoll.stat_value(def, 10, false, db), 24.0, 0.001)
	assert_almost_eq(ItemRoll.stat_value(def, 10, true, db), 24.0 * 1.8, 0.001)


func test_from_dict_garbage() -> void:
	assert_null(Item.from_dict({"base_id": "nope", "uid": "x"}, db))
	assert_null(Item.from_dict("x", db))
	var it := Item.from_dict({"uid": "a", "base_id": "sword_t1", "level": -3, "rarity": "weird", "durability": -5,
		"affixes": [{"id": "strength", "value": 2}, {"id": "strength", "value": 3}, {"id": "nope", "value": 1}]}, db)
	assert_eq(it.level, 1)
	assert_eq(it.rarity, "common")
	assert_eq(it.durability, 0)
	assert_eq(it.affixes.size(), 1)


func test_from_dict_potion_count_clamped() -> void:
	var it := Item.from_dict({"uid": "p", "base_id": "potion_health", "count": 999}, db)
	assert_eq(it.count, 20)


func test_roundtrip() -> void:
	var it := ItemRoll.roll_gear("plate_chest_t1", 12, "rare", rng, db)
	var back := Item.from_dict(it.to_dict(), db)
	assert_eq(back.to_dict(), it.to_dict())


func test_uid_unique() -> void:
	var seen := {}
	for i in 1000:
		var u := ItemRoll.new_uid()
		assert_false(seen.has(u))
		seen[u] = true
