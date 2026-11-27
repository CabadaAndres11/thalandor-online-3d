class_name ProgressRequests
extends RefCounted
## What a player may ask to change in their progress. The host validates every request
## here; an accepted one rebuilds the stats and marks the progress to be sent (and
## saved by its owner). Spending and buying work in combat; resets do not.

const UPGRADE_LEVEL := 50


static func _accept(world: SimWorld, p: PlayerState) -> bool:
	Progression.rebuild(p, world)
	p.progress_dirty = true
	return true


static func spend_attribute(world: SimWorld, p: PlayerState, attr: String) -> bool:
	if p.life == CombatEntity.DEAD or not Attributes.spend(p.progress, attr, world.balance):
		return false
	return _accept(world, p)


static func buy_talent(world: SimWorld, p: PlayerState, id: String) -> bool:
	if p.life == CombatEntity.DEAD or not Talents.buy(p.progress, id, TalentDB.load_default()):
		return false
	return _accept(world, p)


static func buy_mastery(world: SimWorld, p: PlayerState, dir: String) -> bool:
	if p.life == CombatEntity.DEAD or not Talents.buy_mastery(p.progress, dir, TalentDB.load_default()):
		return false
	return _accept(world, p)


## Level 50, no upgrade yet, one of the player's class, alive. The first choice is forced on
## the player wherever they are; only a reset needs Brann.
static func choose_upgrade(world: SimWorld, p: PlayerState, id: String, _near_trainer: bool = true) -> bool:
	var u := world.upgrades.upgrade(id)
	if p.life != CombatEntity.ALIVE or p.progress.level < UPGRADE_LEVEL \
			or p.progress.upgrade != "" or u.is_empty() or str(u.get("class", "")) != p.class_id:
		return false
	p.progress.upgrade = id
	return _accept(world, p)


## What a reset costs (Plan 8.3b): reset_gold_per_level gold per level.
static func reset_cost(level: int, b: Balance) -> int:
	return b.reset_gold_per_level * maxi(1, level)


## what: "attributes" or "talents" (the level 50 upgrade is final). Needs the class trainer
## nearby, a player on their feet, out of combat and with the gold (reset_cost). Returns
## false, charging nothing, when there is nothing to reset or the gold is short.
static func reset(world: SimWorld, p: PlayerState, what: String, near_trainer: bool) -> bool:
	if not near_trainer or p.life != CombatEntity.ALIVE or p.in_combat(world):
		return false
	var pr := p.progress
	var cost := reset_cost(pr.level, world.balance)
	if p.inventory.gold < cost:
		return false
	match what:
		"attributes":
			if Attributes.free_points(pr, world.balance) == int(world.balance.attributes.get("points_per_level", 5)) * (pr.level - 1):
				return false
			for a: String in PlayerProgress.ATTRIBUTES:
				pr.attributes[a] = 0
		"talents":
			if pr.talents.is_empty() and pr.masteries.is_empty():
				return false
			Talents.reset(pr)
		"upgrade":
			return false # the level 50 upgrade is final (Plan 8.3a)
		_:
			return false
	p.inventory.gold -= cost
	p.inventory_dirty = true
	return _accept(world, p)


## Removes the upgrade (talents never depend on it, Plan 8.3g).
static func clear_upgrade(world: SimWorld, p: PlayerState) -> void:
	Combat.dismiss_summons(world, p.id) # the hunter wolf leaves with the upgrade
	# A channelled or repeating ability of the upgrade stops at once.
	for pc: PendingCast in world.pending_casts.duplicate():
		if pc.caster_id == p.id:
			Combat.cancel_cast(world, pc)
	p.progress.upgrade = ""


## A sanitized copy of a progress that came from outside (a saved character in HELLO):
## level and experience in range, attribute points within the level's points, a legal
## talent tree and an upgrade that belongs to the class and the level. It never rejects.
static func sanitize(pr: PlayerProgress, class_id: String, world: SimWorld) -> PlayerProgress:
	var out := pr.copy()
	var b := world.balance
	out.level = clampi(out.level, 1, PlayerProgress.MAX_LEVEL)
	out.xp = 0 if out.level >= PlayerProgress.MAX_LEVEL else clampi(out.xp, 0, Xp.to_next(out.level, b) - 1)
	var spent := 0
	for a: String in PlayerProgress.ATTRIBUTES:
		out.attributes[a] = maxi(0, int(out.attributes.get(a, 0)))
		spent += int(out.attributes[a])
	if spent > int(b.attributes.get("points_per_level", 5)) * (out.level - 1):
		for a: String in PlayerProgress.ATTRIBUTES:
			out.attributes[a] = 0
	if out.upgrade != "":
		var u := world.upgrades.upgrade(out.upgrade)
		if u.is_empty() or str(u.get("class", "")) != class_id or out.level < UPGRADE_LEVEL:
			out.upgrade = ""
	var db := TalentDB.load_default()
	if not Talents.valid(out, db):
		Talents.prune_orphans(out, db) # keep what is connected before giving up on the rest
		if not Talents.valid(out, db):
			Talents.reset(out)
	return out
