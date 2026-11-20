class_name AbilityDetails
extends RefCounted
## The computed details shown under an ability's written description (ventana K):
## damage formula (base + % of power) and its result with the character's stats, who
## it reaches, healing, shields, statuses with their numbers, combo and charge rules,
## crit, cost, cooldown, global cooldown and range. Passives: their level and stat.
## Everything comes from data/abilities and data/balance.json; words from textos.csv.

const RESOURCE_KEYS := {"rage": "DETAIL_RES_RAGE", "mana": "DETAIL_RES_MANA", "focus": "DETAIL_RES_FOCUS",
	"energy": "DETAIL_RES_ENERGY"}
const STAT_KEYS := {"armor_pct": "DETAIL_STAT_ARMOR_PCT", "dodge_add": "DETAIL_STAT_DODGE_ADD",
	"max_resource_pct": "DETAIL_STAT_MAX_RESOURCE_PCT"}

static var _balance: Balance


static func lines(ability: Dictionary, stats: CombatStats, resource_kind: String) -> PackedStringArray:
	var out := PackedStringArray()
	if ability.get("kind") == "passive":
		out.append(TranslationServer.translate("DETAIL_PASSIVE_LEVEL") % int(ability.get("level", 1)))
		for m: Dictionary in ability.get("passive", []):
			if m.get("type") == "stat" and STAT_KEYS.has(str(m.get("stat"))):
				out.append(_tr(STAT_KEYS[m.stat]) % ("+" + pct(float(m.get("value", 0.0)))))
		return out
	var has_damage := false
	for e: Dictionary in ability.get("effects", []):
		has_damage = _effect(e, stats, out) or has_damage
	if bool(ability.get("finisher", false)):
		out.append(_tr("DETAIL_FINISHER"))
	if int(ability.get("combo_gain", 0)) > 0:
		out.append(_tr("DETAIL_COMBO_GAIN") % int(ability.combo_gain))
	if int(ability.get("combo_per_hit", 0)) > 0:
		out.append(_tr("DETAIL_COMBO_PER_HIT") % int(ability.combo_per_hit))
	if ability.has("repeat") and bool(ability.repeat.get("cast", false)):
		out.append(_tr("DETAIL_CAST") % num(ability.repeat.get("delay_s", 0)))
	elif ability.has("repeat"):
		out.append(_tr("DETAIL_REPEAT") % [int(ability.repeat.get("times", 1)), num(ability.repeat.get("interval_s", 0))])
	var charge: Dictionary = ability.get("charge", {})
	if not charge.is_empty() and float(charge.get("cost", 0)) <= 0.0: # a free charge says nothing of a cost
		out.append(_tr("DETAIL_CHARGE_FREE") % [num(charge.get("max_s", 1.5)), num(charge.get("damage_mult", 1.0)), num(charge.get("range_mult", 1.0))])
	elif not charge.is_empty():
		out.append(_tr("DETAIL_CHARGE") % [num(charge.get("max_s", 1.5)), num(charge.get("damage_mult", 1.0)),
			num(charge.get("range_mult", 1.0)), num(charge.get("cost", 0)), _resource(resource_kind)])
	if has_damage:
		var b := _bal()
		out.append(_tr("DETAIL_CRIT") % [pct(stats.crit_chance), num(b.crit_multiplier), pct(b.damage_variance)])
	out.append(_footer(ability, resource_kind))
	for i in out.size():
		out[i] = out[i].left(1).to_upper() + out[i].substr(1) # status-only lines start in lowercase
	return out


# --- Effects ------------------------------------------------------------------------

## Appends the lines of one effect; true when it deals damage.
static func _effect(e: Dictionary, stats: CombatStats, out: PackedStringArray) -> bool:
	var dmg: Dictionary = e.get("damage", {})
	var scope := ""
	match str(e.get("type", "")):
		"melee_arc":
			scope = _tr("DETAIL_SCOPE_ARC") % [num(e.get("angle_deg", 90)), num(e.get("range", 2))]
		"projectile":
			scope = _tr("DETAIL_SCOPE_PIERCE" if bool(e.get("pierce", false)) else "DETAIL_SCOPE_PROJECTILE") % num(e.get("range", 10))
		"area":
			scope = _tr("DETAIL_SCOPE_CURSOR" if str(e.get("at", "cursor")) == "cursor" else "DETAIL_SCOPE_AROUND") % num(e.get("radius", 1))
		"beam":
			scope = _tr("DETAIL_SCOPE_BEAM") % num(e.get("range", 10))
		"summon":
			out.append(_tr("DETAIL_SUMMON") % num(e.get("duration_s", 30)))
		"trap":
			scope = _tr("DETAIL_SCOPE_TRAP") % num(e.get("radius", 1.5))
		"heal":
			_heal(e, stats, out)
		"shield":
			var sp := _power_of(e.get("amount", {}), stats, false)
			out.append(_tr("DETAIL_SHIELD") % [_amount(e.get("amount", {}), sp[0], sp[1]),
				num(e.get("duration_s", 0)), _target(e)])
		"dash":
			out.append(_tr("DETAIL_DASH_BACK" if str(e.get("to", "")) == "back" else "DETAIL_DASH") % num(e.get("distance", 5)))
		"blink":
			out.append(_tr("DETAIL_BLINK_BEHIND" if str(e.get("to", "")) == "behind_target" else "DETAIL_BLINK") % num(e.get("distance", 8)))
		"taunt":
			out.append(_tr("DETAIL_TAUNT") % [num(e.get("radius", 6)), num(e.get("duration_s", 4))])
		"stealth":
			out.append(_tr("DETAIL_STEALTH") % num(e.get("duration_s", 10)))
			if bool(e.get("vanish", false)):
				out.append(_tr("DETAIL_VANISH"))
		"cleanse":
			out.append(_tr("DETAIL_CLEANSE"))
		"revive":
			out.append(_tr("DETAIL_REVIVE") % [num(e.get("range", 20)), pct(_bal().revive_hp_pct)])
		"status":
			var parts := PackedStringArray()
			for s: Dictionary in e.get("statuses", []):
				parts.append(_status(s))
			var text := ", ".join(parts)
			match str(e.get("target", "self")):
				"allies_around":
					text = _tr("DETAIL_TO_ALLIES") % [num(e.get("radius", 8)), text]
				"enemy":
					text = _tr("DETAIL_TO_ENEMY") % text
			out.append(text)
			for s: Dictionary in e.get("statuses", []):
				if not (s.get("on_hit", {}) as Dictionary).is_empty():
					out.append(_tr("DETAIL_ON_HIT") % _status(s.on_hit))
	var has_damage := not dmg.is_empty()
	if has_damage:
		out.append(_damage("DETAIL_DAMAGE", dmg, stats, scope))
	if str(e.get("type")) == "area":
		if int(e.get("pulses", 1)) > 1:
			out.append(_tr("DETAIL_PULSES") % [int(e.pulses), num(e.get("interval_s", 0.5))])
		elif float(e.get("delay_s", 0.0)) > 0.0:
			out.append(_tr("DETAIL_DELAY") % num(e.delay_s))
	if str(e.get("type")) == "trap":
		out.append(_tr("DETAIL_TRAP") % [num(e.get("arm_s", 1)), num(e.get("lifetime_s", 30))])
	var explode: Dictionary = e.get("explode", {})
	if not explode.is_empty() and not (explode.get("damage", {}) as Dictionary).is_empty():
		out.append(_damage("DETAIL_EXPLOSION", explode.damage, stats, _tr("DETAIL_SCOPE_CURSOR_HIT") % num(explode.get("radius", 2))))
	if not e.get("statuses", []).is_empty() and str(e.get("type")) != "status":
		var parts := PackedStringArray()
		for s: Dictionary in e.statuses:
			parts.append(_status(s))
		out.append(", ".join(parts))
	for sub: Dictionary in e.get("on_arrive", []):
		has_damage = _effect(sub, stats, out) or has_damage
	return has_damage


static func _heal(e: Dictionary, stats: CombatStats, out: PackedStringArray) -> void:
	out.append(_tr("DETAIL_HEAL") % [_amount(e.get("amount", {}), stats.spell_power, "DETAIL_POWER_SPELL"), _target(e)])
	var hot: Dictionary = e.get("hot", {})
	if not hot.is_empty():
		out.append(_tr("DETAIL_HOT") % [num(hot.get("duration_s", 3)), num(hot.get("every_s", 1))])


static func _damage(label_key: String, spec: Dictionary, stats: CombatStats, scope: String) -> String:
	var physical := str(spec.get("kind", "physical")) == "physical"
	var pw := _power_of(spec, stats, physical)
	var text := _tr("DETAIL_DAMAGE_FMT") % [_tr(label_key),
		_amount(spec, pw[0], pw[1]),
		_tr("DETAIL_PHYSICAL" if physical else "DETAIL_MAGIC")]
	return text + (", " + scope if scope != "" else "")


## The power an amount scales with: [value, text key]. "power": "attack" or "armor" override
## the default (attack power for physical, spell power otherwise).
static func _power_of(spec: Dictionary, stats: CombatStats, physical: bool) -> Array:
	match str(spec.get("power", "")):
		"armor":
			return [stats.armor, "DETAIL_POWER_ARMOR"]
		"attack":
			return [stats.attack_power, "DETAIL_POWER_ATTACK"]
		"spell":
			return [stats.spell_power, "DETAIL_POWER_SPELL"]
	return [stats.attack_power, "DETAIL_POWER_ATTACK"] if physical else [stats.spell_power, "DETAIL_POWER_SPELL"]


## "18 + 80 % de tu poder de ataque (20) = 34".
static func _amount(spec: Dictionary, power: float, power_key: String) -> String:
	var base := float(spec.get("base", 0.0))
	var coef := float(spec.get("coef", 0.0))
	var total := roundi(base + coef * power)
	if coef == 0.0:
		return str(total)
	return _tr("DETAIL_FORMULA") % [num(base), pct(coef), _tr(power_key), num(power), str(total)]


static func _status(s: Dictionary) -> String:
	var kind := str(s.get("kind", ""))
	var d := num(s.get("duration_s", 0))
	var m := float(s.get("magnitude", 0.0))
	match kind:
		"slow", "mark", "damage_buff", "damage_reduction", "evasion", "haste", "vulnerable", "attack_slow", "weaken", "armor_break", "speed_buff":
			return _tr("DETAIL_ST_" + kind.to_upper()) % [pct(m), d]
		"poison", "burn":
			return _tr("DETAIL_ST_" + kind.to_upper()) % [num(m), num(s.get("every_s", 1)), d, int(s.get("max_stacks", 1))]
		"bleed":
			return _tr("DETAIL_ST_BLEED") % [num(float(s.get("coef", 0.0)) * 100.0), num(s.get("every_s", 1)), d]
		"envenom":
			return _tr("DETAIL_ST_ENVENOM") % d
	return _tr("DETAIL_ST_" + kind.to_upper()) % d


static func _target(e: Dictionary) -> String:
	match str(e.get("target", "self")):
		"ally_or_self":
			return _tr("DETAIL_TARGET_ALLY_OR_SELF")
		"allies_around":
			return _tr("DETAIL_TARGET_ALLIES_AROUND") % num(e.get("radius", 8))
	return _tr("DETAIL_TARGET_SELF")


static func _footer(ability: Dictionary, resource_kind: String) -> String:
	var parts := PackedStringArray()
	var cost := float(ability.get("cost", 0))
	parts.append(_tr("DETAIL_COST") % [num(cost), _resource(resource_kind)] if cost > 0.0 else _tr("DETAIL_NO_COST"))
	var cd := float(ability.get("cooldown_s", 0))
	if ability.has("combat_cooldown_s"):
		parts.append(_tr("DETAIL_COMBAT_COOLDOWN") % [num(cd), num(ability.combat_cooldown_s)])
	elif cd > 0.0:
		parts.append(_tr("DETAIL_COOLDOWN") % num(cd))
	if bool(ability.get("gcd", false)):
		parts.append(_tr("DETAIL_GCD"))
	if float(ability.get("range", 0)) > 0.0:
		parts.append(_tr("DETAIL_RANGE") % num(ability.range))
	return " · ".join(parts)


# --- Formatting -----------------------------------------------------------------------

## 8 -> "8", 2.5 -> "2,5" (one decimal, Spanish comma).
static func num(v: Variant) -> String:
	var f := float(v)
	if is_equal_approx(f, roundf(f)):
		return str(roundi(f))
	return str(snappedf(f, 0.1)).replace(".", ",")


## 0.15 -> "15 %".
static func pct(v: float) -> String:
	return num(v * 100.0) + " %"


static func _resource(kind: String) -> String:
	return _tr(RESOURCE_KEYS.get(kind, "DETAIL_RES_MANA"))


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func _bal() -> Balance:
	if _balance == null:
		_balance = Balance.load_from()
	return _balance
