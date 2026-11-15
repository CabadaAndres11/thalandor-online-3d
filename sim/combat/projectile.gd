class_name Projectile
extends RefCounted
## A projectile in flight. Keeps a copy of its owner (team and stats) so it still
## resolves if the owner has left. Positions are world XZ (Vector2).

var id: int = 0
var owner: CombatEntity # snapshot of the caster, see Combat.snapshot_of
var ability_id: String = ""
var pos: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.ZERO
var speed: float = 0.0
var radius: float = 0.2
var remaining: float = 0.0
var pierce: bool = false
var effect: Dictionary = {}
var hit_ids: Dictionary = {}
