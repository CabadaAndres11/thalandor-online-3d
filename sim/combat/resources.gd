class_name Resources
extends RefCounted
## Class resources (GDD §4.1). Rules come from the entity's resource_def
## (data/characters/classes.json): regen_per_s, regen_in_combat_mult, decay_per_s,
## gain_per_hit, gain_per_damage_taken, dodging_regen_mult.
##   rage:   no regen; gains on hits dealt and damage taken; decays out of combat.
##   mana:   regen out of combat; in combat × regen_in_combat_mult (0 by default).
##   focus:  regen always, × dodging_regen_mult while dodging.
##   energy: fixed regen always.


static func tick(e: CombatEntity, world: SimWorld) -> void:
	if not e.is_alive() or e.resource_kind == "":
		return
	var d := e.resource_def
	var per_tick := 1.0 / float(world.balance.tick_rate)
	var change := 0.0
	match e.resource_kind:
		"rage":
			if not e.in_combat(world):
				var decay_mult := float(Passives.has_hook(e, "rage_decay_mult").get("mult", d.get("decay_mult", 1.0)))
				change = -float(d.get("decay_per_s", 0.0)) * per_tick * decay_mult
		"mana":
			var in_combat_mult := maxf(float(d.get("regen_in_combat_mult", 0.0)),
				float(Passives.has_hook(e, "mana_regen_in_combat").get("mult", 0.0)))
			var mult := in_combat_mult if e.in_combat(world) else 1.0
			change = float(d.get("regen_per_s", 0.0)) * per_tick * mult
		"focus":
			var mult := float(d.get("dodging_regen_mult", 1.0)) if e.is_dashing() else 1.0
			change = float(d.get("regen_per_s", 0.0)) * per_tick * mult
		"energy":
			change = float(d.get("regen_per_s", 0.0)) * per_tick
	add(e, change)


static func add(e: CombatEntity, amount: float) -> void:
	e.resource = clampf(e.resource + amount, 0.0, e.stats.max_resource)


static func on_damage_dealt(e: CombatEntity, _amount: float, world: SimWorld) -> void:
	e.last_combat_tick = world.tick
	if e.resource_kind == "rage":
		add(e, float(e.resource_def.get("gain_per_hit", 0.0)))


static func on_damage_taken(e: CombatEntity, amount: float, world: SimWorld) -> void:
	e.last_combat_tick = world.tick
	if e.resource_kind == "rage":
		add(e, amount * float(e.resource_def.get("gain_per_damage_taken", 0.0)))
