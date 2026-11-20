extends GutTest
## Merchant: potions and common items for sale, buying at 25 %, repairs.

var f: CombatFixture
var db: ItemDB
var p: PlayerState


func before_each() -> void:
	f = CombatFixture.new()
	f.world.map.npcs = [{"id": "merchant", "at": [10, 10], "facing": 0}]
	db = f.world.items
	p = f.player(1, Vector3(11, 0, 10.5))
	p.class_id = "mage"
	p.progress.level = 10
	p.level = 10


func test_near() -> void:
	assert_true(Merchant.near(f.world, p))
	p.position = Vector3(20, 0, 20)
	assert_false(Merchant.near(f.world, p))


func test_stock_four_usable_commons() -> void:
	var s := Merchant.stock(f.world, p)
	assert_eq(s.size(), 4)
	for it: Item in s:
		assert_eq(it.rarity, "common")
		assert_eq(it.level, 10)
		assert_true(db.can_use("mage", it.base_id), it.base_id)


func test_restock_after_10min() -> void:
	var first := Merchant.stock(f.world, p).map(func(it: Item) -> String: return it.uid)
	f.world.tick += f.world.ticks(300.0)
	assert_eq(Merchant.stock(f.world, p).map(func(it: Item) -> String: return it.uid), first, "same stock")
	f.world.tick += f.world.ticks(301.0)
	assert_ne(Merchant.stock(f.world, p).map(func(it: Item) -> String: return it.uid), first)


func test_buy_potion() -> void:
	p.inventory.gold = 100
	assert_true(Merchant.buy(f.world, p, Merchant.BUY_HEALTH))
	assert_eq(p.inventory.gold, 100 - (5 + 2 * 10))
	assert_eq(p.inventory.bag[0].base_id, "potion_health")
	assert_true(p.inventory_dirty)


func test_buy_item() -> void:
	var wanted: Item = Merchant.stock(f.world, p)[1]
	var price := ItemRoll.value(wanted, db)
	p.inventory.gold = price
	assert_true(Merchant.buy(f.world, p, 1))
	assert_eq(p.inventory.gold, 0)
	assert_eq(p.inventory.bag[0].uid, wanted.uid)
	assert_eq(Merchant.stock(f.world, p).size(), 3, "sold out")


func test_buy_not_enough_gold() -> void:
	p.inventory.gold = 1
	assert_false(Merchant.buy(f.world, p, Merchant.BUY_HEALTH))
	assert_eq(p.inventory.gold, 1)


func test_far_from_merchant_refused() -> void:
	p.inventory.gold = 100
	p.position = Vector3(25, 0, 25)
	assert_false(Merchant.buy(f.world, p, Merchant.BUY_HEALTH))


func test_sell_25pct() -> void:
	var it := ItemRoll.new_item("sword_t1", 10, "rare")
	p.inventory.add(it, db)
	assert_true(Merchant.sell(f.world, p, 0))
	assert_eq(p.inventory.gold, floori(ItemRoll.value(it, db) * 0.25))
	assert_null(p.inventory.bag[0])


func test_sell_worthless_refused() -> void:
	p.inventory.add(ItemRoll.new_item("potion_health", 1), db)
	assert_false(Merchant.sell(f.world, p, 0))


func test_repair_cost() -> void:
	var it := ItemRoll.new_item("mage_chest_t1", 10, "rare")
	it.durability = 50
	assert_eq(Merchant.repair_cost(it, db), ceili(ItemRoll.value(it, db) * 0.1))


func test_repair_all() -> void:
	var a := ItemRoll.new_item("mage_chest_t1", 10)
	a.durability = 50
	var b := ItemRoll.new_item("mage_legs_t1", 10)
	b.durability = 0
	p.inventory.equipment["chest"] = a
	p.inventory.equipment["legs"] = b
	var cost := Merchant.repair_cost(a, db) + Merchant.repair_cost(b, db)
	assert_eq(Merchant.repair_all_cost(p, db), cost)
	p.inventory.gold = cost
	assert_true(Merchant.repair_all(f.world, p))
	assert_eq(p.inventory.gold, 0)
	assert_eq(a.durability, 100)
	assert_eq(b.durability, 100)
	assert_false(Merchant.repair_all(f.world, p), "nothing left to repair")


func test_in_combat_refused() -> void:
	p.inventory.gold = 100
	p.last_combat_tick = f.world.tick
	assert_false(Merchant.buy(f.world, p, Merchant.BUY_HEALTH))


func test_sell_cheap_level1_item_for_one_gold() -> void:
	var it := ItemRoll.new_item("sword_t1", 1, "common")
	assert_eq(floori(ItemRoll.value(it, db) * 0.25), 0, "worth 0 before the floor")
	p.inventory.add(it, db)
	assert_true(Merchant.sell(f.world, p, 0))
	assert_eq(p.inventory.gold, 1)


func test_trade_margin_at_edge_of_range() -> void:
	var at: Vector3 = NpcDB.load_default().placed(f.world.map)[0].position
	p.position = at + Vector3(NpcDB.TALK_RANGE + 0.3, 0, 0)
	assert_false(Merchant.near(f.world, p), "outside the talk range")
	p.inventory.gold = 100
	assert_true(Merchant.buy(f.world, p, Merchant.BUY_HEALTH), "within the 0.5 m margin")


func test_refused_trade_tells_the_player() -> void:
	p.inventory.add(ItemRoll.new_item("sword_t1", 10, "rare"), db)
	p.last_combat_tick = f.world.tick
	assert_false(Merchant.sell(f.world, p, 0))
	var evs := f.world.events.filter(func(e: Array) -> bool: return str(e[0]) == "trade_refused")
	assert_eq(evs.size(), 1)
	assert_eq(evs[0], ["trade_refused", 1, "combat"])
