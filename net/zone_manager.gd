class_name ZoneManager
extends RefCounted
## The host's zones (Plan 8.1): one SimWorld per open zone or dungeon instance, keyed by
## the zone id ("bosque") or, for an instance, "<zone>#<group>@<level>". Only the worlds
## with players step; an empty one sleeps (keeps its monsters, its tick stands still) and
## catches its tick up when someone comes back. An instance closes CLOSE_IDLE_S after it
## empties. A player is the same PlayerState in whichever world it stands.

const CLOSE_IDLE_S := 300.0

var balance: Balance
## Where zone ids are looked up (tests point it at their own zones).
var zone_dir: String = ZoneLayout.DIR
## The world the host started with (the zone of its map).
var start_key: String = ""
## Seconds the host has run, for closing idle instances.
var time_s: float = 0.0
## The host's tick: every stepping world is brought to it.
var tick: int = 0

var _seed: int
var _worlds: Dictionary = {} # key -> SimWorld
var _layouts: Dictionary = {} # key -> ZoneLayout (null for a world made from a bare map)
var _occupants: Dictionary = {} # key -> Array of player ids
var _empty_since: Dictionary = {} # key -> time_s it emptied (instances only)


func _init(p_balance: Balance, p_seed: int) -> void:
	balance = p_balance
	_seed = p_seed


## Makes a world from a map the host was given (its start zone).
func adopt(map: CollisionMap, layout: ZoneLayout = null) -> String:
	var key := map.zone_id if map.zone_id != "" else "start"
	if layout == null and map.zone_id != "" and FileAccess.file_exists(zone_dir + map.zone_id + ".json"):
		layout = ZoneLayout.load_path(zone_dir + map.zone_id + ".json") # its exits and entries
	_worlds[key] = SimWorld.new(balance, map, _seed)
	_layouts[key] = layout
	_occupants[key] = []
	if start_key == "":
		start_key = key
	return key


## Opens a zone (or returns it if already open) and gives its key; "" if it does not exist.
## An instanced zone gets its own world per instance id and level.
func open(zone_id: String, instance: String = "", level: int = 0) -> String:
	var layout := ZoneLayout.load_path(zone_dir + zone_id + ".json") if FileAccess.file_exists(zone_dir + zone_id + ".json") else null
	if layout == null:
		return ""
	var key := zone_id
	if layout.instanced:
		key = "%s#%s@%d" % [zone_id, instance, level]
	if _worlds.has(key):
		return key
	var w := SimWorld.new(balance, layout.collision(), _seed + hash(key))
	w.tick = tick
	if layout.instanced:
		w.instance_level = level
	_worlds[key] = w
	_layouts[key] = layout
	_occupants[key] = []
	if layout.instanced:
		_empty_since[key] = time_s
	return key


func world(key: String) -> SimWorld:
	return _worlds.get(key)


func layout(key: String) -> ZoneLayout:
	return _layouts.get(key)


func keys() -> Array:
	return _worlds.keys()


func occupants(key: String) -> Array:
	return _occupants.get(key, [])


func is_instance(key: String) -> bool:
	return key.contains("#")


## Adds a new player to a world at `at`.
func add_player(id: int, key: String, at: Vector3) -> PlayerState:
	var w := world(key)
	_wake(key)
	var p := w.add_player(id, at)
	(_occupants[key] as Array).append(id)
	return p


func remove_player(id: int, key: String) -> void:
	var w := world(key)
	if w == null:
		return
	w.remove_player(id)
	_leave(id, key)


## Moves a player's state from one world to another (the same object), standing at `at`.
func move(id: int, from_key: String, to_key: String, at: Vector3) -> PlayerState:
	var from := world(from_key)
	var to := world(to_key)
	var p: PlayerState = from.players.get(id)
	if p == null or to == null:
		return p
	from.remove_player(id)
	_leave(id, from_key)
	_wake(to_key)
	p.position = at
	p.aim = at
	p.target_id = 0
	to.players[id] = p
	to.rescale_monsters()
	(_occupants[to_key] as Array).append(id)
	return p


## Steps every world with players, each with its players' inputs.
func step_occupied(inputs_by_key: Dictionary) -> void:
	tick += 1
	time_s += 1.0 / float(balance.tick_rate)
	for key: String in _worlds:
		if not (_occupants[key] as Array).is_empty():
			(_worlds[key] as SimWorld).step(inputs_by_key.get(key, {}))


## Closes instances empty since CLOSE_IDLE_S before `now_s`.
func close_idle(now_s: float) -> void:
	for key: String in _empty_since.keys():
		if (_occupants[key] as Array).is_empty() and now_s - float(_empty_since[key]) > CLOSE_IDLE_S:
			_worlds.erase(key)
			_layouts.erase(key)
			_occupants.erase(key)
			_empty_since.erase(key)


func _leave(id: int, key: String) -> void:
	var occ: Array = _occupants.get(key, [])
	occ.erase(id)
	if occ.is_empty() and is_instance(key):
		_empty_since[key] = time_s


## A sleeping world catches its tick up before it runs again (timers keep their sense).
func _wake(key: String) -> void:
	var w := world(key)
	if (_occupants[key] as Array).is_empty() and w.tick < tick:
		w.tick = tick
