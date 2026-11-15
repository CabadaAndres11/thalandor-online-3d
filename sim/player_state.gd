class_name PlayerState
extends CombatEntity
## Simulated state of one player. Only movement fields are predicted by the client
## (copy_from/clone); combat values come from the host.

var aim: Vector3 = Vector3.ZERO


func _init() -> void:
	team = TEAM_PLAYERS
	radius = 0.4


func copy_from(other: PlayerState) -> void:
	id = other.id
	position = other.position
	aim = other.aim
	facing = other.facing


func clone() -> PlayerState:
	var c := PlayerState.new()
	c.copy_from(self)
	return c
