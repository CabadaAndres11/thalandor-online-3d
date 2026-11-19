class_name ItemDB
extends RefCounted
## Items from data/items/: bases (bases.json, with stat templates and level tiers),
## random properties (affixes.json), loot numbers (loot.json) and weapon rules
## (weapons.json: families, weapon types and what each class may use).

const DIR := "res://data/items"
## Equipment slots of a base ("ring" goes to ring_1 or ring_2; "consumable" is not worn).
const BASE_SLOTS := ["main", "offhand", "head", "shoulders", "chest", "hands", "legs", "feet", "neck", "ring", "consumable"]
const ARMOR_SLOTS := ["head", "shoulders", "chest", "hands", "legs", "feet"]
## Stats an item may give: the five attributes and the Progression modifiers.
const ATTRIBUTE_STATS := ["strength", "agility", "intellect", "stamina", "spirit"]

static var _default: ItemDB

var _bases: Dictionary = {}
var _order: Array = []
var _affixes: Dictionary = {}
var _loot: Dictionary = {}
var _weapons: Dictionary = {}


static func load_default() -> ItemDB:
	if _default == null:
		_default = load_dir(DIR)
	return _default


static func load_dir(dir: String) -> ItemDB:
	var db := ItemDB.new()
	var raw: Dictionary = _read(dir.path_join("bases.json"))
	var tiers: Dictionary = raw.get("tiers", {})
	var templates: Dictionary = raw.get("templates", {})
	var bases: Dictionary = raw.get("bases", {})
	for id: String in bases:
		var b: Dictionary = (bases[id] as Dictionary).duplicate(true)
		b["id"] = id
		var tier := str(int(b.get("tier", 0)))
		if not b.has("min_level") and tiers.has(tier):
			b["min_level"] = int(tiers[tier][0])
			b["max_level"] = int(tiers[tier][1])
		if not b.has("stats"):
			b["stats"] = (templates.get(str(b.get("template", "")), []) as Array).duplicate(true)
		db._bases[id] = b
		db._order.append(id)
	db._affixes = _read(dir.path_join("affixes.json"))
	db._loot = _read(dir.path_join("loot.json"))
	db._weapons = _read(dir.path_join("weapons.json"))
	return db


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		push_error("ItemDB: %s is missing or not a JSON object" % path)
		return {}
	return parsed


func base_ids() -> Array:
	return _order


func base(id: String) -> Dictionary:
	return _bases.get(id, {})


func affix(id: String) -> Dictionary:
	return _affixes.get(id, {})


func affix_ids() -> Array:
	return _affixes.keys()


func loot() -> Dictionary:
	return _loot


func weapons() -> Dictionary:
	return _weapons


## The weapon type entry of a base (empty for armor, jewelry and potions).
func weapon_type(base_id: String) -> Dictionary:
	return (_weapons.get("weapon_types", {}) as Dictionary).get(str(base(base_id).get("kind", "")), {})


## The family of a weapon ({id, grip?, melee_anim?, ...}); empty when it is not a weapon.
func family_of(base_id: String) -> Dictionary:
	var fam := str(weapon_type(base_id).get("family", ""))
	if fam == "":
		return {}
	var out: Dictionary = ((_weapons.get("families", {}) as Dictionary).get(fam, {}) as Dictionary).duplicate()
	out["id"] = fam
	return out


## 2 for two-handed weapons, 1 for one-handed weapons and off-hands, 0 for the rest.
func hands(base_id: String) -> int:
	return int(weapon_type(base_id).get("hands", 0))


func is_consumable(base_id: String) -> bool:
	return str(base(base_id).get("slot", "")) == "consumable"


## Starter kit of a class: base ids, worn at level 1 and common.
func starter(class_id: String) -> Array:
	return (_weapons.get("starter", {}) as Dictionary).get(class_id, [])


func can_use(class_id: String, base_id: String) -> bool:
	var b := base(base_id)
	if b.is_empty():
		return false
	var slot := str(b.slot)
	if slot in ["neck", "ring", "consumable"]:
		return true
	var rules: Dictionary = (_weapons.get("classes", {}) as Dictionary).get(class_id, {})
	if rules.is_empty():
		return false
	var kind := str(b.get("kind", ""))
	if slot in ARMOR_SLOTS:
		var order: Array = _weapons.get("armor_order", [])
		var max_i := order.find(str(rules.get("armor", "")))
		var i := order.find(kind)
		return i >= 0 and max_i >= 0 and i <= max_i
	return kind in (rules.get("weapons", []) as Array) or kind in (rules.get("offhand", []) as Array)


## Bases that drop at this level (tier containing it); never consumables, uniques or the
## villager's weapon. Optionally only those a class can use, or of one slot.
func bases_for(level: int, class_id: String = "", slot: String = "") -> Array:
	var out: Array = []
	for id: String in _order:
		var b: Dictionary = _bases[id]
		if int(b.get("tier", 0)) < 1 or b.has("unique_of") or b.slot == "consumable":
			continue
		if level < int(b.get("min_level", 1)) or level > int(b.get("max_level", 0)):
			continue
		if class_id != "" and not can_use(class_id, id):
			continue
		if slot != "" and b.slot != slot:
			continue
		out.append(id)
	return out


## The unique base a monster drops, or "".
func unique_for(monster_id: String) -> String:
	for id: String in _order:
		if str(_bases[id].get("unique_of", "")) == monster_id:
			return id
	return ""


static func known_stat(stat: String) -> bool:
	return stat in ATTRIBUTE_STATS or Progression.FLAT.has(stat) or Progression.PERCENT.has(stat)


## Problems in the data, as readable lines (empty when everything is fine).
func validate() -> Array[String]:
	var errors: Array[String] = []
	var classes: Array = (_weapons.get("classes", {}) as Dictionary).keys()
	for id: String in _order:
		var b: Dictionary = _bases[id]
		if not str(b.get("slot", "")) in BASE_SLOTS:
			errors.append("%s: unknown slot %s" % [id, b.get("slot")])
		if str(b.get("name", "")) == "" or TranslationServer.translate(str(b.name)) == str(b.name):
			errors.append("%s: name not translated" % id)
		for s: Variant in b.get("stats", []):
			if not s is Dictionary or not known_stat(str(s.get("stat", ""))):
				errors.append("%s: unknown stat %s" % [id, s])
		if str(b.slot) in ["main", "offhand"] and weapon_type(id).is_empty():
			errors.append("%s: unknown weapon type %s" % [id, b.get("kind")])
		if str(b.slot) == "main" and family_of(id).is_empty():
			errors.append("%s: weapon without family" % id)
		if not classes.any(func(c: String) -> bool: return can_use(c, id)):
			errors.append("%s: no class can use it" % id)
		if b.has("unique_of") and str(b.get("unique_of")) == "":
			errors.append("%s: empty unique_of" % id)
	for id: String in _affixes:
		var a: Dictionary = _affixes[id]
		if not known_stat(str(a.get("stat", ""))):
			errors.append("affix %s: unknown stat %s" % [id, a.get("stat")])
	var stats_seen := {}
	for id: String in _order:
		for s: Variant in _bases[id].get("stats", []):
			if s is Dictionary:
				stats_seen[str(s.stat)] = true
	for id: String in _affixes:
		stats_seen[str(_affixes[id].get("stat", ""))] = true
	for stat: String in stats_seen:
		var key := "STAT_" + stat.to_upper()
		if TranslationServer.translate(key) == key:
			errors.append("text %s missing" % key)
	for c: String in classes:
		for id: String in starter(c):
			if not can_use(c, id):
				errors.append("starter %s: %s not usable" % [c, id])
	return errors
