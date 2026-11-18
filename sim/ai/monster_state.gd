class_name MonsterState
extends CombatEntity
## A monster: combat entity plus its AI state, home, threat table and path.

enum { IDLE, CHASE, ATTACK, RETURN }

## Type data from data/monsters (speed, ranges, abilities, behavior…).
var def: Dictionary = {}
var home: Vector3 = Vector3.ZERO
var ai: int = IDLE
## player id -> threat; the target is the highest (with a margin, see MonsterAI).
var threat: Dictionary = {}
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var repath_tick: int = 0
var path_goal: Vector2 = Vector2.INF
## Max health before group scaling.
var base_max_hp: float = 0.0
var elite: bool = false
var phase: int = 1
## Spawn point index (Spawner), -1 if none.
var spawn_index: int = -1
var died_tick: int = -1
## Ticks spent unable to find a way to the target (gives up after a while).
var unreachable_ticks: int = 0
## Busy with an ability (a charge's windup and run) until this tick: no AI.
var busy_until: int = 0
## Boss: tick of its next cultist call (0 = as soon as the phase allows) and the
## monsters it called.
var next_summon_tick: int = 0
var minions: Array = []
## Boss: phases whose "phase_abilities" entry it has already cast (cleared at home).
var phase_casts: Array = []
## Id of the monster or player that called this one (0 = none): it gives no experience.
var summoned_by: int = 0
## Allied summons: the tick they vanish (0 = never).
var despawn_tick: int = 0


func _init() -> void:
	team = TEAM_MONSTERS


func speed() -> float:
	return float(def.get("speed", 4.0)) * move_mult()


func add_threat(player_id: int, amount: float) -> void:
	threat[player_id] = float(threat.get(player_id, 0.0)) + maxf(amount, 0.0)
