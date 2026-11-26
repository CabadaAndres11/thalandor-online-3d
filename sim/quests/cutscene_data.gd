class_name CutsceneData
extends RefCounted
## Cutscenes as data (Plan 8.2): data/cutscenes/<id>.json. Actors (an NPC by id, a monster
## by type, the player, or a loose look), and tracks of steps that run side by side:
## camera, move, pose, line, wait, fade, ambience, show, hide, shake, fx. "stage" is "here"
## (where the player stands), "player" (cells counted from the player, Plan 8.3a) or {zone,
## variant} for scenes away from the player ([ANIMACIÓN]). A line spoken by "" is narration.

const DIR := "res://data/cutscenes/"
const STEP_KEYS := ["camera", "move", "pose", "line", "wait", "fade", "ambience", "show", "hide", "shake", "fx"]
const POSES := ["idle", "melee", "shoot", "cast", "cast_long", "heavy", "thrust", "stab", "pray", "downed", "die", "dash", "kneel", "point", "lie"]
const FX := ["fire", "smoke", "flash", "embers", "blood"]

## Where cutscenes are read from (tests point it at their own).
static var dir: String = DIR


static func ids() -> Array:
	var out: Array = []
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				out.append(f.get_basename())
	out.sort()
	return out


static func load_id(id: String) -> Dictionary:
	var path := dir.path_join(id + ".json")
	if id == "" or not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


static func validate(id: String) -> Array[String]:
	var d := load_id(id)
	if d.is_empty():
		return ["%s: no existe o no se puede leer" % id] as Array[String]
	return validate_dict(d)


## The kind of step: the first of STEP_KEYS it has ("" if none).
static func kind_of(step: Dictionary) -> String:
	for k: String in STEP_KEYS:
		if step.has(k):
			return k
	return ""


static func validate_dict(d: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := str(d.get("id", "?"))
	var actors: Dictionary = d.get("actors", {}) if d.get("actors") is Dictionary else {}
	var err := func(msg: String) -> void: errors.append("%s: %s" % [id, msg])
	for name: String in actors:
		var a: Dictionary = actors[name]
		if a.has("npc") and NpcDB.load_default().npc(str(a.npc)).is_empty():
			err.call("PNJ desconocido '%s'" % a.npc)
		if a.has("monster") and MonsterDB.load_default().get_type(str(a.monster)).is_empty():
			err.call("monstruo desconocido '%s'" % a.monster)
	var stage: Variant = d.get("stage", "here")
	if stage is Dictionary:
		var z := ZoneLayout.load_id(str(stage.get("zone", "")))
		if z == null:
			err.call("zona desconocida '%s'" % stage.get("zone", ""))
		elif str(stage.get("variant", "")) != "" and not z.has_variant(str(stage.variant)):
			err.call("variante desconocida '%s'" % stage.variant)
	var actor_ok := func(n: String) -> bool: return n == "player" or actors.has(n)
	for track: Variant in d.get("tracks", []):
		for s: Variant in track if track is Array else []:
			if not s is Dictionary:
				err.call("paso mal formado")
				continue
			var step: Dictionary = s
			match kind_of(step):
				"":
					err.call("paso sin tipo %s" % step)
				"move":
					if not actor_ok.call(str(step.move)):
						err.call("actor desconocido '%s'" % step.move)
				"pose":
					if not actor_ok.call(str(step.pose[0])):
						err.call("actor desconocido '%s'" % step.pose[0])
					if not str(step.pose[1]) in POSES:
						err.call("pose desconocida '%s'" % step.pose[1])
				"line":
					var who := str(step.line[0])
					if who != "player" and who != "" and not actors.has(who) and NpcDB.load_default().npc(who).is_empty() \
							and MonsterDB.load_default().get_type(who).is_empty(): # a monster speaks by its type
						err.call("quién habla '%s'" % who)
					if TranslationServer.translate(str(step.line[1])) == str(step.line[1]):
						err.call("texto sin traducir '%s'" % step.line[1])
				"ambience":
					if not str(step.ambience) in Ambience.ids():
						err.call("ambiente desconocido '%s'" % step.ambience)
				"show", "hide":
					var n := str(step.get("show", step.get("hide", "")))
					if not actor_ok.call(n):
						err.call("actor desconocido '%s'" % n)
				"fx":
					if not str(step.fx) in FX:
						err.call("efecto desconocido '%s'" % step.fx)
	return errors
