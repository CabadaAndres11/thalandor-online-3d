class_name Loot
extends RefCounted
## Personal loot. When a monster dies each player near it (alive or downed) rolls their
## own: gold goes straight to the purse, items fall around the body for that player only,
## are picked up by walking over them and vanish after loot_ttl_s.
## Events: ["gold", owner, amount, pos], ["loot", owner, drop_id, item dict, pos],
## ["loot_gone", owner, drop_id, picked_up], ["bag_full", owner] (sent to the owner only).


static func drop(world: SimWorld, m: MonsterState) -> void:
	if m.summoned_by != 0 or m.def.is_empty():
		return
	var db := world.items
	var range_m := float(world.balance.xp.get("share_range", 30.0))
	var boss := bool(m.def.get("boss", false))
	var kind := "boss" if boss else ("elite" if m.elite else "normal")
	var unique := db.unique_for(m.type_id) if boss else ""
	var chance := float((db.loot().get("items", {}) as Dictionary).get("unique_chance", 0.25))
	for p: PlayerState in world.players.values():
		if p.life == CombatEntity.DEAD or Effects.flat(p.position).distance_to(Effects.flat(m.position)) > range_m:
			continue
		var got := ItemRoll.roll_loot(p.class_id, m.level, kind, world.rng, db)
		var items: Array = got.items
		if unique != "" and world.rng.randf() < chance:
			items.append(ItemRoll.new_item(unique, m.level, "unique"))
		if int(got.gold) > 0:
			p.inventory.gold = mini(Inventory.MAX_GOLD, p.inventory.gold + int(got.gold))
			p.inventory_dirty = true
			world.emit(["gold", p.id, int(got.gold), m.position])
		for it: Item in items:
			place(world, p.id, it, _scatter(world, m.position))


static func _scatter(world: SimWorld, at: Vector3) -> Vector3:
	var r := float(world.items.loot().get("loot_scatter", 1.5)) * sqrt(world.rng.randf())
	var a := world.rng.randf() * TAU
	return at + Vector3(cos(a) * r, 0.0, sin(a) * r)


## Puts an item on the ground for `owner`; returns its drop id.
static func place(world: SimWorld, owner: int, it: Item, pos: Vector3) -> int:
	var id := world.next_object_id()
	var ttl := float(world.items.loot().get("loot_ttl_s", 120.0))
	world.loot[id] = {"owner": owner, "item": it, "pos": pos, "expire_tick": world.tick + world.ticks(ttl), "warned": false}
	world.emit(["loot", owner, id, it.to_dict(), pos])
	return id


## Pickups (owner alive and within pickup_radius, if the bag has room) and expiry.
static func step(world: SimWorld) -> void:
	if world.loot.is_empty():
		return
	var radius := float(world.items.loot().get("pickup_radius", 1.0))
	for id: int in world.loot.keys():
		var d: Dictionary = world.loot[id]
		var p: PlayerState = world.players.get(d.owner)
		if world.tick >= int(d.expire_tick) or p == null:
			world.loot.erase(id)
			world.emit(["loot_gone", d.owner, id, false])
			continue
		if p.life != CombatEntity.ALIVE or Effects.flat(p.position).distance_to(Effects.flat(d.pos)) > radius:
			continue
		if p.inventory.add(d.item, world.items):
			world.loot.erase(id)
			p.inventory_dirty = true
			world.emit(["loot_gone", d.owner, id, true])
		elif not d.warned:
			d.warned = true
			world.emit(["bag_full", d.owner])
