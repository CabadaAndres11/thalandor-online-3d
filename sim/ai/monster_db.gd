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
func make(type_id: String, id: int, pos: Vector3, world: SimWorld, level: int = 1) -> MonsterState:
	var d := get_type(type_id)
	var m := MonsterState.new()
	m.id = id
	m.type_id = type_id
	m.def = d
	m.position = pos
	m.home = pos
	m.radius = float(d.get("radius", 0.5))
	apply_level(m, level, world.balance)
	m.facing = world.rng.randf_range(-PI, PI)
	return m


## Sets the monster's level: stats are rebuilt from its type and scaled by
## (1 + factor × (level − 1)) in health, armor and damage; an elite stays elite.
## Health ends full (before group scaling).
static func apply_level(m: MonsterState, level: int, b: Balance) -> void:
	level = maxi(1, level)
	var sc := b.monster_scaling
	var steps := float(level - 1)
	m.level = level
	m.stats = CombatStats.from_dict(m.def.get("stats", {}))
	m.stats.max_hp *= 1.0 + float(sc.get("hp", 0.0)) * steps
	m.stats.armor *= 1.0 + float(sc.get("armor", 0.0)) * steps
	m.stats.damage_done_mult *= 1.0 + float(sc.get("damage", 0.0)) * steps
	if m.elite:
		m.stats.max_hp *= b.elite_hp_mult
		m.stats.damage_done_mult *= b.elite_damage_mult
	m.base_max_hp = m.stats.max_hp
	m.hp = m.stats.max_hp


## Turns a fresh monster into its elite version (bigger, tougher, hits harder).
static func make_elite(m: MonsterState, b: Balance) -> void:
	if m.elite:
		return
	m.elite = true
	m.base_max_hp *= b.elite_hp_mult
	m.stats.max_hp *= b.elite_hp_mult
	m.hp = m.stats.max_hp
	m.radius *= b.elite_scale
	m.stats.damage_done_mult *= b.elite_damage_mult
