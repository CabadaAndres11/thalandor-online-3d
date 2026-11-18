class_name AbilityDB
extends RefCounted
## Abilities from data/abilities/*.json (files starting with "_" are test data).
## Each ability is a Dictionary: id, class|monster, name, desc, icon, kind
## (basic|secondary|active|passive), level, cost, cooldown_s, gcd, range, anim,
## threat_mult, effects: [{type, ...}] (see Effects).

const DIR := "res://data/abilities"
const KINDS := ["basic", "secondary", "active", "passive"]

static var _default: AbilityDB

var _by_id: Dictionary = {}
var _order: Array = []


static func load_default() -> AbilityDB:
	if _default == null:
		var paths: Array = []
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".json") and not f.begins_with("_"):
				paths.append(DIR.path_join(f))
		paths.sort()
		_default = load_files(paths)
	return _default


static func load_files(paths: Array) -> AbilityDB:
	var list: Array = []
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if parsed is Array:
			list.append_array(parsed)
		else:
			push_error("AbilityDB: %s is not a JSON array" % path)
	return from_list(list)


static func from_list(list: Array) -> AbilityDB:
	var db := AbilityDB.new()
	for a: Variant in list:
		if a is Dictionary and (a as Dictionary).get("id") is String:
			db._by_id[a.id] = a
			db._order.append(a.id)
	return db


func get_ability(id: String) -> Dictionary:
	return _by_id.get(id, {})


## The ability as a player with this upgrade casts it: the upgrade's evolution of this
## ability ("evolves": {ability, set: {fields}, effects?: [...]}) replaces fields and,
## when given, the effects list.
func resolved(id: String, upgrade: String, upgrades: UpgradeDB = null) -> Dictionary:
	var a := get_ability(id)
	if a.is_empty() or upgrade == "":
		return a
	var u := (upgrades if upgrades != null else UpgradeDB.load_default()).upgrade(upgrade)
	var ev: Dictionary = u.get("evolves", {})
	if str(ev.get("ability", "")) != id:
		return a
	var out := a.duplicate(true)
	var set: Dictionary = ev.get("set", {})
	for k: String in set:
		out[k] = set[k]
	if ev.has("effects"):
		out["effects"] = (ev.effects as Array).duplicate(true)
	return out


func has(id: String) -> bool:
	return _by_id.has(id)


## Abilities of a class (or monster type) in file order.
func class_abilities(owner_id: String) -> Array:
	var out: Array = []
	for id: String in _order:
		var a: Dictionary = _by_id[id]
		if a.get("class", a.get("monster", "")) == owner_id:
			out.append(a)
	return out


const BAR_SIZE := 9


## Id of the class's ability of this kind ("basic" or "secondary"), or "".
func kind_of(class_id: String, kind: String) -> String:
	for a: Dictionary in class_abilities(class_id):
		if a.get("kind") == kind:
			return a.id
	return ""


## Whether an ability applies to a player with this upgrade: abilities of an upgrade
## need it, the rest are always there.
static func upgrade_ok(a: Dictionary, upgrade: String) -> bool:
	var u := str(a.get("upgrade", ""))
	return u == "" or u == upgrade


## Ids of the class's active abilities (those of an upgrade only when it is `upgrade`),
## lowest level first (file order on ties).
func actives(class_id: String, upgrade: String = "") -> Array:
	var list := class_abilities(class_id).filter(func(a: Dictionary) -> bool:
		return a.get("kind") == "active" and upgrade_ok(a, upgrade))
	var indexed: Array = []
	for i in list.size():
		indexed.append([int(list[i].get("level", 1)), i, list[i].id])
	indexed.sort()
	return indexed.map(func(row: Array) -> String: return row[2])


## Active abilities available at `level` (with the player's upgrade), lowest level first.
func unlocked(class_id: String, level: int, upgrade: String = "") -> Array:
	return actives(class_id, upgrade).filter(func(id: String) -> bool: return int(_by_id[id].get("level", 1)) <= level)


## The first BAR_SIZE unlocked actives, padded with "".
func default_bar(class_id: String, level: int = 1, upgrade: String = "") -> Array:
	var bar := unlocked(class_id, level, upgrade).slice(0, BAR_SIZE)
	while bar.size() < BAR_SIZE:
		bar.append("")
	return bar


## A bar sent by a client: exactly BAR_SIZE entries, each one of the actives unlocked
## at `level` (anything else becomes ""), no duplicates. Not an array or empty -> the
## default bar.
func sanitize_bar(class_id: String, bar: Variant, level: int = 1, upgrade: String = "") -> Array:
	if not bar is Array or (bar as Array).is_empty():
		return default_bar(class_id, level, upgrade)
	var allowed := unlocked(class_id, level, upgrade)
	var out: Array = []
	for i in BAR_SIZE:
		var v: Variant = (bar as Array)[i] if i < (bar as Array).size() else ""
		out.append(v if v is String and v in allowed and not v in out else "")
	return out


## Puts the actives unlocked between `old_level` (exclusive) and `new_level` (inclusive)
## in the free slots of the bar, lowest level first. A full bar stays as it is.
func place_unlocked(bar: Array, class_id: String, old_level: int, new_level: int, upgrade: String) -> Array:
	var out := bar.duplicate()
	while out.size() < BAR_SIZE:
		out.append("")
	var fresh := unlocked(class_id, new_level, upgrade).filter(func(id: String) -> bool:
		return int(_by_id[id].get("level", 1)) > old_level and not id in out)
	for id: String in fresh:
		var slot := out.find("")
		if slot < 0 or slot >= BAR_SIZE:
			break
		out[slot] = id
	return out


## Human-readable problems (empty = all good). check_texts: names and descriptions
## must be translated (off for test data).
func validate(check_texts: bool = true) -> Array[String]:
	var errors: Array[String] = []
	for id: String in _order:
		var a: Dictionary = _by_id[id]
		if not a.get("kind") in KINDS:
			errors.append("%s: unknown kind %s" % [id, a.get("kind")])
		var effects: Variant = a.get("effects")
		if a.get("kind") != "passive" and (not effects is Array or (effects as Array).is_empty()):
			errors.append("%s: no effects" % id)
		elif effects is Array:
			for e: Variant in effects:
				if not e is Dictionary or not str((e as Dictionary).get("type", "")) in Effects.TYPES:
					errors.append("%s: unknown effect type %s" % [id, (e as Dictionary).get("type", "?") if e is Dictionary else e])
		if check_texts:
			for key: String in ["name", "desc"]:
				var k := str(a.get(key, ""))
				if k == "" or TranslationServer.translate(k) == k:
					errors.append("%s: text %s '%s' not translated" % [id, key, k])
	return errors
