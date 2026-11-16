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


## The upgrades of a class in file order.
func for_class(class_id: String) -> Array:
	var out: Array = []
	for id: String in _order:
		if str(_by_id[id].get("class", "")) == class_id:
			out.append(_by_id[id])
	return out
