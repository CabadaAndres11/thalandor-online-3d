class_name Damage
extends RefCounted
## Damage rolls (GDD §4.7 without attributes): (base + coef × power) × variance ×
## multipliers × armor mitigation (physical only), ×crit. Rolls use world.rng in a
## fixed order (dodge, variance, crit) so the host is deterministic.
## Multipliers: stats, statuses (attacker damage_buff; target mark and
## damage_reduction) and the attacker's passives (Passives.damage_mult).
## spec.force_crit makes the hit critical without rolling (Ráfaga, Emboscada).


## Physical hits from this close (or from a melee arc) can be blocked.
const BLOCK_RANGE := 3.0


## Armor weakens against stronger attackers: K grows with the attacker's level.
static func mitigation(armor: float, balance: Balance, attacker_level: int = 1) -> float:
	if armor <= 0.0:
		return 0.0
	var k := balance.armor_k + balance.armor_k_per_level * float(maxi(attacker_level, 1) - 1)
	return minf(armor / (armor + k), balance.mitigation_cap)


## spec: {base, coef, kind: "physical"|"magic", can_crit := true, force_crit := false}.
## Returns {amount, crit, dodged, absorbed}.
## `melee`: the hit comes from a melee arc (physical melee hits can be blocked).
static func roll(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld, melee: bool = false) -> Dictionary:
	var result := {"amount": 0.0, "crit": false, "dodged": false, "absorbed": 0.0, "blocked": false}
	var b := world.balance
	var dodge := target.stats.dodge_chance + target.status_magnitude("evasion")
	if dodge > 0.0 and world.rng.randf() < dodge:
		result.dodged = true
		return result
	var physical := str(spec.get("kind", "physical")) == "physical"
	# Block: a physical hit from a melee arc or from 3 m or less. Rolled only when the
	# target can block, so characters without it keep the same sequence of random numbers.
	if physical and target.stats.block_chance > 0.0 \
			and (melee or Effects.flat(attacker.position).distance_to(Effects.flat(target.position)) <= BLOCK_RANGE) \
			and world.rng.randf() < target.stats.block_chance:
		result.blocked = true
	var power := attacker.stats.attack_power if physical else attacker.stats.spell_power
	if str(spec.get("power", "")) == "armor":
		power = attacker.stats.armor # the Protector's abilities scale with armour
	var amount := float(spec.get("base", 0.0)) + float(spec.get("coef", 0.0)) * power
	amount *= 1.0 + world.rng.randf_range(-b.damage_variance, b.damage_variance)
	var crit_chance := attacker.stats.crit_chance + Passives.school_crit(attacker, str(spec.get("school", "")))
	if bool(spec.get("can_crit", true)) and (bool(spec.get("force_crit", false)) or world.rng.randf() < crit_chance):
		result.crit = true
		amount *= b.crit_multiplier + attacker.stats.crit_damage
	amount *= attacker.stats.damage_done_mult * target.stats.damage_taken_mult
	amount *= 1.0 + attacker.status_magnitude("damage_buff")
	amount *= 1.0 + target.status_magnitude("mark") + target.status_magnitude("vulnerable")
	amount *= maxf(0.0, 1.0 - attacker.status_magnitude("weaken"))
	var execute: Dictionary = spec.get("execute", {})
	if not execute.is_empty() and target.stats.max_hp > 0.0 and target.hp / target.stats.max_hp < float(execute.get("below_pct", 0.25)):
		amount *= float(execute.get("mult", 1.0))
	amount *= maxf(0.0, 1.0 - target.status_magnitude("damage_reduction"))
	amount *= Passives.damage_mult(attacker, target, spec, world)
	if physical:
		amount *= 1.0 - mitigation(target.stats.armor, b, attacker.level)
	if result.blocked:
		amount *= float(b.attributes.get("block_reduction", 0.5))
	result.amount = maxf(amount, 0.0)
	return result


## Shield first, then health; at 0 health the world decides (dead, downed…).
## Any damage reveals a stealthed target.
static func apply(target: CombatEntity, result: Dictionary, world: SimWorld) -> void:
	var amount: float = result.amount
	var absorbed := minf(target.shield, amount)
	target.shield -= absorbed
	result.absorbed = absorbed
	target.last_hurt_tick = world.tick
	if target.has_status("stealth"):
		target.remove_status("stealth")
		world.emit(["status_end", target.id, "stealth"])
	target.hp = maxf(target.hp - (amount - absorbed), 0.0)
	if target.hp <= 0.0 and target.is_alive() and not _survives(target, world):
		world.on_zero_hp(target)


## Fénix (cheat_death on the target) or Ángel guardián (an ally with the hook in range)
## keep a fatal hit from killing: health goes to hp_pct and the hook starts its recharge.
static func _survives(target: CombatEntity, world: SimWorld) -> bool:
	for h: Dictionary in Passives.hooks(target, "cheat_death"):
		if Passives.hook_ready(target, "cheat_death", world):
			Passives.hook_use(target, "cheat_death", float(h.get("cooldown_s", 180.0)), world)
			target.hp = maxf(1.0, target.stats.max_hp * float(h.get("hp_pct", 0.3)))
			world.emit(["cheat_death", target.id])
			return true
	for o: CombatEntity in world.entities():
		if o == target or o.team != target.team or not o.is_alive():
			continue
		for h: Dictionary in Passives.hooks(o, "guardian_angel"):
			if Effects.flat(o.position).distance_to(Effects.flat(target.position)) <= float(h.get("radius", 20.0)) \
					and Passives.hook_ready(o, "guardian_angel", world):
				Passives.hook_use(o, "guardian_angel", float(h.get("cooldown_s", 120.0)), world)
				target.hp = maxf(1.0, target.stats.max_hp * float(h.get("hp_pct", 0.25)))
				world.emit(["guardian_angel", o.id, target.id])
				return true
	return false
