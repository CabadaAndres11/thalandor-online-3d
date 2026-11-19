class_name PlayerState
extends CombatEntity
## Simulated state of one player. Only movement fields are predicted by the client
## (copy_from/clone); combat values come from the host.

var aim: Vector3 = Vector3.ZERO
## True while an effect keeps the character facing where it is (Bloque de hielo): the cursor
## moves but the body does not turn. Set before Movement.apply, on the host and the client.
var lock_facing: bool = false
## Dodge (predicted): direction, and the input sequence from which it is ready again.
var dash_dir: Vector2 = Vector2.ZERO
var dodge_ready_seq: int = 0
## Set by Movement when a dodge starts; the host turns it into brief invulnerability.
var dodge_started: bool = false
## Class (data/characters/classes.json) and its per-player combat state.
var class_id: String = ""
var combo: int = 0
## Tick when the archer started charging the basic shot (-1 = not charging).
var charge_start: int = -1
## Tick when a dead player reappears at the map's respawn point (-1 = not dead).
var respawn_tick: int = -1
## Experience, attributes, talents… (see PlayerProgress); progress_dirty asks the host to send it.
var progress := PlayerProgress.new()
var progress_dirty: bool = false
## Gold, bag and equipment (see Inventory); inventory_dirty asks the host to send it.
var inventory := Inventory.new()
var inventory_dirty: bool = false
## Tick from which a potion can be drunk again (shared by health and resource potions).
var potion_ready_tick: int = 0
## What the merchant offers this player and when it was rolled (-1 = never), see Merchant.
var merchant_stock: Array = []
var merchant_tick: int = -1
## Evasión mortal: the next combo gain is raised after a dodge.
var bonus_combo_ready: bool = false
## Conditional passive buffs on at the last tick (Passives.CONDITIONAL keys), to send changes only.
var buffs_on: Array = []
## Downed (in a group): the tick it bleeds out and dies if nobody revives it.
var downed_end_tick: int = -1
## Reviving an ally with E: who, since when and from where (moving cancels).
var revive_target_id: int = 0
var revive_start_tick: int = 0
var revive_from: Vector3 = Vector3.ZERO


func _init() -> void:
	team = TEAM_PLAYERS
	radius = 0.4


func copy_from(other: PlayerState) -> void:
	id = other.id
	position = other.position
	aim = other.aim
	facing = other.facing
	dash_ticks = other.dash_ticks
	dash_dir = other.dash_dir
	dodge_ready_seq = other.dodge_ready_seq


func clone() -> PlayerState:
	var c := PlayerState.new()
	c.copy_from(self)
	return c
