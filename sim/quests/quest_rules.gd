class_name QuestRules
extends RefCounted
## How quests advance (Plan 8.2), on the host. Killing, collecting and reaching places count
## for every nearby player with that objective (the experience share range); talking,
## examining, scenes and choices only for whoever does them, after the host checked them.
## A quest whose steps are all done waits at step == steps.size() to be turned in.
## Events for the host: quest_started, quest_step, quest_ready, quest_done [player, id(, step)],
## quest_scene [player, scene], quest_moment [player, zone, variant], quest_bag_full [player].

## How far a quest point can be examined from (meters, on the ground).
const INTERACT_RANGE := 2.5
## How often reach objectives are checked (seconds).
const REACH_EVERY_S := 0.5

## Positions compared by step_reach (tests check that nobody pays for nothing).
static var reach_checks: int = 0


static func _db(world: SimWorld) -> QuestDB:
	return world.quests if world.quests != null else QuestDB.load_default()


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Starting ---

static func can_start(world: SimWorld, p: PlayerState, id: String) -> bool:
	var q := _db(world).quest(id)
	if q.is_empty() or p.quests.is_active(id) or p.quests.is_done(id):
		return false
	return requirements_met(q, p.quests, p.progress.level, p.class_id)


## A quest's requirements for this log, level and class (clients use it for the NPC marks).
static func requirements_met(q: Dictionary, log: QuestLog, level: int, class_id: String) -> bool:
	if q.is_empty():
		return false
	var r: Dictionary = q.requires
	for prev: Variant in r.get("quests", []):
		if not log.is_done(str(prev)):
			return false
	if level < int(r.get("level", 1)):
		return false
	var classes: Array = r.get("classes", [])
	if not classes.is_empty() and not class_id in classes:
		return false
	for fl: Variant in r.get("flags", []):
		if not log.has_flag(str(fl)):
			return false
	for fl: Variant in r.get("not_flags", []):
		if log.has_flag(str(fl)):
			return false
	return true


static func start(world: SimWorld, p: PlayerState, id: String) -> bool:
	if not can_start(world, p, id):
		return false
	var q := _db(world).quest(id)
	p.quests.active[id] = {"step": 0, "counts": _zeros(q, 0)}
	if p.quests.tracked == "":
		p.quests.tracked = id
	p.quests_dirty = true
	world.emit(["quest_started", p.id, id])
	_give(world, p, q)
	if q.get("moment") is Dictionary:
		world.emit(["quest_moment", p.id, str(q.moment.get("zone", "")), str(q.moment.get("variant", ""))])
	_refresh(world, p, id)
	return true


## The quest items a quest (when it starts) or a step's on_done hands over ("give": [[base, count], ...]).
static func _give(world: SimWorld, p: PlayerState, d: Dictionary) -> void:
	for g: Variant in d.get("give", []):
		if not g is Array or (g as Array).is_empty() or world.items.base(str(g[0])).is_empty():
			continue
		var it := ItemRoll.new_item(str(g[0]), maxi(1, int(world.items.base(str(g[0])).get("min_level", 1))))
		it.count = maxi(1, int(g[1])) if (g as Array).size() > 1 else 1
		if p.inventory.add(it, world.items):
			p.inventory_dirty = true
		else:
			world.emit(["quest_bag_full", p.id])


## Starts a quest whatever its requirements (the /mision test command).
static func force_start(world: SimWorld, p: PlayerState, id: String) -> bool:
	var q := _db(world).quest(id)
	if q.is_empty() or p.quests.is_active(id):
		return false
	p.quests.done.erase(id)
	p.quests.active[id] = {"step": 0, "counts": _zeros(q, 0)}
	p.quests.tracked = id
	p.quests_dirty = true
	world.emit(["quest_started", p.id, id])
	_give(world, p, q)
	_refresh(world, p, id)
	return true


## Completes every objective of the current step (the /mision paso test command).
static func complete_step(world: SimWorld, p: PlayerState, id: String) -> void:
	var objs := current_objectives(world, p, id)
	if objs.is_empty():
		return
	var st: Dictionary = p.quests.active[id]
	for i in objs.size():
		var o: Dictionary = objs[i]
		if str(o.type) == "collect":
			var missing := int(o.count) - p.inventory.count_of(str(o.item))
			if missing > 0:
				var it := ItemRoll.new_item(str(o.item), 1)
				it.count = missing
				p.inventory.add(it, world.items)
				p.inventory_dirty = true
		st.counts[i] = int(o.count)
	p.quests_dirty = true
	_refresh(world, p, id)


## Starts every automatic quest whose requirements are met (the story chains itself).
static func check_auto(world: SimWorld, p: PlayerState) -> void:
	var db := _db(world)
	for id: String in db.ids():
		if bool(db.quest(id).auto) and can_start(world, p, id):
			start(world, p, id)


static func _zeros(q: Dictionary, step: int) -> Array:
	if step >= (q.steps as Array).size():
		return []
	return (q.steps[step].objectives as Array).map(func(_o: Dictionary) -> int: return 0)


## The objectives of a quest's current step ([] when ready to turn in).
static func current_objectives(world: SimWorld, p: PlayerState, id: String) -> Array:
	var q := _db(world).quest(id)
	if q.is_empty() or not p.quests.is_active(id):
		return []
	var step := int(p.quests.active[id].step)
	return q.steps[step].objectives if step < (q.steps as Array).size() else []


## The story moment a player stands in, from the steps it finished: {zone, variant}, or {}.
static func current_moment(world: SimWorld, p: PlayerState) -> Dictionary:
	var out := {}
	for id: String in p.quests.active:
		var q := _db(world).quest(id)
		if q.get("moment") is Dictionary:
			out = q.moment
		for i in mini(int(p.quests.active[id].step), (q.steps as Array).size()):
			var od: Dictionary = q.steps[i].on_done
			if od.has("moment"):
				out = od.moment if od.moment is Dictionary else {}
	return out


static func is_ready(world: SimWorld, p: PlayerState, id: String) -> bool:
	var q := _db(world).quest(id)
	return not q.is_empty() and p.quests.is_active(id) and int(p.quests.active[id].step) >= (q.steps as Array).size()


# --- Progress ---

## Adds `n` to an objective's count (up to its target) and advances the step when all its
## objectives are done.
static func _bump(world: SimWorld, p: PlayerState, id: String, index: int, n: int = 1) -> void:
	var st: Dictionary = p.quests.active[id]
	var objs := current_objectives(world, p, id)
	st.counts[index] = mini(int(objs[index].count), int(st.counts[index]) + n)
	p.quests_dirty = true
	_refresh(world, p, id)


## Recomputes what is read from elsewhere (collected items in the bag, choice flags) and
## moves through every step that is complete.
static func _refresh(world: SimWorld, p: PlayerState, id: String) -> void:
	var q := _db(world).quest(id)
	while p.quests.is_active(id):
		var st: Dictionary = p.quests.active[id]
		var step := int(st.step)
		if step >= (q.steps as Array).size():
			if str(q.turn_in) == "":
				turn_in(world, p, id, "") # nobody to hand it in to: its rewards at once
			return
		var objs: Array = q.steps[step].objectives
		for i in objs.size():
			var o: Dictionary = objs[i]
			match str(o.type):
				"collect":
					st.counts[i] = mini(int(o.count), p.inventory.count_of(str(o.item)))
				"class":
					if CharacterCatalog.load_default().is_selectable(p.class_id):
						st.counts[i] = int(o.count)
				"choice":
					if (o.get("any_flag", []) as Array).any(func(fl: Variant) -> bool: return p.quests.has_flag(str(fl))):
						st.counts[i] = int(o.count)
		var complete := true
		for i in objs.size():
			if int(st.counts[i]) < int(objs[i].count):
				complete = false
		if not complete:
			return
		st.step = step + 1
		st.counts = _zeros(q, step + 1)
		p.quests_dirty = true
		world.emit(["quest_step", p.id, id, step + 1])
		_apply(world, p, q.steps[step].on_done)
		if int(st.step) >= (q.steps as Array).size():
			world.emit(["quest_ready", p.id, id])


## A step's or a quest's on_done: flags, marks, a scene, a story moment, the next quest.
static func _apply(world: SimWorld, p: PlayerState, od: Dictionary) -> void:
	for fl: Variant in od.get("flags", []):
		if not p.quests.has_flag(str(fl)):
			p.quests.flags.append(str(fl))
	for fl: Variant in od.get("clear_flags", []):
		p.quests.flags.erase(str(fl))
	for mk: Variant in od.get("marks", []):
		if not str(mk) in p.quests.marks:
			p.quests.marks.append(str(mk))
	if str(od.get("scene", "") if od.get("scene") != null else "") != "":
		world.emit(["quest_scene", p.id, str(od.scene)])
	if od.has("moment"):
		var m: Variant = od.moment
		if m is Dictionary:
			world.emit(["quest_moment", p.id, str(m.get("zone", "")), str(m.get("variant", ""))])
		else:
			world.emit(["quest_moment", p.id, "", ""])
	_give(world, p, od)
	p.quests_dirty = true
	if str(od.get("next", "")) != "":
		start(world, p, str(od.next))
	if not (od.get("flags", []) as Array).is_empty():
		_refresh_all(world, p)


static func _refresh_all(world: SimWorld, p: PlayerState) -> void:
	for id: String in p.quests.active.keys():
		if p.quests.is_active(id):
			_refresh(world, p, id)


## A story flag (a dialogue choice the host checked, or a command).
static func set_flag(world: SimWorld, p: PlayerState, flag: String) -> void:
	if flag == "" or p.quests.has_flag(flag):
		return
	p.quests.flags.append(flag)
	p.quests_dirty = true
	_refresh_all(world, p)
	check_auto(world, p)


static func _finish(world: SimWorld, p: PlayerState, id: String) -> void:
	var q := _db(world).quest(id)
	_remove_quest_items(world, p, q)
	p.quests.active.erase(id)
	if not p.quests.is_done(id):
		p.quests.done.append(id)
	if p.quests.tracked == id:
		p.quests.tracked = p.quests.active.keys()[0] if not p.quests.active.is_empty() else ""
	p.quests_dirty = true
	world.emit(["quest_done", p.id, id])
	_apply(world, p, q.on_done)
	check_auto(world, p)


static func _remove_quest_items(world: SimWorld, p: PlayerState, q: Dictionary) -> void:
	for step: Dictionary in q.steps:
		for o: Dictionary in step.objectives:
			if str(o.type) in ["collect", "deliver"] and world.items.is_quest(str(o.get("item", ""))):
				if p.inventory.remove_count(str(o.item), 1 << 30) > 0:
					p.inventory_dirty = true


## Killing and collecting: every player sharing the experience with that objective.
static func on_monster_died(world: SimWorld, m: MonsterState) -> void:
	if m.summoned_by != 0:
		return
	for p: PlayerState in Xp.sharers(world, m):
		for id: String in p.quests.active.keys():
			if not p.quests.is_active(id):
				continue
			# One monster counts for every objective of the step it feeds (kill and collect
			# alike); the step moves on once, after all of them.
			var objs := current_objectives(world, p, id)
			var st: Dictionary = p.quests.active[id]
			var changed := false
			for i in objs.size():
				var o: Dictionary = objs[i]
				if o.has("zone") and str(o.zone) != world.map.zone_id:
					continue
				if str(o.type) == "kill" and str(o.get("monster", "")) == m.type_id and int(st.counts[i]) < int(o.count):
					st.counts[i] = int(st.counts[i]) + 1
					changed = true
				elif str(o.type) == "collect" and str(o.get("from", "")) == m.type_id:
					if p.inventory.count_of(str(o.item)) >= int(o.count):
						continue
					if world.rng.randf() >= float(o.get("chance", 1.0)):
						continue
					if p.inventory.add(ItemRoll.new_item(str(o.item), 1), world.items):
						p.inventory_dirty = true
						changed = true
					else:
						world.emit(["quest_bag_full", p.id])
			if changed:
				p.quests_dirty = true
				_refresh(world, p, id)


## A player's blow landed on a monster (Plan 8.3a): "hit" objectives (with: basic, secondary
## or any) and "hit_secondary". ability_kind is the kind of the ability that dealt it.
static func on_hit(world: SimWorld, source: CombatEntity, target: CombatEntity, ability_kind: String) -> void:
	if not source is PlayerState or not target is MonsterState:
		return
	var p := source as PlayerState
	for id: String in p.quests.active.keys():
		if not p.quests.is_active(id):
			continue
		var objs := current_objectives(world, p, id)
		var st: Dictionary = p.quests.active[id]
		var changed := false
		for i in objs.size():
			var o: Dictionary = objs[i]
			var t := str(o.type)
			if not t in ["hit", "hit_secondary"] or str(o.get("monster", "")) != (target as MonsterState).type_id:
				continue
			var want := "secondary" if t == "hit_secondary" else str(o.get("with", ""))
			if want != "" and want != ability_kind:
				continue
			if int(st.counts[i]) < int(o.count):
				st.counts[i] = int(st.counts[i]) + 1
				changed = true
		if changed:
			p.quests_dirty = true
			_refresh(world, p, id)


## A player started a dodge (Plan 8.3a): "dodge" objectives.
static func on_dodge(world: SimWorld, p: PlayerState) -> void:
	_bump_type(world, p, "dodge")


## The player now has a class: "class" objectives.
static func on_class_chosen(world: SimWorld, p: PlayerState) -> void:
	for id: String in p.quests.active.keys():
		if p.quests.is_active(id):
			_refresh(world, p, id)


## True while the step being done asks to choose a class (then no trainer is needed).
static func allows_class_choice(world: SimWorld, p: PlayerState) -> bool:
	for id: String in p.quests.active:
		for o: Dictionary in current_objectives(world, p, id):
			if str(o.type) == "class":
				return true
	return false


static func _bump_type(world: SimWorld, p: PlayerState, type: String) -> void:
	for id: String in p.quests.active.keys():
		if not p.quests.is_active(id):
			continue
		var objs := current_objectives(world, p, id)
		for i in objs.size():
			if str(objs[i].type) == type and int(p.quests.active[id].counts[i]) < int(objs[i].count):
				_bump(world, p, id, i)
				break


## Reaching places, every REACH_EVERY_S: whoever stands on the point, and players with the
## same objective within the share range of them.
static func step_reach(world: SimWorld) -> void:
	var wanted: Array = [] # [player, quest id, objective index, point]
	for p: PlayerState in world.players.values():
		for id: String in p.quests.active:
			var objs := current_objectives(world, p, id)
			for i in objs.size():
				var o: Dictionary = objs[i]
				if str(o.type) == "reach" and (not o.has("zone") or str(o.zone) == world.map.zone_id) \
						and world.map.quest_points.has(str(o.get("point", ""))):
					wanted.append([p, id, i, world.map.quest_points[str(o.point)]])
	if wanted.is_empty():
		return
	var range_m := float(world.balance.xp.get("share_range", 30.0))
	var arrived: Array = [] # quest points reached by someone: [point, position]
	for w: Array in wanted:
		var p: PlayerState = w[0]
		var pt: Dictionary = w[3]
		reach_checks += 1
		if p.life != CombatEntity.DEAD and _flat_dist(p.position, Vector3(pt.at.x + 0.5, 0, pt.at.y + 0.5)) <= float(pt.radius):
			arrived.append([pt, p.position])
	if arrived.is_empty():
		return
	for w: Array in wanted:
		var p: PlayerState = w[0]
		if not p.quests.is_active(w[1]):
			continue
		for a: Array in arrived:
			if a[0] == w[3] and _flat_dist(p.position, a[1]) <= range_m:
				_bump(world, p, w[1], w[2])
				break


# --- Requests the host checked ---

static func _npc_position(world: SimWorld, npc: String) -> Variant:
	for n: Dictionary in NpcDB.placed(world.map):
		if n.id == npc:
			return n.position
	return null


static func near_npc(world: SimWorld, p: PlayerState, npc: String) -> bool:
	var pos: Variant = _npc_position(world, npc)
	return pos != null and _flat_dist(p.position, pos) <= NpcDB.TALK_RANGE + 0.5


## What the client reports: "talk" (arg npc, arg2 dialogue), "interact" (arg point), "scene"
## (arg scene id). True when it advanced something.
static func report(world: SimWorld, p: PlayerState, kind: String, arg: String, arg2: String = "") -> bool:
	if kind == "talk" and not near_npc(world, p, arg):
		return false
	if kind == "interact":
		var pt: Variant = world.map.quest_points.get(arg)
		if pt == null or _flat_dist(p.position, Vector3(pt.at.x + 0.5, 0, pt.at.y + 0.5)) > maxf(INTERACT_RANGE, float(pt.radius)):
			return false
	var done := false
	for id: String in p.quests.active.keys():
		if not p.quests.is_active(id):
			continue
		var objs := current_objectives(world, p, id)
		for i in objs.size():
			var o: Dictionary = objs[i]
			if int(p.quests.active[id].counts[i]) >= int(o.count):
				continue
			match [kind, str(o.type)]:
				["talk", "talk"]:
					if str(o.get("npc", "")) == arg and (not o.has("dialogue") or str(o.dialogue) == arg2):
						_bump(world, p, id, i, int(o.count))
						done = true
				["talk", "deliver"]:
					if str(o.get("npc", "")) == arg and (not o.has("dialogue") or str(o.dialogue) == arg2) \
							and p.inventory.count_of(str(o.item)) >= int(o.count):
						p.inventory.remove_count(str(o.item), int(o.count))
						p.inventory_dirty = true
						_bump(world, p, id, i, int(o.count))
						done = true
				["interact", "interact"], ["scene", "scene"]:
					if str(o.get("point", o.get("scene", ""))) == arg:
						_bump(world, p, id, i, int(o.count))
						done = true
			if done:
				break
		if done:
			break
	return done


## Hands in a finished quest at its NPC: rewards (experience for `levels`, gold, items and the
## chosen one). Refused, with nothing lost, when the bag has no room for the items.
static func turn_in(world: SimWorld, p: PlayerState, id: String, choice: String) -> bool:
	var q := _db(world).quest(id)
	if not is_ready(world, p, id) or (str(q.turn_in) != "" and not near_npc(world, p, str(q.turn_in))):
		return false
	var r: Dictionary = q.rewards
	var choices: Array = r.get("choice", [])
	if not choices.is_empty() and not choice in choices:
		return false
	var items: Array = (r.get("items", []) as Array).duplicate()
	if not choices.is_empty():
		items.append(choice)
	var made: Array = items.map(func(b: Variant) -> Item: return _reward_item(world, p, str(b)))
	var test := Inventory.from_wire_exact(p.inventory.to_wire(), world.items)
	for it: Item in made:
		if not test.add(it, world.items):
			world.emit(["quest_bag_full", p.id])
			return false
	for it: Item in made:
		p.inventory.add(it, world.items)
	p.inventory.gold = mini(Inventory.MAX_GOLD, p.inventory.gold + int(r.get("gold", 0)))
	p.inventory_dirty = true
	var xp := reward_xp(p.progress.level, int(r.get("levels", 0)), world.balance) + int(r.get("xp", 0))
	Xp.award(world, p, xp)
	_finish(world, p, id)
	return true


static func _reward_item(world: SimWorld, p: PlayerState, base_id: String) -> Item:
	var b := world.items.base(base_id)
	var level := clampi(p.progress.level, int(b.get("min_level", 1)), maxi(int(b.get("min_level", 1)), int(b.get("max_level", 9999))))
	return ItemRoll.new_item(base_id, level)


## The experience that takes a player `levels` levels up from where it stands: what the next
## levels need, so the experience already earned toward the next one is kept.
static func reward_xp(level: int, levels: int, b: Balance) -> int:
	var total := 0
	for i in maxi(0, levels):
		if level + i >= PlayerProgress.MAX_LEVEL:
			break
		total += Xp.to_next(level + i, b)
	return total


## Gives up a quest that is not part of the story; its quest items go away.
static func abandon(world: SimWorld, p: PlayerState, id: String) -> bool:
	var q := _db(world).quest(id)
	if q.is_empty() or bool(q.story) or not p.quests.is_active(id):
		return false
	_remove_quest_items(world, p, q)
	p.quests.active.erase(id)
	if p.quests.tracked == id:
		p.quests.tracked = ""
	p.quests_dirty = true
	return true
