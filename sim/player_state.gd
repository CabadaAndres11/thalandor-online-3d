class_name PlayerState
extends RefCounted
## Simulated state of one player. `facing` is in radians, 0 = +Z, PI/2 = +X.

var id: int = 0
var position: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.ZERO
var facing: float = 0.0


func copy_from(other: PlayerState) -> void:
	id = other.id
	position = other.position
	aim = other.aim
	facing = other.facing


func clone() -> PlayerState:
	var c := PlayerState.new()
	c.copy_from(self)
	return c
