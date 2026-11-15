extends GutTest
## Task 14: threat from damage and healing, taunt, the switch margin and players
## leaving mid-fight.


func _fixture() -> CombatFixture:
	var f := CombatFixture.new([], Vector2i(40, 40))
	f.world.abilities = AbilityDB.load_default()
	return f


func _wolf(f: CombatFixture, pos := Vector3(20, 0, 20)) -> MonsterState:
	var m := MonsterDB.load_default().make("wolf", f.world.next_monster_id(), pos, f.world)
	f.world.add_entity(m)
	return m


const HIT := {"type": "melee_arc", "damage": {"base": 10, "coef": 0.0, "kind": "physical", "can_crit": false}}


func test_damage_threat_uses_threat_mult() -> void:
	var f := _fixture()
	var m := _wolf(f)
	m.stats.armor = 0.0
	m.stats.dodge_chance = 0.0
	var p := f.player(1, Vector3(21, 0, 20))
	p.stats.threat_mult = 2.0
	Combat.deal(f.world, p, m, HIT, {"id": "x"})
	var dealt := m.stats.max_hp - m.hp
	assert_almost_eq(float(m.threat[1]), dealt * 2.0, 0.001)


func test_highest_threat_targeted_with_margin() -> void:
	var f := _fixture()
	var m := _wolf(f)
	f.player(1, Vector3(21, 0, 20), 9999.0)
	f.player(2, Vector3(19, 0, 20), 9999.0)
	m.threat = {1: 100.0}
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 1)
	m.threat[2] = 105.0
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 1, "5 % more is not enough to switch")
	m.threat[2] = 111.0
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 2, "more than 10 % above switches")


func test_heal_threat_split() -> void:
	var f := _fixture()
	var chasing := _wolf(f, Vector3(20, 0, 20))
	var other := _wolf(f, Vector3(30, 0, 30))
	var tank := f.player(1, Vector3(21, 0, 20), 200.0)
	var healer := f.player(2, Vector3(15, 0, 15), 200.0)
	var bystander := f.player(3, Vector3(31, 0, 30), 200.0)
	healer.stats.threat_mult = 1.0
	chasing.threat = {1: 50.0}
	other.threat = {3: 50.0}
	tank.hp = 100.0
	Combat.heal(f.world, healer, tank, 40.0)
	assert_almost_eq(float(chasing.threat.get(2, 0.0)), 20.0, 0.001, "half the healing, on monsters chasing the healed")
	assert_false(other.threat.has(2), "monsters not on the healed player do not care")
	bystander.hp = 200.0
	Combat.heal(f.world, healer, bystander, 40.0)
	assert_false(other.threat.has(2), "overhealing (0 healed) gives no threat")


func test_taunt_overrides() -> void:
	var f := _fixture()
	var m := _wolf(f)
	var dps := f.player(1, Vector3(21, 0, 20), 9999.0)
	var tank := f.player(2, Vector3(19, 0, 20), 9999.0)
	m.threat = {1: 300.0}
	m.target_id = 1
	Effects.apply(f.world, tank, {"id": "t"}, {"type": "taunt", "radius": 6, "duration_s": 4}, {"aim": tank.position})
	assert_almost_eq(float(m.threat[2]), 330.0, 0.001, "top threat + 10 %")
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 2, "taunted: attacks the taunter")
	for i in f.world.ticks(4.5):
		f.world.step({})
	m.threat[1] = 340.0 # not 10 % above 330
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 2, "after the taunt it keeps the taunter until someone passes the margin")
	assert_true(dps.is_alive())


func test_player_leaving_mid_fight_cleans_threat_and_projectiles() -> void:
	var f := _fixture()
	var m := _wolf(f, Vector3(20, 0, 20))
	f.player(1, Vector3(21, 0, 20), 9999.0)
	var leaver := f.player(2, Vector3(20, 0, 10), 9999.0)
	m.threat = {1: 10.0, 2: 50.0}
	Spawner.scale_health(f.world, m, 1.0)
	var hp_two := m.stats.max_hp
	var shot := {"type": "projectile", "speed": 20, "radius": 0.3, "range": 20, "pierce": false,
		"damage": {"base": 10, "coef": 0.0, "kind": "physical", "can_crit": false}}
	Effects.apply(f.world, leaver, {"id": "shot"}, shot, {"aim": m.position})
	assert_eq(f.world.projectiles.size(), 1)
	f.world.remove_player(2)
	assert_lt(m.stats.max_hp, hp_two, "health rescaled for the smaller group")
	var ended := false
	for i in f.world.ticks(1.0):
		f.world.events.clear()
		f.world.step({})
		if f.world.events.any(func(ev: Array) -> bool: return ev[0] == "projectile_end"):
			ended = true
	assert_true(ended, "the shot still resolves without its owner")
	assert_true(f.world.projectiles.is_empty())
	assert_false(m.threat.has(2), "the leaver is gone from the threat table")
	assert_eq(m.target_id, 1)
