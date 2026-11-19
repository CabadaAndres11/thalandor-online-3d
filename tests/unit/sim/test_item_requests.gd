extends GutTest
## ItemRequests: what a player may do with their items; the host checks each request.

var f: CombatFixture
var db: ItemDB


func before_each() -> void:
	f = CombatFixture.new()
	db = ItemDB.load_default()


func _hero(class_id: String, level := 10) -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	return p


func _give(p: PlayerState, base_id: String, count := 1) -> int:
	var it := ItemRoll.new_item(base_id, 1)
	it.count = count
	p.inventory.add(it, db)
	for i in p.inventory.bag.size():
		if p.inventory.bag[i] != null and p.inventory.bag[i].base_id == base_id:
			return i
	return -1


func test_equip_rebuilds_and_marks_dirty() -> void:
	var p := _hero("warrior")
	var armor := p.stats.armor
	var i := _give(p, "plate_chest_t1")
	assert_true(ItemRequests.equip(f.world, p, i))
	assert_gt(p.stats.armor, armor)
	assert_true(p.inventory_dirty)


func test_unequip() -> void:
	var p := _hero("warrior")
	ItemRequests.equip(f.world, p, _give(p, "plate_chest_t1"))
	p.inventory_dirty = false
	assert_true(ItemRequests.unequip(f.world, p, "chest"))
	assert_true(p.inventory_dirty)


func test_dead_cannot_equip() -> void:
	var p := _hero("warrior")
	var i := _give(p, "plate_chest_t1")
	p.life = CombatEntity.DEAD
	assert_false(ItemRequests.equip(f.world, p, i))
	p.life = CombatEntity.DOWNED
	assert_false(ItemRequests.equip(f.world, p, i))


func test_potion_heals_35() -> void:
	var p := _hero("mage")
	p.hp = 1.0
	var i := _give(p, "potion_health", 3)
	assert_true(ItemRequests.use(f.world, p, i))
	assert_almost_eq(p.hp, 1.0 + p.stats.max_hp * 0.35, 0.01)
	assert_eq(p.inventory.bag[i].count, 2)


func test_last_potion_leaves_the_bag() -> void:
	var p := _hero("mage")
	p.hp = 1.0
	var i := _give(p, "potion_health", 1)
	assert_true(ItemRequests.use(f.world, p, i))
	assert_null(p.inventory.bag[i])


func test_potion_shared_cooldown() -> void:
	var p := _hero("mage")
	p.hp = 1.0
	p.resource = 0.0
	_give(p, "potion_health", 2)
	_give(p, "potion_resource", 2)
	assert_true(ItemRequests.use_potion(f.world, p, "health"))
	assert_false(ItemRequests.use_potion(f.world, p, "resource"))
	f.world.tick += f.world.ticks(30.0)
	assert_true(ItemRequests.use_potion(f.world, p, "resource"))


func test_no_potion_at_full() -> void:
	var p := _hero("mage")
	_give(p, "potion_health", 1)
	assert_false(ItemRequests.use_potion(f.world, p, "health"))


func test_no_potion_left() -> void:
	var p := _hero("mage")
	p.hp = 1.0
	assert_false(ItemRequests.use_potion(f.world, p, "health"))


func test_rage_no_resource_potion() -> void:
	var p := _hero("warrior")
	p.resource = 0.0
	_give(p, "potion_resource", 1)
	assert_false(ItemRequests.use_potion(f.world, p, "resource"))


func test_cannot_use_gear() -> void:
	var p := _hero("warrior")
	assert_false(ItemRequests.use(f.world, p, _give(p, "sword_t1")))


func test_death_durability() -> void:
	var p := _hero("warrior")
	ItemRequests.equip(f.world, p, _give(p, "plate_chest_t1"))
	ItemRequests.on_death(f.world, p)
	ItemRequests.on_death(f.world, p)
	assert_eq(p.inventory.equipment.chest.durability, 80)
	for i in 9:
		ItemRequests.on_death(f.world, p)
	assert_eq(p.inventory.equipment.chest.durability, 0)
	assert_true(p.inventory_dirty)
