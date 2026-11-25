class_name QuestLog
extends RefCounted
## A character's quests (Plan 8.2): the active ones with their step and objective counts,
## the finished ones, the story flags and the character marks the story set (tutorial_done).
## Saved in the character file; the host owns it while playing (PlayerState.quests).

const MAX_FLAGS := 512
const MAX_TEXT := 64

## id -> {step: int, counts: Array[int]} (one count per objective of the current step).
var active: Dictionary = {}
var done: Array = []
var flags: Array = []
var marks: Array = []
## The quest shown in the HUD tracker ("" for none).
var tracked: String = ""


func is_active(id: String) -> bool:
	return active.has(id)


func is_done(id: String) -> bool:
	return id in done


func has_flag(f: String) -> bool:
	return f in flags


func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "done": done.duplicate(), "flags": flags.duplicate(),
		"marks": marks.duplicate(), "tracked": tracked}


func duplicate() -> QuestLog:
	var l := QuestLog.new()
	l.active = active.duplicate(true)
	l.done = done.duplicate()
	l.flags = flags.duplicate()
	l.marks = marks.duplicate()
	l.tracked = tracked
	return l


static func _texts(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for s: Variant in v:
			if s is String and (s as String) != "" and (s as String).length() <= MAX_TEXT and not s in out:
				out.append(s)
				if out.size() >= MAX_FLAGS:
					break
	return out


## A sanitized log from anything (a save may be old, hand-edited or from another version of
## the data): unknown quests and past-the-end steps are dropped, counts are clamped.
static func from_dict(v: Variant, db: QuestDB) -> QuestLog:
	var l := QuestLog.new()
	if not v is Dictionary:
		return l
	var d: Dictionary = v
	var raw_active: Variant = d.get("active", {})
	if raw_active is Dictionary:
		for id: Variant in raw_active:
			var q := db.quest(str(id))
			var st: Variant = raw_active[id]
			if q.is_empty() or not st is Dictionary:
				continue
			var step: Variant = (st as Dictionary).get("step", 0)
			if not (step is int or step is float) or int(step) < 0 or int(step) > (q.steps as Array).size():
				continue
			var objs: Array = q.steps[int(step)].objectives if int(step) < (q.steps as Array).size() else []
			var raw_counts: Variant = (st as Dictionary).get("counts", [])
			var counts: Array = []
			for i in objs.size():
				var c: Variant = (raw_counts as Array)[i] if raw_counts is Array and i < (raw_counts as Array).size() else 0
				counts.append(clampi(int(c) if (c is int or c is float) else 0, 0, int(objs[i].count)))
			l.active[str(id)] = {"step": int(step), "counts": counts}
	l.done = _texts(d.get("done")).filter(func(id: String) -> bool: return not db.quest(id).is_empty() and not l.active.has(id))
	l.flags = _texts(d.get("flags"))
	l.marks = _texts(d.get("marks"))
	var t: Variant = d.get("tracked", "")
	l.tracked = t if t is String and l.active.has(t) else ""
	return l
