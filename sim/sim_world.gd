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
	return players.values()


func entity(id: int) -> CombatEntity:
	return players.get(id)


## Health reached 0. Later tasks decide between dead, downed and respawn.
func on_zero_hp(e: CombatEntity) -> void:
	e.life = CombatEntity.DEAD


## Advances one tick. `inputs` maps player id -> PlayerInput; players without input stay still.
func step(inputs: Dictionary) -> void:
	for id: int in inputs:
		if players.has(id):
			Movement.apply(players[id], inputs[id], dt(), balance, map)
	tick += 1


func dt() -> float:
	return balance.dt()


## Seconds -> whole simulation ticks (at least 1 for positive times).
func ticks(seconds: float) -> int:
	return 0 if seconds <= 0.0 else maxi(1, roundi(seconds * balance.tick_rate))
