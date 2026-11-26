class_name Spawner
extends RefCounted
## Keeps the map's spawn points populated: spawns `count` monsters around each point,
## removes corpses after CORPSE_S (clients play the death) and respawns each one
## respawn_s after it died. Monster health scales with the group size.
## Hordes (Plan 8.1): an area kept full of `count` monsters of weighted types, each at a
## random level of the band (or the dungeon instance level); every dead one comes back
## respawn_s (8 s) after its death, one by one, so there is always something to hunt.

const CORPSE_S := 2.0
const PLACE_TRIES := 12
const HORDE_RESPAWN_S := 8.0

var points: Array = []
## Per point: ticks at which a monster is due.
var _due: Array = []
var hordes: Array = []
## Per horde: ticks at which a monster is due.
var _horde_due: Array = []


func _init(spawns: Array, p_hordes: Array = []) -> void:
	hordes = p_hordes
	for h: Dictionary in hordes:
		var hdue: Array = []
		for i in int(h.get("count", 1)):
			hdue.append(0)
		_horde_due.append(hdue)
	points = spawns
	for p: Dictionary in points:
		var due: Array = []
		for i in int(p.get("count", 1)):
			due.append(0)
		_due.append(due)


func tick(world: SimWorld) -> void:
	for e: CombatEntity in world.monsters.values():
		var m := e as MonsterState
		if m == null or m.is_alive():
			continue
		if m.died_tick < 0:
			m.died_tick = world.tick
		elif world.tick - m.died_tick >= world.ticks(CORPSE_S):
			world.remove_entity(m.id)
			if m.horde_index >= 0 and m.horde_index < _horde_due.size():
				if not bool((hordes[m.horde_index] as Dictionary).get("respawn", true)):
					continue # a story horde (Plan 8.2): once killed, it is gone
				var hr := float((hordes[m.horde_index] as Dictionary).get("respawn_s", HORDE_RESPAWN_S))
				(_horde_due[m.horde_index] as Array).append(m.died_tick + world.ticks(hr))
			elif m.spawn_index >= 0 and m.spawn_index < _due.size():
				var respawn := float(points[m.spawn_index].get("respawn_s", 30.0))
				if bool(m.def.get("boss", false)):
					respawn = world.balance.boss_respawn_s
				(_due[m.spawn_index] as Array).append(m.died_tick + world.ticks(respawn))
	for i in points.size():
		if not _story_open(world, points[i]):
			continue # waits for the story (Plan 8.3d: the assault's foes come after the awakening)
		var due: Array = _due[i]
		var keep: Array = []
		for t: int in due:
			if t <= world.tick:
				_spawn(world, i)
			else:
				keep.append(t)
		_due[i] = keep
	for i in hordes.size():
		if not _story_open(world, hordes[i]):
			continue
		var hdue: Array = _horde_due[i]
		var hkeep: Array = []
		for t: int in hdue:
			if t <= world.tick:
				_spawn_horde(world, i)
			else:
				hkeep.append(t)
		_horde_due[i] = hkeep


## True when a horde or spawn point has no "requires", or some player here has all its flags.
static func _story_open(world: SimWorld, d: Dictionary) -> bool:
	var flags: Array = (d.get("requires", {}) as Dictionary).get("flags", []) if d.get("requires") is Dictionary else []
	if flags.is_empty():
		return true
	for p: PlayerState in world.players.values():
		if flags.all(func(fl: Variant) -> bool: return p.quests.has_flag(str(fl))):
			return true
	return false


## A monster that left without dying (a boss that fled, Plan 8.3a) comes back like a dead
## one: so a story fight is never lost by fleeing before its step.
func left(world: SimWorld, m: MonsterState) -> void:
	if m.horde_index >= 0 and m.horde_index < _horde_due.size():
		if bool((hordes[m.horde_index] as Dictionary).get("respawn", true)):
			(_horde_due[m.horde_index] as Array).append(world.tick + world.ticks(float((hordes[m.horde_index] as Dictionary).get("respawn_s", HORDE_RESPAWN_S))))
	elif m.spawn_index >= 0 and m.spawn_index < _due.size():
		(_due[m.spawn_index] as Array).append(world.tick + world.ticks(float(points[m.spawn_index].get("respawn_s", 30.0))))


func _spawn(world: SimWorld, index: int) -> void:
	var p: Dictionary = points[index]
	var at: Array = p.get("at", [0, 0])
	var center := Vector3(float(at[0]) + 0.5, 0, float(at[1]) + 0.5)
	var radius := float(p.get("radius", 0.0))
	var pos := center
	for attempt in PLACE_TRIES:
		var a := world.rng.randf_range(0.0, TAU)
		var r := world.rng.randf_range(0.0, radius)
		var c := center + Vector3(sin(a) * r, 0, cos(a) * r)
		if not world.map.is_solid(Vector2i(floori(c.x), floori(c.z))):
			pos = c
			break
	var type_id := str(p.get("type", ""))
	var level := world.monster_level(p, MonsterDB.load_default().get_type(type_id))
	var m := MonsterDB.load_default().make(type_id, world.next_monster_id(), pos, world, level)
	m.spawn_index = index
	if not bool(m.def.get("boss", false)) and world.rng.randf() < float(p.get("elite_chance", 0.0)):
		MonsterDB.make_elite(m, world.balance)
	scale_health(world, m, 1.0)
	world.add_entity(m)
	world.emit(["spawned", m.id, m.type_id, m.position])


func _spawn_horde(world: SimWorld, index: int) -> void:
	var h: Dictionary = hordes[index]
	var a: Array = h.get("area", [0, 0, 1, 1])
	var pos := Vector3(float(a[0]) + 0.5, 0, float(a[1]) + 0.5)
	for attempt in PLACE_TRIES:
		var c := Vector3(world.rng.randf_range(float(a[0]), float(a[0]) + float(a[2])), 0,
			world.rng.randf_range(float(a[1]), float(a[1]) + float(a[3])))
		if not world.map.is_solid(Vector2i(floori(c.x), floori(c.z))):
			pos = c
			break
	var type_id := _pick_type(world, h.get("monsters", []))
	if type_id == "":
		return
	var band: Array = h.get("levels", [1, 1])
	var level := world.instance_level if world.instance_level > 0 else world.rng.randi_range(int(band[0]), int(band[1]))
	var m := MonsterDB.load_default().make(type_id, world.next_monster_id(), pos, world, level)
	m.horde_index = index
	if world.rng.randf() < float(h.get("elite_chance", 0.0)):
		MonsterDB.make_elite(m, world.balance)
	scale_health(world, m, 1.0)
	world.add_entity(m)
	world.emit(["spawned", m.id, m.type_id, m.position])


## A type id by weight from [[type, weight], ...].
static func _pick_type(world: SimWorld, list: Array) -> String:
	var total := 0.0
	for e: Array in list:
		total += float(e[1])
	var roll := world.rng.randf() * total
	for e: Array in list:
		roll -= float(e[1])
		if roll <= 0.0:
			return str(e[0])
	return str(list.back()[0]) if not list.is_empty() else ""


## Sets max health for the current group size, keeping `fraction` of it as health.
static func scale_health(world: SimWorld, m: MonsterState, fraction: float) -> void:
	var players := maxi(1, world.players.size())
	m.stats.max_hp = m.base_max_hp * (1.0 + world.balance.group_hp_scale * (players - 1))
	m.hp = m.stats.max_hp * clampf(fraction, 0.0, 1.0)
