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

const REPATH_S := 0.5
const UNREACHABLE_S := 3.0
const HOME_ARRIVE := 0.5


static func tick(world: SimWorld, m: MonsterState) -> void:
	if not m.is_alive():
		return
	if m.ai == MonsterState.RETURN:
		_go_home(world, m)
		return
	_clean_threat(world, m)
	if m.threat.is_empty():
		if m.ai != MonsterState.IDLE:
			_start_return(m)
			return
		var seen := _nearest_visible(world, m, float(m.def.get("aggro_range", 8.0)))
		if seen == null:
			return
		m.add_threat(seen.id, 1.0)
	if Effects.flat(m.position).distance_to(Effects.flat(m.home)) > float(m.def.get("leash_range", 20.0)):
		_start_return(m)
		return
	var target := _pick_target(world, m)
	if target == null:
		_start_return(m)
		return
	m.target_id = target.id
	var gap := Effects.flat(m.position).distance_to(Effects.flat(target.position)) - target.radius
	if gap <= float(m.def.get("attack_range", 1.5)):
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
	m.position = Movement.move_circle(m.position, move, m.radius, world.map)
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
		return
	if not _move_toward(world, m, m.home):
		m.position = m.home # walled in: never stay stuck away from home
