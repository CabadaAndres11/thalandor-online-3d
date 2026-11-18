class_name PlayerInput
extends RefCounted
## One tick of player input. `move` is a world-space XZ direction (x → X, y → Z).
## `buttons` holds action bits: "pressed" bits are edges (this tick only) and are
## never repeated when the host reuses a missing input; "held" bits are states.

const BTN_BASIC := 1
const BTN_BASIC_HELD := 2
const BTN_SECONDARY := 4
const BTN_SLOT1 := 8
const BTN_SLOT2 := 16
const BTN_SLOT3 := 32
const BTN_SLOT4 := 64
const BTN_DODGE := 128
const BTN_INTERACT_HELD := 256
const BTN_SLOT5 := 512
const BTN_SLOT6 := 1024
const BTN_SLOT7 := 2048
const BTN_SLOT8 := 4096
const BTN_SLOT9 := 8192
const SLOT_BITS := [BTN_SLOT1, BTN_SLOT2, BTN_SLOT3, BTN_SLOT4, BTN_SLOT5, BTN_SLOT6, BTN_SLOT7, BTN_SLOT8, BTN_SLOT9]
const HELD_MASK := BTN_BASIC_HELD | BTN_INTERACT_HELD

var seq: int = 0
var move: Vector2 = Vector2.ZERO
var aim: Vector3 = Vector3.ZERO
var buttons: int = 0


func _init(p_seq: int = 0, p_move: Vector2 = Vector2.ZERO, p_aim: Vector3 = Vector3.ZERO, p_buttons: int = 0) -> void:
	seq = p_seq
	move = p_move
	aim = p_aim
	buttons = p_buttons


func duplicate_input() -> PlayerInput:
	return PlayerInput.new(seq, move, aim, buttons)


## The same input with only the held buttons (for when the host repeats it).
func held_only() -> PlayerInput:
	return PlayerInput.new(seq, move, aim, buttons & HELD_MASK)


func pressed(bit: int) -> bool:
	return buttons & bit != 0
