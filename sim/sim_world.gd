class_name SimWorld
extends RefCounted
## Authoritative world: tick counter and player states.

var tick: int = 0
var players: Dictionary = {} # int -> PlayerState
var balance: Balance
var map: CollisionMap


func _init(p_balance: Balance, p_map: CollisionMap) -> void:
	balance = p_balance
	map = p_map


func add_player(id: int, position: Vector3) -> PlayerState:
	var s := PlayerState.new()
	s.id = id
	s.position = position
	s.aim = position
	players[id] = s
	return s


func remove_player(id: int) -> void:
	players.erase(id)


## Advances one tick. `inputs` maps player id -> PlayerInput; players without input stay still.
func step(inputs: Dictionary) -> void:
	for id: int in inputs:
		if players.has(id):
			Movement.apply(players[id], inputs[id], dt(), balance, map)
	tick += 1


func dt() -> float:
	return balance.dt()
