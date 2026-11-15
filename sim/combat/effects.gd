class_name Effects
extends RefCounted
## The generic effects abilities are made of. Each effect is a Dictionary with a
## "type" and its parameters (distances in meters, times in seconds):
##   melee_arc  {angle_deg, range, damage, statuses?}
##   projectile {speed, radius, range, pierce, damage, statuses?, explode?: {radius, damage}}
##   area       {at: "cursor"|"self", radius, delay_s, telegraph, damage?, statuses?,
##               pulses?, interval_s?}
##   dash       {to: "cursor"|"back", distance, speed, on_arrive?: [effects]}
##   blink      {to: "cursor"|"behind_target", distance}
##   heal       {target: "ally_or_self"|"self", amount: {base, coef}}  (spell power)
##   shield     {target: "ally_or_self"|"self", amount: {base, coef}, duration_s}
## damage = {base, coef, kind: "physical"|"magic", can_crit}.

const TYPES := ["melee_arc", "projectile", "area", "dash", "blink", "heal", "shield"]
## Effects that need an enemy near the cursor before the cast is accepted.
const TARGETED := {"blink": ["behind_target"]}
const TARGET_PICK_RADIUS := 1.5


static func needs_target(effect: Dictionary) -> bool:
	return str(effect.get("to", "")) in TARGETED.get(str(effect.get("type", "")), [])


static func apply(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary, ctx: Dictionary) -> void:
	match str(effect.get("type", "")):
		"melee_arc":
			_melee_arc(world, caster, ability, effect)
		"projectile":
			_projectile(world, caster, ability, effect, ctx.aim)
		"area":
			_area(world, caster, ability, effect, ctx.aim)
		"dash":
			_dash(world, caster, effect, ctx.aim)
		"blink":
			_blink(world, caster, effect, ctx)
		"heal":
			_heal(world, caster, effect, ctx.aim)
		"shield":
			_shield(world, caster, effect, ctx.aim)
		_:
			push_error("Effects: unknown effect %s in %s" % [effect.get("type"), ability.get("id")])


# --- Targeting --------------------------------------------------------------------

static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func forward(facing: float) -> Vector2:
	return Vector2(sin(facing), cos(facing))


static func enemies_of(world: SimWorld, e: CombatEntity) -> Array:
	return world.entities().filter(func(o: CombatEntity) -> bool: return o.team != e.team and o.is_alive())


## The living enemy closest to `point`, if within pick radius (+ its own radius).
static func enemy_near(world: SimWorld, caster: CombatEntity, point: Vector3, max_range: float) -> CombatEntity:
	var best: CombatEntity = null
	var best_d := INF
	for o: CombatEntity in enemies_of(world, caster):
		var d := flat(o.position).distance_to(flat(point))
		if d <= TARGET_PICK_RADIUS + o.radius and d < best_d \
				and flat(o.position).distance_to(flat(caster.position)) <= max_range:
			best = o
			best_d = d
	return best


static func in_circle(world: SimWorld, caster: CombatEntity, center: Vector3, radius: float) -> Array:
	return enemies_of(world, caster).filter(func(o: CombatEntity) -> bool:
		return flat(o.position).distance_to(flat(center)) <= radius + o.radius)


# --- Effects ----------------------------------------------------------------------

static func _melee_arc(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary) -> void:
	var fwd := forward(caster.facing)
	var half := deg_to_rad(float(effect.get("angle_deg", 90.0))) / 2.0
	var reach := float(effect.get("range", 2.0))
	for o: CombatEntity in enemies_of(world, caster):
		var to := flat(o.position) - flat(caster.position)
		if to.length() > reach + o.radius:
			continue
		if to.length() > 0.01 and absf(fwd.angle_to(to.normalized())) > half:
			continue
		Combat.deal(world, caster, o, effect, ability)


static func _projectile(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary, aim: Vector3) -> void:
	var p := Projectile.new()
	p.id = world.next_object_id()
	p.owner = Combat.snapshot_of(caster)
	p.ability_id = str(ability.get("id", ""))
	p.pos = flat(caster.position)
	var to := flat(aim) - p.pos
	p.dir = to.normalized() if to.length() > 0.01 else forward(caster.facing)
	p.speed = float(effect.get("speed", 15.0))
	p.radius = float(effect.get("radius", 0.2))
	p.remaining = float(effect.get("range", 10.0))
	p.pierce = bool(effect.get("pierce", false))
	p.effect = effect
	world.projectiles.append(p)
	world.emit(["projectile", p.id, caster.id, p.ability_id, caster.position, p.dir, p.speed, p.remaining])


static func _area(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary, aim: Vector3) -> void:
	var a := PendingArea.new()
	a.id = world.next_object_id()
	a.owner = Combat.snapshot_of(caster)
	a.ability_id = str(ability.get("id", ""))
	a.pos = aim if str(effect.get("at", "cursor")) == "cursor" else caster.position
	a.pos.y = 0.0
	if a.pos.distance_to(Vector3(caster.position.x, 0, caster.position.z)) > float(ability.get("range", 100.0)):
		var dir := (a.pos - Vector3(caster.position.x, 0, caster.position.z)).normalized()
		a.pos = Vector3(caster.position.x, 0, caster.position.z) + dir * float(ability.get("range", 100.0))
	a.fire_tick = world.tick + world.ticks(float(effect.get("delay_s", 0.0)))
	a.pulses_left = maxi(1, int(effect.get("pulses", 1)))
	a.interval = world.ticks(float(effect.get("interval_s", 0.0)))
	a.effect = effect
	if bool(effect.get("telegraph", false)):
		world.emit(["telegraph", a.id, a.pos, float(effect.get("radius", 1.0)), a.fire_tick])
	if a.fire_tick <= world.tick:
		Combat.fire_area(world, a)
	if a.pulses_left > 0:
		world.pending_areas.append(a)


static func _dash(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> void:
	var to := flat(aim) - flat(caster.position)
	var dir := to.normalized() if to.length() > 0.01 else forward(caster.facing)
	var distance := float(effect.get("distance", 5.0))
	if str(effect.get("to", "cursor")) == "back":
		dir = -forward(caster.facing)
	elif to.length() > 0.01:
		distance = minf(distance, to.length())
	var speed := maxf(float(effect.get("speed", 20.0)), 0.1)
	caster.forced_vel = dir * speed / float(world.balance.tick_rate)
	caster.forced_ticks = maxi(1, ceili(distance / speed * world.balance.tick_rate))
	caster.forced_on_arrive = effect.get("on_arrive", [])
	# The last tick only covers what is left of the distance.
	caster.forced_last = distance - speed / float(world.balance.tick_rate) * (caster.forced_ticks - 1)


static func _blink(world: SimWorld, caster: CombatEntity, effect: Dictionary, ctx: Dictionary) -> void:
	var distance := float(effect.get("distance", 8.0))
	if str(effect.get("to", "cursor")) == "behind_target":
		var t: CombatEntity = ctx.get("target")
		if t == null:
			return
		var back := -forward(t.facing)
		var gap := t.radius + caster.radius + 0.1
		var dest := flat(t.position) + back * gap
		caster.position = Movement.move_circle(t.position, dest - flat(t.position), caster.radius, world.map)
		caster.facing = t.facing
		return
	var to := flat(ctx.aim) - flat(caster.position)
	if to.length() < 0.01:
		return
	var step := to.normalized() * minf(distance, to.length())
	caster.position = Movement.move_circle(caster.position, step, caster.radius, world.map)


static func _support_target(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> CombatEntity:
	if str(effect.get("target", "self")) == "ally_or_self":
		var ally := ClassRules.ally_under_cursor(world, caster, aim)
		if ally != null:
			return ally
	return caster


static func _amount(caster: CombatEntity, spec: Dictionary) -> float:
	return float(spec.get("base", 0.0)) + float(spec.get("coef", 0.0)) * caster.stats.spell_power


static func _heal(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> void:
	var t := _support_target(world, caster, effect, aim)
	var amount := _amount(caster, effect.get("amount", {})) * caster.stats.healing_done_mult * t.stats.healing_received_mult
	Combat.heal(world, caster, t, amount)


static func _shield(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> void:
	var t := _support_target(world, caster, effect, aim)
	t.shield = maxf(t.shield, _amount(caster, effect.get("amount", {})))
	t.shield_end = world.tick + world.ticks(float(effect.get("duration_s", 5.0)))
	world.emit(["status", t.id, "shield", t.shield_end])
