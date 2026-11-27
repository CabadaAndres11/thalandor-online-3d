class_name Passives
extends RefCounted
## Passive abilities as data: each passive ability lists modifiers in "passive":
##   {"type": "stat", "stat": <name>, "value": v}
##     the "<name>_add" and "<name>_pct" stats listed in Progression (applied by Progression.rebuild)
##   {"type": "hook", "hook": <name>, ...params}
##     warrior:  rage_decay_mult {mult}, block_generates_rage {amount}, on_crit_heal_pct {pct}
##     cleric:   mana_regen_in_combat {mult},
##               heal_leaves_hot {pct, duration_s, every_s}
##     mage:     spell_power_after_no_damage_s {seconds, pct}, fire_crit_burn {magnitude,
##               duration_s, every_s}, bonus_vs_status {statuses, pct}
##     archer:   range_pct {pct}, bonus_vs_far {distance, pct}, every_nth_basic_crits {n}
##     assassin: back_damage_pct {pct}, stealth_opener_crit_bonus {pct}, after_dodge_combo {combo}
##   upgrades: damage_per_missing_hp {max_pct}, on_kill {reset_cooldown?, heal_pct?}, low_hp_guard
##               {below_pct, reduction, duration_s, cooldown_s}, cheat_death {hp_pct, cooldown_s},
##               guardian_angel {radius, hp_pct, cooldown_s}, melee_hit_restores {amount},
##               stacking_school_damage {school, pct, max, duration_s}, school_crit {school, add},
##               slow_adds_attack_slow {pct}, freeze_reduces_cooldowns {seconds, max?}, stationary_damage
##               {seconds, pct}, traps_rearm {times}, bonus_vs_low_hp {below_pct, pct},
##               stealth_duration_pct {pct}, poison_max_stacks {max}, poisoned_deal_less {pct},
##               finisher_refund_per_combo {amount}, poison_spreads_on_death {radius}. (poison spreading on death is the "contagion"
##               status: its magnitude is the radius in meters.) Internal recharges live in
##               entity.cooldowns["hook:<name>"].
## Hooks are read where their rule lives (Resources, Damage, Combat, Effects, ClassRules).

## Conditional buffs a player's passives grant right now (not always on): they show as tiles.
## Key -> the hook that grants it; the key doubles as the status text id (STATUS_<KEY>).
const CONDITIONAL := {
	"focus": "spell_power_after_no_damage_s", # Concentración: some seconds without being hit
	"steady": "stationary_damage", # standing still
	"combat_regen": "mana_regen_in_combat", # in combat
}


## Keys of the conditional buffs that are on for this entity at this tick.
static func active_buffs(e: CombatEntity, world: SimWorld) -> Array:
	var out: Array = []
	var h := has_hook(e, "spell_power_after_no_damage_s")
	if not h.is_empty() and world.tick - e.last_hurt_tick >= world.ticks(float(h.get("seconds", 3.0))):
		out.append("focus")
	for sh: Dictionary in hooks(e, "stationary_damage"):
		if world.tick - e.still_since >= world.ticks(float(sh.get("seconds", 1.5))):
			out.append("steady")
			break
	if not has_hook(e, "mana_regen_in_combat").is_empty() and e.in_combat(world):
		out.append("combat_regen")
	return out


## Half-angle (degrees) of the cone behind a target that counts as "from behind".
const BACK_HALF_ANGLE := 60.0


## Modifiers of the class passives unlocked at `level` (those of an upgrade only with it).
static func collect(db: AbilityDB, class_id: String, level: int, upgrade: String = "") -> Array:
	var out: Array = []
	for a: Dictionary in db.class_abilities(class_id):
		if a.get("kind") == "passive" and int(a.get("level", 1)) <= level and AbilityDB.upgrade_ok(a, upgrade) 				and (AbilityDB.is_variant(a) or db.variant_for(str(a.id), upgrade).is_empty()):
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


## Every hook with this name (several sources can grant the same one).
static func hooks(e: CombatEntity, hook: String) -> Array:
	var out: Array = []
	if e == null:
		return out
	for m: Dictionary in e.passives:
		if m.get("type") == "hook" and m.get("hook") == hook:
			out.append(m)
	return out


## Damage multiplier from the attacker's passives against this target.
static func damage_mult(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld) -> float:
	var mult := 1.0
	var h := has_hook(attacker, "spell_power_after_no_damage_s")
	if not h.is_empty() and str(spec.get("kind", "physical")) == "magic" \
			and world.tick - attacker.last_hurt_tick >= world.ticks(float(h.get("seconds", 3.0))):
		mult *= 1.0 + float(h.get("pct", 0.0))
	for bh: Dictionary in hooks(attacker, "bonus_vs_status"):
		for k: Variant in bh.get("statuses", []):
			if target.has_status(str(k)):
				mult *= 1.0 + float(bh.get("pct", 0.0))
				break
	h = has_hook(attacker, "bonus_vs_far")
	if not h.is_empty() and Effects.flat(attacker.position).distance_to(Effects.flat(target.position)) >= float(h.get("distance", 10.0)):
		mult *= 1.0 + float(h.get("pct", 0.0))
	h = has_hook(attacker, "back_damage_pct")
	if not h.is_empty() and is_behind(attacker, target):
		mult *= 1.0 + float(h.get("pct", 0.0))
	# Upgrade hooks.
	for lh: Dictionary in hooks(attacker, "bonus_vs_low_hp"):
		if target.stats.max_hp > 0.0 and target.hp / target.stats.max_hp < float(lh.get("below_pct", 0.3)):
			mult *= 1.0 + float(lh.get("pct", 0.0))
	for sh: Dictionary in hooks(attacker, "stationary_damage"):
		if world.tick - attacker.still_since >= world.ticks(float(sh.get("seconds", 1.5))):
			mult *= 1.0 + float(sh.get("pct", 0.0))
	for mh: Dictionary in hooks(attacker, "damage_per_missing_hp"):
		if attacker.stats.max_hp > 0.0:
			mult *= 1.0 + float(mh.get("max_pct", 0.0)) * (1.0 - clampf(attacker.hp / attacker.stats.max_hp, 0.0, 1.0))
	var school := str(spec.get("school", ""))
	if school != "":
		for st: Dictionary in hooks(attacker, "stacking_school_damage"):
			if str(st.get("school", "")) == school:
				var holder := world.entity(attacker.id) if world.entity(attacker.id) != null else attacker # projectiles carry a snapshot: stacks live on the caster
				mult *= 1.0 + float(st.get("pct", 0.0)) * holder.status_stacks("stack_" + school)
	return mult


## Crit chance added by school_crit hooks for a damage of this school.
static func school_crit(attacker: CombatEntity, school: String) -> float:
	var add := 0.0
	if school == "":
		return add
	for h: Dictionary in hooks(attacker, "school_crit"):
		if str(h.get("school", "")) == school:
			add += float(h.get("add", 0.0))
	return add


## Internal recharge of a hook ("hook:<name>" in the entity cooldowns): true when ready.
static func hook_ready(e: CombatEntity, name: String, world: SimWorld) -> bool:
	return world.tick >= int(e.cooldowns.get("hook:" + name, 0))


static func hook_use(e: CombatEntity, name: String, cooldown_s: float, world: SimWorld) -> void:
	e.cooldowns["hook:" + name] = world.tick + world.ticks(cooldown_s)


## Whether `attacker` stands in the cone behind where `target` looks.
static func is_behind(attacker: CombatEntity, target: CombatEntity) -> bool:
	var to := Effects.flat(attacker.position) - Effects.flat(target.position)
	if to.length() < 0.01:
		return false
	var back := -Effects.forward(target.facing)
	return absf(rad_to_deg(back.angle_to(to.normalized()))) <= BACK_HALF_ANGLE
