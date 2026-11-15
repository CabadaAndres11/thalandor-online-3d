extends GutTest
## Task 14: downed in a group, reviving with E, cancelling, bleeding out and the whole
## group falling.


func _world() -> SimWorld:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [5, 5], "blocks": [], "respawn_point": [6, 6]})
	return SimWorld.new(Balance.load_from(), map, 5)


func _player(w: SimWorld, id: int, pos: Vector3) -> PlayerState:
	var p := w.add_player(id, pos)
	ClassRules.setup_player(p, "warrior")
	return p


func _kill(w: SimWorld, e: CombatEntity) -> void:
	Damage.apply(e, {"amount": 99999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)


var _seq := 0


## Steps with `id` holding E (and optionally moving).
func _hold(w: SimWorld, id: int, seconds: float, move := Vector2.ZERO) -> Array:
	var seen: Array = []
	for i in w.ticks(seconds):
		_seq += 1
		w.events.clear()
		w.step({id: PlayerInput.new(_seq, move, Vector3.ZERO, PlayerInput.BTN_INTERACT_HELD)})
		seen.append_array(w.events)
	return seen


func _kinds(events: Array) -> Array:
	return events.map(func(ev: Array) -> String: return str(ev[0]))


func test_solo_player_dies_not_downed() -> void:
	var w := _world()
	var p := _player(w, 1, Vector3(20, 0, 20))
	_kill(w, p)
	assert_eq(p.life, CombatEntity.DEAD)


func test_downed_in_group_revived_with_e() -> void:
	var w := _world()
	var down := _player(w, 1, Vector3(20, 0, 20))
	_player(w, 2, Vector3(21, 0, 20))
	_kill(w, down)
	assert_eq(down.life, CombatEntity.DOWNED, "an ally is standing: downed, not dead")
	assert_has(_kinds(w.events), "downed")
	var evs := _hold(w, 2, w.balance.revive_hold_s - 0.2)
	assert_has(_kinds(evs), "revive_start")
	assert_eq(down.life, CombatEntity.DOWNED, "not yet")
	evs = _hold(w, 2, 0.4)
	assert_eq(down.life, CombatEntity.ALIVE)
	assert_almost_eq(down.hp, down.stats.max_hp * w.balance.revive_hp_pct, 0.01)
	assert_has(_kinds(evs), "revived")


func test_revive_needs_range() -> void:
	var w := _world()
	var down := _player(w, 1, Vector3(20, 0, 20))
	_player(w, 2, Vector3(20 + w.balance.revive_range + 1.0, 0, 20))
	_kill(w, down)
	_hold(w, 2, w.balance.revive_hold_s + 0.5)
	assert_eq(down.life, CombatEntity.DOWNED, "too far away")


func test_revive_cancels_on_move_or_damage() -> void:
	var w := _world()
	var down := _player(w, 1, Vector3(20, 0, 20))
	var helper := _player(w, 2, Vector3(21, 0, 20))
	_kill(w, down)
	_hold(w, 2, 1.5)
	var evs := _hold(w, 2, 0.1, Vector2(0, 1))
	assert_has(_kinds(evs), "revive_cancel", "moving cancels")
	helper.position = Vector3(21, 0, 20)
	_hold(w, 2, 2.0)
	assert_eq(down.life, CombatEntity.DOWNED, "the time starts again after a cancel")
	Damage.apply(helper, {"amount": 5.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	evs = _hold(w, 2, 0.1)
	assert_has(_kinds(evs), "revive_cancel", "taking damage cancels")
	_hold(w, 2, 2.0)
	assert_eq(down.life, CombatEntity.DOWNED)
	evs = []
	for i in w.ticks(0.2):
		w.events.clear()
		w.step({})
		evs.append_array(w.events)
	assert_has(_kinds(evs), "revive_cancel", "letting go of E cancels")
	_hold(w, 2, w.balance.revive_hold_s + 0.2)
	assert_eq(down.life, CombatEntity.ALIVE, "a full uninterrupted hold works")


func test_downed_bleeds_out_then_respawns() -> void:
	var w := _world()
	var down := _player(w, 1, Vector3(20, 0, 20))
	_player(w, 2, Vector3(30, 0, 30))
	_kill(w, down)
	for i in w.ticks(w.balance.downed_s - 0.2):
		w.step({})
	assert_eq(down.life, CombatEntity.DOWNED)
	for i in w.ticks(0.4):
		w.step({})
	assert_eq(down.life, CombatEntity.DEAD, "nobody came")
	for i in w.ticks(w.balance.respawn_s + 0.2):
		w.step({})
	assert_eq(down.life, CombatEntity.ALIVE)


func test_all_down_respawn_all() -> void:
	var w := _world()
	var a := _player(w, 1, Vector3(20, 0, 20))
	var b := _player(w, 2, Vector3(25, 0, 20))
	_kill(w, a)
	assert_eq(a.life, CombatEntity.DOWNED)
	_kill(w, b)
	assert_eq(b.life, CombatEntity.DEAD, "the last one standing falls: nobody can revive")
	assert_eq(a.life, CombatEntity.DEAD, "the downed ones die with them")
	for i in w.ticks(w.balance.respawn_s + 0.2):
		w.step({})
	for p: PlayerState in [a, b]:
		assert_eq(p.life, CombatEntity.ALIVE)
		assert_eq(p.hp, p.stats.max_hp)
		assert_eq(Effects.flat(p.position), Vector2(6.5, 6.5))


func test_downed_cannot_act_and_is_ignored() -> void:
	var w := _world()
	w.abilities = AbilityDB.load_default()
	var down := _player(w, 1, Vector3(20, 0, 20))
	_player(w, 2, Vector3(35, 0, 35))
	var m := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(22, 0, 20), w)
	w.add_entity(m)
	_kill(w, down)
	assert_false(Combat.try_cast(w, down, "warrior_slash", Vector3(22, 0, 20)))
	for i in w.ticks(0.5):
		w.step({})
	assert_ne(m.target_id, 1, "monsters ignore downed players")
