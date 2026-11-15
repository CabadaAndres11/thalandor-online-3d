class_name Damage
extends RefCounted
## Damage rolls (GDD §4.7 without attributes): (base + coef × power) × variance ×
## multipliers × armor mitigation (physical only), ×crit. Rolls use world.rng in a
## fixed order (dodge, variance, crit) so the host is deterministic.


static func mitigation(armor: float, balance: Balance) -> float:
	if armor <= 0.0:
		return 0.0
	return minf(armor / (armor + balance.armor_k), balance.mitigation_cap)


## spec: {base, coef, kind: "physical"|"magic", can_crit := true}.
## Returns {amount, crit, dodged, absorbed}.
static func roll(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld) -> Dictionary:
	var result := {"amount": 0.0, "crit": false, "dodged": false, "absorbed": 0.0}
	var b := world.balance
	if target.stats.dodge_chance > 0.0 and world.rng.randf() < target.stats.dodge_chance:
		result.dodged = true
		return result
	var physical := str(spec.get("kind", "physical")) == "physical"
	var power := attacker.stats.attack_power if physical else attacker.stats.spell_power
	var amount := float(spec.get("base", 0.0)) + float(spec.get("coef", 0.0)) * power
	amount *= 1.0 + world.rng.randf_range(-b.damage_variance, b.damage_variance)
	if bool(spec.get("can_crit", true)) and world.rng.randf() < attacker.stats.crit_chance:
		result.crit = true
		amount *= b.crit_multiplier
	amount *= attacker.stats.damage_done_mult * target.stats.damage_taken_mult
	if physical:
		amount *= 1.0 - mitigation(target.stats.armor, b)
	result.amount = maxf(amount, 0.0)
	return result


## Shield first, then health; at 0 health the world decides (dead, downed…).
static func apply(target: CombatEntity, result: Dictionary, world: SimWorld) -> void:
	var amount: float = result.amount
	var absorbed := minf(target.shield, amount)
	target.shield -= absorbed
	result.absorbed = absorbed
	target.hp = maxf(target.hp - (amount - absorbed), 0.0)
	if target.hp <= 0.0 and target.is_alive():
		world.on_zero_hp(target)
