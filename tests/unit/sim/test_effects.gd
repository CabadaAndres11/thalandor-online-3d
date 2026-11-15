extends GutTest


func test_melee_arc_hits_inside_angle_and_range_only() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(10, 0, 10))
	var front := f.dummy(1000, Vector3(10, 0, 11.5))
	var side := f.dummy(1001, Vector3(11.5, 0, 10)) # 90° away: outside a 90° arc
	var far := f.dummy(1002, Vector3(10, 0, 13.5))
	assert_true(Combat.try_cast(f.world, p, "t_arc", Vector3(10, 0, 15)))
	assert_eq(front.hp, 90.0)
	assert_eq(side.hp, 100.0)
	assert_eq(far.hp, 100.0)


func test_no_friendly_fire() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(10, 0, 10))
	var ally := f.player(2, Vector3(10, 0, 11))
	Combat.try_cast(f.world, p, "t_arc", Vector3(10, 0, 15))
	assert_eq(ally.hp, 100.0)


func test_projectile_travels_and_hits_first_enemy() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 10))
	var first := f.dummy(1000, Vector3(9, 0, 10))
	var second := f.dummy(1001, Vector3(12, 0, 10))
	Combat.try_cast(f.world, p, "t_proj", Vector3(20, 0, 10))
	assert_eq(f.events_of("projectile").size(), 1)
	assert_eq(first.hp, 100.0, "not instant")
	f.run(1.0)
	assert_eq(first.hp, 90.0)
	assert_eq(second.hp, 100.0)
	assert_eq(f.events_of("projectile_end").size(), 1)
	assert_true(f.world.projectiles.is_empty())


func test_piercing_projectile_hits_all_in_line() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 10))
	var a := f.dummy(1000, Vector3(8, 0, 10))
	var b := f.dummy(1001, Vector3(11, 0, 10))
	Combat.try_cast(f.world, p, "t_pierce", Vector3(25, 0, 10))
	f.run(1.0)
	assert_eq(a.hp, 90.0)
	assert_eq(b.hp, 90.0, "pierces")


func test_projectile_stops_at_solid_cell() -> void:
	var f := CombatFixture.new([[8, 10, 1]])
	var p := f.player(1, Vector3(5, 0, 10.5))
	var behind := f.dummy(1000, Vector3(11, 0, 10.5))
	Combat.try_cast(f.world, p, "t_proj", Vector3(20, 0, 10.5))
	f.run(1.0)
	assert_eq(behind.hp, 100.0)
	assert_true(f.world.projectiles.is_empty())


func test_area_waits_delay_and_emits_telegraph() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(10, 0, 10))
	Combat.try_cast(f.world, p, "t_area", Vector3(10, 0, 10))
	var tele := f.events_of("telegraph")
	assert_eq(tele.size(), 1)
	assert_eq(tele[0][2], Vector3(10, 0, 10))
	f.run(0.3)
	assert_eq(d.hp, 100.0, "still waiting")
	f.run(0.3)
	assert_eq(d.hp, 80.0)


func test_dash_moves_toward_cursor_and_stops_at_wall() -> void:
	var f := CombatFixture.new([[12, 10, 1]])
	var p := f.player(1, Vector3(8, 0, 10.5))
	Combat.try_cast(f.world, p, "t_dash", Vector3(20, 0, 10.5))
	f.run(0.5)
	assert_almost_eq(p.position.x, 12.0 - p.radius, 0.01, "stopped at the block")
	var q := f.player(2, Vector3(3, 0, 20))
	Combat.try_cast(f.world, q, "t_dash", Vector3(20, 0, 20))
	f.run(0.5)
	assert_almost_eq(q.position.x, 9.0, 0.01, "6 m dash")


func test_blink_behind_target() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(10, 0, 10))
	d.facing = 0.0 # looks toward +Z, so its back is -Z
	assert_true(Combat.try_cast(f.world, p, "t_blink_behind", Vector3(10.2, 0, 10)))
	assert_lt(p.position.z, 10.0, "behind the target")
	assert_almost_eq(p.position.x, 10.0, 0.01)
	assert_almost_eq(p.facing, 0.0, 0.01, "facing the target's back")


func test_blink_behind_without_target_fails_without_cost() -> void:
	var f := CombatFixture.new()
	var p := f.player(1, Vector3(5, 0, 5))
	assert_false(Combat.try_cast(f.world, p, "t_blink_behind", Vector3(10, 0, 10)))
	assert_eq(p.position, Vector3(5, 0, 5))
