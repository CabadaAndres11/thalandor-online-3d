class_name Trap
extends RefCounted
## A trap on the ground (Trampa explosiva): arms after a moment and goes off once
## when an enemy steps inside its radius, or fades at the end of its lifetime.
## Keeps a copy of its owner like Projectile.

var id: int = 0
var owner: CombatEntity
var ability_id: String = ""
var pos: Vector3 = Vector3.ZERO
var armed_tick: int = 0
var end_tick: int = 0
var effect: Dictionary = {}
