class_name UpgradeDB
extends RefCounted
## Class upgrades chosen at level 50 (data/upgrades/<class>.json, each a list of
## {id, class, name, desc, actives, passives, evolves, look?}).

const DIR := "res://data/upgrades"

static var _default: UpgradeDB

var _by_id: Dictionary = {}
var _order: Array = []


static func load_default() -> UpgradeDB:
	if _default == null:
		var list: Array = []
		for f: String in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
				if parsed is Array:
					list.append_array(parsed)
				else:
					push_error("UpgradeDB: %s is not a JSON array" % f)
		_default = from_list(list)
	return _default


static func from_list(list: Array) -> UpgradeDB:
	var db := UpgradeDB.new()
	for u: Variant in list:
		if u is Dictionary and (u as Dictionary).get("id") is String:
			db._by_id[u.id] = u
			db._order.append(u.id)
	return db


func has(id: String) -> bool:
	return _by_id.has(id)


func upgrade(id: String) -> Dictionary:
	return _by_id.get(id, {})


## Human-readable problems (empty = all good): the ids it names must exist and belong to
## the class, an evolution must point at an ability of the class, and every upgrade has
## texts. `check_complete`: also 2 actives, 2 passives and an evolution each.
func validate(abilities: AbilityDB, check_complete: bool = false) -> Array[String]:
	var errors: Array[String] = []
	for id: String in _order:
		var u: Dictionary = _by_id[id]
		var cls := str(u.get("class", ""))
		for key: String in ["name", "desc"]:
			var k := str(u.get(key, ""))
			if k == "" or TranslationServer.translate(k) == k:
				errors.append("%s: text %s '%s' not translated" % [id, key, k])
		for kind: String in ["actives", "passives"]:
			var list: Array = u.get(kind, [])
			if check_complete and list.size() != 2:
				errors.append("%s: needs 2 %s, has %d" % [id, kind, list.size()])
			for aid: Variant in list:
				var a := abilities.get_ability(str(aid))
				if a.is_empty():
					errors.append("%s: %s '%s' does not exist" % [id, kind, aid])
				elif str(a.get("class", "")) != cls or str(a.get("upgrade", "")) != id or int(a.get("level", 0)) != 50:
					errors.append("%s: %s must be class %s, upgrade %s, level 50" % [id, aid, cls, id])
		var ev: Dictionary = u.get("evolves", {})
		if check_complete and ev.is_empty():
			errors.append("%s: no evolution" % id)
		if not ev.is_empty():
			var target := abilities.get_ability(str(ev.get("ability", "")))
			if target.is_empty() or str(target.get("class", "")) != cls:
				errors.append("%s: evolves unknown ability '%s'" % [id, ev.get("ability", "")])
	return errors


## The upgrades of a class in file order.
func for_class(class_id: String) -> Array:
	var out: Array = []
	for id: String in _order:
		if str(_by_id[id].get("class", "")) == class_id:
			out.append(_by_id[id])
	return out
