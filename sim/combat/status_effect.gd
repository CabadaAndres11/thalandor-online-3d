class_name StatusEffect
extends RefCounted
## A timed effect on an entity. Periodic ones (poison, burn, hot) act every
## `tick_every` ticks with magnitude × stacks.
## Kinds: stun, root, freeze, slow, poison, burn, mark, damage_buff,
## damage_reduction, evasion, taunted, stealth, invulnerable, hot, envenom, bleed, haste (recharges
## x (1 - magnitude)), vulnerable (+damage taken), attack_slow (monsters: recharges x (1 + magnitude)),
## speed_buff (+movement speed), weaken (-damage done), ice_block (invulnerable and cannot act), contagion (its poison spreads
## on death, magnitude = radius), armor_break (its armour counts magnitude less).

const NEGATIVE := ["stun", "root", "freeze", "slow", "poison", "burn", "mark", "taunted", "bleed", "vulnerable", "attack_slow", "weaken", "armor_break"]

var kind: String = ""
var end_tick: int = 0
var stacks: int = 1
var magnitude: float = 0.0
var source_id: int = 0
var tick_every: int = 0
var next_tick: int = 0
## envenom: the status the bearer's hits apply (a status entry from the data).
var on_hit: Dictionary = {}


static func make(p_kind: String, p_end_tick: int, p_magnitude: float = 0.0, p_source_id: int = 0,
		p_stacks: int = 1, p_tick_every: int = 0) -> StatusEffect:
	var s := StatusEffect.new()
	s.kind = p_kind
	s.end_tick = p_end_tick
	s.magnitude = p_magnitude
	s.source_id = p_source_id
	s.stacks = p_stacks
	s.tick_every = p_tick_every
	return s


func is_negative() -> bool:
	return kind in NEGATIVE


## Expires statuses and applies periodic damage or healing for this tick.
static func tick_entity(e: CombatEntity, world: SimWorld) -> void:
	var kept: Array = []
	for s: StatusEffect in e.statuses:
		if world.tick >= s.end_tick:
			continue
		if s.tick_every > 0:
			if s.next_tick == 0:
				s.next_tick = world.tick + s.tick_every
			elif world.tick >= s.next_tick:
				s.next_tick += s.tick_every
				_periodic(e, s, world)
		kept.append(s)
	e.statuses = kept


static func _periodic(e: CombatEntity, s: StatusEffect, world: SimWorld) -> void:
	if not e.is_alive() or e.has_status("in_scene"):
		return
	var amount := s.magnitude * s.stacks
	match s.kind:
		"poison", "burn", "bleed":
			var r := {"amount": amount, "crit": false, "dodged": false, "absorbed": 0.0}
			world.current_source = s.source_id
			Damage.apply(e, r, world)
			world.emit(["hit", e.id, amount, false, s.source_id])
		"hot":
			var healed := minf(amount, e.stats.max_hp - e.hp)
			e.hp += healed
			if healed > 0.0:
				world.emit(["heal", e.id, healed])
				Combat.heal_threat(world, world.entity(s.source_id), e, healed)


## Order of the status bits sent in snapshots (for icons and stealth on clients).
const BIT_KINDS := ["stun", "root", "freeze", "slow", "poison", "burn", "mark", "damage_buff",
	"damage_reduction", "evasion", "taunted", "stealth", "invulnerable", "hot", "bleed", "haste", "vulnerable", "attack_slow", "weaken", "ice_block", "armor_break", "in_scene"]


static func bits_of(e: CombatEntity) -> int:
	var bits := 0
	for s: StatusEffect in e.statuses:
		var i := BIT_KINDS.find(s.kind)
		if i >= 0:
			bits |= 1 << i
	return bits


static func has_bit(bits: int, kind: String) -> bool:
	var i := BIT_KINDS.find(kind)
	return i >= 0 and bits & (1 << i) != 0
