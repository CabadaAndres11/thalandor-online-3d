extends GutTest
## Resets at the capital's trainer cost gold (Plan 8.3b): 20 per level, nothing charged when
## the reset is refused.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new()


func _hero(level: int) -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, "warrior", null, f.world)
	ProgressRequests.spend_attribute(f.world, p, "strength")
	return p


func test_reset_cost() -> void:
	assert_eq(ProgressRequests.reset_cost(10, f.world.balance), 200)
	assert_eq(f.world.balance.reset_gold_per_level, 20)


func test_reset_charges_gold() -> void:
	var p := _hero(10)
	p.inventory.gold = 199
	assert_false(ProgressRequests.reset(f.world, p, "attributes", true), "one short")
	assert_eq(p.inventory.gold, 199)
	assert_eq(p.progress.attributes.strength, 1)
	p.inventory.gold = 200
	assert_true(ProgressRequests.reset(f.world, p, "attributes", true), "the exact price")
	assert_eq(p.inventory.gold, 0)
	assert_eq(p.progress.attributes.strength, 0)
	assert_true(p.inventory_dirty)


func test_refused_resets_charge_nothing() -> void:
	var p := _hero(10)
	p.inventory.gold = 1000
	assert_false(ProgressRequests.reset(f.world, p, "talents", true), "no talents to reset")
	assert_eq(p.inventory.gold, 1000)
	p.last_combat_tick = f.world.tick
	assert_false(ProgressRequests.reset(f.world, p, "attributes", true), "in combat")
	assert_eq(p.inventory.gold, 1000)
	assert_false(ProgressRequests.reset(f.world, p, "upgrade", true), "the upgrade is final")
	assert_eq(p.inventory.gold, 1000)


func test_reset_needs_trainer() -> void:
	var p := _hero(10)
	p.inventory.gold = 1000
	assert_false(ProgressRequests.reset(f.world, p, "attributes", false))
	assert_eq(p.inventory.gold, 1000)
