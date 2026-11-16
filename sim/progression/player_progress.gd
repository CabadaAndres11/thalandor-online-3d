class_name PlayerProgress
extends RefCounted
## Everything a character earns: level, experience, hand-spent attributes, talents,
## masteries and the class upgrade. Pure data; rules live in Xp, Attributes, Talents.

const ATTRIBUTES := ["strength", "agility", "intellect", "stamina", "spirit"]
const MAX_LEVEL := 65535

var level: int = 1
var xp: int = 0
## Points spent by hand on each attribute.
var attributes: Dictionary = {}
## Bought talent node ids.
var talents: Array = []
## Mastery direction -> rank.
var masteries: Dictionary = {}
var upgrade: String = ""


func _init() -> void:
	for a: String in ATTRIBUTES:
		attributes[a] = 0


func to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"attributes": attributes.duplicate(),
		"talents": talents.duplicate(),
		"masteries": masteries.duplicate(),
		"upgrade": upgrade,
	}


func copy() -> PlayerProgress:
	return PlayerProgress.from_dict(to_dict())


## Never returns null: anything unexpected falls back to the default value.
static func from_dict(v: Variant) -> PlayerProgress:
	var p := PlayerProgress.new()
	if not v is Dictionary:
		return p
	var d: Dictionary = v
	p.level = clampi(_int(d.get("level"), 1), 1, MAX_LEVEL)
	p.xp = maxi(0, _int(d.get("xp"), 0))
	if d.get("attributes") is Dictionary:
		var attrs: Dictionary = d["attributes"]
		for a: String in ATTRIBUTES:
			p.attributes[a] = maxi(0, _int(attrs.get(a), 0))
	if d.get("talents") is Array:
		for t: Variant in d["talents"]:
			if t is String and not p.talents.has(t):
				p.talents.append(t)
	if d.get("masteries") is Dictionary:
		var m: Dictionary = d["masteries"]
		for k: Variant in m:
			if k is String:
				var r := maxi(0, _int(m[k], 0))
				if r > 0:
					p.masteries[k] = r
	if d.get("upgrade") is String:
		p.upgrade = d["upgrade"]
	return p


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float and is_finite(v):
		return int(clampf(v, -2.0e9, 2.0e9))
	return fallback
