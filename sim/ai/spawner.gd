class_name Spawner
extends RefCounted
## Keeps the map's spawn points populated: spawns `count` monsters around each point,
## removes corpses after CORPSE_S (clients play the death) and respawns each one
## respawn_s after it died. Monster health scales with the group size.

const CORPSE_S := 2.0
const PLACE_TRIES := 12

var points: Array = []
## Per point: ticks at which a monster is due.
var _due: Array = []


func _init(spawns: Array) -> void:
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
			if m.spawn_index >= 0 and m.spawn_index < _due.size():
				var respawn := float(points[m.spawn_index].get("respawn_s", 30.0))
				(_due[m.spawn_index] as Array).append(m.died_tick + world.ticks(respawn))
	for i in points.size():
		var due: Array = _due[i]
		var keep: Array = []
		for t: int in due:
			if t <= world.tick:
				_spawn(world, i)
			else:
				keep.append(t)
		_due[i] = keep


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
	var m := MonsterDB.load_default().make(str(p.get("type", "")), world.next_monster_id(), pos, world)
	m.spawn_index = index
	if world.rng.randf() < float(p.get("elite_chance", 0.0)):
		MonsterDB.make_elite(m, world.balance)
	scale_health(world, m, 1.0)
	world.add_entity(m)
	world.emit(["spawned", m.id, m.type_id, m.position])


## Sets max health for the current group size, keeping `fraction` of it as health.
static func scale_health(world: SimWorld, m: MonsterState, fraction: float) -> void:
	var players := maxi(1, world.players.size())
	m.stats.max_hp = m.base_max_hp * (1.0 + world.balance.group_hp_scale * (players - 1))
	m.hp = m.stats.max_hp * clampf(fraction, 0.0, 1.0)
