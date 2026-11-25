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
## Nothing is scattered this close to an exit area, so every way out (a crypt door in the
## woods) can be seen from afar (Plan 8.1.1).
const EXIT_CLEAR := 6
## Cells of decorated, never walkable land drawn around a zone (Plan 8.1.1; deeper in
## 8.1.2 so the camera never sees past it).
const MARGIN := 30
## The last cells inside an outdoor zone are a thick band of trees, never walked but by
## the path of each way out (Plan 8.1.2).
const BAND := 10
## A way out triggers this many cells before the edge, inside its path.
const EXIT_DEPTH := 5
const MARGIN_KINDS := {
	"forest": ["tree_oak", "tree_pine", "tree_pine", "tree_oak", "rock_large"],
	"rock": ["crypt_wall", "crypt_wall", "rock_large"],
}
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
## Quest points (Plan 8.2): id -> {at: Vector2i, radius: float, look: String}.
var quest_points: Dictionary = {}
## Variants of this zone for story moments (raw data) and the one applied ("" for the base).
var variants: Dictionary = {}
var variant: String = ""
var _raw: Dictionary = {}
var _pieces_path: String = PIECES_PATH
var _zone_dir: String = DIR
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
## What is suspicious but not broken ("exit to unknown zone atlantis").
var warnings: Array = []
## Walkable houses placed (Plan 8.1.1), in placing order: {index, id, at, rot,
## cells: Array (world interior cells), door: Array (world door cells)}.
var houses: Array = []
var _house_cells: Dictionary = {} # Vector2i -> house index
## Pieces outside the map (a thick tree line or rock), drawn only: {id, at, rot}.
var margin_pieces: Array = []
## Depth of the edge band (0: none, as in dungeons) and the paths through it.
var band: int = 0
var _paths_out: Array = [] # Rect2i
## A signpost and two torches at each way out on the zone's edge: {at, to, rot, exit}.
var exit_markers: Array = []

static var _pieces_cache: Dictionary = {}
var _piece_defs: Dictionary = {}
var _road: Dictionary = {} # Vector2i -> true: path cells (nothing is scattered on them)


static func load_id(zone_id: String) -> ZoneLayout:
	return load_path(DIR + zone_id + ".json")


## A zone with a story variant applied (Plan 8.2); the base zone when the variant is "" or unknown.
static func load_variant(zone_id: String, variant: String) -> ZoneLayout:
	var z := load_id(zone_id)
	if z == null or variant == "" or not z.has_variant(variant):
		return z
	return z.apply_variant(variant)


static func load_path(path: String, pieces_path: String = PIECES_PATH) -> ZoneLayout:
	if not FileAccess.file_exists(path):
		push_warning("ZoneLayout: no zone at " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ZoneLayout: bad JSON in " + path)
		return null
	var z := from_dict(path.get_file().get_basename(), parsed, pieces_path, path.get_base_dir() + "/")
	for e: String in z.errors:
		push_error("ZoneLayout %s: %s" % [z.id, e])
	for w: String in z.warnings:
		push_warning("ZoneLayout %s: %s" % [z.id, w])
	return z


static func from_dict(zone_id: String, d: Dictionary, pieces_path: String = PIECES_PATH, zone_dir: String = DIR) -> ZoneLayout:
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
	z._raw = d
	z._pieces_path = pieces_path
	z._zone_dir = zone_dir
	z.variants = d.get("variants", {}) if d.get("variants") is Dictionary else {}
	for qp: Variant in d.get("quest_points", []):
		if qp is Dictionary and str((qp as Dictionary).get("id", "")) != "":
			z.quest_points[str(qp.id)] = {"at": _v2i(qp.get("at", [0, 0])), "radius": float(qp.get("radius", 2.0)),
				"look": str(qp.get("look", ""))}
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
	var margin_kind := str(d.get("margin", "rock" if z.instanced else "forest"))
	# Zones that say "margin": "forest" end in a band of trees inside the map (Plan 8.1.2).
	z.band = int(d.get("band", BAND if str(d.get("margin", "")) == "forest" else 0))
	z._open_paths()
	z._add_exit_markers()
	for s: Dictionary in d.get("scatter", []):
		z._scatter(s)
	if margin_kind != "none":
		z._add_margin(margin_kind)
	var monsters := MonsterDB.load_default()
	for h: Dictionary in z.hordes:
		for m: Variant in h.get("monsters", []):
			if m is Array and not (m as Array).is_empty() and monsters.get_type(str(m[0])).is_empty():
				z.errors.append("unknown monster " + str(m[0]))
	for sp: Dictionary in z.spawns:
		if monsters.get_type(str(sp.get("type", ""))).is_empty():
			z.errors.append("unknown monster " + str(sp.get("type", "")))
	for e: Dictionary in z.exits:
		if not FileAccess.file_exists(zone_dir + str(e.to) + ".json"):
			z.warnings.append("exit to unknown zone " + str(e.to))
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
	return cells_of(piece_id, "footprint", at, rot)


## A list of relative cells of a piece's data ("footprint", "interior", "door"), placed
## at `at` and turned like its footprint.
func cells_of(piece_id: String, key: String, at: Vector2i, rot: int) -> Array:
	var out: Array = []
	for f: Array in (_piece_defs.get(piece_id, {}) as Dictionary).get(key, []):
		out.append(at + turn(Vector2i(int(f[0]), int(f[1])), rot))
	return out


## A relative cell turned `rot` degrees ((dx, dz) -> (-dz, dx) per 90°).
static func turn(c: Vector2i, rot: int) -> Vector2i:
	for i in posmod(roundi(rot / 90.0), 4):
		c = Vector2i(-c.y, c.x)
	return c


## The house whose inside holds `cell` (its index in houses), or -1.
func house_at(cell: Vector2i) -> int:
	return int(_house_cells.get(cell, -1))


func piece_def(piece_id: String) -> Dictionary:
	return _piece_defs.get(piece_id, {})


func has_variant(name: String) -> bool:
	return variants.has(name) and variants[name] is Dictionary


## A new layout: this zone with a variant applied (null if there is no such variant). A
## variant replaces the ambience, NPCs, hordes or respawn, adds pieces and quest points, and
## removes pieces by id and cell ("remove_pieces": [{id, at}]).
func apply_variant(name: String) -> ZoneLayout:
	if not has_variant(name):
		return null
	var v: Dictionary = variants[name]
	var d := _raw.duplicate(true)
	for k in ["ambience", "npcs", "hordes", "respawn", "spawns", "torches"]:
		if v.has(k):
			d[k] = v[k]
	var gone: Array = v.get("remove_pieces", [])
	d["pieces"] = (d.get("pieces", []) as Array).filter(func(p: Dictionary) -> bool:
		return not gone.any(func(g: Dictionary) -> bool:
			return str(g.get("id", "")) == str(p.get("id", "")) and _v2i(g.get("at", [-1, -1])) == _v2i(p.get("at", [0, 0]))))
	d["pieces"] += (v.get("add_pieces", []) as Array).duplicate(true)
	d["quest_points"] = (d.get("quest_points", []) as Array) + (v.get("quest_points", []) as Array).duplicate(true)
	var z := from_dict(id, d, _pieces_path, _zone_dir)
	z.variant = name
	return z


func collision() -> CollisionMap:
	var map := CollisionMap.new()
	map.zone_id = id
	map.size = size
	map.spawn_cell = entries.default
	map.respawn_cell = respawn
	map.spawns = spawns
	map.hordes = hordes
	map.npcs = npcs.duplicate(true)
	map.quest_points = quest_points.duplicate(true)
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
	if band > 0:
		for x in size.x:
			for zz in size.y:
				if in_band(Vector2i(x, zz)):
					map.set_solid(Vector2i(x, zz), true)
	return map


## How far a cell is from the zone's edge (0 on the edge).
func depth(c: Vector2i) -> int:
	return mini(mini(c.x, c.y), mini(size.x - 1 - c.x, size.y - 1 - c.y))


## Inside the edge band and off every path out.
func in_band(c: Vector2i) -> bool:
	if band <= 0 or c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y or depth(c) >= band:
		return false
	for r: Rect2i in _paths_out:
		if r.has_point(c):
			return false
	return true


## Inside the map and not in the edge band (pieces and water aside).
func walkable(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y and not in_band(c)


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
	if (_piece_defs[piece_id] as Dictionary).has("interior"):
		var h := {"index": houses.size(), "id": piece_id, "at": at, "rot": rot,
			"cells": cells_of(piece_id, "interior", at, rot), "door": cells_of(piece_id, "door", at, rot)}
		for c: Vector2i in h.cells:
			_house_cells[c] = h.index
		houses.append(h)


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
	for h: Dictionary in houses: # the inside, the door and the cell in front of it stay free
		for c: Vector2i in h.cells + h.door:
			taken[c] = true
		for c: Vector2i in h.door:
			taken[c + turn(Vector2i(0, 1), h.rot)] = true
	var keep_clear: Array = entries.values()
	for e: Dictionary in exits:
		keep_clear.append((e.area as Rect2i).get_center())
	for x in range(int(r[0]), int(r[0]) + int(r[2])):
		for z in range(int(r[1]), int(r[1]) + int(r[3])):
			var c := Vector2i(x, z)
			var roll := rng.randf()
			var kind := str(kinds[rng.randi_range(0, kinds.size() - 1)])
			var rot := rng.randi_range(0, 3) * 90
			if roll >= density or _road.has(c) or taken.has(c) or _near_any(c, keep_clear) or _near_exit(c) or in_band(c):
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


## The inward direction of an exit on the zone's edge (ZERO for one inside the map).
func exit_inward(area: Rect2i) -> Vector2i:
	if area.end.x >= size.x:
		return Vector2i(-1, 0)
	if area.position.x <= 0:
		return Vector2i(1, 0)
	if area.end.y >= size.y:
		return Vector2i(0, -1)
	if area.position.y <= 0:
		return Vector2i(0, 1)
	return Vector2i.ZERO


## With an edge band, each way out on the edge becomes a path through it, as wide as the
## exit, and the exit triggers EXIT_DEPTH cells before the edge (Plan 8.1.2).
func _open_paths() -> void:
	if band <= 0:
		return
	for e: Dictionary in exits:
		var r: Rect2i = e.area
		var inward := exit_inward(r)
		if inward == Vector2i.ZERO:
			continue
		if inward.x != 0:
			var x0 := 0 if inward.x > 0 else size.x - band
			var t0 := 0 if inward.x > 0 else size.x - EXIT_DEPTH
			_paths_out.append(Rect2i(x0, r.position.y, band, r.size.y))
			e.area = Rect2i(t0, r.position.y, EXIT_DEPTH, r.size.y)
		else:
			var z0 := 0 if inward.y > 0 else size.y - band
			var t1 := 0 if inward.y > 0 else size.y - EXIT_DEPTH
			_paths_out.append(Rect2i(r.position.x, z0, r.size.x, band))
			e.area = Rect2i(r.position.x, t1, r.size.x, EXIT_DEPTH)


func _add_exit_markers() -> void:
	for i in exits.size():
		var r: Rect2i = exits[i].area
		var inward := exit_inward(r)
		if inward == Vector2i.ZERO:
			continue
		# The exit's inner line (with a band, the mouth of its path), and the two cells
		# just beyond its ends along that line.
		var a: Vector2i
		var b: Vector2i
		if inward.x != 0:
			var x := r.position.x if inward.x < 0 else r.end.x - 1
			if band > 0:
				x = band if inward.x > 0 else size.x - 1 - band
			a = Vector2i(x, r.position.y - 1)
			b = Vector2i(x, r.end.y)
		else:
			var zz := r.position.y if inward.y < 0 else r.end.y - 1
			if band > 0:
				zz = band if inward.y > 0 else size.y - 1 - band
			a = Vector2i(r.position.x - 1, zz)
			b = Vector2i(r.end.x, zz)
		torches.append([a.x, a.y])
		torches.append([b.x, b.y])
		var sign := a + inward + (a - b).sign()
		if _piece_defs.has("signpost"): # (test piece tables have none)
			_place("signpost", sign, 0)
		exit_markers.append({"at": sign, "to": str(exits[i].to), "rot": 0, "exit": i})


## A thick band of trees (or rock) around the map, denser near the edge, leaving the
## way out of each exit open; seeded by the zone id so it never changes.
func _add_margin(kind: String) -> void:
	var kinds: Array = MARGIN_KINDS.get(kind, MARGIN_KINDS.forest)
	if not _piece_defs.has(str(kinds[0])):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + "#margin")
	var open := []
	for e: Dictionary in exits:
		var r: Rect2i = e.area
		if exit_inward(r) != Vector2i.ZERO:
			open.append(r.grow(1))
	for x in range(-MARGIN, size.x + MARGIN):
		for zz in range(-MARGIN, size.y + MARGIN):
			var c := Vector2i(x, zz)
			var inside := x >= 0 and zz >= 0 and x < size.x and zz < size.y
			if inside and not in_band(c):
				continue
			var ring := maxi(maxi(-x, x - size.x + 1), maxi(-zz, zz - size.y + 1))
			var density := 0.85 if inside else (0.9 if ring <= 4 else (0.6 if ring <= 12 else 0.4))
			var roll := rng.randf()
			var piece := str(kinds[rng.randi_range(0, kinds.size() - 1)])
			var rot := rng.randi_range(0, 3) * 90
			if roll >= density or (not inside and _in_way_out(c, open)):
				continue
			margin_pieces.append({"id": piece, "at": c, "rot": rot})


## Outside the map in line with an exit (its rows or columns, one more on each side).
func _in_way_out(c: Vector2i, open: Array) -> bool:
	for r: Rect2i in open:
		var inward := exit_inward(r.grow(-1))
		if inward.x != 0 and c.y >= r.position.y and c.y < r.end.y and (c.x < 0 if inward.x > 0 else c.x >= size.x):
			return true
		if inward.y != 0 and c.x >= r.position.x and c.x < r.end.x and (c.y < 0 if inward.y > 0 else c.y >= size.y):
			return true
	return false


func _near_exit(c: Vector2i) -> bool:
	for e: Dictionary in exits:
		if (e.area as Rect2i).grow(EXIT_CLEAR).has_point(c):
			return true
	return false


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
