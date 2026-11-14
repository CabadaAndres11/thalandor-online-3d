class_name PlayerInput
extends RefCounted
## One tick of player input. `move` is a world-space XZ direction (x → X, y → Z).

var seq: int = 0
var move: Vector2 = Vector2.ZERO
var aim: Vector3 = Vector3.ZERO


func _init(p_seq: int = 0, p_move: Vector2 = Vector2.ZERO, p_aim: Vector3 = Vector3.ZERO) -> void:
	seq = p_seq
	move = p_move
	aim = p_aim


func duplicate_input() -> PlayerInput:
	return PlayerInput.new(seq, move, aim)
