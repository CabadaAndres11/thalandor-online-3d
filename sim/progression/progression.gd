class_name Progression
extends RefCounted
## The single place that computes the final stats of a player from class, level,
## attributes and modifiers (passives now; talents, masteries and upgrade later).

## Stat modifiers added to a plain number with "<name>_add" ...
const FLAT := {
	"armor_add": "armor", "max_hp_add": "max_hp", "hp_regen_add": "hp_regen", "dodge_add": "dodge_chance",
	"crit_add": "crit_chance", "block_add": "block_chance", "crit_damage_add": "crit_damage",
	"lifesteal_add": "lifesteal", "cooldown_reduction_add": "cooldown_reduction",
	"attack_power_add": "attack_power", "spell_power_add": "spell_power", "max_resource_add": "max_resource",
}
## ... and stats scaled by (1 + sum of the values) with "<name>_pct".
const PERCENT := {
	"armor_pct": "armor", "max_hp_pct": "max_hp", "max_resource_pct": "max_resource",
	"move_speed_pct": "move_speed_mult", "attack_power_pct": "attack_power", "spell_power_pct": "spell_power",
	"damage_done_pct": "damage_done_mult", "damage_taken_pct": "damage_taken_mult",
	"healing_done_pct": "healing_done_mult", "healing_received_pct": "healing_received_mult",
	"threat_pct": "threat_mult", "resource_regen_pct": "resource_regen_mult",
}


## The stats a character with this class and progress has (for windows: the client has no
## PlayerState of its own to read them from). Same numbers the host computes.
static func preview_stats(class_id: String, progress: PlayerProgress, b: Balance) -> CombatStats:
	var p := PlayerState.new()
	p.class_id = class_id
	p.progress = progress
	rebuild(p, null, true, b)
	return p.stats


## Modifiers in effect for the player: stat and hook entries.
static func modifiers(p: PlayerState, world: SimWorld) -> Array:
	var db := world.abilities if world != null else AbilityDB.load_default()
	var b := world.balance if world != null else Balance.load_from()
	var out := Passives.collect(db, p.class_id, p.progress.level, p.progress.upgrade)
	out.append_array(Talents.mods(p.progress, TalentDB.load_default(), b))
	return out


## Recomputes stats and passives from class, level, attributes and modifiers. Keeps the
## health and resource percentages and touches no statuses, cooldowns or position.
## `fresh`: a new character or a new class, which starts full (resource at its start).
static func rebuild(p: PlayerState, world: SimWorld, fresh: bool = false, balance: Balance = null) -> void:
	var b := balance if balance != null else (world.balance if world != null else Balance.load_from())
	var def := CharacterCatalog.load_default().class_def(p.class_id)
	p.level = p.progress.level
	if def.is_empty():
		return # a test dummy or a player without a class: nothing to build from
	var hp_ratio := p.hp / maxf(p.stats.max_hp, 1.0)
	var res_ratio := p.resource / p.stats.max_resource if p.stats.max_resource > 0.0 else 0.0
	var res: Dictionary = def.get("resource", {})
	var base: Dictionary = (def.get("stats", {}) as Dictionary).duplicate()
	base["max_resource"] = res.get("max", 0)
	var s := CombatStats.from_dict(base)
	p.level = p.progress.level
	p.resource_kind = str(res.get("kind", ""))
	p.resource_def = res.duplicate()
	# Attributes.
	var t := Attributes.totals(p.progress, def, b)
	var ab := b.attributes
	var attack_attr := str(def.get("attack_attribute", "strength"))
	s.attack_power += Attributes.effective(int(t.get(attack_attr, 0)), b) * float(ab.get("attack_power", 0.0))
	s.spell_power += Attributes.effective(int(t.intellect), b) * float(ab.get("spell_power", 0.0))
	s.max_hp += Attributes.effective(int(t.stamina), b) * float(ab.get("max_hp", 0.0))
	if p.resource_kind == "mana":
		s.max_resource += Attributes.effective(int(t.intellect), b) * float(ab.get("max_mana", 0.0))
		s.resource_regen_add += Attributes.effective(int(t.spirit), b) * float(ab.get("mana_regen", 0.0))
	s.crit_chance += Attributes.effective(int(t.agility), b) * float(ab.get("crit", 0.0))
	s.dodge_chance += Attributes.effective(int(t.agility), b) * float(ab.get("dodge", 0.0))
	s.block_chance += Attributes.effective(int(t.strength), b) * float(ab.get("block", 0.0))
	s.hp_regen += Attributes.effective(int(t.spirit), b) * float(ab.get("hp_regen", 0.0))
	# Modifiers: flat ones first, then the percentages of each stat added together.
	var mods := modifiers(p, world)
	var pct: Dictionary = {}
	for m: Variant in mods:
		if not m is Dictionary or m.get("type") != "stat":
			continue
		var stat := str(m.get("stat", ""))
		var v := float(m.get("value", 0.0))
		if FLAT.has(stat):
			s.set(FLAT[stat], float(s.get(FLAT[stat])) + v)
		elif PERCENT.has(stat):
			pct[stat] = float(pct.get(stat, 0.0)) + v
	for stat: String in pct:
		var field: String = PERCENT[stat]
		s.set(field, float(s.get(field)) * (1.0 + float(pct[stat])))
	# Caps.
	s.crit_chance = minf(s.crit_chance, float(ab.get("crit_cap", 1.0)))
	s.dodge_chance = minf(s.dodge_chance, float(ab.get("dodge_cap", 1.0)))
	s.block_chance = minf(s.block_chance, float(ab.get("block_cap", 1.0)))
	s.cooldown_reduction = clampf(s.cooldown_reduction, 0.0, float(ab.get("cooldown_cap", 1.0)))
	p.stats = s
	p.passives = mods
	if fresh:
		p.hp = s.max_hp
		p.resource = minf(float(res.get("start", res.get("max", 0))), s.max_resource)
	else:
		p.hp = s.max_hp * hp_ratio
		p.resource = s.max_resource * res_ratio
