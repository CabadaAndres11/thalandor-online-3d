class_name Item
extends RefCounted
## One item: a base (data/items/bases.json) with its level, rarity, random properties
## and durability; potions also have a stack count.

var uid: String = ""
var base_id: String = ""
var level: int = 1
var rarity: String = "common"
## [{id, value}]: random properties (affixes.json ids).
var affixes: Array = []
## 0..100; at 0 the item gives nothing.
var durability: int = 100
var count: int = 1


func to_dict() -> Dictionary:
	return {
		"uid": uid, "base_id": base_id, "level": level, "rarity": rarity,
		"affixes": affixes.duplicate(true), "durability": durability, "count": count,
	}


## Compact form for the network: [uid, base_id, level, rarity, [affix id, value, …], durability, count].
func to_wire() -> Array:
	var flat: Array = []
	for a: Dictionary in affixes:
		flat.append(a.id)
		flat.append(a.value)
	return [uid, base_id, level, rarity, flat, durability, count]


## The dictionary from_dict reads, from a wire array ({} when it is not one).
static func wire_to_dict(v: Variant) -> Dictionary:
	if not v is Array or (v as Array).size() != 7 or not v[4] is Array:
		return {}
	var a: Array = v
	var aff: Array = []
	var flat: Array = a[4]
	for i in range(0, flat.size() - 1, 2):
		aff.append({"id": flat[i], "value": flat[i + 1]})
	return {"uid": a[0], "base_id": a[1], "level": a[2], "rarity": a[3], "affixes": aff, "durability": a[5], "count": a[6]}


static func from_wire(v: Variant, db: ItemDB) -> Item:
	return from_dict(wire_to_dict(v), db)


## null when `v` is not an item of a known base. Everything else is clamped or dropped.
static func from_dict(v: Variant, db: ItemDB) -> Item:
	if not v is Dictionary:
		return null
	var d: Dictionary = v
	var base_id: Variant = d.get("base_id")
	if not base_id is String or db.base(base_id).is_empty():
		return null
	var it := Item.new()
	it.base_id = base_id
	var uid: Variant = d.get("uid")
	it.uid = uid if uid is String and (uid as String).length() > 0 and (uid as String).length() <= 32 else ItemRoll.new_uid()
	it.level = clampi(_int(d.get("level"), 1), 1, 65535)
	var rarity: Variant = d.get("rarity")
	it.rarity = rarity if rarity is String and rarity in (db.loot().get("rarities", []) as Array) else "common"
	it.durability = clampi(_int(d.get("durability"), 100), 0, 100)
	var stack := int((db.loot().get("potion", {}) as Dictionary).get("stack", 20))
	it.count = clampi(_int(d.get("count"), 1), 1, stack) if db.is_consumable(base_id) else 1
	var raw: Variant = d.get("affixes", [])
	var seen := {}
	if raw is Array:
		for a: Variant in raw:
			if not a is Dictionary:
				continue
			var def := db.affix(str(a.get("id", "")))
			var value: Variant = a.get("value")
			if def.is_empty() or not (value is int or value is float) or seen.has(def.stat):
				continue
			seen[def.stat] = true
			it.affixes.append({"id": str(a.id), "value": float(value)})
	return it


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
