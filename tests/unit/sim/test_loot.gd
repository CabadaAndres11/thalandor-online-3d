extends GutTest
## Personal loot: each nearby player rolls their own, only they can pick it up, it expires.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(80, 80))


func _hero(id: int, pos: Vector3, class_id := "mage") -> PlayerState:
	var p := f.player(id, pos)
	p.class_id = class_id
	return p


func _monster(type_id := "cultist", pos := Vector3(20, 0, 20), elite := false) -> MonsterState:
	var m := MonsterDB.load_default().make(type_id, f.world.next_monster_id(), pos, f.world, 5)
	if elite:
		MonsterDB.make_elite(m, f.world.balance)
	f.world.add_entity(m)
	return m


func _kill(m: MonsterState) -> void:
	m.hp = 0.0
	f.world.on_zero_hp(m)


func _drops_of(owner: int) -> Array:
	return f.world.loot.values().filter(func(d: Dictionary) -> bool: return d.owner == owner)


func test_each_player_own_roll() -> void:
	var a := _hero(1, Vector3(21, 0, 20))
	var b := _hero(2, Vector3(22, 0, 20), "warrior")
	_kill(_monster("cultist", Vector3(20, 0, 20), true))
	assert_gte(_drops_of(a.id).size(), 1)
	assert_gte(_drops_of(b.id).size(), 1)
	var loot_events := f.world.events.filter(func(ev: Array) -> bool: return ev[0] == "loot")
	assert_eq(loot_events.size(), f.world.loot.size())


func test_gold_goes_straight_to_the_purse() -> void:
	var a := _hero(1, Vector3(21, 0, 20))
	_kill(_monster("cultist", Vector3(20, 0, 20), true)) # elites always give gold
	assert_gt(a.inventory.gold, 0)
	assert_true(a.inventory_dirty)
	assert_true(f.world.events.any(func(ev: Array) -> bool: return ev[0] == "gold" and ev[1] == a.id))


func test_far_player_no_loot() -> void:
	var a := _hero(1, Vector3(60, 0, 20))
	_kill(_monster("cultist", Vector3(20, 0, 20), true))
	assert_eq(_drops_of(a.id).size(), 0)
	assert_eq(a.inventory.gold, 0)


func test_dead_player_no_loot() -> void:
	var a := _hero(1, Vector3(21, 0, 20))
	a.life = CombatEntity.DEAD
	_kill(_monster("cultist", Vector3(20, 0, 20), true))
	assert_eq(_drops_of(a.id).size(), 0)


func test_summons_no_loot() -> void:
	_hero(1, Vector3(21, 0, 20))
	var m := _monster("cultist", Vector3(20, 0, 20), true)
	m.summoned_by = 5
	_kill(m)
	assert_true(f.world.loot.is_empty())


func _place(owner: int, pos: Vector3) -> int:
	return Loot.place(f.world, owner, ItemRoll.new_item("sword_t1", 1), pos)


func test_pickup_only_owner() -> void:
	var a := _hero(1, Vector3(30, 0, 30))
	var b := _hero(2, Vector3(20, 0, 20))
	var id := _place(a.id, Vector3(20, 0, 20))
	Loot.step(f.world)
	assert_true(f.world.loot.has(id), "b stands on it but it is a's")
	assert_eq(b.inventory.free_slots(), 30)
	a.position = Vector3(20.5, 0, 20)
	f.world.events.clear()
	Loot.step(f.world)
	assert_false(f.world.loot.has(id))
	assert_eq(a.inventory.free_slots(), 29)
	assert_true(a.inventory_dirty)
	assert_true(f.world.events.any(func(ev: Array) -> bool: return ev[0] == "loot_gone" and ev[2] == id and ev[3] == true))


func test_full_bag_stays() -> void:
	var a := _hero(1, Vector3(20, 0, 20))
	while a.inventory.add(ItemRoll.new_item("ring_t1", 1), f.world.items):
		pass
	var id := _place(a.id, Vector3(20, 0, 20))
	f.world.events.clear()
	Loot.step(f.world)
	Loot.step(f.world)
	assert_true(f.world.loot.has(id))
	var warns := f.world.events.filter(func(ev: Array) -> bool: return ev[0] == "bag_full")
	assert_eq(warns.size(), 1, "warned once")


func test_expire_120s() -> void:
	var a := _hero(1, Vector3(40, 0, 40))
	var id := _place(a.id, Vector3(20, 0, 20))
	f.world.tick += f.world.ticks(119.0)
	Loot.step(f.world)
	assert_true(f.world.loot.has(id))
	f.world.tick += f.world.ticks(2.0)
	f.world.events.clear()
	Loot.step(f.world)
	assert_false(f.world.loot.has(id))
	assert_true(f.world.events.any(func(ev: Array) -> bool: return ev[0] == "loot_gone" and ev[2] == id and ev[3] == false))


func test_drops_scatter_near_the_body() -> void:
	_hero(1, Vector3(21, 0, 20))
	for i in 10:
		_kill(_monster("cultist", Vector3(20, 0, 20), true))
	for d: Dictionary in f.world.loot.values():
		assert_lte(Effects.flat(d.pos).distance_to(Vector2(20, 20)), 1.5 + 0.001)


func test_world_step_picks_up() -> void:
	var a := _hero(1, Vector3(20, 0, 20))
	var id := _place(a.id, Vector3(20, 0, 20))
	f.world.step({})
	assert_false(f.world.loot.has(id))
