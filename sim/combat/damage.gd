class_name Damage
extends RefCounted
## Damage rolls (GDD §4.7 without attributes): (base + coef × power) × variance ×
## multipliers × armor mitigation (physical only), ×crit. Rolls use world.rng in a
## fixed order (dodge, variance, crit) so the host is deterministic.
## Multipliers: stats, statuses (attacker damage_buff; target mark and
## damage_reduction) and the attacker's passives (Passives.damage_mult).
## spec.force_crit makes the hit critical without rolling (Ráfaga, Emboscada).


static func mitigation(armor: float, balance: Balance) -> float:
	if armor <= 0.0:
		return 0.0
	return minf(armor / (armor + balance.armor_k), balance.mitigation_cap)


## spec: {base, coef, kind: "physical"|"magic", can_crit := true, force_crit := false}.
## Returns {amount, crit, dodged, absorbed}.
static func roll(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld) -> Dictionary:
	var result := {"amount": 0.0, "crit": false, "dodged": false, "absorbed": 0.0}
	var b := world.balance
	var dodge := target.stats.dodge_chance + target.status_magnitude("evasion")
	if dodge > 0.0 and world.rng.randf() < dodge:
		result.dodged = true
		return result
	var physical := str(spec.get("kind", "physical")) == "physical"
	var power := attacker.stats.attack_power if physical else attacker.stats.spell_power
	var amount := float(spec.get("base", 0.0)) + float(spec.get("coef", 0.0)) * power
	amount *= 1.0 + world.rng.randf_range(-b.damage_variance, b.damage_variance)
	if bool(spec.get("can_crit", true)) and (bool(spec.get("force_crit", false)) or world.rng.randf() < attacker.stats.crit_chance):
		result.crit = true
		amount *= b.crit_multiplier
	amount *= attacker.stats.damage_done_mult * target.stats.damage_taken_mult
	amount *= 1.0 + attacker.status_magnitude("damage_buff")
	amount *= 1.0 + target.status_magnitude("mark")
	amount *= maxf(0.0, 1.0 - target.status_magnitude("damage_reduction"))
	amount *= Passives.damage_mult(attacker, target, spec, world)
	if physical:
		amount *= 1.0 - mitigation(target.stats.armor, b)
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
	if target.hp <= 0.0 and target.is_alive():
		world.on_zero_hp(target)
