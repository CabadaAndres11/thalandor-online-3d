class_name Talents
extends RefCounted
## Talent and mastery rules: one point per level above 1, spent on nodes of the tree that
## touch the start or a bought node (ring 2 needs a class upgrade) or on masteries of a
## direction whose nodes are all bought.


static func points(level: int) -> int:
	return maxi(0, level - 1)


## Points spent on nodes and mastery ranks.
static func spent(pr: PlayerProgress) -> int:
	var n := pr.talents.size()
	for dir: Variant in pr.masteries:
		n += int(pr.masteries[dir])
	return n


static func can_buy(pr: PlayerProgress, id: String, db: TalentDB) -> bool:
	if not db.has(id) or id == db.start_id() or pr.talents.has(id) or spent(pr) >= points(pr.level):
		return false
	var node := db.node(id)
	if int(node.get("ring", 1)) == 2 and pr.upgrade == "":
		return false
	for other: String in node.get("links", []):
		if other == db.start_id() or pr.talents.has(other):
			return true
	return false


static func buy(pr: PlayerProgress, id: String, db: TalentDB) -> bool:
	if not can_buy(pr, id, db):
		return false
	pr.talents.append(id)
	return true


## Every node of a direction that can be bought now (ring 2 only with an upgrade) is owned.
static func direction_complete(pr: PlayerProgress, dir: String, db: TalentDB) -> bool:
	for id: String in db.ids():
		var node := db.node(id)
		if str(node.get("dir", "")) != dir:
			continue
		if int(node.get("ring", 1)) == 2 and pr.upgrade == "":
			continue
		if not pr.talents.has(id):
			return false
	return true


static func can_buy_mastery(pr: PlayerProgress, dir: String, db: TalentDB) -> bool:
	return dir in db.directions() and spent(pr) < points(pr.level) and direction_complete(pr, dir, db)


static func buy_mastery(pr: PlayerProgress, dir: String, db: TalentDB) -> bool:
	if not can_buy_mastery(pr, dir, db):
		return false
	pr.masteries[dir] = int(pr.masteries.get(dir, 0)) + 1
	return true


## Whether the bought nodes and masteries are a legal state: real distinct nodes, within
## the points, all reachable from the start through bought nodes, ring 2 only with an
## upgrade, and masteries only in directions that are complete.
static func valid(pr: PlayerProgress, db: TalentDB) -> bool:
	if spent(pr) > points(pr.level):
		return false
	var seen := {}
	for id: Variant in pr.talents:
		if not id is String or not db.has(id) or id == db.start_id() or seen.has(id):
			return false
		if int(db.node(id).get("ring", 1)) == 2 and pr.upgrade == "":
			return false
		seen[id] = true
	var reached := {db.start_id(): true}
	var queue: Array = [db.start_id()]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		for n: String in db.node(cur).get("links", []):
			if seen.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	if reached.size() != seen.size() + 1:
		return false
	for dir: Variant in pr.masteries:
		if not dir is String or not dir in db.directions() or int(pr.masteries[dir]) < 0:
			return false
		if int(pr.masteries[dir]) > 0 and not direction_complete(pr, dir, db):
			return false
	return true


## Stat modifiers of the bought nodes and the mastery ranks.
static func mods(pr: PlayerProgress, db: TalentDB, b: Balance) -> Array:
	var out: Array = []
	for id: String in pr.talents:
		for m: Dictionary in db.node(id).get("mods", []):
			out.append(m)
	var cfg := b.masteries
	var half_at := maxf(float(cfg.get("half_at", 100.0)), 1.0)
	for dir: String in db.directions():
		var rank := float(pr.masteries.get(dir, 0))
		if rank <= 0.0 or not cfg.has(dir):
			continue
		var c: Dictionary = cfg[dir]
		out.append({"type": "stat", "stat": str(c.get("stat", "")),
			"value": float(c.get("value", 0.0)) * rank * half_at / (rank + half_at)})
	return out


## Gives every point back (nodes and masteries).
static func reset(pr: PlayerProgress) -> void:
	pr.talents = []
	pr.masteries = {}
