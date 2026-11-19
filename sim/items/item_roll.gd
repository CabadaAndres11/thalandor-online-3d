class_name ItemRoll
extends RefCounted
## Loot and item rolls (data/items/loot.json), ported from the 2D prototype
## (D:\RPG\src\sim\items\roll.ts). Game randomness comes from the given rng; only item
## ids use their own generator, so they never repeat across sessions.

static var _uid_rng: RandomNumberGenerator


static func new_uid() -> String:
	if _uid_rng == null:
		_uid_rng = RandomNumberGenerator.new()
		_uid_rng.randomize()
	var s := "i"
	for i in 12:
		s += "0123456789abcdefghijklmnopqrstuvwxyz"[_uid_rng.randi() % 36]
	return s


## "normal" or "elite" (bosses use the elite table).
static func roll_rarity(table: String, rng: RandomNumberGenerator, db: ItemDB) -> String:
	var t: Dictionary = (db.loot().get("rarity", {}) as Dictionary).get(table, {})
	var r := rng.randf()
	for rarity: String in db.loot().get("rarities", []):
		if not t.has(rarity):
			continue
		r -= float(t[rarity])
		if r < 0.0:
			return rarity
	return "common"


## Highest value of a property at this level.
static func affix_max(def: Dictionary, level: int) -> float:
	return float(def.get("base", 0.0)) + float(def.get("per_level", 0.0)) * level


## A fixed stat of a base at this level; two-handed weapons give two_hand_mult times as much.
static func stat_value(def: Dictionary, level: int, two_hand: bool, db: ItemDB) -> float:
	var v := float(def.get("base", 0.0)) + float(def.get("per_level", 0.0)) * level
	return v * float(db.loot().get("two_hand_mult", 1.8)) if two_hand else v


static func new_item(base_id: String, level: int, rarity: String = "common") -> Item:
	var it := Item.new()
	it.uid = new_uid()
	it.base_id = base_id
	it.level = level
	it.rarity = rarity
	return it


## A piece of equipment with its random properties (none repeat a stat; each rolls between
## affix_roll.min and max of its top value at the item's level).
static func roll_gear(base_id: String, level: int, rarity: String, rng: RandomNumberGenerator, db: ItemDB) -> Item:
	var it := new_item(base_id, level, rarity)
	var count := int((db.loot().get("affix_count", {}) as Dictionary).get(rarity, 0))
	var roll: Dictionary = db.loot().get("affix_roll", {"min": 0.6, "max": 1.0})
	var slot := str(db.base(base_id).get("slot", ""))
	var pool: Array = []
	for id: String in db.affix_ids():
		var slots: Array = db.affix(id).get("slots", [])
		if slots.is_empty() or slot in slots:
			pool.append(id)
	var taken := {}
	while it.affixes.size() < count and not pool.is_empty():
		var id: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var def := db.affix(id)
		if taken.has(def.stat):
			continue
		taken[def.stat] = true
		var top := affix_max(def, level)
		var f := lerpf(float(roll.min), float(roll.max), rng.randf())
		it.affixes.append({"id": id, "value": _round_stat(str(def.stat), top * f)})
	return it


## Whole numbers for attributes, armor and power; two decimals for other values of 1 or
## more (regeneration); four for chances and percentages.
static func _round_stat(stat: String, v: float) -> float:
	if stat in ItemDB.ATTRIBUTE_STATS or stat in ["armor_add", "attack_power_add", "spell_power_add"]:
		return float(maxi(1, roundi(v)))
	return snappedf(v, 0.01) if absf(v) >= 1.0 else snappedf(v, 0.0001)


## One item for a player of this class: usually something they can use.
static func roll_item_for(class_id: String, level: int, kind: String, rng: RandomNumberGenerator, db: ItemDB) -> Item:
	var items: Dictionary = db.loot().get("items", {})
	var usable := rng.randf() < float(items.get("usable_share", 0.75))
	var pool := db.bases_for(level, class_id if usable else "")
	if pool.is_empty():
		pool = db.bases_for(level)
	if pool.is_empty():
		return null
	var base_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	return roll_gear(base_id, level, roll_rarity("normal" if kind == "normal" else "elite", rng, db), rng, db)


## Gold for a monster; `variance` in -1..1 picks within ±variance of the formula.
static func gold_amount(level: int, elite: bool, variance: float, db: ItemDB) -> int:
	var g: Dictionary = db.loot().get("gold", {})
	var v := 1.0 + float(g.get("variance", 0.2)) * variance
	return maxi(1, roundi(float(g.base) * pow(level, float(g.exponent)) * v * (float(g.elite_mult) if elite else 1.0)))


## Everything one player gets from one monster. kind: "normal", "elite" or "boss".
static func roll_loot(class_id: String, monster_level: int, kind: String, rng: RandomNumberGenerator, db: ItemDB) -> Dictionary:
	var loot := db.loot()
	var items: Dictionary = loot.get("items", {})
	var level := maxi(1, monster_level)
	var out: Array = []
	var n := 0
	match kind:
		"boss":
			n = int(items.get("boss_guaranteed", 2))
		"elite":
			n = int(items.get("elite_guaranteed", 1)) + (1 if rng.randf() < float(items.get("elite_extra_chance", 0.4)) else 0)
		_:
			n = 1 if rng.randf() < float(items.get("normal_chance", 0.12)) else 0
	for i in n:
		var it := roll_item_for(class_id, level, kind, rng, db)
		if it != null:
			out.append(it)
	if rng.randf() < float(loot.get("potion_chance", 0.06)):
		var rage := str(CharacterCatalog.load_default().class_def(class_id).get("resource", {}).get("kind", "")) == "rage"
		out.append(new_item("potion_health" if rage or rng.randf() < 0.5 else "potion_resource", 1))
	var gold := 0
	var strong := kind != "normal"
	if strong or rng.randf() < float((loot.get("gold", {}) as Dictionary).get("chance", 0.9)):
		gold = gold_amount(level, strong, rng.randf_range(-1.0, 1.0), db)
	return {"gold": gold, "items": out}


## Sale value: base × level^exponent × rarity; consumables are worth nothing.
static func value(it: Item, db: ItemDB) -> int:
	if db.is_consumable(it.base_id):
		return 0
	var v: Dictionary = db.loot().get("value", {})
	var mult := float((v.get("rarity_mult", {}) as Dictionary).get(it.rarity, 1))
	return roundi(float(v.get("base", 3)) * pow(it.level, float(v.get("exponent", 1.4))) * mult)
