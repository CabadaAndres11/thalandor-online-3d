class_name ItemRequests
extends RefCounted
## What a player may do with their items. The host validates every request here; an
## accepted one rebuilds the stats when the equipment changed and marks the inventory to
## be sent to (and saved by) its owner.


static func _db(world: SimWorld) -> ItemDB:
	return world.items if world != null and world.items != null else ItemDB.load_default()


static func _changed(world: SimWorld, p: PlayerState, gear: bool) -> bool:
	if gear:
		Progression.rebuild(p, world)
	p.inventory_dirty = true
	return true


static func equip(world: SimWorld, p: PlayerState, index: int, target: String = "") -> bool:
	if p.life != CombatEntity.ALIVE or not p.inventory.equip(index, p.class_id, p.progress.level, _db(world), target):
		return false
	return _changed(world, p, true)


static func unequip(world: SimWorld, p: PlayerState, slot: String) -> bool:
	if p.life != CombatEntity.ALIVE or not p.inventory.unequip(slot):
		return false
	return _changed(world, p, true)


## Uses the bag item at `index`. Potions are no longer in the bag (they are drunk with
## use_potion), so nothing in it can be used for now.
static func use(world: SimWorld, p: PlayerState, index: int) -> bool:
	var inv := p.inventory
	if index < 0 or index >= inv.bag.size() or inv.bag[index] == null:
		return false
	var kind := str(_db(world).base((inv.bag[index] as Item).base_id).get("potion", ""))
	return kind != "" and use_potion(world, p, kind)


## Q and R: drinks a potion of that kind ("health" or "resource"): potion.heal_pct /
## resource_pct of the maximum, one shared cooldown. Rage cannot be filled; nothing is drunk
## when already full or when none is left.
static func use_potion(world: SimWorld, p: PlayerState, kind: String) -> bool:
	var inv := p.inventory
	var db := _db(world)
	if p.life != CombatEntity.ALIVE or inv.potion_count(kind) <= 0 or world.tick < p.potion_ready_tick:
		return false
	var cfg: Dictionary = db.loot().get("potion", {})
	if kind == "health":
		if p.hp >= p.stats.max_hp:
			return false
		p.hp = minf(p.stats.max_hp, p.hp + p.stats.max_hp * float(cfg.get("heal_pct", 0.35)))
	else:
		if p.resource_kind == "rage" or p.stats.max_resource <= 0.0 or p.resource >= p.stats.max_resource:
			return false
		p.resource = minf(p.stats.max_resource, p.resource + p.stats.max_resource * float(cfg.get("resource_pct", 0.35)))
	p.potion_ready_tick = world.tick + world.ticks(float(cfg.get("cooldown_s", 30.0)))
	inv.remove_count("potion_" + kind, 1)
	world.emit(["potion", p.id, kind])
	return _changed(world, p, false)


## Dying (not being downed) wears every worn item by durability_loss_on_death.
static func on_death(world: SimWorld, p: PlayerState) -> void:
	if p.inventory.equipment.is_empty():
		return
	var loss := int(_db(world).loot().get("durability_loss_on_death", 10))
	for slot: String in p.inventory.equipment:
		var it: Item = p.inventory.equipment[slot]
		it.durability = maxi(0, it.durability - loss)
	_changed(world, p, true)
