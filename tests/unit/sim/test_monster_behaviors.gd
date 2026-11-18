extends GutTest
## Task 12 behaviors: the marked_boar's telegraphed charge, the cult archer keeping its
## distance, cultist packs and elite modifiers.


func _fixture(blocks := []) -> CombatFixture:
	var f := CombatFixture.new(blocks, Vector2i(48, 48))
	f.world.abilities = AbilityDB.load_default()
	return f


func _monster(f: CombatFixture, type_id: String, pos: Vector3) -> MonsterState:
	var m := MonsterDB.load_default().make(type_id, f.world.next_monster_id(), pos, f.world)
	m.facing = 0.0
	f.world.add_entity(m)
	return m


func _steps(f: CombatFixture, seconds: float) -> void:
	for i in f.world.ticks(seconds):
		_step(f)


func _step(f: CombatFixture) -> void:
	f.world.events.clear()
	f.world.step({})
	f.log.append_array(f.world.events)


func _events(f: CombatFixture, kind: String) -> Array:
	return f.log.filter(func(ev: Array) -> bool: return str(ev[0]) == kind)


func test_new_monsters_load_from_data() -> void:
	var db := MonsterDB.load_default()
	for id: String in ["marked_boar", "cultist", "cult_archer"]:
		var d := db.get_type(id)
		assert_false(d.is_empty(), id)
		for ab: String in d.get("abilities", []):
			assert_true(AbilityDB.load_default().has(ab), "%s: ability %s" % [id, ab])
	assert_eq(db.get_type("marked_boar").behavior, "charger")
	assert_eq(db.get_type("cult_archer").behavior, "ranged_kite")
	assert_true(bool(db.get_type("cultist").get("pack", false)))
	assert_true(AbilityDB.load_default().validate().is_empty(), str(AbilityDB.load_default().validate()))


func test_boar_telegraphs_then_charges_line() -> void:
	var f := _fixture()
	var marked_boar := _monster(f, "marked_boar", Vector3(20, 0, 20))
	var p := f.player(1, Vector3(20, 0, 26), 500.0)
	var start := marked_boar.position
	for i in f.world.ticks(1.0):
		_step(f)
		if not _events(f, "telegraph_line").is_empty():
			break
	var tele := _events(f, "telegraph_line")
	assert_eq(tele.size(), 1, "the charge is announced on the ground")
	var ev: Array = tele[0]
	# ["telegraph_line", id, from, to, width, fire_tick]
	assert_almost_eq(Effects.flat(ev[2]).distance_to(Effects.flat(start)), 0.0, 0.01)
	assert_almost_eq(Effects.flat(ev[3]).distance_to(Effects.flat(start)), 8.0, 0.05, "8 m line")
	assert_gt(Effects.flat(ev[3]).y, start.z, "toward the player")
	var fire_tick: int = ev[5]
	assert_gt(fire_tick, f.world.tick, "a windup before it charges")
	while f.world.tick < fire_tick - 1:
		_step(f)
	assert_eq(marked_boar.position, start, "it stays put while warning")
	assert_eq(p.hp, 500.0)
	_steps(f, 1.0)
	assert_lt(p.hp, 500.0, "the charge hits whoever stands in the line")
	assert_gt(Effects.flat(marked_boar.position).distance_to(Effects.flat(start)), 5.0, "it ran along the line")


func test_boar_charge_can_be_sidestepped() -> void:
	var f := _fixture()
	var marked_boar := _monster(f, "marked_boar", Vector3(20, 0, 20))
	var p := f.player(1, Vector3(20, 0, 26), 500.0)
	for i in f.world.ticks(1.0):
		_step(f)
		if not _events(f, "telegraph_line").is_empty():
			break
	assert_eq(_events(f, "telegraph_line").size(), 1)
	p.position = Vector3(24, 0, 26) # out of the warned line
	_steps(f, 0.9)
	var charge_hits := _events(f, "hit").filter(func(ev: Array) -> bool: return int(ev[1]) == p.id)
	assert_eq(charge_hits.size(), 0, "nothing outside the line")


func test_cult_archer_keeps_distance_and_shoots() -> void:
	var f := _fixture()
	var sk := _monster(f, "cult_archer", Vector3(20, 0, 20))
	var p := f.player(1, Vector3(20, 0, 22.5), 500.0) # 2.5 m: too close
	_steps(f, 1.5)
	var gap := Effects.flat(sk.position).distance_to(Effects.flat(p.position))
	assert_gt(gap, 4.0, "it backs away from a close player (%.1f m)" % gap)
	p.position = sk.position + Vector3(0, 0, 8)
	f.log.clear()
	_steps(f, 2.5)
	assert_gt(_events(f, "projectile").size(), 0, "it shoots from range")
	assert_lt(p.hp, 500.0, "and the arrows land")
	assert_lt(Effects.flat(sk.position).distance_to(Effects.flat(p.position)), 11.5, "it does not run off when far enough")


func test_cult_archer_cornered_still_shoots() -> void:
	# Walled in on three sides: backing away is impossible, so it fights.
	var blocks := [[19, 18, 2], [20, 18, 2], [21, 18, 2], [18, 19, 2], [18, 20, 2], [22, 19, 2], [22, 20, 2]]
	var f := _fixture(blocks)
	var sk := _monster(f, "cult_archer", Vector3(20.5, 0, 19.5))
	var p := f.player(1, Vector3(20.5, 0, 22.5), 500.0)
	_steps(f, 3.0)
	assert_gt(_events(f, "projectile").size(), 0)
	assert_lt(p.hp, 500.0)
	assert_true(sk.is_alive())


func test_goblins_pack_share_aggro() -> void:
	var f := _fixture()
	var a := _monster(f, "cultist", Vector3(20, 0, 20))
	var b := _monster(f, "cultist", Vector3(26, 0, 20)) # 6 m away, can't see the player yet
	var far := _monster(f, "cultist", Vector3(40, 0, 40)) # outside the pack radius
	var marked_hound := _monster(f, "marked_hound", Vector3(22, 0, 16))
	var p := f.player(1, Vector3(14, 0, 20))
	_steps(f, 0.2)
	assert_true(a.threat.has(p.id), "the nearest cultist sees the player")
	_steps(f, 0.2)
	assert_true(b.threat.has(p.id), "its pack mate joins in")
	assert_eq(b.ai, MonsterState.CHASE)
	assert_false(far.threat.has(p.id), "goblins too far away do not")
	assert_false(marked_hound.threat.has(p.id), "other monster types do not")


func test_pack_joins_when_a_cultist_is_hit() -> void:
	var f := _fixture()
	var a := _monster(f, "cultist", Vector3(20, 0, 20))
	var b := _monster(f, "cultist", Vector3(23, 0, 20))
	var p := f.player(1, Vector3(5, 0, 5)) # far: nobody sees it
	_steps(f, 0.2)
	a.add_threat(p.id, 10.0) # as if hit from afar
	_steps(f, 0.2)
	assert_true(b.threat.has(p.id))


func test_elite_modifiers() -> void:
	var f := _fixture()
	var b := f.world.balance
	var normal := _monster(f, "marked_hound", Vector3(10, 0, 10))
	var elite := _monster(f, "marked_hound", Vector3(12, 0, 10))
	MonsterDB.make_elite(elite, b)
	assert_true(elite.elite)
	assert_almost_eq(elite.base_max_hp, normal.base_max_hp * 2.5, 0.01)
	assert_almost_eq(elite.stats.max_hp, normal.stats.max_hp * 2.5, 0.01)
	assert_almost_eq(elite.hp, elite.stats.max_hp, 0.01)
	assert_almost_eq(elite.radius, normal.radius * 1.3, 0.001)
	assert_almost_eq(elite.stats.damage_done_mult, normal.stats.damage_done_mult * 1.4, 0.001)
	# The damage really is 1.4x.
	var p1 := f.player(1, Vector3(30, 0, 30), 1000.0)
	var p2 := f.player(2, Vector3(30, 0, 40), 1000.0)
	var bite := {"type": "melee_arc", "damage": {"base": 10, "coef": 0.0, "kind": "physical", "can_crit": false}}
	normal.stats.crit_chance = 0.0
	elite.stats.crit_chance = 0.0
	Combat.deal(f.world, normal, p1, bite, {"id": "hound_bite"})
	Combat.deal(f.world, elite, p2, bite, {"id": "hound_bite"})
	assert_almost_eq(1000.0 - p2.hp, (1000.0 - p1.hp) * 1.4, 0.01)


func test_spawner_makes_elites_by_chance() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"respawn_point": [20, 20], "spawns": [
			{"type": "cultist", "at": [30, 10], "count": 2, "radius": 1, "respawn_s": 5, "elite_chance": 1.0},
			{"type": "cultist", "at": [10, 30], "count": 2, "radius": 1, "respawn_s": 5, "elite_chance": 0.0}]})
	var w := SimWorld.new(Balance.load_from(), map, 3)
	w.step({})
	var base := float(MonsterDB.load_default().get_type("cultist").stats.max_hp)
	for m: MonsterState in w.monsters.values():
		if m.spawn_index == 0:
			assert_true(m.elite)
			assert_almost_eq(m.stats.max_hp, base * 2.5, 0.01)
		else:
			assert_false(m.elite)
			assert_almost_eq(m.stats.max_hp, base, 0.01)


func test_melee_monster_does_not_hit_through_a_wall() -> void:
	var wall := []
	for z in 48:
		wall.append([20, z, 1])
	var f := _fixture(wall)
	var p := f.player(1, Vector3(21.4, 0, 20.5), 500.0)
	var m := _monster(f, "cult_acolyte", Vector3(19.0, 0, 20.5))
	m.threat[p.id] = 10.0
	var hp := p.hp
	_steps(f, 1.5)
	assert_eq(p.hp, hp, "the wall is in the way, not a clear line")
