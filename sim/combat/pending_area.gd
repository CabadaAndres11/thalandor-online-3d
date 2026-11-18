class_name PendingArea
extends RefCounted
## An area effect waiting to go off (delay and optional pulses), e.g. Explosión
## arcana or a boss jump. Keeps a copy of its owner like Projectile.

var id: int = 0
var owner: CombatEntity
var ability_id: String = ""
var pos: Vector3 = Vector3.ZERO
var fire_tick: int = 0
var pulses_left: int = 1
var interval: int = 0
var effect: Dictionary = {}
## Line areas (a charge): the far end of the line; pos is where it starts.
var end: Vector3 = Vector3.ZERO
## Areas that follow their caster (Himno): the caster id (0 = stays put).
var follow_id: int = 0
## Wall areas (a line of fire): direction along the wall, its length and width (0 = round area).
var wall_dir: Vector2 = Vector2.ZERO
var wall_len: float = 0.0
var wall_w: float = 0.0
