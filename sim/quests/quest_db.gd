class_name QuestDB
extends RefCounted
## Quests as data (Plan 8.2): data/quests/<id>.json. Each quest has ordered steps; a step
## holds objectives that may be done in any order. Objectives are normalized on load
## (count defaults to 1) so the rules never guess. validate() names every broken reference.

const DIR := "res://data/quests/"
const TYPES := ["talk", "deliver", "kill", "collect", "reach", "interact", "scene", "choice", "hit", "hit_secondary", "dodge", "class"]

static var _default: QuestDB
var _by_id: Dictionary = {}
var _order: Array = []


static func load_default() -> QuestDB:
	if _default == null:
		_default = load_dir(DIR)
	return _default


static func load_dir(dir: String) -> QuestDB:
	var db := QuestDB.new()
	if not DirAccess.dir_exists_absolute(dir):
		return db
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if d is Dictionary and str((d as Dictionary).get("id", "")) != "":
			db._add(_normalize(d))
	return db


## Adds a quest given as a dictionary (tests build their own).
func add(d: Dictionary) -> void:
	_add(_normalize(d))


func _add(q: Dictionary) -> void:
	if not _by_id.has(q.id):
		_order.append(q.id)
	_by_id[q.id] = q


static func _normalize(d: Dictionary) -> Dictionary:
	var q := d.duplicate(true)
	q.id = str(q.id)
	q["story"] = bool(q.get("story", false))
	q["auto"] = bool(q.get("auto", false))
	q["giver"] = str(q.get("giver", ""))
	q["turn_in"] = str(q.get("turn_in", q.giver))
	for k in ["requires", "on_done", "rewards", "dialogues"]:
		if not q.get(k) is Dictionary:
			q[k] = {}
	var steps: Array = []
	for s: Variant in q.get("steps", []):
		if not s is Dictionary:
			continue
		var step: Dictionary = (s as Dictionary).duplicate(true)
		if not step.get("on_done") is Dictionary:
			step["on_done"] = {}
		var objs: Array = []
		for o: Variant in step.get("objectives", []):
			if o is Dictionary:
				var ob: Dictionary = (o as Dictionary).duplicate(true)
				ob["type"] = str(ob.get("type", ""))
				ob["count"] = maxi(1, int(ob.get("count", 1)))
				objs.append(ob)
		step["objectives"] = objs
		steps.append(step)
	q["steps"] = steps
	return q


func quest(id: String) -> Dictionary:
	return _by_id.get(id, {})


func ids() -> Array:
	return _order.duplicate()


func by_giver(npc: String) -> Array:
	return _order.filter(func(id: String) -> bool: return _by_id[id].giver == npc)


func by_turn_in(npc: String) -> Array:
	return _order.filter(func(id: String) -> bool: return _by_id[id].turn_in == npc)


static func _has_text(key: String) -> bool:
	return key != "" and TranslationServer.translate(key) != key


## Problems in the data, as readable lines (empty when everything is fine).
func validate(npcs: NpcDB, monsters: MonsterDB, items: ItemDB, zones_dir: String, dialogues_dir: String,
		cutscenes_dir: String) -> Array[String]:
	var errors: Array[String] = []
	var zone_points := {} # zone id -> {point id: true} (null when the zone does not exist)
	var point_ok := func(zone: String, point: String) -> bool:
		if not zone_points.has(zone):
			var path := zones_dir.path_join(zone + ".json")
			var pts := {}
			if FileAccess.file_exists(path):
				var z: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if z is Dictionary:
					for p: Variant in (z as Dictionary).get("quest_points", []):
						if p is Dictionary:
							pts[str(p.get("id", ""))] = true
					for v: Variant in ((z as Dictionary).get("variants", {}) as Dictionary).values():
						for p: Variant in (v as Dictionary).get("quest_points", []) if v is Dictionary else []:
							if p is Dictionary:
								pts[str(p.get("id", ""))] = true
				zone_points[zone] = pts
			else:
				zone_points[zone] = null
		return zone_points[zone] != null and (zone_points[zone] as Dictionary).has(point)
	var npc_ok := func(id: String) -> bool: return not npcs.npc(id).is_empty()
	var file_ok := func(dir: String, id: String) -> bool: return id != "" and FileAccess.file_exists(dir.path_join(id + ".json"))
	for id: String in _order:
		var q: Dictionary = _by_id[id]
		var err := func(msg: String) -> void: errors.append("%s: %s" % [id, msg])
		for k in ["name", "summary"]:
			if not _has_text(str(q.get(k, ""))):
				err.call("texto sin traducir '%s'" % q.get(k, ""))
		if q.giver != "" and not npc_ok.call(q.giver):
			err.call("PNJ desconocido '%s'" % q.giver)
		if q.turn_in != "" and not npc_ok.call(q.turn_in):
			err.call("PNJ desconocido '%s'" % q.turn_in)
		if q.steps.is_empty():
			err.call("sin pasos")
		for prev: Variant in (q.requires as Dictionary).get("quests", []):
			if not _by_id.has(str(prev)):
				err.call("misión previa desconocida '%s'" % prev)
		for dk: String in (q.dialogues as Dictionary):
			if not file_ok.call(dialogues_dir, str(q.dialogues[dk])):
				err.call("diálogo desconocido '%s'" % q.dialogues[dk])
		var dones: Array = [q.on_done]
		for step: Dictionary in q.steps:
			dones.append(step.on_done)
			if not _has_text(str(step.get("text", ""))):
				err.call("texto sin traducir '%s'" % step.get("text", ""))
			for o: Dictionary in step.objectives:
				var t: String = o.type
				if not t in TYPES:
					err.call("tipo de objetivo desconocido '%s'" % t)
					continue
				if t in ["talk", "deliver", "interact"] or o.has("npc"):
					if t != "interact" and not npc_ok.call(str(o.get("npc", ""))):
						err.call("PNJ desconocido '%s'" % o.get("npc", ""))
				if o.has("dialogue") and not file_ok.call(dialogues_dir, str(o.dialogue)):
					err.call("diálogo desconocido '%s'" % o.dialogue)
				if t in ["kill", "collect", "hit", "hit_secondary"]:
					var m := str(o.get("monster", o.get("from", "")))
					if monsters.get_type(m).is_empty():
						err.call("monstruo desconocido '%s'" % m)
				if t in ["collect", "deliver"]:
					if not items.is_quest(str(o.get("item", ""))):
						err.call("objeto de misión desconocido '%s'" % o.get("item", ""))
				if t in ["reach", "interact"] and not point_ok.call(str(o.get("zone", "")), str(o.get("point", ""))):
					err.call("punto de misión desconocido '%s' en '%s'" % [o.get("point", ""), o.get("zone", "")])
				if t == "scene" and not file_ok.call(cutscenes_dir, str(o.get("scene", ""))):
					err.call("escena desconocida '%s'" % o.get("scene", ""))
				if t == "choice" and (o.get("any_flag", []) as Array).is_empty():
					err.call("elección sin marcas (any_flag)")
		for od: Dictionary in dones:
			if od.get("scene") != null and str(od.get("scene", "")) != "" and not file_ok.call(cutscenes_dir, str(od.scene)):
				err.call("escena desconocida '%s'" % od.scene)
			if str(od.get("next", "")) != "" and not _by_id.has(str(od.next)):
				err.call("misión siguiente desconocida '%s'" % od.next)
		for it: Variant in (q.rewards as Dictionary).get("items", []) + (q.rewards as Dictionary).get("choice", []):
			if items.base(str(it)).is_empty():
				err.call("objeto desconocido '%s'" % it)
	return errors
