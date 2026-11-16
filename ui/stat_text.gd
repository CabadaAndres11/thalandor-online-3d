class_name StatText
extends RefCounted
## Words for stat modifiers ({"type": "stat", "stat": name, "value": v}): "+3 % poder de
## ataque", "-2 % daño recibido", "+15 armadura".

## Stats whose value is a fraction shown as a percentage.
const FRACTION := ["dodge_add", "crit_add", "block_add", "crit_damage_add", "lifesteal_add", "cooldown_reduction_add"]


## "+3 %", "-2 %", "+15", "+1.5": the signed value of a modifier.
static func value_text(stat: String, value: float) -> String:
	var percent := stat.ends_with("_pct") or stat in FRACTION
	var rounded := snappedf(value * 100.0 if percent else value, 0.1)
	var body: String
	if is_equal_approx(rounded, roundf(rounded)):
		body = str(absi(roundi(rounded)))
	else:
		body = "%.1f" % absf(rounded)
	return ("-" if rounded < 0.0 else "+") + body + (" %" if percent else "")


## Translation key of a stat modifier's sentence.
static func key_of(stat: String) -> String:
	return "STAT_" + stat.to_upper()


## "+3 % poder de ataque".
static func describe(mod: Dictionary) -> String:
	var stat := str(mod.get("stat", ""))
	return TranslationServer.translate(key_of(stat)) % value_text(stat, float(mod.get("value", 0.0)))


## Every modifier of a node, one per line.
static func describe_all(mods: Array) -> String:
	var lines: Array = []
	for m: Variant in mods:
		if m is Dictionary:
			lines.append(describe(m))
	return "\n".join(lines)
