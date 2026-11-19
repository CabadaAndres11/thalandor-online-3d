extends GutTest
## Equipment in the final stats (GearStats + Progression.rebuild) and shield-only block.

var f: CombatFixture
var db: ItemDB


func before_each() -> void:
	f = CombatFixture.new()
	db = ItemDB.load_default()


func _hero(class_id: String, level := 1) -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	return p


func _wear(p: PlayerState, slot: String, base_id: String, level := 1, affixes: Array = []) -> Item:
	var it := ItemRoll.new_item(base_id, level)
	it.affixes = affixes
	p.inventory.equipment[slot] = it
	Progression.rebuild(p, f.world)
	return it


func test_gear_adds_armor() -> void:
	var p := _hero("warrior", 10)
	var before := p.stats.armor
	_wear(p, "chest", "plate_chest_t1", 10)
	assert_almost_eq(p.stats.armor - before, 1.0 + 1.2 * 10, 0.001)


func test_attribute_affix_raises_attack_power() -> void:
	var p := _hero("warrior", 10)
	var before := p.stats.attack_power
	_wear(p, "neck", "neck_t1", 10, [{"id": "strength", "value": 12.0}])
	# neck_t1: +2 stamina at level 10; +12 strength → +6 attack power (0.5 per point).
	assert_almost_eq(p.stats.attack_power - before, 6.0, 0.001)


func test_two_handed_stats_scaled() -> void:
	var mods := GearStats.mods(_inv_with("main", "greatsword_t1", 10), db)
	var ap := 0.0
	for m: Dictionary in mods:
		if m.stat == "attack_power_add":
			ap += float(m.value)
	assert_almost_eq(ap, (4 + 2 * 10) * 1.8, 0.001)


func _inv_with(slot: String, base_id: String, level: int) -> Inventory:
	var inv := Inventory.new()
	inv.equipment[slot] = ItemRoll.new_item(base_id, level)
	return inv


func test_pct_affix() -> void:
	var p := _hero("mage", 10)
	var before := p.stats.max_hp
	_wear(p, "ring_1", "ring_t1", 1, [{"id": "max_hp", "value": 0.1}])
	assert_gt(p.stats.max_hp, before * 1.09)


func test_broken_gear_ignored() -> void:
	var p := _hero("warrior", 10)
	var before := p.stats.armor
	var it := _wear(p, "chest", "plate_chest_t1", 10)
	it.durability = 0
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.armor, before, 0.001)


func test_block_needs_shield() -> void:
	var p := _hero("warrior", 10)
	p.progress.attributes.strength = 45
	Progression.rebuild(p, f.world)
	assert_eq(p.stats.block_chance, 0.0)
	_wear(p, "offhand", "shield_t1", 10)
	assert_gt(p.stats.block_chance, 0.0)


func test_broken_shield_no_block() -> void:
	var p := _hero("warrior", 10)
	var it := _wear(p, "offhand", "shield_t1", 10)
	it.durability = 0
	Progression.rebuild(p, f.world)
	assert_eq(p.stats.block_chance, 0.0)


func test_family() -> void:
	assert_eq(GearStats.family(_inv_with("main", "wand_t1", 1), db), "wand")
	assert_eq(GearStats.family(Inventory.new(), db), "")


func test_rebuild_keeps_ratio() -> void:
	var p := _hero("warrior", 10)
	p.hp = p.stats.max_hp * 0.5
	_wear(p, "chest", "plate_chest_t1", 10, [{"id": "stamina", "value": 20.0}])
	assert_almost_eq(p.hp / p.stats.max_hp, 0.5, 0.001)
