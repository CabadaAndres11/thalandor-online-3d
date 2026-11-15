extends GutTest


func _world() -> SimWorld:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [5, 5], "blocks": [], "respawn_point": [6, 6]})
	return SimWorld.new(Balance.load_from(), map, 5)


func _kill(w: SimWorld, e: CombatEntity) -> void:
	Damage.apply(e, {"amount": 99999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)


func _steps(w: SimWorld, seconds: float) -> void:
	for i in w.ticks(seconds):
		w.step({})


func test_solo_death_respawns_after_3s_full_hp() -> void:
	var w := _world()
	var p := w.add_player(1, Vector3(20, 0, 20))
	ClassRules.setup_player(p, "mage")
	p.resource = 10.0
	p.add_status(StatusEffect.make("poison", 100000, 1.0, 0, 1, 30), 5)
	_kill(w, p)
	assert_eq(p.life, CombatEntity.DEAD)
	assert_has(w.events.map(func(ev: Array) -> String: return ev[0]), "died")
	_steps(w, w.balance.respawn_s - 0.2)
	assert_eq(p.life, CombatEntity.DEAD, "still down")
	w.events.clear()
	_steps(w, 0.4)
	assert_eq(p.life, CombatEntity.ALIVE)
	assert_eq(p.hp, p.stats.max_hp)
	assert_eq(p.resource, p.stats.max_resource)
	assert_true(p.statuses.is_empty())
	assert_eq(Effects.flat(p.position), Vector2(6.5, 6.5), "at the respawn point")
	assert_true(w.events.any(func(ev: Array) -> bool: return ev[0] == "respawned" and ev[1] == 1))


func test_dead_player_cannot_move_or_act() -> void:
	var w := _world()
	var p := w.add_player(1, Vector3(20, 0, 20))
	ClassRules.setup_player(p, "warrior")
	_kill(w, p)
	w.step({1: PlayerInput.new(1, Vector2(1, 0), Vector3(25, 0, 20), PlayerInput.BTN_DODGE)})
	assert_eq(p.position, Vector3(20, 0, 20))
	assert_false(Combat.try_cast(w, p, "warrior_slash", Vector3(25, 0, 20)))


func test_monsters_return_home_after_target_died() -> void:
	var w := _world()
	var p := w.add_player(1, Vector3(20, 0, 20))
	ClassRules.setup_player(p, "warrior")
	var m := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(22, 0, 20), w)
	w.add_entity(m)
	m.home = Vector3(30, 0, 20) # it came from afar
	m.threat[1] = 10.0
	m.ai = MonsterState.CHASE
	_kill(w, p)
	_steps(w, 0.2)
	assert_eq(m.ai, MonsterState.RETURN)
	_steps(w, 2.0)
	assert_eq(m.ai, MonsterState.IDLE)


func test_monsters_stay_dead() -> void:
	var w := _world()
	var m := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(22, 0, 20), w)
	w.add_entity(m)
	_kill(w, m)
	_steps(w, 5.0)
	assert_eq(m.life, CombatEntity.DEAD, "monsters never respawn in place (the spawner makes new ones)")


func test_projectile_hit_puts_caster_in_combat() -> void:
	var w := _world()
	var p := w.add_player(1, Vector3(20, 0, 20))
	ClassRules.setup_player(p, "mage")
	var m := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(24, 0, 20), w)
	w.add_entity(m)
	m.stats.dodge_chance = 0.0
	m.add_status(StatusEffect.make("stun", 100000, 0.0, 0, 1, 0), 1) # it must not bite back
	p.resource = 50.0
	assert_true(Combat.try_cast(w, p, "mage_missile", m.position))
	_steps(w, 0.5)
	assert_lt(m.hp, m.stats.max_hp, "the missile hit")
	assert_true(p.in_combat(w), "ranged damage counts as fighting")
	var mana := p.resource
	_steps(w, 1.0)
	assert_lte(p.resource, mana, "no mana regen while in combat")


func test_area_hit_gives_rage() -> void:
	var w := _world()
	var p := w.add_player(1, Vector3(20, 0, 20))
	ClassRules.setup_player(p, "warrior")
	var m := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(20.6, 0, 20), w)
	w.add_entity(m)
	m.stats.dodge_chance = 0.0
	var pa := PendingArea.new()
	pa.owner = Combat.snapshot_of(p)
	var before := p.resource
	Combat.deal(w, pa.owner, m, {"damage": {"base": 5, "coef": 0, "kind": "physical"}}, {})
	assert_gt(p.resource, before, "rage from a hit dealt through a snapshot")
	assert_true(p.in_combat(w))
