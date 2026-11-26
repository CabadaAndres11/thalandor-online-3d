class_name NpcTalk
extends RefCounted
## What an NPC says to one player (Plan 8.2), from that player's quest log only: handing in
## a finished quest first, then a talk or delivery objective with that NPC, then a quest to
## offer, then the quest in progress, then the NPC's own "talk" entries, then a greeting.
## mark() is the sign over its head: "?" (something to hand in or say), "!" (a quest for
## you), "!grey" (one for you at a higher level) or "".


## {dialogue, quest, kind}: kind turn_in | talk | offer | progress | npc | greet.
static func pick(npc_id: String, log: QuestLog, level: int, class_id: String, quests: QuestDB) -> Dictionary:
	for id: String in quests.by_turn_in(npc_id):
		if _ready(log, quests.quest(id), id):
			return {"dialogue": str((quests.quest(id).dialogues as Dictionary).get("turn_in", "")), "quest": id, "kind": "turn_in"}
	for id: String in log.active:
		var q := quests.quest(id)
		var step := int(log.active[id].step)
		if q.is_empty() or step >= (q.steps as Array).size():
			continue
		var objs: Array = q.steps[step].objectives
		for i in objs.size():
			var o: Dictionary = objs[i]
			if str(o.type) in ["talk", "deliver"] and str(o.get("npc", "")) == npc_id and int(log.active[id].counts[i]) < int(o.count):
				return {"dialogue": str(o.get("dialogue", "")), "quest": id, "kind": "talk"}
	for id: String in quests.by_giver(npc_id):
		var q := quests.quest(id)
		if not bool(q.auto) and QuestRules.requirements_met(q, log, level, class_id) and not log.is_active(id) and not log.is_done(id):
			return {"dialogue": str((q.dialogues as Dictionary).get("offer", "")), "quest": id, "kind": "offer"}
	for id: String in log.active:
		var q := quests.quest(id)
		if not q.is_empty() and (q.giver == npc_id or q.turn_in == npc_id) and (q.dialogues as Dictionary).has("progress"):
			return {"dialogue": str(q.dialogues.progress), "quest": id, "kind": "progress"}
	var entry := talk_entry(NpcDB.load_default().npc(npc_id), log, quests)
	if entry != "":
		return {"dialogue": entry, "quest": "", "kind": "npc"}
	return {"dialogue": "", "quest": "", "kind": "greet"}


static func _ready(log: QuestLog, q: Dictionary, id: String) -> bool:
	return not q.is_empty() and log.is_active(id) and int(log.active[id].step) >= (q.steps as Array).size()


static func mark(npc_id: String, log: QuestLog, level: int, class_id: String, quests: QuestDB) -> String:
	var k := str(pick(npc_id, log, level, class_id, quests).kind)
	if k in ["turn_in", "talk"]:
		return "?"
	if k == "offer":
		return "!"
	for id: String in quests.by_giver(npc_id):
		var q := quests.quest(id)
		if bool(q.auto) or log.is_active(id) or log.is_done(id) or QuestRules.requirements_met(q, log, level, class_id):
			continue
		if QuestRules.requirements_met(q, log, PlayerProgress.MAX_LEVEL, class_id):
			return "!grey" # only the level is missing
	return ""


## The first of an NPC's "talk" entries whose condition holds ("" if none).
static func talk_entry(npc: Dictionary, log: QuestLog, quests: QuestDB) -> String:
	for e: Variant in npc.get("talk", []):
		if e is Dictionary and _when(e.get("when", {}), log, quests):
			return str(e.get("dialogue", ""))
	return ""


static func _when(w: Variant, log: QuestLog, quests: QuestDB) -> bool:
	if not w is Dictionary:
		return true
	var c: Dictionary = w
	for f: Variant in c.get("flags", []):
		if not log.has_flag(str(f)):
			return false
	for f: Variant in c.get("not_flags", []):
		if log.has_flag(str(f)):
			return false
	if c.has("quest"):
		var id := str(c.quest)
		var state := "done" if log.is_done(id) else ("ready" if _ready(log, quests.quest(id), id) else ("active" if log.is_active(id) else "none"))
		var want := str(c.get("state", "active"))
		if want == "active" and state == "ready":
			state = "active"
		if state != want:
			return false
		if c.has("step") and (not log.is_active(id) or int(log.active[id].step) != int(c.step)):
			return false
	return true
