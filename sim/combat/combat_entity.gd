class_name CombatEntity
extends RefCounted
## Anything that fights in the simulation: players and monsters. Time is counted in
## simulation ticks. Only the host simulates combat; clients see its results.

enum { TEAM_PLAYERS, TEAM_MONSTERS }
enum { ALIVE, DOWNED, DEAD }

var id: int = 0
## Character or monster level (players: PlayerProgress.level via Progression.rebuild).
var level: int = 1
## Monster type (data/monsters) or "" for players.
var type_id: String = ""
## Who it is attacking (monsters), 0 = nobody.
var target_id: int = 0
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
## Tick when the current shield fades.
var shield_end: int = 0
var life: int = ALIVE
var statuses: Array = [] # StatusEffect
var cooldowns: Dictionary = {} # ability id -> tick when ready
var gcd_end: int = 0
## Last tick this entity dealt or took damage (in combat for balance.in_combat_s).
var last_combat_tick: int = -100000
## Resource rules of its class (see Resources): regen_per_s, decay_per_s…
var resource_def: Dictionary = {}
## Ticks left of a dodge (players, predicted; see Movement).
var dash_ticks: int = 0
## Movement imposed by an ability (Carga, Voltereta…): per-tick velocity (world XZ),
## ticks left, length of the last step and effects applied on arrival.
var forced_ticks: int = 0
var forced_vel: Vector2 = Vector2.ZERO
var forced_last: float = 0.0
var forced_on_arrive: Array = []
## Passive modifiers in effect (see Passives): {"type": "stat"|"hook", ...}.
var passives: Array = []
## Last tick it took damage (Concentración needs time without being hurt).
var last_hurt_tick: int = -100000
## Basic attacks cast so far (Ráfaga: every n-th is a crit).
var basic_count: int = 0


func is_alive() -> bool:
	return life == ALIVE


## Alive and not stunned or frozen.
func can_act(_tick: int) -> bool:
	return is_alive() and not has_status("stun") and not has_status("freeze")


## Movement speed factor from statuses (rooted, stunned or frozen = 0).
func move_mult() -> float:
	if not is_alive() or has_status("stun") or has_status("freeze") or has_status("root"):
		return 0.0
	return stats.move_speed_mult * maxf(0.0, 1.0 - status_magnitude("slow"))


func is_dashing() -> bool:
	return dash_ticks > 0


func in_combat(world: SimWorld) -> bool:
	return world.tick - last_combat_tick < world.ticks(world.balance.in_combat_s)


## Adds a status, or refreshes the existing one of the same kind (duration and
## stacks up to max_stacks; the stronger magnitude wins).
func add_status(s: StatusEffect, max_stacks: int = 1) -> void:
	for existing: StatusEffect in statuses:
		if existing.kind == s.kind:
			existing.end_tick = maxi(existing.end_tick, s.end_tick)
			existing.stacks = mini(existing.stacks + s.stacks, maxi(max_stacks, 1))
			existing.magnitude = maxf(existing.magnitude, s.magnitude)
			existing.source_id = s.source_id
			return
	s.stacks = mini(s.stacks, maxi(max_stacks, 1))
	statuses.append(s)


func has_status(kind: String) -> bool:
	for s: StatusEffect in statuses:
		if s.kind == kind:
			return true
	return false


## Sum of magnitude × stacks of the statuses of this kind (0 if none).
func status_magnitude(kind: String) -> float:
	var total := 0.0
	for s: StatusEffect in statuses:
		if s.kind == kind:
			total += s.magnitude * s.stacks
	return total


func remove_status(kind: String) -> void:
	statuses = statuses.filter(func(s: StatusEffect) -> bool: return s.kind != kind)
