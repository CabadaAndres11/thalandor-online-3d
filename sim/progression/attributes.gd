class_name Attributes
extends RefCounted
## Attribute points: earned per level, spent by hand, plus the automatic ones of the class.


static func _a(b: Balance, key: String) -> float:
	return float(b.attributes.get(key, 0.0))


## Points earned by level and not yet spent.
static func free_points(pr: PlayerProgress, b: Balance) -> int:
	var spent := 0
	for a: String in PlayerProgress.ATTRIBUTES:
		spent += int(pr.attributes.get(a, 0))
	return int(_a(b, "points_per_level")) * (pr.level - 1) - spent


## Hand-spent points plus auto_per_level x (level - 1) in each main attribute of the class.
static func totals(pr: PlayerProgress, class_def: Dictionary, b: Balance) -> Dictionary:
	var out: Dictionary = {}
	var auto := int(_a(b, "auto_per_level")) * (pr.level - 1)
	var mains: Array = class_def.get("main_attributes", [])
	for a: String in PlayerProgress.ATTRIBUTES:
		out[a] = int(pr.attributes.get(a, 0)) + (auto if a in mains else 0)
	return out


## Points after the soft-cap tramos: each [from, factor] makes the points above `from`
## count `factor` as much.
static func effective(points: int, b: Balance) -> float:
	var total := 0.0
	var from := 0.0
	var factor := 1.0
	var p := float(maxi(points, 0))
	for cap: Variant in b.attributes.get("soft_caps", []):
		var edge := float(cap[0])
		if p <= edge:
			break
		total += (edge - from) * factor
		from = edge
		factor = float(cap[1])
	return total + (p - from) * factor


static func spend(pr: PlayerProgress, attr: String, b: Balance) -> bool:
	if not attr in PlayerProgress.ATTRIBUTES or free_points(pr, b) <= 0:
		return false
	pr.attributes[attr] = int(pr.attributes.get(attr, 0)) + 1
	return true
