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


func test_potions_wait_on_their_button_not_in_the_bag() -> void:
	var p := _it("potion_health")
	p.count = 15
	assert_true(inv.add(p, db))
	var q := _it("potion_health")
	q.count = 30
	assert_true(inv.add(q, db), "no limit")
	inv.add(_it("potion_resource"), db)
	assert_eq(inv.free_slots(), 30, "the bag stays empty")
	assert_eq([inv.potion_count("health"), inv.potion_count("resource")], [45, 1])
	assert_eq(inv.count_of("potion_health"), 45)
	assert_eq(inv.remove_count("potion_health", 5), 5)
	assert_eq(inv.potion_count("health"), 40)


func test_potions_go_to_their_button_even_with_a_full_bag() -> void:
	_fill_bag()
	assert_true(inv.add(_it("potion_health"), db))
	assert_eq(inv.potion_count("health"), 1)


func test_potions_survive_save_and_wire() -> void:
	var p := _it("potion_health")
	p.count = 7
	inv.add(p, db)
	var back := Inventory.from_dict(inv.to_dict(), "mage", 1, db)
	assert_eq(back.potion_count("health"), 7)
	assert_eq(Inventory.from_wire(inv.to_wire(), "mage", 1, db).potion_count("health"), 7)
	assert_eq(Inventory.from_wire_exact(inv.to_wire(), db).potion_count("health"), 7)


func test_old_saves_move_bag_potions_to_their_button() -> void:
	var old := {"gold": 3, "bag": [_it("potion_resource").to_dict(), _it("sword_t1").to_dict()], "equipment": {}}
	old.bag[0].count = 4
	var back := Inventory.from_dict(old, "warrior", 1, db)
	assert_eq(back.potion_count("resource"), 4)
	assert_null(back.bag[0], "no potion left in the bag")
	assert_eq(back.bag[1].base_id, "sword_t1", "the rest keeps its slot")


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


## 2026-11-27: with a weapon in each hand, a third one takes the place of the worse of them.
func test_new_dagger_replaces_the_worse_hand() -> void:
	var good := _it("dagger_t1")
	good.rarity = "epic"
	inv.equipment["main"] = good
	inv.equipment["offhand"] = _it("dagger_t1") # common: the worse one
	var fresh := _it("dagger_t1")
	fresh.rarity = "rare"
	inv.add(fresh, db)
	assert_true(inv.equip(0, "assassin", 1, db))
	assert_same(inv.equipment.main, good, "the better dagger stays")
	assert_same(inv.equipment.offhand, fresh)
	inv.equipment["offhand"].rarity = "legendary"
	var other := _it("dagger_t1")
	other.rarity = "uncommon"
	inv.add(other, db)
	assert_true(inv.equip(inv.bag.find(other), "assassin", 1, db))
	assert_same(inv.equipment.main, other, "now the main hand was the worse")


func test_rings() -> void:
	inv.add(_it("ring_t1"), db)
	inv.add(_it("ring_t1"), db)
	inv.add(_it("ring_t1"), db)
	assert_true(inv.equip(0, "mage", 1, db))
	assert_true(inv.equip(1, "mage", 1, db))
	assert_true(inv.equipment.has("ring_1") and inv.equipment.has("ring_2"))
	assert_true(inv.equip(2, "mage", 1, db, "ring_2"))
	assert_eq(inv.bag[2].base_id, "ring_t1", "the old ring_2 went back")


func test_quest_item_cannot_be_equipped() -> void:
	inv.add(_it("q_paquete"), db)
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


func test_wire_keeps_bag_gaps() -> void:
	inv.bag[0] = null
	inv.bag[3] = _it("sword_t1")
	inv.bag[7] = _it("ring_t1")
	var back := Inventory.from_wire(inv.to_wire(), "warrior", 10, db)
	assert_null(back.bag[0])
	assert_eq(back.bag[3].base_id, "sword_t1", "same slot as on the host")
	assert_eq(back.bag[7].base_id, "ring_t1")
	assert_eq(back.bag.size(), Inventory.SIZE)


func test_save_keeps_bag_gaps() -> void:
	inv.bag[5] = _it("sword_t1")
	var back := Inventory.from_dict(inv.to_dict(), "warrior", 10, db)
	assert_eq(back.bag[5].base_id, "sword_t1")
	assert_null(back.bag[0])


func test_unwearable_equipment_fills_the_first_gap() -> void:
	inv.bag[0] = _it("sword_t1")
	var d := inv.to_dict()
	d.equipment = {"chest": _it("mage_chest_t1").to_dict()}
	var back := Inventory.from_dict(d, "warrior", 10, db)
	assert_eq(back.bag[0].base_id, "sword_t1")
	assert_eq(back.bag[1].base_id, "mage_chest_t1", "a mage chest on a warrior goes to the first free slot")


func test_the_client_copies_the_host_inventory_as_is() -> void:
	inv.bag[4] = _it("sword_t1", 5)
	inv.equipment["chest"] = _it("mage_chest_t1", 20) # the client thinks it is a level 10 warrior
	var seen := Inventory.from_wire_exact(inv.to_wire(), db)
	assert_eq(seen.equipment.chest.base_id, "mage_chest_t1", "the host's word, not re-checked")
	assert_eq(seen.bag[4].base_id, "sword_t1")
	assert_null(seen.bag[0], "nothing moved into the gaps")


# --- Sorting the bag (Plan 8.1.1) -------------------------------------------------------

func _put(i: int, base_id: String, level := 1, rarity := "common", count := 1) -> void:
	var it := _it(base_id, level)
	it.rarity = rarity
	it.count = count
	inv.bag[i] = it


func test_sort_order() -> void:
	_put(0, "q_paquete", 1, "common", 5)
	_put(3, "warrior_chest_t1", 3, "common")
	_put(5, "sword_t1", 2, "common")
	_put(7, "warrior_chest_t1", 5, "rare")
	_put(9, "sword_t1", 4, "common")
	_put(12, "warrior_head_t1", 1, "uncommon")
	inv.sort_bag(db)
	var got := []
	for it: Variant in inv.bag:
		if it != null:
			got.append("%s/%s/%d" % [(it as Item).base_id, (it as Item).rarity, (it as Item).level])
	assert_eq(got, ["sword_t1/common/4", "sword_t1/common/2", "warrior_head_t1/uncommon/1",
		"warrior_chest_t1/rare/5", "warrior_chest_t1/common/3", "q_paquete/common/1"])
	assert_eq(inv.bag.size(), 30, "same size")
	assert_null(inv.bag[6], "empty slots at the end")


func test_sort_merges_stacks_without_loss() -> void:
	for i: int in [2, 8, 20]:
		_put(i, "q_paquete", 1, "common", 50)
	inv.sort_bag(db)
	assert_eq(inv.bag[0].count, Inventory.QUEST_STACK)
	assert_eq(inv.bag[1].count, 150 - Inventory.QUEST_STACK)
	assert_null(inv.bag[2])


func test_sort_keeps_equipment() -> void:
	var worn := _it("sword_t1")
	inv.equipment["main"] = worn
	_put(4, "sword_t1", 3)
	inv.sort_bag(db)
	assert_same(inv.equipment["main"], worn)
	assert_eq(inv.bag[0].level, 3)


## 2026-11-27: the eye in the character window hides the worn helmet from everyone, and it is kept.
func test_hidden_head_is_not_shown_and_is_saved() -> void:
	inv.equipment["head"] = _it("warrior_head_t1")
	assert_eq(inv.visible_bases()[Inventory.VISIBLE.find("head")], "warrior_head_t1")
	inv.hide_head = true
	assert_eq(inv.visible_bases()[Inventory.VISIBLE.find("head")], "", "hidden")
	assert_true(inv.equipment.has("head"), "still worn: its stats count")
	assert_true(Inventory.from_dict(inv.to_dict(), "warrior", 1, db).hide_head)
	assert_true(Inventory.from_wire(inv.to_wire(), "warrior", 1, db).hide_head)
	assert_true(Inventory.from_wire_exact(inv.to_wire(), db).hide_head)
