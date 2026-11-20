class_name Inventory
extends RefCounted
## A character's gold, bag (30 slots, more only when sanitizing would otherwise lose
## items) and worn equipment (11 slots). Only the host changes it during a game.

const SLOTS := ["main", "offhand", "head", "shoulders", "chest", "hands", "legs", "feet", "neck", "ring_1", "ring_2"]
## Slots with a voxel model, in the order PLAYER_GEAR sends them.
const VISIBLE := ["main", "offhand", "head", "shoulders", "chest", "hands", "legs", "feet"]
const SIZE := 30
const MAX_GOLD := 2_000_000_000

var gold: int = 0
## Item or null per slot.
var bag: Array = []
## slot -> Item.
var equipment: Dictionary = {}


func _init() -> void:
	bag.resize(SIZE)


func free_slots() -> int:
	return bag.count(null)


## Stacks consumables of the same base, then takes the first free slot. False if it does not fit.
func add(item: Item, db: ItemDB) -> bool:
	if db.is_consumable(item.base_id):
		var stack := int((db.loot().get("potion", {}) as Dictionary).get("stack", 20))
		var left := item.count
		var room := 0
		for it: Variant in bag:
			if it != null and it.base_id == item.base_id:
				room += stack - int(it.count)
		if room + free_slots() * stack < left:
			return false
		for it: Variant in bag:
			if left > 0 and it != null and it.base_id == item.base_id and it.count < stack:
				var n := mini(stack - int(it.count), left)
				it.count += n
				left -= n
		while left > 0:
			var part := item if left <= stack and left == item.count else ItemRoll.new_item(item.base_id, item.level)
			part.count = mini(left, stack)
			left -= part.count
			bag[bag.find(null)] = part
		return true
	var i := bag.find(null)
	if i < 0:
		return false
	bag[i] = item
	return true


func take(index: int) -> Item:
	if index < 0 or index >= bag.size():
		return null
	var it: Item = bag[index]
	bag[index] = null
	return it


## The slot an item would go to, or "" when this class cannot wear it there.
## `target`: a preferred slot (ring_1/ring_2, or offhand for daggers and short swords).
func slot_for(item: Item, class_id: String, db: ItemDB, target: String = "") -> String:
	var b := db.base(item.base_id)
	if b.is_empty() or not db.can_use(class_id, item.base_id):
		return ""
	var slot := str(b.slot)
	match slot:
		"consumable":
			return ""
		"ring":
			if target in ["ring_1", "ring_2"]:
				return target
			return "ring_1" if not equipment.has("ring_1") or equipment.has("ring_2") else "ring_2"
		"main":
			var off_ok := bool(db.weapon_type(item.base_id).get("offhand", false)) and _class_offhand(class_id, db).has(str(b.kind))
			if off_ok and (target == "offhand" or (target == "" and equipment.has("main") and not equipment.has("offhand") \
					and db.hands(equipment.main.base_id) == 1)):
				return "offhand"
			return "main" if target in ["", "main"] else ""
	return slot if target in ["", slot] else ""


func _class_offhand(class_id: String, db: ItemDB) -> Array:
	return ((db.weapons().get("classes", {}) as Dictionary).get(class_id, {}) as Dictionary).get("offhand", [])


## Wears the bag item at `index`. What it replaces goes back to the bag (a two-handed weapon
## also takes off the off-hand, an off-hand takes off a two-handed weapon); nothing changes
## if the class or level do not allow it or the bag has no room for what comes off.
func equip(index: int, class_id: String, level: int, db: ItemDB, target: String = "") -> bool:
	if index < 0 or index >= bag.size() or bag[index] == null:
		return false
	var item: Item = bag[index]
	if item.level > level:
		return false
	var slot := slot_for(item, class_id, db, target)
	if slot == "":
		return false
	var off: Array = [slot]
	if slot == "main" and db.hands(item.base_id) == 2:
		off.append("offhand")
	if slot == "offhand" and equipment.has("main") and db.hands(equipment.main.base_id) == 2:
		off.append("main")
	var back: Array = []
	for s: String in off:
		if equipment.has(s):
			back.append(equipment[s])
	if back.size() > free_slots() + 1:
		return false
	bag[index] = null
	for s: String in off:
		equipment.erase(s)
	equipment[slot] = item
	if not back.is_empty():
		bag[index] = back[0]
		for i in range(1, back.size()):
			bag[bag.find(null)] = back[i]
	return true


func unequip(slot: String, _db: ItemDB = null) -> bool:
	if not equipment.has(slot) or free_slots() == 0:
		return false
	bag[bag.find(null)] = equipment[slot]
	equipment.erase(slot)
	return true


## The starter kit of a class worn (level 1, common), with an empty bag and no gold.
static func starter(class_id: String, db: ItemDB) -> Inventory:
	var inv := Inventory.new()
	inv.wear_starter(class_id, db)
	return inv


## Replaces whatever is worn by the class's starter kit (bag and gold stay).
func wear_starter(class_id: String, db: ItemDB) -> void:
	equipment.clear()
	for id: String in db.starter(class_id):
		var it := ItemRoll.new_item(id, 1)
		var slot := slot_for(it, class_id, db)
		if slot != "" and not equipment.has(slot):
			equipment[slot] = it


## Base ids of the 8 visible slots ("" when empty).
func visible_bases() -> Array:
	return VISIBLE.map(func(s: String) -> String: return equipment[s].base_id if equipment.has(s) else "")


func to_dict() -> Dictionary:
	var eq := {}
	for s: String in equipment:
		eq[s] = equipment[s].to_dict()
	return {"gold": gold, "bag": bag.map(func(it: Variant) -> Variant: return it.to_dict() if it != null else null), "equipment": eq}


## Compact form for the network: {g: gold, b: [item wire or null], e: {slot: item wire}}.
func to_wire() -> Dictionary:
	var eq := {}
	for s: String in equipment:
		eq[s] = equipment[s].to_wire()
	return {"g": gold, "b": bag.map(func(it: Variant) -> Variant: return it.to_wire() if it != null else null), "e": eq}


## Reads a wire inventory with the same sanitizing as from_dict.
static func from_wire(v: Variant, class_id: String, level: int, db: ItemDB) -> Inventory:
	if not v is Dictionary:
		return from_dict(null, class_id, level, db)
	var d: Dictionary = v
	var eq := {}
	var raw_eq: Variant = d.get("e", {})
	if raw_eq is Dictionary:
		for s: Variant in raw_eq:
			eq[s] = Item.wire_to_dict((raw_eq as Dictionary)[s])
	var raw_bag: Variant = d.get("b", [])
	var bag_dicts: Array = (raw_bag as Array).map(func(x: Variant) -> Variant: return Item.wire_to_dict(x)) if raw_bag is Array else []
	return from_dict({"gold": d.get("g", 0), "bag": bag_dicts, "equipment": eq}, class_id, level, db)


## The host's inventory exactly as sent (for its owner's client): every item in its slot and
## every worn piece as worn, unknown items dropped and nothing re-checked. The host already
## sanitized it, and moving anything here would make the client's slots point at other items.
static func from_wire_exact(v: Variant, db: ItemDB) -> Inventory:
	var inv := Inventory.new()
	if not v is Dictionary:
		return inv
	var d: Dictionary = v
	var g: Variant = d.get("g", 0)
	inv.gold = clampi(int(g), 0, MAX_GOLD) if g is int or g is float else 0
	var raw_bag: Variant = d.get("b", [])
	if raw_bag is Array:
		inv.bag.resize(maxi(SIZE, (raw_bag as Array).size()))
		for i in (raw_bag as Array).size():
			inv.bag[i] = Item.from_dict(Item.wire_to_dict((raw_bag as Array)[i]), db)
	var raw_eq: Variant = d.get("e", {})
	if raw_eq is Dictionary:
		for s: Variant in raw_eq:
			var it := Item.from_dict(Item.wire_to_dict((raw_eq as Dictionary)[s]), db)
			if it != null and str(s) in SLOTS:
				inv.equipment[str(s)] = it
	return inv


## Never null. Unknown items are dropped; anything valid that cannot be worn (other class,
## too high, wrong slot, an off-hand under a two-handed weapon) goes to the bag, which grows
## past 30 slots instead of losing it. Repeated uids get new ones.
static func from_dict(v: Variant, class_id: String, level: int, db: ItemDB) -> Inventory:
	var inv := Inventory.new()
	if not v is Dictionary:
		return inv
	var d: Dictionary = v
	var g: Variant = d.get("gold", 0)
	inv.gold = clampi(int(g), 0, MAX_GOLD) if g is int or g is float else 0
	var uids := {}
	var loose: Array = []
	var raw_bag: Variant = d.get("bag", [])
	if raw_bag is Array:
		# Every item keeps its slot: the client and the host must agree on the indexes the
		# requests (sell, equip, use) refer to.
		inv.bag.resize(maxi(SIZE, (raw_bag as Array).size()))
		for i in (raw_bag as Array).size():
			var it := _unique(Item.from_dict((raw_bag as Array)[i], db), uids)
			if it != null:
				inv.bag[i] = it
	var raw_eq: Variant = d.get("equipment", {})
	if raw_eq is Dictionary:
		for s: String in SLOTS: # a fixed order, so main is worn before offhand is checked
			var it := _unique(Item.from_dict((raw_eq as Dictionary).get(s), db), uids)
			if it == null:
				continue
			if it.level <= level and inv.slot_for(it, class_id, db, s) == s \
					and not (s == "offhand" and inv.equipment.has("main") and db.hands(inv.equipment.main.base_id) == 2):
				inv.equipment[s] = it
			else:
				loose.append(it)
		for s: Variant in (raw_eq as Dictionary):
			if not s in SLOTS:
				var it := _unique(Item.from_dict((raw_eq as Dictionary)[s], db), uids)
				if it != null:
					loose.append(it)
	for it: Item in loose:
		var i := inv.bag.find(null)
		if i < 0:
			inv.bag.append(it)
		else:
			inv.bag[i] = it
	while inv.bag.size() > SIZE and inv.bag.back() == null: # a grown bag shrinks back when it can
		inv.bag.pop_back()
	return inv


static func _unique(it: Item, uids: Dictionary) -> Item:
	if it == null:
		return null
	while uids.has(it.uid):
		it.uid = ItemRoll.new_uid()
	uids[it.uid] = true
	return it
