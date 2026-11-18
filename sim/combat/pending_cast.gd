class_name PendingCast
extends RefCounted
## An ability with a "repeat" block that is still hitting: the caster, the ability as it
## was shaped when cast, where it was aimed, how many hits are left and when the next
## one lands. A channelled one is cut if the caster moves or dodges.

var caster_id: int = 0
var ability: Dictionary = {}
var aim: Vector3 = Vector3.ZERO
var left: int = 1
var next_tick: int = 0
var interval: int = 0
var channel: bool = false
## Where the caster stood when it started (a channel breaks if they move away).
var origin: Vector2 = Vector2.ZERO
## Hits that landed so far (combo points are counted once at the end).
var hits: int = 0
