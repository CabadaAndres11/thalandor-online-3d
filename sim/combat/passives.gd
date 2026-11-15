class_name Passives
extends RefCounted
## Passive abilities as data: each passive ability lists modifiers in "passive":
##   {"type": "stat", "stat": <name>, "value": v}
##     armor_pct, max_hp_pct, max_resource_pct, move_speed_pct (× (1 + v)), dodge_add (+ v)
##   {"type": "hook", "hook": <name>, ...params}
##     warrior:  rage_decay_mult {mult}, block_generates_rage {amount}, on_crit_heal_pct {pct}
##     cleric:   mana_regen_in_combat {mult}, healing_received_pct {pct}, healing_done_pct {pct},
##               heal_leaves_hot {pct, duration_s, every_s}
##     mage:     spell_power_after_no_damage_s {seconds, pct}, fire_crit_burn {magnitude,
##               duration_s, every_s}, bonus_vs_status {statuses, pct}
##     archer:   range_pct {pct}, bonus_vs_far {distance, pct}, every_nth_basic_crits {n}
##     assassin: back_damage_pct {pct}, stealth_opener_crit_bonus {pct}, after_dodge_combo {combo}
## Hooks are read where their rule lives (Resources, Damage, Combat, Effects, ClassRules).

## Half-angle (degrees) of the cone behind a target that counts as "from behind".
const BACK_HALF_ANGLE := 60.0


## Modifiers of the class's passives unlocked at `level`.
static func collect(db: AbilityDB, class_id: String, level: int) -> Array:
	var out: Array = []
	for a: Dictionary in db.class_abilities(class_id):
		if a.get("kind") == "passive" and int(a.get("level", 1)) <= level:
			for m: Variant in a.get("passive", []):
				if m is Dictionary:
					out.append(m)
	return out


## Sum of the "stat" modifiers by stat name.
static func stat_mods(e: CombatEntity) -> Dictionary:
	var out: Dictionary = {}
	for m: Dictionary in e.passives:
		if m.get("type") == "stat":
			var stat := str(m.get("stat", ""))
			out[stat] = float(out.get(stat, 0.0)) + float(m.get("value", 0.0))
	return out


## Parameters of the hook, or {} when the entity does not have it.
static func has_hook(e: CombatEntity, hook: String) -> Dictionary:
	if e == null:
		return {}
	for m: Dictionary in e.passives:
		if m.get("type") == "hook" and m.get("hook") == hook:
			return m
	return {}


## Applies the stat modifiers (and the healing hooks) to the entity's stats once.
static func apply_stats(e: CombatEntity) -> void:
	var mods := stat_mods(e)
	var s := e.stats
	s.armor *= 1.0 + float(mods.get("armor_pct", 0.0))
	s.max_hp *= 1.0 + float(mods.get("max_hp_pct", 0.0))
	s.max_resource *= 1.0 + float(mods.get("max_resource_pct", 0.0))
	s.move_speed_mult *= 1.0 + float(mods.get("move_speed_pct", 0.0))
	s.dodge_chance += float(mods.get("dodge_add", 0.0))
	s.healing_received_mult *= 1.0 + float(has_hook(e, "healing_received_pct").get("pct", 0.0))
	s.healing_done_mult *= 1.0 + float(has_hook(e, "healing_done_pct").get("pct", 0.0))


## Damage multiplier from the attacker's passives against this target.
static func damage_mult(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld) -> float:
	var mult := 1.0
	var h := has_hook(attacker, "spell_power_after_no_damage_s")
	if not h.is_empty() and str(spec.get("kind", "physical")) == "magic" \
			and world.tick - attacker.last_hurt_tick >= world.ticks(float(h.get("seconds", 3.0))):
		mult *= 1.0 + float(h.get("pct", 0.0))
	h = has_hook(attacker, "bonus_vs_status")
	if not h.is_empty():
		for k: Variant in h.get("statuses", []):
			if target.has_status(str(k)):
				mult *= 1.0 + float(h.get("pct", 0.0))
				break
	h = has_hook(attacker, "bonus_vs_far")
	if not h.is_empty() and Effects.flat(attacker.position).distance_to(Effects.flat(target.position)) >= float(h.get("distance", 10.0)):
		mult *= 1.0 + float(h.get("pct", 0.0))
	h = has_hook(attacker, "back_damage_pct")
	if not h.is_empty() and is_behind(attacker, target):
		mult *= 1.0 + float(h.get("pct", 0.0))
	return mult


## Whether `attacker` stands in the cone behind where `target` looks.
static func is_behind(attacker: CombatEntity, target: CombatEntity) -> bool:
	var to := Effects.flat(attacker.position) - Effects.flat(target.position)
	if to.length() < 0.01:
		return false
	var back := -Effects.forward(target.facing)
	return absf(rad_to_deg(back.angle_to(to.normalized()))) <= BACK_HALF_ANGLE
