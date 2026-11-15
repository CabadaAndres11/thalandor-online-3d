class_name MonsterDB
extends RefCounted
## Monster types from data/monsters/*.json: model, stats, speed, ranges, behavior
## and abilities (ids in data/abilities/monsters.json).

const DIR := "res://data/monsters"

static var _default: MonsterDB

var _types: Dictionary = {}


static func load_default() -> MonsterDB:
	if _default == null:
		_default = MonsterDB.new()
		for f in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
				if d is Dictionary and (d as Dictionary).get("id") is String:
					_default._types[d.id] = d
				else:
					push_error("MonsterDB: bad monster file %s" % f)
	return _default


func get_type(type_id: String) -> Dictionary:
	return _types.get(type_id, {})


func type_ids() -> Array:
	return _types.keys()


## A new monster of `type_id` at `pos`, at full health (before group scaling).
func make(type_id: String, id: int, pos: Vector3, world: SimWorld) -> MonsterState:
	var d := get_type(type_id)
	var m := MonsterState.new()
	m.id = id
	m.type_id = type_id
	m.def = d
	m.position = pos
	m.home = pos
	m.radius = float(d.get("radius", 0.5))
	m.stats = CombatStats.from_dict(d.get("stats", {}))
	m.base_max_hp = m.stats.max_hp
	m.hp = m.stats.max_hp
	m.facing = world.rng.randf_range(-PI, PI)
	return m
