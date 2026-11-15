class_name CombatStats
extends RefCounted
## Combat numbers of an entity (class base stats or monster stats; levels and items
## come in later plans). Multipliers default to 1.

var max_hp: float = 100.0
var max_resource: float = 0.0
var attack_power: float = 0.0
var spell_power: float = 0.0
var armor: float = 0.0
var crit_chance: float = 0.05
var dodge_chance: float = 0.0
var move_speed_mult: float = 1.0
var damage_done_mult: float = 1.0
var damage_taken_mult: float = 1.0
var healing_done_mult: float = 1.0
var healing_received_mult: float = 1.0
var threat_mult: float = 1.0

const FIELDS := [
	"max_hp", "max_resource", "attack_power", "spell_power", "armor", "crit_chance",
	"dodge_chance", "move_speed_mult", "damage_done_mult", "damage_taken_mult",
	"healing_done_mult", "healing_received_mult", "threat_mult",
]


static func from_dict(d: Dictionary) -> CombatStats:
	var s := CombatStats.new()
	for f: String in FIELDS:
		var v: Variant = d.get(f)
		if v is int or v is float:
			s.set(f, float(v))
	return s


func duplicate_stats() -> CombatStats:
	var s := CombatStats.new()
	for f: String in FIELDS:
		s.set(f, get(f))
	return s
