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
