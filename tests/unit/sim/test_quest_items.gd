extends GutTest
## Quest items (Plan 8.2): they go to the bag, stack, and cannot be equipped, used or
## sold; only the quest takes them away.

var f: CombatFixture
var db: ItemDB


func before_each() -> void:
	f = CombatFixture.new()
	db = ItemDB.load_default()


func _hero() -> PlayerState:
	var p := f.world.add_player(1, Vector3(5.5, 0, 5.5))
	p.progress.level = 5
	ClassRules.setup_player(p, "warrior", null, f.world)
	return p


func _quest_item(count: int) -> Item:
	var it := ItemRoll.new_item("q_colmillo", 1)
	it.count = count
	return it


func _index_of(inv: Inventory, base_id: String) -> int:
	for i in inv.bag.size():
		if inv.bag[i] != null and inv.bag[i].base_id == base_id:
			return i
	return -1


func test_is_quest() -> void:
	assert_true(db.is_quest("q_colmillo"))
	assert_true(db.is_quest("q_paquete"))
	assert_false(db.is_quest("potion_health"))


func test_quest_item_stacks() -> void:
	var inv := Inventory.new()
	assert_true(inv.add(_quest_item(3), db))
	assert_true(inv.add(_quest_item(2), db))
	assert_eq(inv.count_of("q_colmillo"), 5)
	assert_eq(inv.free_slots(), Inventory.SIZE - 1)


func test_quest_item_locked() -> void:
	var p := _hero()
	f.world.map.npcs = [{"id": "merchant", "at": [5, 6], "facing": 0}]
	p.inventory.add(_quest_item(2), db)
	var i := _index_of(p.inventory, "q_colmillo")
	var gold := p.inventory.gold
	assert_false(ItemRequests.equip(f.world, p, i))
	assert_false(ItemRequests.use(f.world, p, i))
	assert_false(Merchant.sell(f.world, p, i))
	assert_eq(Merchant.sell_price(p.inventory.bag[i], db), 0)
	assert_eq(p.inventory.count_of("q_colmillo"), 2)
	assert_eq(p.inventory.gold, gold)


func test_sort_puts_quest_last() -> void:
	var inv := Inventory.new()
	inv.add(_quest_item(1), db)
	inv.add(ItemRoll.new_item("potion_health", 1), db)
	inv.add(ItemRoll.new_item("warrior_chest_t1", 1), db)
	inv.sort_bag(db)
	assert_eq(inv.bag[2].base_id, "q_colmillo")
	assert_eq(inv.count_of("q_colmillo"), 1)


func test_sort_keeps_quest_stack() -> void:
	var inv := Inventory.new()
	inv.add(_quest_item(40), db)
	inv.sort_bag(db)
	assert_eq(inv.count_of("q_colmillo"), 40)


func test_add_fails_when_full() -> void:
	var inv := Inventory.new()
	for i in Inventory.SIZE:
		inv.add(ItemRoll.new_item("warrior_chest_t1", 1), db)
	assert_false(inv.add(_quest_item(1), db))
	assert_eq(inv.count_of("q_colmillo"), 0)


func test_remove_count() -> void:
	var inv := Inventory.new()
	inv.add(_quest_item(5), db)
	assert_eq(inv.remove_count("q_colmillo", 3), 3)
	assert_eq(inv.count_of("q_colmillo"), 2)
	assert_eq(inv.remove_count("q_colmillo", 9), 2)
	assert_eq(inv.count_of("q_colmillo"), 0)
	assert_eq(inv.free_slots(), Inventory.SIZE)


func test_stack_survives_save_and_wire() -> void:
	var it := _quest_item(40)
	assert_eq(Item.from_dict(it.to_dict(), db).count, 40)
	assert_eq(Item.from_wire(it.to_wire(), db).count, 40)
	it.count = 500
	assert_eq(Item.from_dict(it.to_dict(), db).count, Inventory.QUEST_STACK)
