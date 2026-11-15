class_name SimWorld
extends RefCounted
## Authoritative world: tick counter, players, the seeded random generator and the
## collision map. Only the host runs combat on it.

var tick: int = 0
var players: Dictionary = {} # int -> PlayerState
var balance: Balance
var map: CollisionMap
## The only source of randomness in the simulation (seeded per game).
var rng := RandomNumberGenerator.new()
## Combat events of the current tick (arrays like ["hit", target_id, amount, crit,
## source_id]); the host sends them and clears the list at the start of each tick.
var events: Array = []
var abilities: AbilityDB = AbilityDB.load_default()
## Non-player entities (monsters; test dummies), id -> CombatEntity.
var monsters: Dictionary = {}
var projectiles: Array = [] # Projectile
var pending_areas: Array = [] # PendingArea
var _next_object_id: int = 1


func emit(ev: Array) -> void:
	events.append(ev)


## Ids for projectiles and areas (their own sequence, separate from entity ids).
func next_object_id() -> int:
	_next_object_id += 1
	return _next_object_id


func add_entity(e: CombatEntity) -> void:
	monsters[e.id] = e


func remove_entity(id: int) -> void:
	monsters.erase(id)


func _init(p_balance: Balance, p_map: CollisionMap, p_seed: int = 1) -> void:
	balance = p_balance
	map = p_map
	rng.seed = p_seed


func add_player(id: int, position: Vector3) -> PlayerState:
	var s := PlayerState.new()
	s.id = id
	s.position = position
	s.aim = position
	players[id] = s
	return s


func remove_player(id: int) -> void:
	players.erase(id)


func entities() -> Array:
	return players.values() + monsters.values()


func entity(id: int) -> CombatEntity:
	return players.get(id, monsters.get(id))


## Health reached 0. Later tasks decide between dead, downed and respawn.
func on_zero_hp(e: CombatEntity) -> void:
	Combat.on_zero_hp(self, e)


## Advances one tick. `inputs` maps player id -> PlayerInput; players without input stay still.
func step(inputs: Dictionary) -> void:
	for id: int in inputs:
		if players.has(id):
			var p: PlayerState = players[id]
			if p.forced_ticks > 0:
				continue # an ability is moving this player (Carga, Voltereta…)
			Movement.apply(p, inputs[id], dt(), balance, map, p.move_mult())
			if p.dodge_started:
				p.dodge_started = false
				p.add_status(StatusEffect.make("invulnerable", tick + ticks(balance.dodge_invuln_s)), 1)
	Combat.tick(self)
	tick += 1


func dt() -> float:
	return balance.dt()


## Seconds -> whole simulation ticks (at least 1 for positive times).
func ticks(seconds: float) -> int:
	return balance.ticks(seconds)
