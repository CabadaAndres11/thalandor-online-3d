class_name GearStats
extends RefCounted
## What worn equipment adds to a character: attribute points and Progression modifiers
## ({type: "stat", stat, value}). Broken items (durability 0) give nothing.


## Attribute points from fixed stats and properties of everything worn.
static func attributes(inv: Inventory, db: ItemDB) -> Dictionary:
	var out := {}
	for e: Array in _entries(inv, db):
		if e[0] in ItemDB.ATTRIBUTE_STATS:
			out[e[0]] = float(out.get(e[0], 0.0)) + float(e[1])
	return out


## Every non-attribute stat as a Progression modifier.
static func mods(inv: Inventory, db: ItemDB) -> Array:
	var out: Array = []
	for e: Array in _entries(inv, db):
		if not e[0] in ItemDB.ATTRIBUTE_STATS:
			out.append({"type": "stat", "stat": e[0], "value": e[1]})
	return out


## [stat, value] pairs of the worn, unbroken items.
static func _entries(inv: Inventory, db: ItemDB) -> Array:
	var out: Array = []
	if inv == null:
		return out
	for slot: String in inv.equipment:
		var it: Item = inv.equipment[slot]
		if it.durability <= 0:
			continue
		var two := db.hands(it.base_id) == 2
		for s: Dictionary in db.base(it.base_id).get("stats", []):
			out.append([str(s.stat), ItemRoll.stat_value(s, it.level, two, db)])
		for a: Dictionary in it.affixes:
			out.append([str(db.affix(a.id).get("stat", "")), float(a.value)])
	return out


static func has_shield(inv: Inventory, db: ItemDB) -> bool:
	if inv == null or not inv.equipment.has("offhand"):
		return false
	var it: Item = inv.equipment.offhand
	return it.durability > 0 and str(db.base(it.base_id).get("kind", "")) == "shield"


## Family id of the main weapon ("" without one).
static func family(inv: Inventory, db: ItemDB) -> String:
	if inv == null or not inv.equipment.has("main"):
		return ""
	return str(db.family_of(inv.equipment.main.base_id).get("id", ""))
