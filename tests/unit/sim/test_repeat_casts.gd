extends GutTest
## Abilities with a "repeat" block hit several times; a channelled one stops if the
## caster moves and blocks other casts while it lasts.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))


func _ab(id: String, repeat: Dictionary, extra := {}) -> Dictionary:
	var a := {"id": id, "class": "test", "kind": "active", "cost": 10, "cooldown_s": 5, "gcd": false, "range": 5,
		"repeat": repeat, "combo_gain": 2,
		"effects": [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 10, "coef": 0, "kind": "magic", "can_crit": false}}]}
	a.merge(extra, true)
	return a


func _setup(repeat: Dictionary, extra := {}) -> Array:
	f.world.abilities = AbilityDB.from_list([_ab("rep", repeat, extra),
		{"id": "other", "class": "test", "kind": "active", "cost": 0, "cooldown_s": 0, "gcd": false, "range": 5,
			"effects": [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 1, "coef": 0, "kind": "magic", "can_crit": false}}]}])
	var p := f.player(1, Vector3(10, 0, 10))
	var t := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	return [p, t]


func test_hits_several_times() -> void:
	var s := _setup({"times": 3, "interval_s": 0.2})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	assert_eq(t.hp, 990.0, "the first hit lands with the cast")
	f.run(0.1)
	assert_eq(t.hp, 990.0)
	f.run(0.2)
	assert_eq(t.hp, 980.0)
	f.run(0.5)
	assert_eq(t.hp, 970.0, "three hits in all")


func test_cost_and_cooldown_are_paid_once_at_the_cast() -> void:
	var s := _setup({"times": 3, "interval_s": 0.2})
	var p: PlayerState = s[0]
	assert_true(Combat.try_cast(f.world, p, "rep", p.position + Vector3(1, 0, 0)))
	assert_eq(p.resource, 90.0)
	assert_eq(p.cooldowns["rep"], f.world.tick + f.world.ticks(5.0))
	f.run(1.0)
	assert_eq(p.resource, 90.0)


func test_delay_before_the_first_hit() -> void:
	var s := _setup({"times": 1, "interval_s": 0.0, "delay_s": 1.5})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	f.run(1.0)
	assert_eq(t.hp, 1000.0)
	f.run(0.8)
	assert_eq(t.hp, 990.0)


func test_combo_counts_once_with_the_total_of_hits() -> void:
	var s := _setup({"times": 4, "interval_s": 0.1})
	var p: PlayerState = s[0]
	assert_true(Combat.try_cast(f.world, p, "rep", (s[1] as CombatEntity).position))
	f.run(0.2)
	assert_eq(p.combo, 0, "not before the end")
	f.run(0.5)
	assert_eq(p.combo, 2)


func test_repeat_stops_when_stunned() -> void:
	var s := _setup({"times": 4, "interval_s": 0.2})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	p.add_status(StatusEffect.make("stun", f.world.tick + 600), 1)
	f.run(1.5)
	assert_eq(t.hp, 990.0, "only the first hit")


func test_repeat_stops_when_the_caster_dies_or_falls() -> void:
	var s := _setup({"times": 4, "interval_s": 0.2})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	p.life = CombatEntity.DOWNED
	f.run(1.5)
	assert_eq(t.hp, 990.0)
	assert_eq(f.world.pending_casts.size(), 0, "nothing left pending")


func test_a_plain_repeat_does_not_stop_when_moving() -> void:
	var s := _setup({"times": 3, "interval_s": 0.2})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	p.position += Vector3(0.5, 0, 0)
	f.run(0.6)
	assert_eq(t.hp, 970.0)


func test_channel_stops_on_move() -> void:
	var s := _setup({"times": 5, "interval_s": 0.2, "channel": true})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	f.run(0.25)
	assert_eq(t.hp, 980.0)
	p.position += Vector3(0.5, 0, 0)
	f.run(1.0)
	assert_eq(t.hp, 980.0, "the move cut the channel")
	assert_eq(f.events_of("channel_end").size(), 1)
	assert_eq(p.combo, 2, "the hits so far still count")


func test_channel_stops_on_dodge() -> void:
	var s := _setup({"times": 5, "interval_s": 0.2, "channel": true})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	p.dash_ticks = 5
	f.run(1.0)
	assert_eq(t.hp, 990.0)


func test_channel_blocks_other_casts() -> void:
	var s := _setup({"times": 3, "interval_s": 0.2, "channel": true})
	var p: PlayerState = s[0]
	var t: CombatEntity = s[1]
	assert_true(Combat.try_cast(f.world, p, "rep", t.position))
	assert_false(Combat.try_cast(f.world, p, "other", t.position), "busy channelling")
	f.run(0.6)
	assert_true(Combat.try_cast(f.world, p, "other", t.position), "free again when it ends")


func test_channel_events() -> void:
	var s := _setup({"times": 3, "interval_s": 0.2, "channel": true})
	var p: PlayerState = s[0]
	assert_true(Combat.try_cast(f.world, p, "rep", (s[1] as CombatEntity).position))
	var started := (f.world.events as Array).filter(func(e: Array) -> bool: return e[0] == "channel")
	assert_eq(started.size(), 1)
	assert_eq(started[0][1], 1)
	assert_eq(started[0][2], "rep")
	assert_almost_eq(float(started[0][3]), 0.4, 0.001, "duration of the channel")
	f.run(0.8)
	assert_eq(f.events_of("channel_end").size(), 1)


func test_two_casts_of_other_players_run_side_by_side() -> void:
	var s := _setup({"times": 2, "interval_s": 0.2})
	var q := f.player(2, Vector3(12, 0, 10))
	assert_true(Combat.try_cast(f.world, s[0], "rep", (s[1] as CombatEntity).position))
	assert_true(Combat.try_cast(f.world, q, "rep", (s[1] as CombatEntity).position))
	f.run(0.5)
	assert_eq((s[1] as CombatEntity).hp, 960.0)
