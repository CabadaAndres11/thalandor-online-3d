class_name Merchant
extends RefCounted
## The merchant (an NPC with role "merchant"; provisionally next to Brann): sells potions
## and a few common items of the player's level, buys at sell_factor of the value and
## repairs worn gear. Every trade needs the player alive, out of combat and next to them.

const BUY_HEALTH := -1
const BUY_RESOURCE := -2
## Extra metres the host allows for trades: the client may see the player in range a
## moment before the host does.
const TRADE_MARGIN := 0.5


static func near(world: SimWorld, p: PlayerState, margin: float = 0.0) -> bool:
	return NpcDB.load_default().near_with_role(world.map, p.position, "merchant", margin) != ""


## Whether the player may trade now; when not, tells them why (["trade_refused", id, reason],
## reason "dead", "combat" or "far").
static func _can_trade(world: SimWorld, p: PlayerState) -> bool:
	var reason := ""
	if p.life != CombatEntity.ALIVE:
		reason = "dead"
	elif p.in_combat(world):
		reason = "combat"
	elif not near(world, p, TRADE_MARGIN):
		reason = "far"
	if reason != "":
		world.emit(["trade_refused", p.id, reason])
	return reason == ""


static func potion_price(level: int, db: ItemDB) -> int:
	var c: Dictionary = db.loot().get("potion", {})
	return int(c.get("price_base", 5)) + int(c.get("price_per_level", 2)) * level


## What the merchant pays: sell_factor of the value, at least 1 gold for anything but potions.
static func sell_price(it: Item, db: ItemDB) -> int:
	if db.is_consumable(it.base_id) or db.is_quest(it.base_id):
		return 0
	return maxi(1, floori(ItemRoll.value(it, db) * float(db.loot().get("sell_factor", 0.25))))


static func repair_cost(it: Item, db: ItemDB) -> int:
	return ceili(ItemRoll.value(it, db) * float(db.loot().get("repair_factor", 0.2)) * (100 - it.durability) / 100.0)


static func repair_all_cost(p: PlayerState, db: ItemDB) -> int:
	var total := 0
	for slot: String in p.inventory.equipment:
		total += repair_cost(p.inventory.equipment[slot], db)
	return total


## The items for sale to this player: stock_commons common items they can use, of their
## level. Rolled again when restock_s have passed since the last roll.
static func stock(world: SimWorld, p: PlayerState) -> Array:
	var db := world.items
	var cfg: Dictionary = db.loot().get("merchant", {})
	if p.merchant_tick < 0 or world.tick - p.merchant_tick >= world.ticks(float(cfg.get("restock_s", 600.0))):
		p.merchant_tick = world.tick
		p.merchant_stock = []
		var pool := db.bases_for(p.level, p.class_id)
		for i in int(cfg.get("stock_commons", 4)):
			if pool.is_empty():
				break
			p.merchant_stock.append(ItemRoll.roll_gear(pool[world.rng.randi_range(0, pool.size() - 1)], p.level, "common", world.rng, db))
	return p.merchant_stock


## index: a stock index, or BUY_HEALTH / BUY_RESOURCE for a potion.
static func buy(world: SimWorld, p: PlayerState, index: int) -> bool:
	if not _can_trade(world, p):
		return false
	var db := world.items
	var it: Item
	var price := 0
	if index == BUY_HEALTH or index == BUY_RESOURCE:
		it = ItemRoll.new_item("potion_health" if index == BUY_HEALTH else "potion_resource", 1)
		price = potion_price(p.level, db)
	else:
		var s := stock(world, p)
		if index < 0 or index >= s.size():
			return false
		it = s[index]
		price = ItemRoll.value(it, db)
	if p.inventory.gold < price or not p.inventory.add(it, db):
		return false
	p.inventory.gold -= price
	if index >= 0:
		p.merchant_stock.remove_at(index)
	p.inventory_dirty = true
	return true


static func sell(world: SimWorld, p: PlayerState, index: int) -> bool:
	if not _can_trade(world, p):
		return false
	if index < 0 or index >= p.inventory.bag.size() or p.inventory.bag[index] == null:
		world.emit(["trade_refused", p.id, "empty"]) # the slot the client sent is empty here
		return false
	var price := sell_price(p.inventory.bag[index], world.items)
	if price <= 0:
		world.emit(["trade_refused", p.id, "worthless"]) # potions: the merchant does not buy them
		return false
	p.inventory.bag[index] = null
	p.inventory.gold = mini(Inventory.MAX_GOLD, p.inventory.gold + price)
	p.inventory_dirty = true
	return true


static func repair_all(world: SimWorld, p: PlayerState) -> bool:
	if not _can_trade(world, p):
		return false
	var cost := repair_all_cost(p, world.items)
	var worn := p.inventory.equipment.values().any(func(it: Item) -> bool: return it.durability < 100)
	if not worn or p.inventory.gold < cost:
		return false
	p.inventory.gold -= cost
	for it: Item in p.inventory.equipment.values():
		it.durability = 100
	Progression.rebuild(p, world)
	p.inventory_dirty = true
	return true
