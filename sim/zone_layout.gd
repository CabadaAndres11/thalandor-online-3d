class_name ZoneLayout
extends RefCounted
## A zone of the world as data (Plan 8.1, data/zones/<id>.json): its size, ground, the
## pieces placed on it (houses, trees, rocks from data/zones/pieces.json, each with the
## cells it blocks), scattered fill (a forest), paths kept clear, NPCs, exits to other
## zones, named entries, hordes and monster points. collision() turns it into the
## CollisionMap the simulation and the client prediction walk on.

const DIR := "res://data/zones/"
const PIECES_PATH := "res://data/zones/pieces.json"
## Exits and entries keep this many cells around them free of scattered pieces.
const CLEAR_RADIUS := 2
## sim/ does not know the visual Ambience class: the same default id.
const DEFAULT_AMBIENCE := "exterior_dia"

var id: String = ""
var name: String = ""
var size: Vector2i = Vector2i.ZERO
var ambience: String = DEFAULT_AMBIENCE
var levels: Vector2i = Vector2i.ZERO
var safe: bool = false
var instanced: bool = false
## Placed pieces, the scatter already expanded: {id, at: Vector2i, rot: int (degrees)}.
var pieces: Array = []
## Ground: {"base": kind, "areas": [{kind, area: [x, z, w, d]}]}; paths add their cells.
var terrain: Dictionary = {}
var paths: Array = []
var npcs: Array = []
## {area: Rect2i, to: zone id, entry: entry name}
var exits: Array = []
## entry name -> Vector2i
var entries: Dictionary = {}
var respawn: Vector2i = Vector2i.ZERO
var hordes: Array = []
var spawns: Array = []
var torches: Array = []
## Old-style solid cells ([x, z, height]) of the test arena.
var blocks: Array = []
## What could not be understood ("unknown piece dragon_statue").
var errors: Array = []

static var _pieces_cache: Dictionary = {}
var _piece_defs: Dictionary = {}
var _road: Dictionary = {} # Vector2i -> true: path cells (nothing is scattered on them)


static func load_id(zone_id: String) -> ZoneLayout:
	return load_path(DIR + zone_id + ".json")


static func load_path(path: String, pieces_path: String = PIECES_PATH) -> ZoneLayout:
	if not FileAccess.file_exists(path):
		push_warning("ZoneLayout: no zone at " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ZoneLayout: bad JSON in " + path)
		return null
	var z := from_dict(path.get_file().get_basename(), parsed, pieces_path)
	for e: String in z.errors:
		push_error("ZoneLayout %s: %s" % [z.id, e])
	return z


static func from_dict(zone_id: String, d: Dictionary, pieces_path: String = PIECES_PATH) -> ZoneLayout:
	var z := ZoneLayout.new()
	z.id = zone_id
	z._piece_defs = _load_pieces(pieces_path)
	z.name = str(d.get("name", ""))
	z.size = _v2i(d.get("size", [0, 0]))
	z.ambience = str(d.get("ambience", DEFAULT_AMBIENCE))
	z.levels = _v2i(d.get("levels", [0, 0]))
	z.safe = bool(d.get("safe", false))
	z.instanced = bool(d.get("instanced", false))
	z.terrain = d.get("terrain", {"base": "grass", "areas": []})
	z.paths = d.get("paths", [])
	z.npcs = (d.get("npcs", []) as Array).duplicate(true)
	z.hordes = d.get("hordes", [])
	z.spawns = d.get("spawns", [])
	z.torches = d.get("torches", [])
	z.blocks = d.get("blocks", [])
	for k: String in d.get("entries", {}):
		z.entries[k] = _v2i(d.entries[k])
	if not z.entries.has("default"):
		z.entries["default"] = _v2i(d.get("spawn", [0, 0])) # the test arena's old key
	z.respawn = _v2i(d.get("respawn", d.get("respawn_point", [z.entries.default.x, z.entries.default.y])))
	for e: Dictionary in d.get("exits", []):
		var a: Array = e.get("area", [0, 0, 1, 1])
		z.exits.append({"area": Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), "to": str(e.get("to", "")),
			"entry": str(e.get("entry", "default"))})
	for p: Dictionary in z.paths:
		for c: Vector2i in path_cells(p):
			z._road[c] = true
	for p: Dictionary in d.get("pieces", []):
		z._place(str(p.get("id", "")), _v2i(p.get("at", [0, 0])), int(p.get("rot", 0)))
	for s: Dictionary in d.get("scatter", []):
		z._scatter(s)
	return z


## The cells a path covers: a polyline of cell points, `width` cells wide.
static func path_cells(p: Dictionary) -> Array:
	var out: Array = []
	var pts: Array = p.get("points", [])
	var half := int(p.get("width", 1)) / 2
	for i in range(pts.size() - 1):
		var a := _v2i(pts[i])
		var b := _v2i(pts[i + 1])
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in steps + 1:
			var t := float(s) / maxf(float(steps), 1.0)
			var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
			for dx in range(-half, half + 1):
				for dz in range(-half, half + 1):
					out.append(c + Vector2i(dx, dz))
	return out


## The cells a piece blocks at `at`, turned `rot` degrees (90° steps: (dx, dz) -> (-dz, dx)).
func footprint(piece_id: String, at: Vector2i, rot: int) -> Array:
	var out: Array = []
	var turns := posmod(roundi(rot / 90.0), 4)
	for f: Array in (_piece_defs.get(piece_id, {}) as Dictionary).get("footprint", []):
		var c := Vector2i(int(f[0]), int(f[1]))
		for i in turns:
			c = Vector2i(-c.y, c.x)
		out.append(at + c)
	return out


func piece_def(piece_id: String) -> Dictionary:
	return _piece_defs.get(piece_id, {})


func collision() -> CollisionMap:
	var map := CollisionMap.new()
	map.zone_id = id
	map.size = size
	map.spawn_cell = entries.default
	map.respawn_cell = respawn
	map.spawns = spawns
	map.hordes = hordes
	map.npcs = npcs.duplicate(true)
	for p: Dictionary in pieces:
		for c: Vector2i in footprint(p.id, p.at, p.rot):
			map.set_solid(c, true)
	for a: Dictionary in terrain.get("areas", []):
		if str(a.get("kind", "")) == "water":
			var r: Array = a.get("area", [0, 0, 0, 0])
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				for z in range(int(r[1]), int(r[1]) + int(r[3])):
					map.set_solid(Vector2i(x, z), true)
	for b: Array in blocks:
		map.set_solid(Vector2i(int(b[0]), int(b[1])), true)
	return map


func entry(entry_name: String) -> Vector3:
	var c: Vector2i = entries.get(entry_name, entries.default)
	return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


## The exit whose area holds `pos`, or {}.
func exit_at(pos: Vector3) -> Dictionary:
	var c := Vector2i(floori(pos.x), floori(pos.z))
	for e: Dictionary in exits:
		if (e.area as Rect2i).has_point(c):
			return e
	return {}


func _place(piece_id: String, at: Vector2i, rot: int) -> void:
	if not _piece_defs.has(piece_id):
		errors.append("unknown piece " + piece_id)
		return
	pieces.append({"id": piece_id, "at": at, "rot": rot})


func _scatter(s: Dictionary) -> void:
	var r: Array = s.get("area", [0, 0, 0, 0])
	var kinds: Array = s.get("pieces", [])
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("seed", 1))
	var density := float(s.get("density", 0.1))
	var taken := {}
	for p: Dictionary in pieces:
		for c: Vector2i in footprint(p.id, p.at, p.rot):
			taken[c] = true
	var keep_clear: Array = entries.values()
	for e: Dictionary in exits:
		keep_clear.append((e.area as Rect2i).get_center())
	for x in range(int(r[0]), int(r[0]) + int(r[2])):
		for z in range(int(r[1]), int(r[1]) + int(r[3])):
			var c := Vector2i(x, z)
			var roll := rng.randf()
			var kind := str(kinds[rng.randi_range(0, kinds.size() - 1)])
			var rot := rng.randi_range(0, 3) * 90
			if roll >= density or _road.has(c) or taken.has(c) or _near_any(c, keep_clear):
				continue
			if not _piece_defs.has(kind):
				errors.append("unknown piece " + kind)
				return
			var cells := footprint(kind, c, rot)
			if cells.any(func(k: Vector2i) -> bool: return taken.has(k) or _road.has(k)):
				continue
			for k: Vector2i in cells:
				taken[k] = true
			pieces.append({"id": kind, "at": c, "rot": rot})


static func _near_any(c: Vector2i, points: Array) -> bool:
	for p: Vector2i in points:
		if absi(p.x - c.x) <= CLEAR_RADIUS and absi(p.y - c.y) <= CLEAR_RADIUS:
			return true
	return false


static func _load_pieces(path: String) -> Dictionary:
	if not _pieces_cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_pieces_cache[path] = parsed if parsed is Dictionary else {}
	return _pieces_cache[path]


static func _v2i(a: Variant) -> Vector2i:
	if a is Array and (a as Array).size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO
