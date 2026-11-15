extends GutTest


func _stun(f: CombatFixture, e: CombatEntity) -> void:
	e.add_status(StatusEffect.make("stun", f.world.tick + 30), 1)


## Attention point 2: every refused cast leaves resource, cooldown and GCD untouched.
func test_cast_rejected_on_cooldown_gcd_no_resource_stunned_dead_without_cost() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5), 100.0, 100.0)
	assert_true(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)))
	assert_eq(p.resource, 50.0)
	assert_false(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)), "cooldown")
	assert_false(Combat.try_cast(f.world, p, "t_gcd_other", Vector3(6, 0, 5)), "global cooldown")
	assert_eq(p.resource, 50.0)
	f.run(2.1)
	p.resource = 10.0
	assert_false(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)), "not enough resource")
	assert_eq(p.resource, 10.0)
	p.resource = 100.0
	_stun(f, p)
	assert_false(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)), "stunned")
	p.statuses.clear()
	p.life = CombatEntity.DOWNED
	assert_false(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)), "downed")
	p.life = CombatEntity.DEAD
	assert_false(Combat.try_cast(f.world, p, "t_costly", Vector3(6, 0, 5)), "dead")
	assert_eq(p.resource, 100.0)


func test_unknown_ability_is_refused() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	assert_false(Combat.try_cast(f.world, p, "nope", Vector3.ZERO))


func test_gcd_does_not_block_basic_secondary_dodge() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "t_gcd_other", Vector3(6, 0, 5)))
	assert_true(Combat.try_cast(f.world, p, "t_arc", Vector3(6, 0, 5)), "basic ignores the GCD")
	assert_true(Combat.try_cast(f.world, p, "t_proj", Vector3(6, 0, 5)), "secondary ignores the GCD")


func test_cast_emits_event_and_faces_aim() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	Combat.try_cast(f.world, p, "t_arc", Vector3(8, 0, 5))
	var casts := f.events_of("cast")
	assert_eq(casts.size(), 1)
	assert_eq([casts[0][1], casts[0][2]], [1, "t_arc"])
	assert_almost_eq(p.facing, PI / 2.0, 0.001, "faces +X")


## Attention point 3: the caster leaves while its projectile is in the air.
func test_projectile_whose_owner_left_still_resolves_without_error() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 10))
	var d := f.dummy(1000, Vector3(10, 0, 10))
	Combat.try_cast(f.world, p, "t_proj", Vector3(20, 0, 10))
	f.world.remove_player(1)
	f.run(1.0)
	assert_eq(d.hp, 90.0)
	assert_true(f.world.projectiles.is_empty())


func test_area_target_dead_before_delay_is_fine() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(10, 0, 10))
	Combat.try_cast(f.world, p, "t_area", Vector3(10, 0, 10))
	d.hp = 0.0
	d.life = CombatEntity.DEAD
	f.world.remove_entity(1000)
	f.run(1.0)
	assert_true(f.world.pending_areas.is_empty())


func test_dead_targets_are_not_hit_again() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(10, 0, 10))
	var d := f.dummy(1000, Vector3(10, 0, 11), 5.0)
	Combat.try_cast(f.world, p, "t_arc", Vector3(10, 0, 15))
	assert_false(d.is_alive())
	assert_eq(f.events_of("died").size(), 1)
	f.run(0.6)
	Combat.try_cast(f.world, p, "t_arc", Vector3(10, 0, 15))
	assert_eq(f.events_of("hit").size(), 1)


func test_invulnerable_target_is_not_damaged() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(10, 0, 10))
	var d := f.dummy(1000, Vector3(10, 0, 11))
	d.add_status(StatusEffect.make("invulnerable", f.world.tick + 30), 1)
	Combat.try_cast(f.world, p, "t_arc", Vector3(10, 0, 15))
	assert_eq(d.hp, 100.0)


func test_ability_db_validate_reports_unknown_effect() -> void:
	var db := AbilityDB.from_list([
		{"id": "bad", "kind": "active", "effects": [{"type": "teleport_to_moon"}]},
		{"id": "no_effects", "kind": "active"},
	])
	var errors := db.validate(false)
	assert_eq(errors.size(), 2, str(errors))
	assert_true(errors[0].contains("teleport_to_moon"))
