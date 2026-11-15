class_name Effects
extends RefCounted
## The generic effects abilities are made of. Each effect is a Dictionary with a
## "type" and its parameters (distances in meters, times in seconds):
##   melee_arc  {angle_deg, range, damage, statuses?}
##   projectile {speed, radius, range, pierce, damage, statuses?, explode?: {radius, damage}}
##   area       {at: "cursor"|"self", radius, delay_s, telegraph, damage?, statuses?,
##               pulses?, interval_s?, leap?}  (leap: the caster lands on it when it goes off)
##   dash       {to: "cursor"|"back", distance, speed, on_arrive?: [effects]}
##   blink      {to: "cursor"|"behind_target", distance}
##   heal       {target: "ally_or_self"|"self"|"allies_around", radius?, amount: {base, coef},
##               hot?: {duration_s, every_s}}
##              (spell power; with "hot" the amount is spread over time)
##   shield     {target: "ally_or_self"|"self", amount: {base, coef}, duration_s}
##   status     {target: "enemy"|"self"|"ally_or_self"|"allies_around"|"enemies_around",
##               radius?, statuses: [{kind, duration_s, magnitude?, stacks?, max_stacks?, every_s?,
##               on_hit?}]}  ("envenom" + on_hit: the bearer's hits apply the on_hit status)
##   trap       {radius, arm_s, lifetime_s, damage, statuses?}  (placed at the cursor)
##   stealth    {duration_s, vanish?}  (out of combat only, unless vanish: then it also
##               leaves combat and monsters forget the caster)
##   cleanse    {target: "ally_or_self"|"self"}  (removes negative statuses)
##   revive     {range}  (a downed ally near the cursor stands up with revive_hp_pct)
##   taunt      {radius, duration_s}  (enemies around must attack the caster)
##   charge     {distance, width, windup_s, speed, damage, statuses?}  (warns a line
##               toward the cursor, then runs along it hitting everyone in the line)
## damage = {base, coef, kind: "physical"|"magic", can_crit, element?}.

const TYPES := ["melee_arc", "projectile", "area", "dash", "blink", "heal", "shield",
	"status", "trap", "stealth", "cleanse", "revive", "taunt", "charge"]
const TARGET_PICK_RADIUS := 1.5


## Effects that need someone near the cursor before the cast is accepted.
static func needs_target(effect: Dictionary) -> bool:
	match str(effect.get("type", "")):
		"blink":
			return str(effect.get("to", "")) == "behind_target"
		"status":
			return str(effect.get("target", "")) == "enemy"
		"revive":
			return true
	return false


## The target a targeted effect will use (null = refuse the cast).
static func find_target(world: SimWorld, caster: CombatEntity, effect: Dictionary, ability: Dictionary, aim: Vector3) -> CombatEntity:
	if effect.get("type") == "revive":
		var reach := float(effect.get("range", ability.get("range", 20.0)))
		var best: CombatEntity = null
		var best_d := INF
		for o: CombatEntity in world.entities():
			if o == caster or o.team != caster.team or o.life != CombatEntity.DOWNED:
				continue
			var d := flat(o.position).distance_to(flat(aim))
			if d <= TARGET_PICK_RADIUS + o.radius and d < best_d \
					and flat(o.position).distance_to(flat(caster.position)) <= reach:
				best = o
				best_d = d
		return best
	return enemy_near(world, caster, aim, float(effect.get("distance", effect.get("range", ability.get("range", 10.0)))))


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
		"status":
			_status(world, caster, effect, ctx)
		"trap":
			_trap(world, caster, ability, effect, ctx.aim)
		"stealth":
			_stealth(world, caster, effect)
		"cleanse":
			_cleanse(world, caster, effect, ctx.aim)
		"revive":
			var t: CombatEntity = ctx.get("target")
			if t != null:
				Combat.revive(world, caster, t)
		"taunt":
			_taunt(world, caster, effect)
		"charge":
			_charge(world, caster, ability, effect, ctx.aim)
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
	if str(effect.get("target", "")) == "allies_around":
		for t: CombatEntity in allies_around(world, caster, float(effect.get("radius", 3.0))):
			_heal_one(world, caster, t, effect)
		return
	_heal_one(world, caster, _support_target(world, caster, effect, aim), effect)


## Living allies (the caster included) within `radius` of the caster.
static func allies_around(world: SimWorld, caster: CombatEntity, radius: float) -> Array:
	return world.entities().filter(func(o: CombatEntity) -> bool:
		return o.team == caster.team and o.is_alive() \
			and flat(o.position).distance_to(flat(caster.position)) <= radius + o.radius)


static func _heal_one(world: SimWorld, caster: CombatEntity, t: CombatEntity, effect: Dictionary) -> void:
	var amount := _amount(caster, effect.get("amount", {})) * caster.stats.healing_done_mult * t.stats.healing_received_mult
	var hot: Dictionary = effect.get("hot", {})
	if not hot.is_empty():
		add_hot(world, caster, t, amount, float(hot.get("duration_s", 3.0)), float(hot.get("every_s", 1.0)))
		return
	var healed := Combat.heal(world, caster, t, amount)
	var echo := Passives.has_hook(caster, "heal_leaves_hot") # Eco de luz
	if not echo.is_empty() and healed > 0.0:
		add_hot(world, caster, t, amount * float(echo.get("pct", 0.0)), float(echo.get("duration_s", 3.0)),
			float(echo.get("every_s", 1.0)))


## Heals `total` over `duration_s`, a pulse every `every_s`.
static func add_hot(world: SimWorld, caster: CombatEntity, t: CombatEntity, total: float, duration_s: float, every_s: float) -> void:
	var pulses := maxi(1, floori(duration_s / maxf(every_s, 0.01) + 0.001))
	var st := StatusEffect.make("hot", world.tick + world.ticks(duration_s) + 1, total / float(pulses), caster.id, 1,
		world.ticks(every_s))
	t.add_status(st, 1)
	world.emit(["status", t.id, "hot", st.end_tick])


static func _status(world: SimWorld, caster: CombatEntity, effect: Dictionary, ctx: Dictionary) -> void:
	var targets: Array = []
	var radius := float(effect.get("radius", 3.0))
	match str(effect.get("target", "self")):
		"enemy":
			if ctx.get("target") != null:
				targets = [ctx.target]
		"ally_or_self":
			targets = [_support_target(world, caster, effect, ctx.aim)]
		"allies_around":
			targets = allies_around(world, caster, radius)
		"enemies_around":
			targets = in_circle(world, caster, caster.position, radius)
		_:
			targets = [caster]
	for t: CombatEntity in targets:
		for s: Dictionary in effect.get("statuses", []):
			Combat.apply_status(world, caster, t, s)


static func _trap(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary, aim: Vector3) -> void:
	var t := Trap.new()
	t.id = world.next_object_id()
	t.owner = Combat.snapshot_of(caster)
	t.ability_id = str(ability.get("id", ""))
	var from := flat(caster.position)
	var to := flat(aim) - from
	var reach := float(ability.get("range", 10.0))
	var spot := from + (to.limit_length(reach) if to.length() > 0.01 else Vector2.ZERO)
	t.pos = Vector3(spot.x, 0, spot.y)
	t.armed_tick = world.tick + world.ticks(float(effect.get("arm_s", 1.0)))
	t.end_tick = world.tick + world.ticks(float(effect.get("lifetime_s", 30.0)))
	t.effect = effect
	world.traps.append(t)
	world.emit(["trap", t.id, caster.id, t.pos, float(effect.get("radius", 1.5)), t.armed_tick])


static func _stealth(world: SimWorld, caster: CombatEntity, effect: Dictionary) -> void:
	var st := StatusEffect.make("stealth", world.tick + world.ticks(float(effect.get("duration_s", 10.0))), 0.0, caster.id)
	caster.add_status(st, 1)
	world.emit(["status", caster.id, "stealth", st.end_tick])
	if bool(effect.get("vanish", false)):
		caster.last_combat_tick = -100000
		for m: CombatEntity in world.monsters.values():
			if m is MonsterState:
				(m as MonsterState).threat.erase(caster.id)


static func _cleanse(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> void:
	var t := _support_target(world, caster, effect, aim)
	var removed := t.statuses.filter(func(s: StatusEffect) -> bool: return s.is_negative())
	t.statuses = t.statuses.filter(func(s: StatusEffect) -> bool: return not s.is_negative())
	for s: StatusEffect in removed:
		world.emit(["status_end", t.id, s.kind])


static func _taunt(world: SimWorld, caster: CombatEntity, effect: Dictionary) -> void:
	for o: CombatEntity in in_circle(world, caster, caster.position, float(effect.get("radius", 6.0))):
		Combat.apply_status(world, caster, o, {"kind": "taunted", "duration_s": float(effect.get("duration_s", 4.0))})
		if o is MonsterState:
			# The taunter takes the top of the table (+10 %) so it keeps the target after.
			var m := o as MonsterState
			var top := 0.0
			for id: int in m.threat:
				top = maxf(top, float(m.threat[id]))
			m.threat[caster.id] = maxf(maxf(float(m.threat.get(caster.id, 0.0)), top * 1.1), 1.0)
			m.target_id = caster.id


static func _shield(world: SimWorld, caster: CombatEntity, effect: Dictionary, aim: Vector3) -> void:
	var t := _support_target(world, caster, effect, aim)
	t.shield = maxf(t.shield, _amount(caster, effect.get("amount", {})))
	t.shield_end = world.tick + world.ticks(float(effect.get("duration_s", 5.0)))
	world.emit(["status", t.id, "shield", t.shield_end])


## Warns a straight line toward `aim` (stopping at walls); when the windup ends the
## caster runs along it (Combat.fire_area).
static func _charge(world: SimWorld, caster: CombatEntity, ability: Dictionary, effect: Dictionary, aim: Vector3) -> void:
	var start := Vector3(caster.position.x, 0, caster.position.z)
	var to := flat(aim) - flat(start)
	var dir := to.normalized() if to.length() > 0.01 else forward(caster.facing)
	caster.facing = atan2(dir.x, dir.y)
	var a := PendingArea.new()
	a.id = world.next_object_id()
	a.owner = Combat.snapshot_of(caster)
	a.ability_id = str(ability.get("id", ""))
	a.pos = start
	a.end = line_end(world, start, dir, float(effect.get("distance", 8.0)), minf(caster.radius, MonsterAI.TERRAIN_RADIUS))
	a.fire_tick = world.tick + world.ticks(float(effect.get("windup_s", 0.8)))
	a.effect = effect
	world.emit(["telegraph_line", a.id, a.pos, a.end, float(effect.get("width", 1.4)), a.fire_tick])
	world.pending_areas.append(a)


## Where a body of `radius` moving from `start` along `dir` stops: `distance` away or
## at the first wall.
static func line_end(world: SimWorld, start: Vector3, dir: Vector2, distance: float, radius: float) -> Vector3:
	const STEP := 0.1
	var reached := 0.0
	while reached + STEP <= distance + 0.0001:
		var next := start + Vector3(dir.x, 0, dir.y) * (reached + STEP)
		if Movement.move_circle(start + Vector3(dir.x, 0, dir.y) * reached, dir * STEP, radius, world.map).distance_to(next) > 0.001:
			break
		reached += STEP
	return start + Vector3(dir.x, 0, dir.y) * reached


## Living enemies of `caster` touching the segment from `a` to `b` (width/2 + their radius).
static func in_line(world: SimWorld, caster: CombatEntity, a: Vector3, b: Vector3, width: float) -> Array:
	var p0 := flat(a)
	var p1 := flat(b)
	return enemies_of(world, caster).filter(func(o: CombatEntity) -> bool:
		var q := Geometry2D.get_closest_point_to_segment(flat(o.position), p0, p1)
		return q.distance_to(flat(o.position)) <= width / 2.0 + o.radius)
