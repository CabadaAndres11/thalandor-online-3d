class_name Combat
extends RefCounted
## The combat system the host runs: casting abilities, resolving damage, and the
## per-tick update of statuses, resources, dashes, projectiles and pending areas.


## Casts `ability_id` toward `aim` if possible. Refused casts change nothing (no cost,
## no cooldown). Returns whether it was cast.
## mods (archer charged shot): {damage_mult, range_mult, extra_cost}.
static func try_cast(world: SimWorld, caster: CombatEntity, ability_id: String, aim: Vector3, mods: Dictionary = {}) -> bool:
	var upgrade := (caster as PlayerState).progress.upgrade if caster is PlayerState else ""
	var ab := world.abilities.resolved(ability_id, upgrade, world.upgrades)
	if ab.is_empty() or ab.get("kind") == "passive" or not caster.can_act(world.tick):
		return false
	if caster is PlayerState and (int(ab.get("level", 1)) > caster.level \
			or not AbilityDB.upgrade_ok(ab, (caster as PlayerState).progress.upgrade)):
		return false
	if world.tick < int(caster.cooldowns.get(ability_id, 0)):
		return false
	if channeling(world, caster.id):
		return false # busy with a channelled ability
	var uses_gcd := bool(ab.get("gcd", false))
	if uses_gcd and world.tick < caster.gcd_end:
		return false
	var cost := float(ab.get("cost", 0.0)) + float(mods.get("extra_cost", 0.0))
	if caster.resource < cost or not ClassRules.can_cast(world, caster, ab):
		return false
	var ctx := {"aim": aim, "target": null}
	for e: Dictionary in ab.get("effects", []):
		if Effects.needs_target(e):
			ctx.target = Effects.find_target(world, caster, e, ab, aim)
			if ctx.target == null:
				return false
	ab = ClassRules.shaped(caster, ab)
	if not mods.is_empty():
		ab = ClassRules.scale_damage(ab, float(mods.get("damage_mult", 1.0)), float(mods.get("range_mult", 1.0)))
	ab = ClassRules.with_passives(world, caster, ab)
	caster.resource -= cost
	# combat_cooldown_s: a longer cooldown when cast in combat (Sigilo's vanish).
	var cd_s := float(ab.get("cooldown_s", 0.0))
	if ab.has("combat_cooldown_s") and caster.in_combat(world):
		cd_s = float(ab.combat_cooldown_s)
	var cd := world.ticks(cd_s * (1.0 - caster.stats.cooldown_reduction) * maxf(0.0, 1.0 - caster.status_magnitude("haste")) * (1.0 + caster.status_magnitude("attack_slow")))
	if cd > 0:
		caster.cooldowns[ability_id] = world.tick + cd
	if uses_gcd:
		caster.gcd_end = world.tick + world.ticks(world.balance.gcd_s)
	var to := Effects.flat(aim) - Effects.flat(caster.position)
	if to.length() > 0.01:
		caster.facing = atan2(to.x, to.y)
	world.emit(["cast", caster.id, ability_id, aim, cd_s])
	if ab.has("repeat"):
		_start_repeat(world, caster, ab, aim)
		return true
	world.cast_hits = 0
	world.cast_kills = 0
	world.cast_cd_reduced = 0.0
	for e: Dictionary in ab.get("effects", []):
		Effects.apply(world, caster, ab, e, ctx)
	ClassRules.after_cast(caster, ab, world.cast_hits)
	if bool(ab.get("refund_on_kill", false)) and world.cast_kills > 0:
		Resources.add(caster, cost) # Ejecutar: a kill gives the cost back
	return true


## Whether this entity is in the middle of a channelled ability.
static func channeling(world: SimWorld, id: int) -> bool:
	for pc: PendingCast in world.pending_casts:
		if pc.channel and pc.caster_id == id:
			return true
	return false


## An ability with {"repeat": {times, interval_s, delay_s?, channel?}} applies its effects
## `times` times, `interval_s` apart, the first one after `delay_s`. Cost and cooldown were
## already paid. Combo points are counted once when it ends.
static func _start_repeat(world: SimWorld, caster: CombatEntity, ab: Dictionary, aim: Vector3) -> void:
	var r: Dictionary = ab.repeat
	var pc := PendingCast.new()
	pc.caster_id = caster.id
	pc.ability = ab
	pc.aim = aim
	pc.left = maxi(1, int(r.get("times", 1)))
	pc.interval = world.ticks(float(r.get("interval_s", 0.0)))
	pc.channel = bool(r.get("channel", false))
	pc.origin = Effects.flat(caster.position)
	pc.next_tick = world.tick + world.ticks(float(r.get("delay_s", 0.0)))
	world.pending_casts.append(pc)
	if pc.channel:
		var total := float(r.get("delay_s", 0.0)) + float(r.get("interval_s", 0.0)) * float(pc.left - 1)
		world.emit(["channel", caster.id, str(ab.get("id", "")), total])
	if pc.next_tick <= world.tick:
		_step_cast(world, pc)
		if pc.left <= 0:
			world.pending_casts.erase(pc)


## Stops a pending repeat now (the upgrade it belongs to was reset).
static func cancel_cast(world: SimWorld, pc: PendingCast) -> void:
	_finish_cast(world, pc, world.entity(pc.caster_id))


## One tick of every pending repeat: cut by death, a fall, a stun or freeze (and, for a
## channel, by moving or dodging), or its next hit.
## Allied summons end when their time is up or their owner is gone.
static func _summons(world: SimWorld) -> void:
	for id: int in world.monsters.keys():
		var m := world.monsters[id] as MonsterState
		if m == null or m.team != CombatEntity.TEAM_PLAYERS or m.summoned_by == 0:
			continue
		var owner := world.entity(m.summoned_by)
		if owner == null or not owner.is_alive() or (m.despawn_tick > 0 and world.tick >= m.despawn_tick):
			world.remove_entity(id)
			world.emit(["summon_end", id])


static func _pending_casts(world: SimWorld) -> void:
	for pc: PendingCast in world.pending_casts.duplicate():
		var caster := world.entity(pc.caster_id)
		var cut := caster == null or not caster.is_alive() or not caster.can_act(world.tick)
		if not cut and pc.channel:
			cut = Effects.flat(caster.position).distance_to(pc.origin) > 0.05 or caster.is_dashing() or caster.forced_ticks > 0
		if cut:
			_finish_cast(world, pc, caster)
			continue
		if world.tick >= pc.next_tick:
			_step_cast(world, pc)
			if pc.left <= 0:
				world.pending_casts.erase(pc)


static func _step_cast(world: SimWorld, pc: PendingCast) -> void:
	var caster := world.entity(pc.caster_id)
	if caster == null:
		return
	world.cast_hits = 0
	var ctx := {"aim": pc.aim, "target": null}
	for e: Dictionary in pc.ability.get("effects", []):
		Effects.apply(world, caster, pc.ability, e, ctx)
	pc.hits += world.cast_hits
	pc.left -= 1
	pc.next_tick += pc.interval
	if pc.left <= 0:
		_finish_cast(world, pc, caster, false)


## Ends a repeat (all hits done, or cut): the combo points of the hits so far are counted.
static func _finish_cast(world: SimWorld, pc: PendingCast, caster: CombatEntity, erase := true) -> void:
	if erase:
		world.pending_casts.erase(pc)
	pc.left = 0
	if caster != null and caster.is_alive():
		ClassRules.after_cast(caster, pc.ability, pc.hits)
	if pc.channel:
		world.emit(["channel_end", pc.caster_id])


## Rolls and applies the damage (and statuses) of `effect` from source to target.
static func deal(world: SimWorld, source: CombatEntity, target: CombatEntity, effect: Dictionary, _ability: Dictionary) -> void:
	if not target.is_alive():
		return
	if target.has_status("invulnerable") or target.has_status("ice_block"):
		_dodged(world, target)
		return
	var spec: Dictionary = effect.get("damage", {})
	if not spec.is_empty():
		var r := Damage.roll(source, target, spec, world, effect.get("type") == "melee_arc")
		if r.dodged:
			_dodged(world, target)
			return
		# Projectiles and areas carry a snapshot of their caster: combat time, rage,
		# healing and hooks go to the live caster when it is still in the world.
		var live := world.entity(source.id)
		var attacker := live if live != null else source
		attacker.last_target_id = target.id if target.team != attacker.team else attacker.last_target_id
		world.current_source = source.id
		Damage.apply(target, r, world)
		world.emit(["hit", target.id, r.amount, r.crit, source.id])
		world.cast_hits += 1
		if r.blocked:
			world.emit(["block", target.id])
			_blocked(target)
		elif r.amount > 0.0 and r.absorbed >= r.amount:
			_blocked(target)
		_reflect(world, attacker, target, r.absorbed)
		var steal := source.stats.lifesteal + float(spec.get("lifesteal_pct", 0.0))
		if steal > 0.0 and r.amount > 0.0 and attacker.is_alive():
			heal(world, attacker, attacker, r.amount * steal)
		Resources.on_damage_dealt(attacker, r.amount, world)
		Resources.on_damage_taken(target, r.amount, world)
		if r.crit:
			_on_crit(world, attacker, source, target, spec)
		if target is MonsterState and source.team == CombatEntity.TEAM_PLAYERS and target.team != source.team:
			var threat: float = r.amount * source.stats.threat_mult * float(_ability.get("threat_mult", 1.0))
			(target as MonsterState).add_threat(source.id, maxf(threat, 1.0))
		# Veneno: while the attacker is envenomed, its hits apply the poison.
		for st: StatusEffect in source.statuses:
			if st.kind == "envenom" and not st.on_hit.is_empty() and world.tick < st.end_tick:
				apply_status(world, source, target, st.on_hit)
		_hit_hooks(world, attacker, source, target, effect, spec)
	for s: Dictionary in effect.get("statuses", []):
		apply_status(world, source, target, s)


## Hooks that react to a hit landed: Celo (melee hits restore resource), Carga arcana
## (stacks of a school) and Último bastión (the target guards itself when low).
static func _hit_hooks(world: SimWorld, attacker: CombatEntity, source: CombatEntity, target: CombatEntity,
		effect: Dictionary, spec: Dictionary) -> void:
	if effect.get("type") == "melee_arc":
		for h: Dictionary in Passives.hooks(source, "melee_hit_restores"):
			Resources.add(attacker, float(h.get("amount", 0.0)))
	var school := str(spec.get("school", ""))
	if school != "":
		for h: Dictionary in Passives.hooks(source, "stacking_school_damage"):
			if str(h.get("school", "")) == school and attacker.is_alive():
				var st := StatusEffect.make("stack_" + school, world.tick + world.ticks(float(h.get("duration_s", 6.0))), 0.0, attacker.id)
				attacker.add_status(st, int(h.get("max", 5)))
	if target.is_alive() and target.stats.max_hp > 0.0:
		for h: Dictionary in Passives.hooks(target, "low_hp_guard"):
			if target.hp / target.stats.max_hp < float(h.get("below_pct", 0.2)) and Passives.hook_ready(target, "low_hp_guard", world):
				Passives.hook_use(target, "low_hp_guard", float(h.get("cooldown_s", 60.0)), world)
				apply_status(world, target, target, {"kind": "damage_reduction", "magnitude": float(h.get("reduction", 0.4)),
					"duration_s": float(h.get("duration_s", 8.0))})


## Represalia: a shield with shield_reflect sends back that share of what it absorbed
## (no crit, and it never reflects again).
static func _reflect(world: SimWorld, attacker: CombatEntity, target: CombatEntity, absorbed: float) -> void:
	if absorbed <= 0.0 or target.shield_reflect <= 0.0 or attacker == target or attacker.team == target.team or not attacker.is_alive():
		return
	var amount := absorbed * target.shield_reflect
	var r := {"amount": amount, "crit": false, "dodged": false, "absorbed": 0.0}
	world.current_source = target.id
	Damage.apply(attacker, r, world)
	world.emit(["hit", attacker.id, amount, false, target.id])


## A hit avoided (dodge roll, evasion or invulnerability): Bloqueo experto and
## Evasión mortal react to it.
static func _dodged(world: SimWorld, target: CombatEntity) -> void:
	world.emit(["dodge", target.id])
	_blocked(target)
	if target is PlayerState and not Passives.has_hook(target, "after_dodge_combo").is_empty():
		(target as PlayerState).bonus_combo_ready = true


## Bloqueo experto: a dodged hit or one the shield fully absorbs gives rage.
static func _blocked(target: CombatEntity) -> void:
	var h := Passives.has_hook(target, "block_generates_rage")
	if not h.is_empty() and target.resource_kind == "rage":
		Resources.add(target, float(h.get("amount", 0.0)))


## Sed de sangre (crits heal) and Ignición (fire crits burn).
static func _on_crit(world: SimWorld, attacker: CombatEntity, source: CombatEntity, target: CombatEntity, spec: Dictionary) -> void:
	var h := Passives.has_hook(source, "on_crit_heal_pct")
	if not h.is_empty() and attacker.is_alive():
		heal(world, attacker, attacker, attacker.stats.max_hp * float(h.get("pct", 0.0)))
	h = Passives.has_hook(source, "fire_crit_burn")
	if not h.is_empty() and str(spec.get("element", "")) == "fire":
		apply_status(world, source, target, {"kind": "burn", "duration_s": float(h.get("duration_s", 4.0)),
			"magnitude": float(h.get("magnitude", 1.0)), "every_s": float(h.get("every_s", 1.0))})


static func apply_status(world: SimWorld, source: CombatEntity, target: CombatEntity, s: Dictionary) -> void:
	if not target.is_alive():
		return
	var kind := str(s.get("kind", ""))
	# "coef": the magnitude grows with the source's attack power (bleed).
	var magnitude := float(s.get("magnitude", 0.0)) + float(s.get("coef", 0.0)) * source.stats.attack_power
	var max_stacks := int(s.get("max_stacks", 1))
	if kind == "poison":
		for h: Dictionary in Passives.hooks(source, "poison_max_stacks"):
			max_stacks = maxi(max_stacks, int(h.get("max", max_stacks)))
	var st := StatusEffect.make(kind, world.tick + world.ticks(float(s.get("duration_s", 1.0))),
		magnitude, source.id, int(s.get("stacks", 1)), world.ticks(float(s.get("every_s", 0.0))))
	st.on_hit = s.get("on_hit", {})
	target.add_status(st, max_stacks)
	world.emit(["status", target.id, st.kind, st.end_tick])
	_status_hooks(world, source, target, kind, s)


## Hooks of the source that add to a status it applies: Sangre corrupta (poisoned enemies
## deal less), Escalofrío (slowed ones attack slower) and Corazón helado (a freeze gives
## recharge back, at most `max` seconds per cast).
static func _status_hooks(world: SimWorld, source: CombatEntity, target: CombatEntity, kind: String, s: Dictionary) -> void:
	var duration := float(s.get("duration_s", 1.0))
	match kind:
		"poison":
			for h: Dictionary in Passives.hooks(source, "poisoned_deal_less"):
				apply_status(world, source, target, {"kind": "weaken", "magnitude": float(h.get("pct", 0.1)), "duration_s": duration})
		"slow":
			for h: Dictionary in Passives.hooks(source, "slow_adds_attack_slow"):
				apply_status(world, source, target, {"kind": "attack_slow", "magnitude": float(h.get("pct", 0.25)), "duration_s": duration})
		"freeze":
			var live := world.entity(source.id)
			for h: Dictionary in Passives.hooks(source, "freeze_reduces_cooldowns"):
				if live == null:
					continue
				var give := minf(float(h.get("seconds", 1.0)), float(h.get("max", 3.0)) - world.cast_cd_reduced)
				if give <= 0.0:
					continue
				world.cast_cd_reduced += give
				for k: String in live.cooldowns.keys():
					if not k.begins_with("hook:"):
						live.cooldowns[k] = maxi(world.tick, int(live.cooldowns[k]) - world.ticks(give))


## A detached copy of an entity for things that outlive their caster (projectiles,
## areas): same id, team, position and stats.
static func snapshot_of(e: CombatEntity) -> CombatEntity:
	var s := CombatEntity.new()
	s.id = e.id
	s.team = e.team
	s.level = e.level
	s.position = e.position
	s.facing = e.facing
	s.stats = e.stats.duplicate_stats()
	s.passives = e.passives
	s.statuses = e.statuses.duplicate()
	s.last_hurt_tick = e.last_hurt_tick
	s.still_since = e.still_since
	return s


static func on_zero_hp(world: SimWorld, e: CombatEntity) -> void:
	world.cast_kills += 1
	_on_kill_hooks(world, e)
	_spread_contagion(world, e)
	e.statuses.clear()
	e.shield = 0.0
	e.shield_reflect = 0.0
	e.forced_ticks = 0
	if e is PlayerState:
		dismiss_summons(world, e.id)
		var p := e as PlayerState
		p.charge_start = -1
		p.combo = 0
		if p.revive_target_id != 0:
			p.revive_target_id = 0
			world.emit(["revive_cancel", p.id])
		if _someone_standing(world, p):
			# In a group with an ally on their feet: downed, waiting for a revive.
			p.life = CombatEntity.DOWNED
			p.downed_end_tick = world.tick + world.ticks(world.balance.downed_s)
			world.emit(["downed", p.id])
			return
		_die(world, p)
		_fall_all(world)
		return
	e.life = CombatEntity.DEAD
	world.emit(["died", e.id])
	if e is MonsterState:
		Xp.share(world, e as MonsterState)
	if e is MonsterState and bool((e as MonsterState).def.get("boss", false)):
		world.emit(["boss_down", e.type_id])
		MonsterAI.dismiss_minions(world, e as MonsterState)


## Masacre: whoever dealt the killing blow gets a recharge reset and/or a heal.
static func _on_kill_hooks(world: SimWorld, dead: CombatEntity) -> void:
	var killer := world.entity(world.current_source)
	if killer == null or killer.team == dead.team or not killer.is_alive():
		return
	for h: Dictionary in Passives.hooks(killer, "on_kill"):
		var ability := str(h.get("reset_cooldown", ""))
		if ability != "":
			killer.cooldowns.erase(ability)
		if float(h.get("heal_pct", 0.0)) > 0.0:
			heal(world, killer, killer, killer.stats.max_hp * float(h.heal_pct))


## Contagio: an enemy that dies with the "contagion" status passes its poison to the
## enemies within the status magnitude (meters) of it.
static func _spread_contagion(world: SimWorld, dead: CombatEntity) -> void:
	var radius := dead.status_magnitude("contagion")
	if radius <= 0.0:
		return
	var poison: StatusEffect = null
	for s: StatusEffect in dead.statuses:
		if s.kind == "poison":
			poison = s
	if poison == null:
		return
	for o: CombatEntity in world.entities():
		if o == dead or o.team != dead.team or not o.is_alive():
			continue
		if Effects.flat(o.position).distance_to(Effects.flat(dead.position)) <= radius + o.radius:
			var copy := StatusEffect.make("poison", poison.end_tick, poison.magnitude, poison.source_id, poison.stacks, poison.tick_every)
			o.add_status(copy, 10)
			world.emit(["status", o.id, "poison", copy.end_tick])


## Allied summons of an owner vanish (the owner died, changed upgrade or left).
static func dismiss_summons(world: SimWorld, owner_id: int) -> void:
	for id: int in world.monsters.keys():
		var m := world.monsters[id] as MonsterState
		if m != null and m.team == CombatEntity.TEAM_PLAYERS and m.summoned_by == owner_id:
			world.remove_entity(id)
			world.emit(["summon_end", id])


static func _someone_standing(world: SimWorld, except: PlayerState) -> bool:
	for o: PlayerState in world.players.values():
		if o != except and o.life == CombatEntity.ALIVE:
			return true
	return false


## Dead, respawning after respawn_s.
static func _die(world: SimWorld, p: PlayerState) -> void:
	p.life = CombatEntity.DEAD
	p.downed_end_tick = -1
	p.respawn_tick = world.tick + world.ticks(world.balance.respawn_s)
	world.emit(["died", p.id])


## Nobody left standing: the downed die too, so the whole group respawns together.
static func _fall_all(world: SimWorld) -> void:
	for o: PlayerState in world.players.values():
		if o.life == CombatEntity.ALIVE:
			return
	for o: PlayerState in world.players.values():
		if o.life == CombatEntity.DOWNED:
			_die(world, o)


## Holding E next to a downed ally revives it after revive_hold_s; moving, taking
## damage, letting go or the ally getting up some other way cancels.
static func update_revive(world: SimWorld, p: PlayerState, holding: bool) -> void:
	if p.revive_target_id != 0:
		var t: PlayerState = world.players.get(p.revive_target_id)
		var cancel := not holding or not p.is_alive() or t == null or t.life != CombatEntity.DOWNED \
			or Effects.flat(p.position).distance_to(Effects.flat(p.revive_from)) > 0.05 \
			or p.last_hurt_tick >= p.revive_start_tick \
			or Effects.flat(p.position).distance_to(Effects.flat(t.position)) > world.balance.revive_range
		if cancel:
			p.revive_target_id = 0
			world.emit(["revive_cancel", p.id])
			return
		if world.tick - p.revive_start_tick >= world.ticks(world.balance.revive_hold_s):
			p.revive_target_id = 0
			revive(world, p, t)
		return
	if not holding or not p.is_alive():
		return
	var best: PlayerState = null
	var best_d := INF
	for o: PlayerState in world.players.values():
		if o == p or o.life != CombatEntity.DOWNED:
			continue
		var d := Effects.flat(o.position).distance_to(Effects.flat(p.position))
		if d <= world.balance.revive_range and d < best_d:
			best = o
			best_d = d
	if best != null:
		p.revive_target_id = best.id
		p.revive_start_tick = world.tick
		p.revive_from = p.position
		world.emit(["revive_start", p.id, best.id])


## Back at the respawn point with full health and resource (rage starts empty).
static func respawn(world: SimWorld, p: PlayerState) -> void:
	p.life = CombatEntity.ALIVE
	p.respawn_tick = -1
	p.hp = p.stats.max_hp
	p.resource = minf(float(p.resource_def.get("start", p.stats.max_resource)), p.stats.max_resource)
	p.statuses.clear()
	p.cooldowns.clear()
	p.dash_ticks = 0
	p.position = world.map.respawn_point()
	world.emit(["respawned", p.id, p.position])


## One simulation tick of combat (the world's tick counter is advanced by the caller).
static func tick(world: SimWorld) -> void:
	_fall_all(world) # e.g. the last player standing left the game
	for p: PlayerState in world.players.values():
		if p.life == CombatEntity.DOWNED and p.downed_end_tick >= 0 and world.tick >= p.downed_end_tick:
			_die(world, p) # bled out
		if p.life == CombatEntity.DEAD and p.respawn_tick >= 0 and world.tick >= p.respawn_tick:
			respawn(world, p)
	_summons(world)
	for e: CombatEntity in world.entities():
		var here := Effects.flat(e.position)
		if here.distance_to(e.last_pos) > 0.01:
			e.still_since = world.tick
			e.last_pos = here
		StatusEffect.tick_entity(e, world)
		if e.shield > 0.0 and world.tick >= e.shield_end:
			e.shield = 0.0
			e.shield_reflect = 0.0
		Resources.tick(e, world)
		_forced_move(world, e)
	_pending_casts(world)
	_projectiles(world)
	_areas(world)
	_traps(world)


static func _traps(world: SimWorld) -> void:
	var kept: Array = []
	for t: Trap in world.traps:
		if world.tick >= t.end_tick:
			world.emit(["trap_end", t.id])
			continue
		var radius := float(t.effect.get("radius", 1.5))
		if world.tick >= t.armed_tick and not Effects.in_circle(world, t.owner, t.pos, radius).is_empty():
			for o: CombatEntity in Effects.in_circle(world, t.owner, t.pos, radius):
				deal(world, t.owner, o, t.effect, {"id": t.ability_id})
			world.emit(["trap_fired", t.id, t.pos, radius])
			if t.rearms > 0:
				t.rearms -= 1
				t.armed_tick = world.tick + world.ticks(float(t.effect.get("arm_s", 1.0)))
				kept.append(t)
			continue
		kept.append(t)
	world.traps = kept


## A downed player stands up with revive_hp_pct of their health (Resurrección, and
## allies holding E in Task 14).
static func revive(world: SimWorld, source: CombatEntity, target: CombatEntity) -> void:
	if target.life != CombatEntity.DOWNED:
		return
	target.life = CombatEntity.ALIVE
	target.hp = maxf(1.0, target.stats.max_hp * world.balance.revive_hp_pct)
	if target is PlayerState:
		(target as PlayerState).downed_end_tick = -1
	world.emit(["revived", target.id, source.id])


static func _forced_move(world: SimWorld, e: CombatEntity) -> void:
	if e.forced_ticks <= 0 or not e.is_alive():
		return
	var step := e.forced_vel
	if e.forced_ticks == 1:
		step = e.forced_vel.normalized() * e.forced_last
	var before := e.position
	e.position = Movement.move_circle(e.position, step, e.radius, world.map)
	e.forced_ticks -= 1
	var blocked := Effects.flat(e.position).distance_to(Effects.flat(before)) < step.length() * 0.5
	if blocked:
		e.forced_ticks = 0
	if e.forced_ticks == 0:
		var ab := {"id": "arrive"}
		for eff: Dictionary in e.forced_on_arrive:
			Effects.apply(world, e, ab, eff, {"aim": e.position, "target": null})
		e.forced_on_arrive = []


static func _projectiles(world: SimWorld) -> void:
	var alive: Array = []
	for p: Projectile in world.projectiles:
		if _advance_projectile(world, p):
			alive.append(p)
	world.projectiles = alive


## Moves a projectile one tick; false when it ended (hit, wall or range).
static func _advance_projectile(world: SimWorld, p: Projectile) -> bool:
	var travel := minf(p.speed / float(world.balance.tick_rate), p.remaining)
	var steps := maxi(1, ceili(travel / 0.25))
	var step := travel / float(steps)
	for i in steps:
		p.pos += p.dir * step
		p.remaining -= step
		if world.map.is_solid(Vector2i(floori(p.pos.x), floori(p.pos.y))):
			_end_projectile(world, p)
			return false
		for o: CombatEntity in Effects.enemies_of(world, p.owner):
			if p.hit_ids.has(o.id):
				continue
			if Effects.flat(o.position).distance_to(p.pos) <= p.radius + o.radius:
				p.hit_ids[o.id] = true
				world.cast_hits = 0
				Combat.deal(world, p.owner, o, p.effect, {"id": p.ability_id})
				if p.combo_gain > 0 and world.cast_hits > 0:
					ClassRules.after_cast(world.entity(p.owner.id), {"combo_gain": p.combo_gain}, 1)
				if not p.pierce:
					_end_projectile(world, p)
					return false
		if p.remaining <= 0.0001:
			_end_projectile(world, p)
			return false
	return true


static func _end_projectile(world: SimWorld, p: Projectile) -> void:
	var explode: Dictionary = p.effect.get("explode", {})
	var at := Vector3(p.pos.x, 0, p.pos.y)
	if not explode.is_empty():
		for o: CombatEntity in Effects.in_circle(world, p.owner, at, float(explode.get("radius", 2.0))):
			Combat.deal(world, p.owner, o, explode, {"id": p.ability_id})
	var leave: Dictionary = explode.get("leave", {})
	if not leave.is_empty():
		var a := PendingArea.new()
		a.id = world.next_object_id()
		a.owner = p.owner
		a.ability_id = p.ability_id
		a.pos = at
		a.fire_tick = world.tick + world.ticks(float(leave.get("delay_s", 0.0)))
		a.pulses_left = maxi(1, int(leave.get("pulses", 1)))
		a.interval = world.ticks(float(leave.get("interval_s", 0.0)))
		a.effect = leave
		if a.fire_tick <= world.tick:
			fire_area(world, a)
		if a.pulses_left > 0:
			world.pending_areas.append(a)
	world.emit(["projectile_end", p.id, at])


static func _areas(world: SimWorld) -> void:
	var kept: Array = []
	for a: PendingArea in world.pending_areas:
		if world.tick >= a.fire_tick and a.pulses_left > 0:
			fire_area(world, a)
		if a.pulses_left > 0:
			kept.append(a)
	world.pending_areas = kept


static func fire_area(world: SimWorld, a: PendingArea) -> void:
	if str(a.effect.get("type", "")) == "charge":
		_fire_charge(world, a)
		return
	if bool(a.effect.get("leap", false)) and not _land(world, a):
		a.pulses_left = 0 # a dead, stunned or rooted jumper never lands: no damage
		var jumper := world.entity(a.owner.id)
		if jumper != null:
			world.emit(["leap", jumper.id, jumper.position, jumper.position]) # comes down where it is
		return
	var live_owner := world.entity(a.owner.id)
	if a.follow_id != 0 and live_owner != null:
		a.pos = Vector3(live_owner.position.x, 0, live_owner.position.z) # Himno: the area goes with the caster
	for o: CombatEntity in Effects.in_circle(world, a.owner, a.pos, float(a.effect.get("radius", 1.0))):
		Combat.deal(world, a.owner, o, a.effect, {"id": a.ability_id})
	var heal: Dictionary = a.effect.get("heal", {})
	if not heal.is_empty():
		for ally: CombatEntity in Effects.allies_in_circle(world, a.owner, a.pos, float(a.effect.get("radius", 1.0))):
			var amount := (float(heal.get("base", 0.0)) + float(heal.get("coef", 0.0)) * a.owner.stats.spell_power) \
				* a.owner.stats.healing_done_mult * ally.stats.healing_received_mult
			Combat.heal(world, live_owner if live_owner != null else a.owner, ally, amount)
	a.pulses_left -= 1
	a.fire_tick = world.tick + maxi(a.interval, 1)
	world.emit(["area", a.id, a.pos, float(a.effect.get("radius", 1.0))])


## A leaping caster (the boss jump) lands on the area when it goes off; false when it
## cannot (gone, dead, stunned, frozen or rooted).
static func _land(world: SimWorld, a: PendingArea) -> bool:
	var live := world.entity(a.owner.id)
	if live == null or not live.can_act(world.tick) or live.has_status("root"):
		return false
	var from := live.position
	live.position = Vector3(a.pos.x, live.position.y, a.pos.z)
	world.emit(["leap", live.id, from, live.position])
	return true


## A charge after its warning: everyone in the warned line is hit and the caster runs
## to its end. A dead, stunned or frozen caster loses the charge.
static func _fire_charge(world: SimWorld, a: PendingArea) -> void:
	a.pulses_left = 0
	var live := world.entity(a.owner.id)
	if live == null or not live.can_act(world.tick) or live.has_status("root"):
		world.emit(["charge_cancel", a.id])
		return
	var width := float(a.effect.get("width", 1.4))
	for o: CombatEntity in Effects.in_line(world, a.owner, a.pos, a.end, width):
		deal(world, a.owner, o, a.effect, {"id": a.ability_id})
	var to := Effects.flat(a.end) - Effects.flat(live.position)
	if to.length() > 0.05:
		var speed := maxf(float(a.effect.get("speed", 16.0)), 0.1)
		live.forced_vel = to.normalized() * speed / float(world.balance.tick_rate)
		live.forced_ticks = maxi(1, ceili(to.length() / speed * world.balance.tick_rate))
		live.forced_last = to.length() - speed / float(world.balance.tick_rate) * (live.forced_ticks - 1)
		live.forced_on_arrive = []
	world.emit(["charge", a.id, live.id, a.pos, a.end])


## Heals up to max health and reports how much was healed.
static func heal(world: SimWorld, source: CombatEntity, target: CombatEntity, amount: float) -> float:
	if not target.is_alive():
		return 0.0
	var healed := minf(maxf(amount, 0.0), target.stats.max_hp - target.hp)
	target.hp += healed
	world.emit(["heal", target.id, healed])
	heal_threat(world, source, target, healed)
	return healed


## Healing draws half its amount as threat from every monster chasing the healed one.
static func heal_threat(world: SimWorld, source: CombatEntity, target: CombatEntity, healed: float) -> void:
	if source == null or healed <= 0.0 or source.team != CombatEntity.TEAM_PLAYERS:
		return
	var live := world.entity(source.id)
	var mult := (live if live != null else source).stats.threat_mult
	for e: CombatEntity in world.monsters.values():
		var m := e as MonsterState
		if m != null and m.is_alive() and m.threat.has(target.id):
			m.add_threat(source.id, healed * 0.5 * mult)
