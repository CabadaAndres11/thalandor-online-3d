extends GutTest
## Inventory: bag, stacks, equipment slots and the rules for wearing things.

var db: ItemDB
var inv: Inventory


func before_each() -> void:
	db = ItemDB.load_default()
	inv = Inventory.new()


func _it(base_id: String, level: int = 1) -> Item:
	return ItemRoll.new_item(base_id, level)


func _fill_bag() -> void:
	while inv.add(_it("ring_t1"), db):
		pass


func test_new_bag_has_30_slots() -> void:
	assert_eq(inv.bag.size(), 30)
	assert_eq(inv.free_slots(), 30)


func test_stack_potions() -> void:
	var p := _it("potion_health")
	p.count = 15
	assert_true(inv.add(p, db))
	var q := _it("potion_health")
	q.count = 10
	assert_true(inv.add(q, db))
	assert_eq(inv.bag[0].count, 20)
	assert_eq(inv.bag[1].count, 5)


func test_full_bag() -> void:
	_fill_bag()
	assert_eq(inv.free_slots(), 0)
	assert_false(inv.add(_it("sword_t1"), db))


func test_equip_rules_class_and_level() -> void:
	inv.add(_it("warrior_chest_t1"), db)
	assert_false(inv.equip(0, "mage", 10, db), "class")
	inv.add(_it("mage_chest_t1", 12), db)
	assert_false(inv.equip(1, "mage", 10, db), "level")
	assert_true(inv.equip(0, "warrior", 10, db))
	assert_eq(inv.equipment.chest.base_id, "warrior_chest_t1")
	assert_null(inv.bag[0])


func test_equip_swaps_with_worn() -> void:
	inv.equipment["main"] = _it("sword_t1")
	inv.add(_it("axe_t1"), db)
	assert_true(inv.equip(0, "warrior", 1, db))
	assert_eq(inv.equipment.main.base_id, "axe_t1")
	assert_eq(inv.bag[0].base_id, "sword_t1")


func test_two_hand_frees_offhand() -> void:
	inv.equipment["main"] = _it("sword_t1")
	inv.equipment["offhand"] = _it("shield_t1")
	inv.add(_it("greatsword_t1"), db)
	assert_true(inv.equip(0, "warrior", 1, db))
	assert_eq(inv.equipment.main.base_id, "greatsword_t1")
	assert_false(inv.equipment.has("offhand"))
	assert_eq(inv.free_slots(), 28)


func test_two_hand_full_bag_refused() -> void:
	inv.equipment["main"] = _it("sword_t1")
	inv.equipment["offhand"] = _it("shield_t1")
	_fill_bag()
	inv.bag[5] = _it("greatsword_t1")
	var before := inv.to_dict()
	assert_false(inv.equip(5, "warrior", 1, db))
	assert_eq(inv.to_dict(), before)


func test_offhand_removes_two_hand() -> void:
	inv.equipment["main"] = _it("greatsword_t1")
	inv.add(_it("shield_t1"), db)
	assert_true(inv.equip(0, "warrior", 1, db))
	assert_false(inv.equipment.has("main"))
	assert_eq(inv.equipment.offhand.base_id, "shield_t1")
	assert_eq(inv.bag[0].base_id, "greatsword_t1")


func test_daggers_fill_main_then_offhand() -> void:
	inv.add(_it("dagger_t1"), db)
	inv.add(_it("dagger_t1"), db)
	assert_true(inv.equip(0, "assassin", 1, db))
	assert_true(inv.equip(1, "assassin", 1, db))
	assert_eq(inv.equipment.main.base_id, "dagger_t1")
	assert_eq(inv.equipment.offhand.base_id, "dagger_t1")


func test_rings() -> void:
	inv.add(_it("ring_t1"), db)
	inv.add(_it("ring_t1"), db)
	inv.add(_it("ring_t1"), db)
	assert_true(inv.equip(0, "mage", 1, db))
	assert_true(inv.equip(1, "mage", 1, db))
	assert_true(inv.equipment.has("ring_1") and inv.equipment.has("ring_2"))
	assert_true(inv.equip(2, "mage", 1, db, "ring_2"))
	assert_eq(inv.bag[2].base_id, "ring_t1", "the old ring_2 went back")


func test_potion_cannot_be_equipped() -> void:
	inv.add(_it("potion_health"), db)
	assert_false(inv.equip(0, "mage", 1, db))


func test_unequip() -> void:
	inv.equipment["chest"] = _it("mage_chest_t1")
	assert_true(inv.unequip("chest", db))
	assert_false(inv.equipment.has("chest"))
	assert_eq(inv.bag[0].base_id, "mage_chest_t1")
	assert_false(inv.unequip("chest", db))


func test_unequip_full_bag_refused() -> void:
	inv.equipment["chest"] = _it("mage_chest_t1")
	_fill_bag()
	assert_false(inv.unequip("chest", db))
	assert_true(inv.equipment.has("chest"))


func test_visible_bases() -> void:
	inv.equipment["main"] = _it("sword_t1")
	inv.equipment["ring_1"] = _it("ring_t1")
	var v := inv.visible_bases()
	assert_eq(v.size(), 8)
	assert_eq(v[0], "sword_t1")
	assert_eq(v[2], "")


func test_roundtrip() -> void:
	inv.gold = 77
	inv.add(_it("sword_t1"), db)
	inv.equipment["chest"] = _it("warrior_chest_t1")
	var back := Inventory.from_dict(inv.to_dict(), "warrior", 5, db)
	assert_eq(back.to_dict(), inv.to_dict())


func test_sanitize() -> void:
	var wrong_class := _it("warrior_chest_t1").to_dict()
	var too_high := _it("mage_head_t1", 50).to_dict()
	var dup := _it("ring_t1").to_dict()
	var d := {
		"gold": -50,
		"bag": [{"base_id": "nope"}, "junk", dup, dup] + range(40).map(func(_i: int) -> Dictionary: return _it("ring_t1").to_dict()),
		"equipment": {"chest": wrong_class, "head": too_high, "main": _it("staff_t1").to_dict(),
			"offhand": _it("orb_t1").to_dict(), "feet": _it("mage_head_t1").to_dict(), "tail": _it("ring_t1").to_dict()},
	}
	var s := Inventory.from_dict(d, "mage", 10, db)
	assert_eq(s.gold, 0)
	assert_eq(s.equipment.keys().size(), 1, "only the staff stays worn")
	assert_eq(s.equipment.main.base_id, "staff_t1")
	var uids := {}
	var count := 0
	for it: Variant in s.bag:
		if it != null:
			count += 1
			assert_false(uids.has(it.uid), "uids are unique")
			uids[it.uid] = true
	# 2 dup rings + 40 rings + plate, cloth head ×2, orb (off the worn two-hander)
	# and the ring from the unknown slot: nothing valid is lost, extra slots hold the rest.
	assert_eq(count, 47)
	assert_gte(s.bag.size(), 47)


func test_from_dict_garbage() -> void:
	var s := Inventory.from_dict("x", "mage", 1, db)
	assert_eq(s.bag.size(), 30)
	assert_eq(s.gold, 0)
