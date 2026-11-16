class_name Combat
extends RefCounted
## The combat system the host runs: casting abilities, resolving damage, and the
## per-tick update of statuses, resources, dashes, projectiles and pending areas.


## Casts `ability_id` toward `aim` if possible. Refused casts change nothing (no cost,
## no cooldown). Returns whether it was cast.
## mods (archer charged shot): {damage_mult, range_mult, extra_cost}.
static func try_cast(world: SimWorld, caster: CombatEntity, ability_id: String, aim: Vector3, mods: Dictionary = {}) -> bool:
	var ab := world.abilities.get_ability(ability_id)
	if ab.is_empty() or ab.get("kind") == "passive" or not caster.can_act(world.tick):
		return false
	if world.tick < int(caster.cooldowns.get(ability_id, 0)):
		return false
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
	var cd := world.ticks(cd_s)
	if cd > 0:
		caster.cooldowns[ability_id] = world.tick + cd
	if uses_gcd:
		caster.gcd_end = world.tick + world.ticks(world.balance.gcd_s)
	var to := Effects.flat(aim) - Effects.flat(caster.position)
	if to.length() > 0.01:
		caster.facing = atan2(to.x, to.y)
	world.emit(["cast", caster.id, ability_id, aim, cd_s])
	world.cast_hits = 0
	for e: Dictionary in ab.get("effects", []):
		Effects.apply(world, caster, ab, e, ctx)
	ClassRules.after_cast(caster, ab, world.cast_hits)
	return true


## Rolls and applies the damage (and statuses) of `effect` from source to target.
static func deal(world: SimWorld, source: CombatEntity, target: CombatEntity, effect: Dictionary, _ability: Dictionary) -> void:
	if not target.is_alive():
		return
	if target.has_status("invulnerable"):
		_dodged(world, target)
		return
	var spec: Dictionary = effect.get("damage", {})
	if not spec.is_empty():
		var r := Damage.roll(source, target, spec, world)
		if r.dodged:
			_dodged(world, target)
			return
		Damage.apply(target, r, world)
		world.emit(["hit", target.id, r.amount, r.crit, source.id])
		world.cast_hits += 1
		if r.amount > 0.0 and r.absorbed >= r.amount:
			_blocked(target)
		# Projectiles and areas carry a snapshot of their caster: combat time, rage
		# and healing go to the live caster when it is still in the world.
		var live := world.entity(source.id)
		var attacker := live if live != null else source
		Resources.on_damage_dealt(attacker, r.amount, world)
		Resources.on_damage_taken(target, r.amount, world)
		if r.crit:
			_on_crit(world, attacker, source, target, spec)
		if target is MonsterState and source.team == CombatEntity.TEAM_PLAYERS:
			var threat: float = r.amount * source.stats.threat_mult * float(_ability.get("threat_mult", 1.0))
			(target as MonsterState).add_threat(source.id, maxf(threat, 1.0))
		# Veneno: while the attacker is envenomed, its hits apply the poison.
		for st: StatusEffect in source.statuses:
			if st.kind == "envenom" and not st.on_hit.is_empty() and world.tick < st.end_tick:
				apply_status(world, source, target, st.on_hit)
	for s: Dictionary in effect.get("statuses", []):
		apply_status(world, source, target, s)


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
	var st := StatusEffect.make(str(s.get("kind", "")), world.tick + world.ticks(float(s.get("duration_s", 1.0))),
		float(s.get("magnitude", 0.0)), source.id, int(s.get("stacks", 1)), world.ticks(float(s.get("every_s", 0.0))))
	st.on_hit = s.get("on_hit", {})
	target.add_status(st, int(s.get("max_stacks", 1)))
	world.emit(["status", target.id, st.kind, st.end_tick])


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
	return s


static func on_zero_hp(world: SimWorld, e: CombatEntity) -> void:
	e.statuses.clear()
	e.shield = 0.0
	e.forced_ticks = 0
	if e is PlayerState:
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
	if e is MonsterState and bool((e as MonsterState).def.get("boss", false)):
		world.emit(["boss_down", e.type_id])
		MonsterAI.dismiss_minions(world, e as MonsterState)


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
	for e: CombatEntity in world.entities():
		StatusEffect.tick_entity(e, world)
		if e.shield > 0.0 and world.tick >= e.shield_end:
			e.shield = 0.0
		Resources.tick(e, world)
		_forced_move(world, e)
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
				Combat.deal(world, p.owner, o, p.effect, {"id": p.ability_id})
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
	for o: CombatEntity in Effects.in_circle(world, a.owner, a.pos, float(a.effect.get("radius", 1.0))):
		Combat.deal(world, a.owner, o, a.effect, {"id": a.ability_id})
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
