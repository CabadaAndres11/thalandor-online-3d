

class_name MonsterAI
extends RefCounted
## Monster brains (deterministic, run by the host each tick):
##   IDLE   -> a visible player inside aggro_range (or damage) -> CHASE
##   CHASE  -> follows a path (or straight line) to its target; in attack_range -> ATTACK
##   ATTACK -> casts its first ready ability at the target
##   RETURN -> beyond leash_range, no valid target or target unreachable: walks home,
##             then heals fully and forgets its threat -> IDLE
## The target is the valid player with most threat; it only switches when another
## has more than threat_switch_margin above the current one.
## Behaviors (data/monsters "behavior"):
##   melee        the above
##   charger      also charges ("charge": {ability, min_range, max_range}) when the
##                target is in that band and in sight; still while it warns and runs
##   ranged_kite  backs away while the target is closer than kite_range (shoots when
##                it cannot back away)
##   boss         phases by health (phase_for): 1 cleaves; from "jump.from_phase" it
##                also leaps at a player (a warned area); from "summon.from_phase" it
##                calls goblins every summon.every_s
## "pack": true monsters wake the IDLE ones of their type within pack_radius.

const REPATH_S := 0.5
const UNREACHABLE_S := 3.0
const HOME_ARRIVE := 0.5
const TERRAIN_RADIUS := 0.45


static func tick(world: SimWorld, m: MonsterState) -> void:
	if not m.is_alive():
		return
	if m.ai == MonsterState.RETURN:
		_go_home(world, m)
		return
	if str(m.def.get("behavior", "")) == "boss":
		_update_phase(world, m)
	if m.forced_ticks > 0 or world.tick < m.busy_until:
		return # charging
	_clean_threat(world, m)
	if m.threat.is_empty():
		if m.ai != MonsterState.IDLE:
			_start_return(m)
			return
		var seen := _nearest_visible(world, m, float(m.def.get("aggro_range", 8.0)))
		if seen == null:
			return
		m.add_threat(seen.id, 1.0)
	if m.ai == MonsterState.IDLE:
		_alert_pack(world, m)
	if Effects.flat(m.position).distance_to(Effects.flat(m.home)) > float(m.def.get("leash_range", 20.0)):
		_start_return(m)
		return
	var target := _pick_target(world, m)
	if target == null:
		_start_return(m)
		return
	m.target_id = target.id
	var gap := Effects.flat(m.position).distance_to(Effects.flat(target.position)) - target.radius
	match str(m.def.get("behavior", "melee")):
		"ranged_kite":
			if gap < float(m.def.get("kite_range", 5.0)) and _back_away(world, m, target):
				m.ai = MonsterState.CHASE
				return
		"boss":
			_maybe_summon(world, m)
			if _try_jump(world, m, target, gap):
				m.ai = MonsterState.ATTACK
				return
		"charger":
			if _try_charge(world, m, target, gap):
				m.ai = MonsterState.ATTACK
				return
	var ranged := str(m.def.get("behavior", "")) == "ranged_kite"
	# Archers need a clear shot; otherwise they walk closer around the obstacle.
	if gap <= float(m.def.get("attack_range", 1.5)) and (not ranged or world.pathfinder().clear_line(m.position, target.position)):
		m.ai = MonsterState.ATTACK
		m.unreachable_ticks = 0
		var to := Effects.flat(target.position) - Effects.flat(m.position)
		if to.length() > 0.01:
			m.facing = atan2(to.x, to.y)
		for ab: String in m.def.get("abilities", []):
			if Combat.try_cast(world, m, ab, target.position):
				break
		return
	m.ai = MonsterState.CHASE
	if not _move_toward(world, m, target.position):
		m.unreachable_ticks += 1
		if m.unreachable_ticks > world.ticks(UNREACHABLE_S):
			_start_return(m)
	else:
		m.unreachable_ticks = 0


static func _valid_target(e: CombatEntity) -> bool:
	return e != null and e.team == CombatEntity.TEAM_PLAYERS and e.is_alive() and not e.has_status("stealth")


static func _clean_threat(world: SimWorld, m: MonsterState) -> void:
	for id: int in m.threat.keys():
		if not _valid_target(world.entity(id)):
			m.threat.erase(id)


static func _nearest_visible(world: SimWorld, m: MonsterState, reach: float) -> CombatEntity:
	var best: CombatEntity = null
	var best_d := INF
	for p: CombatEntity in world.players.values():
		if not _valid_target(p):
			continue
		var d := Effects.flat(p.position).distance_to(Effects.flat(m.position))
		# Only players it can see: nobody notices you through a wall.
		if d <= reach and d < best_d and world.pathfinder().clear_line(m.position, p.position):
			best = p
			best_d = d
	return best


static func _pick_target(world: SimWorld, m: MonsterState) -> CombatEntity:
	# Provocar: while taunted it attacks whoever taunted it, whatever the threat.
	for s: StatusEffect in m.statuses:
		if s.kind == "taunted":
			var taunter := world.entity(s.source_id)
			if _valid_target(taunter):
				if not m.threat.has(taunter.id):
					m.add_threat(taunter.id, 1.0)
				return taunter
	var current := world.entity(m.target_id) if m.threat.has(m.target_id) else null
	var best_id := -1
	var best_threat := -1.0
	for id: int in m.threat:
		if float(m.threat[id]) > best_threat:
			best_threat = m.threat[id]
			best_id = id
	if current != null and _valid_target(current):
		var current_threat := float(m.threat[m.target_id])
		if best_threat <= current_threat * (1.0 + world.balance.threat_switch_margin):
			return current
	return world.entity(best_id) if best_id >= 0 else null


## One tick of movement toward `goal`; false when there is no way to get there.
static func _move_toward(world: SimWorld, m: MonsterState, goal: Vector3) -> bool:
	var pf := world.pathfinder()
	var step := m.speed() / float(world.balance.tick_rate)
	if step <= 0.0:
		return true # rooted or stunned: not unreachable, just stuck for now
	var waypoint := Effects.flat(goal)
	if not pf.clear_line(m.position, goal):
		var goal_flat := Effects.flat(goal)
		if world.tick >= m.repath_tick or m.path_goal.distance_to(goal_flat) > 1.0:
			m.path = pf.path(m.position, goal)
			m.path_index = 0
			m.path_goal = goal_flat
			m.repath_tick = world.tick + world.ticks(REPATH_S)
		if m.path.is_empty():
			return false
		while m.path_index < m.path.size() - 1 and Effects.flat(m.position).distance_to(m.path[m.path_index]) < step:
			m.path_index += 1
		waypoint = m.path[mini(m.path_index, m.path.size() - 1)]
	var to := waypoint - Effects.flat(m.position)
	if to.length() < 0.001:
		return true
	var move := to.normalized() * minf(step, to.length())
	# Paths run through cell centres: bodies wider than half a cell would snag on
	# corners, so terrain collision uses at most TERRAIN_RADIUS (hits use m.radius).
	m.position = Movement.move_circle(m.position, move, minf(m.radius, TERRAIN_RADIUS), world.map)
	m.facing = atan2(to.x, to.y)
	return true


static func _start_return(m: MonsterState) -> void:
	m.ai = MonsterState.RETURN
	m.target_id = 0
	m.threat.clear()
	m.path = PackedVector2Array()
	m.path_goal = Vector2.INF
	m.unreachable_ticks = 0


static func _go_home(world: SimWorld, m: MonsterState) -> void:
	if Effects.flat(m.position).distance_to(Effects.flat(m.home)) <= HOME_ARRIVE:
		m.ai = MonsterState.IDLE
		m.hp = m.stats.max_hp
		m.statuses.clear()
		m.threat.clear()
		dismiss_minions(world, m)
		return
	if not _move_toward(world, m, m.home):
		m.position = m.home # walled in: never stay stuck away from home


## Wakes the idle pack mates (same type, within pack_radius) with this monster's threat.
static func _alert_pack(world: SimWorld, m: MonsterState) -> void:
	if not bool(m.def.get("pack", false)):
		return
	var reach := float(m.def.get("pack_radius", 10.0))
	for e: CombatEntity in world.monsters.values():
		var o := e as MonsterState
		if o == null or o == m or not o.is_alive() or o.type_id != m.type_id or o.ai != MonsterState.IDLE:
			continue
		if Effects.flat(o.position).distance_to(Effects.flat(m.position)) > reach:
			continue
		for id: int in m.threat:
			if not o.threat.has(id):
				o.add_threat(id, 1.0)


## Charger: starts the charge when the target is in the charge band and in sight.
static func _try_charge(world: SimWorld, m: MonsterState, target: CombatEntity, gap: float) -> bool:
	var c: Dictionary = m.def.get("charge", {})
	var id := str(c.get("ability", ""))
	if id == "" or gap < float(c.get("min_range", 3.0)) or gap > float(c.get("max_range", 8.0)):
		return false
	if not world.pathfinder().clear_line(m.position, target.position):
		return false
	if not Combat.try_cast(world, m, id, target.position):
		return false
	var windup := 0.0
	for eff: Dictionary in world.abilities.get_ability(id).get("effects", []):
		windup = maxf(windup, float(eff.get("windup_s", 0.0)))
	m.busy_until = world.tick + world.ticks(windup) + 1
	return true


## Ranged kiter: one step straight away from the target; false when it cannot move
## back (a wall), so it fights instead.
static func _back_away(world: SimWorld, m: MonsterState, target: CombatEntity) -> bool:
	var away := Effects.flat(m.position) - Effects.flat(target.position)
	if away.length() < 0.01:
		away = -Effects.forward(m.facing)
	var dir := away.normalized()
	var step := m.speed() / float(world.balance.tick_rate)
	if step <= 0.0:
		return false
	var before := m.position
	m.position = Movement.move_circle(m.position, dir * step, minf(m.radius, TERRAIN_RADIUS), world.map)
	if Effects.flat(m.position).distance_to(Effects.flat(before)) < step * 0.5:
		m.position = before
		return false
	m.facing = atan2(dir.x, dir.y)
	return true


## Boss phase for a health fraction: 1 above 66 %, 2 above 33 %, then 3.
static func phase_for(fraction: float) -> int:
	if fraction > 0.66:
		return 1
	if fraction > 0.33:
		return 2
	return 3


static func _update_phase(world: SimWorld, m: MonsterState) -> void:
	var p := phase_for(m.hp / maxf(m.stats.max_hp, 1.0))
	if p != m.phase:
		m.phase = p
		world.emit(["boss_phase", m.id, p])


## Boss leap: a warned area on the target; the boss lands there when it goes off.
static func _try_jump(world: SimWorld, m: MonsterState, target: CombatEntity, gap: float) -> bool:
	var j: Dictionary = m.def.get("jump", {})
	var id := str(j.get("ability", ""))
	if id == "" or m.phase < int(j.get("from_phase", 2)):
		return false
	# Centre to centre, the same distance the area is clamped to (never short of the
	# target, so never inside the wall it stands against), and only with a clear line.
	var dist := Effects.flat(m.position).distance_to(Effects.flat(target.position))
	if gap < float(j.get("min_range", 4.0)) or dist > minf(float(j.get("max_range", 14.0)), float(world.abilities.get_ability(id).get("range", 14.0))):
		return false
	if not world.pathfinder().clear_line(m.position, target.position):
		return false
	if not Combat.try_cast(world, m, id, target.position):
		return false
	var delay := 0.0
	for eff: Dictionary in world.abilities.get_ability(id).get("effects", []):
		delay = maxf(delay, float(eff.get("delay_s", 0.0)))
	m.busy_until = world.tick + world.ticks(delay) + 1
	return true


## Boss call: `count` monsters of summon.type around it, fighting its targets.
static func _maybe_summon(world: SimWorld, m: MonsterState) -> void:
	var s: Dictionary = m.def.get("summon", {})
	if s.is_empty() or m.phase < int(s.get("from_phase", 3)) or world.tick < m.next_summon_tick:
		return
	m.next_summon_tick = world.tick + world.ticks(float(s.get("every_s", 20.0)))
	m.minions = m.minions.filter(func(id: int) -> bool:
		var e := world.entity(id)
		return e != null and e.is_alive())
	var room := int(s.get("max_alive", 6)) - m.minions.size()
	var count := mini(int(s.get("count", 3)), room)
	for i in count:
		var a := TAU * float(i) / float(maxi(count, 1)) + m.facing
		var pos := m.position + Vector3(sin(a), 0, cos(a)) * (m.radius + 1.5)
		if world.map.is_solid(Vector2i(floori(pos.x), floori(pos.z))):
			pos = m.position
		var g := MonsterDB.load_default().make(str(s.get("type", "goblin")), world.next_monster_id(), pos, world)
		Spawner.scale_health(world, g, 1.0)
		for pid: int in m.threat:
			g.add_threat(pid, 1.0)
		world.add_entity(g)
		m.minions.append(g.id)
		world.emit(["spawned", g.id, g.type_id, g.position])


## A boss's called monsters leave with it (reset at home, or its death): they never
## respawn, so they would otherwise pile up between attempts.
static func dismiss_minions(world: SimWorld, m: MonsterState) -> void:
	for id: int in m.minions:
		if world.monsters.has(id):
			world.remove_entity(id)
	m.minions.clear()
	m.next_summon_tick = 0
