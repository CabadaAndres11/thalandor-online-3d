class_name ZoneMapImage
extends RefCounted
## The picture of a zone for the map (M) and the minimap (Plan 8.1.1): the ground by
## colour, houses, rocks and trees from above, and the marks drawn over it (you, your
## party, the NPCs, the ways out and the dungeon doors).

## Pixels per cell (metre).
const PX := 4
const HOUSE := Color("#8a5a3a")
const PIECE := Color("#5d4a38")
const TREE := Color("#2f5a2a")
const ROCK := Color("#77736b")
const TREES := ["tree_oak", "tree_pine", "bush", "stump"]
const ROCKS := ["rock_small", "rock_large", "crypt_wall", "crypt_pillar", "crypt_arch"]

static var _zone_graph: Dictionary = {}
static var _instanced: Dictionary = {} # zone id -> instanced (exits that lead to dungeons)


static func make(layout: ZoneLayout, px: int = PX) -> Image:
	var img := Image.create(layout.size.x * px, layout.size.y * px, false, Image.FORMAT_RGBA8)
	var cells := ZoneView.ground_cells_of(layout)
	for c: Vector2i in cells:
		var col: Color = ZoneView.GROUND.get(cells[c], ZoneView.GROUND.grass)
		img.fill_rect(Rect2i(c * px, Vector2i(px, px)), col)
	for p: Dictionary in layout.pieces:
		var id := str(p.id)
		if id in TREES:
			var at: Vector2i = p.at
			var r := px if id != "bush" else px / 2
			img.fill_rect(Rect2i(at * px + Vector2i(px / 2 - r, px / 2 - r), Vector2i(r * 2, r * 2)).intersection(Rect2i(Vector2i.ZERO, img.get_size())), TREE)
			continue
		var col := ROCK if id in ROCKS else PIECE
		for c: Vector2i in layout.footprint(id, p.at, p.rot):
			if Rect2i(Vector2i.ZERO, layout.size).has_point(c):
				img.fill_rect(Rect2i(c * px, Vector2i(px, px)), col)
	if layout.band > 0: # the edge band: thick forest
		for x in layout.size.x:
			for z in layout.size.y:
				if layout.in_band(Vector2i(x, z)):
					img.fill_rect(Rect2i(Vector2i(x, z) * px, Vector2i(px, px)), TREE)
	for h: Dictionary in layout.houses:
		for c: Vector2i in layout.footprint(h.id, h.at, h.rot) + h.cells:
			img.fill_rect(Rect2i(c * px, Vector2i(px, px)), HOUSE)
	return img


## [{kind: "self"|"partner"|"npc"|"exit"|"dungeon", cell: Vector2, label, yaw}] in cells.
static func markers(layout: ZoneLayout, client: ClientSession) -> Array:
	var out := []
	var npcs := NpcDB.load_default()
	for n: Dictionary in layout.npcs:
		if bool(npcs.npc(str(n.id)).get("minor", false)):
			continue # townsfolk and vendors are not marked (2026-11-27)
		out.append({"kind": "npc", "cell": Vector2(float(n.at[0]) + 0.5, float(n.at[1]) + 0.5),
			"label": tr_key(str(npcs.npc(str(n.id)).get("name", n.id))), "yaw": 0.0})
	for e: Dictionary in layout.exits:
		var r: Rect2i = e.area
		var to := str(e.to)
		out.append({"kind": "dungeon" if _is_instanced(to) else "exit", "cell": Vector2(r.position) + Vector2(r.size) / 2.0,
			"label": tr_key("ZONE_" + to.to_upper()), "yaw": 0.0})
	if client != null:
		var target := quest_target(layout, client.quests, QuestDB.load_default())
		if not target.is_empty():
			out.append({"kind": "quest", "cell": target.get("at", target.get("exit", Vector2.ZERO)), "label": "", "yaw": 0.0})
		var wanted := QuestText.target_monsters(client.quests, QuestDB.load_default())
		if not wanted.is_empty():
			for mid: int in client.monsters:
				if not str(client.monsters[mid].get("type", "")) in wanted or int(client.monsters[mid].get("hp", 0)) <= 0:
					continue
				var ms := client.monster_render_state(mid)
				if not ms.is_empty():
					out.append({"kind": "foe", "cell": Vector2(ms.position.x, ms.position.z), "label": "", "yaw": 0.0})
		for id: int in client.roster:
			var rs := client.render_state(id)
			if rs.is_empty():
				continue
			var pos: Vector3 = rs.position
			out.append({"kind": "self" if id == client.my_id else "partner", "cell": Vector2(pos.x, pos.z),
				"label": str(client.roster[id].get("name", "")), "yaw": float(rs.get("facing", 0.0))})
	return out


## Where the tracked objective is on this zone's map (Plan 8.2): {at} (a cell centre) when it
## is here, {exit} (the way out toward its zone) when it is elsewhere, {} when unknown.
static func quest_target(layout: ZoneLayout, log: QuestLog, quests: QuestDB) -> Dictionary:
	var id := log.tracked
	if layout == null or id == "" or not log.is_active(id):
		return {}
	var objs := QuestText.objectives(log, quests, id)
	var q := quests.quest(id)
	var targets: Array = []
	for i in objs.size():
		var o: Dictionary = objs[i]
		if int(log.active[id].counts[i]) >= int(o.count):
			continue
		targets.append(o)
	if objs.is_empty():
		targets.append({"type": "talk", "npc": str(q.turn_in)})
	for o: Dictionary in targets:
		var zone := str(o.get("zone", ""))
		if zone == "" and o.has("npc") and not _npc_here(layout, str(o.npc)):
			zone = _zone_of_npc(str(o.npc)) # a talk objective in another zone
		if zone != "" and zone != layout.id:
			var toward := _exit_toward(layout.id, zone)
			for e: Dictionary in layout.exits:
				if str(e.to) == toward:
					var r: Rect2i = e.area
					return {"exit": Vector2(r.position) + Vector2(r.size) / 2.0}
			continue
		if str(o.type) in ["reach", "interact"] and layout.quest_points.has(str(o.get("point", ""))):
			var at: Vector2i = layout.quest_points[str(o.point)].at
			return {"at": Vector2(at.x + 0.5, at.y + 0.5)}
		if o.has("npc"):
			for n: Dictionary in layout.npcs:
				if str(n.id) == str(o.npc):
					return {"at": Vector2(float(n.at[0]) + 0.5, float(n.at[1]) + 0.5)}
	return {}


static func _npc_here(layout: ZoneLayout, npc: String) -> bool:
	for n: Dictionary in layout.npcs:
		if str(n.id) == npc:
			return true
	return false


## Zone ids -> {exits: [zone ids], npcs: [npc ids]}, read once from data/zones (not instanced ones).
static func _graph() -> Dictionary:
	if _zone_graph.is_empty():
		var dir := DirAccess.open(ZoneLayout.DIR)
		if dir != null:
			for f: String in dir.get_files():
				if not f.ends_with(".json") or f == "pieces.json":
					continue
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.DIR + f))
				if not d is Dictionary:
					continue
				var zid := f.get_basename()
				var ex := []
				for e: Dictionary in d.get("exits", []):
					ex.append(str(e.to))
				var np := []
				for n: Dictionary in d.get("npcs", []):
					np.append(str(n.id))
				_zone_graph[zid] = {"exits": ex, "npcs": np}
	return _zone_graph


static func _zone_of_npc(npc: String) -> String:
	var g := _graph()
	for zid: String in g:
		if npc in g[zid].npcs:
			return zid
	return ""


## The neighbour of `from` on the shortest way to `to` ("" when there is none).
static func _exit_toward(from: String, to: String) -> String:
	var g := _graph()
	var first := {} # zone -> the neighbour of from it was reached through
	var queue := [from]
	first[from] = ""
	while not queue.is_empty():
		var z: String = queue.pop_front()
		if not g.has(z):
			continue
		for nx: String in g[z].exits:
			if first.has(nx):
				continue
			first[nx] = nx if z == from else first[z]
			if nx == to:
				return first[nx]
			queue.append(nx)
	return ""


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


static func _is_instanced(zone_id: String) -> bool:
	if not _instanced.has(zone_id):
		var z := ZoneLayout.load_id(zone_id) if FileAccess.file_exists(ZoneLayout.DIR + zone_id + ".json") else null
		_instanced[zone_id] = z != null and z.instanced
	return _instanced[zone_id]
