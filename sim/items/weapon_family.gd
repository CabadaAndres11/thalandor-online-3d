class_name WeaponFamily
extends RefCounted
## Weapon families (data/items/weapons.json "families"): the same abilities, but the basic
## attack changes with the weapon in hand. A family may set cooldown_mult, damage_mult,
## range_add, angle_deg (melee arcs), melee_anim (replaces "melee"), projectile {speed,
## range} and auto_charge (the crossbow: every shot is the full charged shot).


## The family of the player's main weapon ({} without one).
static func of(p: PlayerState, world: SimWorld = null) -> Dictionary:
	if not p.inventory.equipment.has("main"):
		return {}
	var db := world.items if world != null else ItemDB.load_default()
	return db.family_of(p.inventory.equipment.main.base_id)


## A copy of `ability` changed by the family; abilities other than the basic one, and an
## empty family, come back as they are.
static func adjust(ability: Dictionary, family: Dictionary) -> Dictionary:
	if family.is_empty() or str(ability.get("kind", "")) != "basic":
		return ability
	var keys := ["cooldown_mult", "damage_mult", "range_add", "angle_deg", "melee_anim", "projectile", "auto_charge"]
	if not keys.any(func(k: String) -> bool: return family.has(k)):
		return ability
	var a := ability.duplicate(true)
	var dmg := float(family.get("damage_mult", 1.0))
	var add := float(family.get("range_add", 0.0))
	var proj: Dictionary = family.get("projectile", {})
	a.cooldown_s = float(a.get("cooldown_s", 0.0)) * float(family.get("cooldown_mult", 1.0))
	if a.has("range"):
		a.range = float(proj.get("range", float(a.range) + add)) if not proj.is_empty() else float(a.range) + add
	if family.has("melee_anim") and str(a.get("anim", "")) == "melee":
		a.anim = family.melee_anim
	if bool(family.get("auto_charge", false)):
		a.auto_charge = true
	for e: Dictionary in a.get("effects", []):
		if e.has("damage"):
			e.damage.base = float(e.damage.get("base", 0.0)) * dmg
			e.damage.coef = float(e.damage.get("coef", 0.0)) * dmg
		match str(e.get("type", "")):
			"melee_arc":
				e.range = float(e.get("range", 0.0)) + add
				if family.has("angle_deg"):
					e.angle_deg = family.angle_deg
			"projectile":
				for k: String in proj:
					e[k] = proj[k]
	return a
