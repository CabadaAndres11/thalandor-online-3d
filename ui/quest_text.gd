class_name QuestText
extends RefCounted
## How quests read on screen (Plan 8.2): objective lines with their counts, shared by the
## tracker and the journal, and which quest points the local player should see.


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## The objectives of a quest's current step for this log ([] when ready to turn in).
static func objectives(log: QuestLog, quests: QuestDB, id: String) -> Array:
	var q := quests.quest(id)
	if q.is_empty() or not log.is_active(id):
		return []
	var step := int(log.active[id].step)
	return q.steps[step].objectives if step < (q.steps as Array).size() else []


## One line per objective of the current step, e.g. "Lobo cazador 3/5".
static func objective_lines(log: QuestLog, quests: QuestDB, id: String, bag: Inventory) -> Array:
	var out: Array = []
	var objs := objectives(log, quests, id)
	if objs.is_empty() and log.is_active(id):
		var q := quests.quest(id)
		var npc := NpcDB.load_default().npc(str(q.turn_in))
		return [_tr("UI_QUEST_TURN_IN") % _tr(str(npc.get("name", q.turn_in)))]
	for i in objs.size():
		var o: Dictionary = objs[i]
		var have := int(log.active[id].counts[i])
		var need := int(o.count)
		var line := ""
		match str(o.type):
			"kill":
				line = "%s %d/%d" % [_tr(str(MonsterDB.load_default().get_type(str(o.monster)).get("name", o.monster))), have, need]
			"collect":
				have = mini(need, bag.count_of(str(o.item)) if bag != null else have)
				line = "%s %d/%d" % [_tr(str(ItemDB.load_default().base(str(o.item)).get("name", o.item))), have, need]
			"talk", "deliver":
				var npc := NpcDB.load_default().npc(str(o.npc))
				line = _tr("UI_QUEST_TALK" if str(o.type) == "talk" else "UI_QUEST_DELIVER") % _tr(str(npc.get("name", o.npc)))
			"reach", "interact":
				line = _tr(str(o.get("label", "UI_QUEST_REACH" if str(o.type) == "reach" else "UI_QUEST_EXAMINE")))
			"hit", "hit_secondary":
				line = "%s %d/%d" % [_tr("UI_QUEST_HIT_SECONDARY" if str(o.type) == "hit_secondary" else "UI_QUEST_HIT") % _tr(str(MonsterDB.load_default().get_type(str(o.monster)).get("name", o.monster))), have, need]
			"dodge":
				line = "%s %d/%d" % [_tr("UI_QUEST_DODGE"), have, need]
			"class":
				line = _tr("UI_QUEST_CLASS")
		# The tutorial says it its own way (Plan 8.3a): a label with the count when there is one.
		if o.has("label") and not str(o.type) in ["reach", "interact"]:
			line = _tr(str(o.label)) + (" %d/%d" % [have, need] if need > 1 else "")
		if line != "":
			out.append(("✓ " if have >= need else "") + line)
	return out


## The text of the step being done (or of the last one when all are done).
static func step_text(log: QuestLog, quests: QuestDB, id: String) -> String:
	var q := quests.quest(id)
	if q.is_empty() or not log.is_active(id):
		return ""
	var step := mini(int(log.active[id].step), (q.steps as Array).size() - 1)
	return _tr(str(q.steps[step].get("text", "")))


## The quest points of a zone the local player has an objective for right now.
static func visible_points(points: Dictionary, log: QuestLog, quests: QuestDB, zone_id: String) -> Array:
	var out: Array = []
	for id: String in log.active:
		var objs := objectives(log, quests, id)
		for i in objs.size():
			var o: Dictionary = objs[i]
			if not str(o.type) in ["reach", "interact"] or int(log.active[id].counts[i]) >= int(o.count):
				continue
			if o.has("zone") and str(o.zone) != zone_id:
				continue
			var pt := str(o.get("point", ""))
			if points.has(pt) and not pt in out:
				out.append(pt)
	return out


## An interact point the local player can examine from `pos` ("" if none).
static func interact_point_near(points: Dictionary, log: QuestLog, quests: QuestDB, zone_id: String, pos: Vector3) -> String:
	for id: String in log.active:
		for o: Dictionary in objectives(log, quests, id):
			if str(o.type) != "interact" or (o.has("zone") and str(o.zone) != zone_id):
				continue
			var pt: Variant = points.get(str(o.get("point", "")))
			if pt != null and Vector2(pos.x - (pt.at.x + 0.5), pos.z - (pt.at.y + 0.5)).length() <= maxf(QuestRules.INTERACT_RANGE, float(pt.radius)):
				return str(o.point)
	return ""
