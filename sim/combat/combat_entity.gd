class_name CombatEntity
extends RefCounted
## Anything that fights in the simulation: players and monsters. Time is counted in
## simulation ticks. Only the host simulates combat; clients see its results.

enum { TEAM_PLAYERS, TEAM_MONSTERS }
enum { ALIVE, DOWNED, DEAD }

var id: int = 0
var team: int = TEAM_PLAYERS
var position: Vector3 = Vector3.ZERO
## Radians, 0 = +Z, PI/2 = +X.
var facing: float = 0.0
var radius: float = 0.4
var stats: CombatStats = CombatStats.new()
var hp: float = 0.0
var resource: float = 0.0
## "rage", "mana", "focus", "energy" or "" (monsters).
var resource_kind: String = ""
var shield: float = 0.0
var life: int = ALIVE
var statuses: Array = [] # StatusEffect
var cooldowns: Dictionary = {} # ability id -> tick when ready
var gcd_end: int = 0
## Last tick this entity dealt or took damage (in combat for balance.in_combat_s).
var last_combat_tick: int = -100000


func is_alive() -> bool:
	return life == ALIVE


## Alive and not stunned or frozen (statuses arrive with StatusEffect).
func can_act(_tick: int) -> bool:
	return is_alive()
