extends GutTest

var world: SimWorld


func before_each() -> void:
	world = SimWorld.new(Balance.load_from(), CollisionMap.from_layout({"size": [20, 20], "spawn": [5, 5], "blocks": []}))


func _entity(kind := "", def := {}) -> CombatEntity:
	var e := CombatEntity.new()
	e.stats = CombatStats.from_dict({"max_hp": 100, "max_resource": 100})
	e.hp = 100.0
	e.resource_kind = kind
	e.resource_def = def
	return e


func _status(kind: String, seconds: float, magnitude := 0.0, stacks := 1, every_s := 0.0) -> StatusEffect:
	return StatusEffect.make(kind, world.tick + world.ticks(seconds), magnitude, 0, stacks, world.ticks(every_s))


func _run(e: CombatEntity, seconds: float) -> void:
	for i in world.ticks(seconds):
		StatusEffect.tick_entity(e, world)
		Resources.tick(e, world)
		world.tick += 1


func test_rage_gains_on_hit_and_decays_out_of_combat() -> void:
	var e := _entity("rage", {"gain_per_hit": 8, "gain_per_damage_taken": 0.5, "decay_per_s": 5})
	Resources.on_damage_dealt(e, 20.0, world)
	assert_eq(e.resource, 8.0)
	Resources.on_damage_taken(e, 20.0, world)
	assert_eq(e.resource, 18.0)
	_run(e, 2.0)
	assert_eq(e.resource, 18.0, "no decay while in combat")
	_run(e, 5.0)
	assert_lt(e.resource, 18.0, "decays once out of combat")


func test_mana_no_regen_in_combat_without_meditation() -> void:
	var e := _entity("mana", {"regen_per_s": 10, "regen_in_combat_mult": 0.0})
	e.resource = 50.0
	e.last_combat_tick = world.tick
	_run(e, 1.0)
	assert_eq(e.resource, 50.0)
	world.tick += world.ticks(world.balance.in_combat_s)
	_run(e, 1.0)
	assert_almost_eq(e.resource, 60.0, 0.5)


func test_resource_capped_at_max() -> void:
	var e := _entity("energy", {"regen_per_s": 50})
	e.resource = 90.0
	_run(e, 1.0)
	assert_eq(e.resource, 100.0)


func test_focus_regen_slower_while_dodging() -> void:
	var a := _entity("focus", {"regen_per_s": 30, "dodging_regen_mult": 0.3})
	var b := _entity("focus", {"regen_per_s": 30, "dodging_regen_mult": 0.3})
	b.dash_ticks = 1000
	_run(a, 1.0)
	_run(b, 1.0)
	assert_almost_eq(a.resource, 30.0, 0.5)
	assert_almost_eq(b.resource, 9.0, 0.5)


func test_energy_fixed_regen() -> void:
	var e := _entity("energy", {"regen_per_s": 20})
	e.last_combat_tick = world.tick
	_run(e, 1.0)
	assert_almost_eq(e.resource, 20.0, 0.5, "same rate in combat")


func test_status_expires_on_tick() -> void:
	var e := _entity()
	e.add_status(_status("stun", 1.0), 1)
	assert_true(e.has_status("stun"))
	_run(e, 1.1)
	assert_false(e.has_status("stun"))


func test_reapplying_refreshes_duration() -> void:
	var e := _entity()
	e.add_status(_status("slow", 1.0, 0.5), 1)
	_run(e, 0.8)
	e.add_status(_status("slow", 1.0, 0.5), 1)
	_run(e, 0.8)
	assert_true(e.has_status("slow"))
	assert_eq(e.statuses.size(), 1)


func test_poison_stacks_to_five_and_ticks_damage() -> void:
	var e := _entity()
	for i in 7:
		e.add_status(_status("poison", 10.0, 2.0, 1, 1.0), 5)
	assert_eq((e.statuses[0] as StatusEffect).stacks, 5)
	_run(e, 1.05)
	assert_almost_eq(e.hp, 90.0, 0.001, "5 stacks × 2 per second")


func test_slow_reduces_move_speed_mult() -> void:
	var e := _entity()
	e.add_status(_status("slow", 2.0, 0.4), 1)
	assert_almost_eq(e.move_mult(), 0.6, 0.0001)


func test_stun_and_freeze_block_actions() -> void:
	var e := _entity()
	assert_true(e.can_act(world.tick))
	e.add_status(_status("stun", 1.0), 1)
	assert_false(e.can_act(world.tick))
	var f := _entity()
	f.add_status(_status("freeze", 1.0), 1)
	assert_false(f.can_act(world.tick))
	assert_eq(f.move_mult(), 0.0)


func test_root_blocks_movement_not_actions() -> void:
	var e := _entity()
	e.add_status(_status("root", 1.0), 1)
	assert_true(e.can_act(world.tick))
	assert_eq(e.move_mult(), 0.0)


func test_hot_heals_over_time_capped() -> void:
	var e := _entity()
	e.hp = 95.0
	e.add_status(_status("hot", 3.0, 4.0, 1, 1.0), 1)
	_run(e, 3.1)
	assert_eq(e.hp, 100.0)


func test_players_regen_life_out_of_combat() -> void:
	assert_eq(world.balance.out_of_combat_hp_pct, 0.02)
	var p := PlayerState.new()
	p.stats = CombatStats.from_dict({"max_hp": 200})
	p.hp = 100.0
	_run(p, 1.0)
	assert_almost_eq(p.hp, 104.0, 0.01, "2 % of max life per second")


func test_no_passive_regen_in_combat() -> void:
	var p := PlayerState.new()
	p.stats = CombatStats.from_dict({"max_hp": 200})
	p.hp = 100.0
	p.last_combat_tick = world.tick
	_run(p, 1.0)
	assert_eq(p.hp, 100.0)


func test_monsters_have_no_passive_regen() -> void:
	var e := _entity()
	e.hp = 50.0
	_run(e, 1.0)
	assert_eq(e.hp, 50.0)
