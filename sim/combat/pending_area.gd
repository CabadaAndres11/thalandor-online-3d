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
