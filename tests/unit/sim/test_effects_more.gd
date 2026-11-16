extends GutTest
## Task 9 effects: status (all kinds), heal over time, trap, stealth, cleanse, revive
## and taunt.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new()


func _ab(id: String, effects: Array, extra: Dictionary = {}) -> Dictionary:
	var a := {"id": id, "class": "test", "kind": "active", "cost": 0, "cooldown_s": 0, "gcd": false,
		"range": 30, "effects": effects}
	a.merge(extra, true)
	return a


func _use(list: Array) -> void:
	f.world.abilities = AbilityDB.from_list(list)


func _hits_on(id: int) -> Array:
	return f.events_of("hit").filter(func(ev: Array) -> bool: return ev[1] == id)


# --- status ---------------------------------------------------------------------

func test_status_on_enemy_needs_a_target() -> void:
	_use([_ab("net", [{"type": "status", "target": "enemy", "statuses": [{"kind": "root", "duration_s": 3}]}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(9, 0, 5))
	assert_false(Combat.try_cast(f.world, p, "net", Vector3(20, 0, 20)), "nobody under the cursor")
	assert_true(Combat.try_cast(f.world, p, "net", d.position))
	assert_true(d.has_status("root"))
	assert_eq(d.move_mult(), 0.0)


func test_status_on_allies_around() -> void:
	_use([_ab("shout", [{"type": "status", "target": "allies_around", "radius": 5,
		"statuses": [{"kind": "damage_buff", "duration_s": 8, "magnitude": 0.2}]}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var near := f.player(2, Vector3(7, 0, 5))
	var far := f.player(3, Vector3(20, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "shout", p.position))
	assert_true(p.has_status("damage_buff"))
	assert_true(near.has_status("damage_buff"))
	assert_false(far.has_status("damage_buff"))


func test_damage_statuses_change_damage() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5), 1000.0)
	var spec := {"base": 100, "coef": 0, "kind": "magic"}
	assert_eq(Damage.roll(p, d, spec, f.world).amount, 100.0)
	p.add_status(StatusEffect.make("damage_buff", 999, 0.2))
	assert_almost_eq(float(Damage.roll(p, d, spec, f.world).amount), 120.0, 0.01, "+20 % damage done")
	d.add_status(StatusEffect.make("mark", 999, 0.15))
	assert_almost_eq(float(Damage.roll(p, d, spec, f.world).amount), 138.0, 0.01, "+15 % damage taken")
	d.add_status(StatusEffect.make("damage_reduction", 999, 0.5))
	assert_almost_eq(float(Damage.roll(p, d, spec, f.world).amount), 69.0, 0.01, "−50 % damage taken")


func test_evasion_adds_dodge() -> void:
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5))
	d.add_status(StatusEffect.make("evasion", 999, 1.0))
	assert_true(Damage.roll(p, d, {"base": 10}, f.world).dodged)


# --- heal over time ---------------------------------------------------------------

func test_hot_ticks() -> void:
	_use([_ab("renew", [{"type": "heal", "target": "self", "amount": {"base": 30, "coef": 0},
		"hot": {"duration_s": 3, "every_s": 1}}])])
	var p := f.player(1, Vector3(5, 0, 5))
	p.hp = 50.0
	assert_true(Combat.try_cast(f.world, p, "renew", p.position))
	assert_eq(p.hp, 50.0, "nothing up front")
	f.run(3.1)
	assert_almost_eq(p.hp, 80.0, 0.01, "30 over 3 ticks of 10")
	assert_eq(f.events_of("heal").size(), 3)


# --- trap ---------------------------------------------------------------------------

func test_trap_arms_and_triggers_once() -> void:
	_use([_ab("trap", [{"type": "trap", "radius": 1.5, "arm_s": 1.0, "lifetime_s": 20,
		"damage": {"base": 40, "coef": 0, "kind": "physical"}}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(10, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "trap", Vector3(10, 0, 5)))
	f.run(0.5)
	assert_eq(d.hp, 100.0, "not armed yet")
	f.run(1.0)
	assert_eq(d.hp, 60.0, "armed: the enemy standing on it sets it off")
	f.run(2.0)
	assert_eq(d.hp, 60.0, "only once")
	assert_eq(f.world.traps.size(), 0)
	assert_eq(f.events_of("trap_fired").size(), 1)


func test_trap_expires() -> void:
	_use([_ab("trap", [{"type": "trap", "radius": 1.5, "arm_s": 0.1, "lifetime_s": 1.0,
		"damage": {"base": 40, "coef": 0}}])])
	var p := f.player(1, Vector3(5, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "trap", Vector3(10, 0, 5)))
	f.run(1.2)
	assert_eq(f.world.traps.size(), 0)
	var d := f.dummy(1000, Vector3(10, 0, 5))
	f.run(0.5)
	assert_eq(d.hp, 100.0)


# --- stealth -----------------------------------------------------------------------

func test_stealth_breaks_on_attack_and_damage() -> void:
	_use([_ab("stealth", [{"type": "stealth", "duration_s": 20}]),
		_ab("hit", [{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 5}}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var d := f.dummy(1000, Vector3(6, 0, 5))
	assert_true(Combat.try_cast(f.world, p, "stealth", p.position))
	assert_true(p.has_status("stealth"))
	assert_true(Combat.try_cast(f.world, p, "hit", d.position))
	assert_false(p.has_status("stealth"), "attacking reveals you")
	f.world.tick += f.world.ticks(10.0) # out of combat again
	assert_true(Combat.try_cast(f.world, p, "stealth", p.position))
	Damage.apply(p, {"amount": 1.0, "crit": false, "dodged": false, "absorbed": 0.0}, f.world)
	assert_false(p.has_status("stealth"), "taking damage reveals you")


func test_stealth_cast_rejected_when_in_combat_unless_vanish() -> void:
	_use([_ab("stealth", [{"type": "stealth", "duration_s": 20}], {"cost": 10, "cooldown_s": 5}),
		_ab("vanish", [{"type": "stealth", "duration_s": 5, "vanish": true}], {"cost": 10, "cooldown_s": 5})])
	var p := f.player(1, Vector3(5, 0, 5))
	var m := MonsterDB.load_default().make("marked_hound", f.world.next_monster_id(), Vector3(8, 0, 5), f.world)
	f.world.add_entity(m)
	m.threat[1] = 50.0
	p.last_combat_tick = f.world.tick
	assert_false(Combat.try_cast(f.world, p, "stealth", p.position), "in combat")
	assert_eq(p.resource, 100.0, "no cost")
	assert_false(p.cooldowns.has("stealth"), "no cooldown")
	assert_true(Combat.try_cast(f.world, p, "vanish", p.position), "vanish works in combat")
	assert_true(p.has_status("stealth"))
	assert_false(p.in_combat(f.world), "vanish leaves combat")
	assert_false(m.threat.has(1), "monsters forget you")


# --- cleanse -------------------------------------------------------------------------

func test_cleanse_removes_only_negative() -> void:
	_use([_ab("purify", [{"type": "cleanse", "target": "ally_or_self"}])])
	var p := f.player(1, Vector3(5, 0, 5))
	var ally := f.player(2, Vector3(9, 0, 5))
	for k: String in ["poison", "slow", "root", "mark"]:
		ally.add_status(StatusEffect.make(k, 999, 0.1))
	ally.add_status(StatusEffect.make("damage_buff", 999, 0.2))
	ally.add_status(StatusEffect.make("hot", 999, 1.0))
	assert_true(Combat.try_cast(f.world, p, "purify", ally.position))
	var kinds := ally.statuses.map(func(s: StatusEffect) -> String: return s.kind)
	kinds.sort()
	assert_eq(kinds, ["damage_buff", "hot"])


# --- revive ----------------------------------------------------------------------------

func test_revive_far_ally() -> void:
	_use([_ab("res", [{"type": "revive", "range": 20}], {"cooldown_s": 60})])
	var p := f.player(1, Vector3(5, 0, 5))
	var ally := f.player(2, Vector3(20, 0, 5))
	ally.hp = 0.0
	ally.life = CombatEntity.DOWNED
	assert_false(Combat.try_cast(f.world, p, "res", Vector3(5, 0, 20)), "nobody downed there")
	assert_false(p.cooldowns.has("res"))
	assert_true(Combat.try_cast(f.world, p, "res", ally.position))
	assert_eq(ally.life, CombatEntity.ALIVE)
	assert_almost_eq(ally.hp, ally.stats.max_hp * f.world.balance.revive_hp_pct, 0.01)
	assert_eq(f.events_of("revived").size(), 1)


func test_revive_out_of_range_rejected() -> void:
	_use([_ab("res", [{"type": "revive", "range": 10}])])
	var p := f.player(1, Vector3(2, 0, 5))
	var ally := f.player(2, Vector3(25, 0, 5))
	ally.life = CombatEntity.DOWNED
	assert_false(Combat.try_cast(f.world, p, "res", ally.position))
	assert_eq(ally.life, CombatEntity.DOWNED)


# --- taunt -------------------------------------------------------------------------------

func test_taunt_forces_target() -> void:
	_use([_ab("taunt", [{"type": "taunt", "radius": 8, "duration_s": 4}])])
	var tank := f.player(1, Vector3(10, 0, 10))
	var dps := f.player(2, Vector3(12, 0, 10))
	var m := MonsterDB.load_default().make("marked_hound", f.world.next_monster_id(), Vector3(13, 0, 10), f.world)
	f.world.add_entity(m)
	m.threat[2] = 500.0
	m.target_id = 2
	m.ai = MonsterState.CHASE
	assert_true(Combat.try_cast(f.world, tank, "taunt", tank.position))
	assert_true(m.has_status("taunted"))
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 1, "taunted: attacks the tank despite less threat")
	f.world.tick += f.world.ticks(5.0)
	StatusEffect.tick_entity(m, f.world)
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 1, "after the taunt the tank holds the top threat (+10 %)")
	m.threat[2] = float(m.threat[1]) * 1.2
	MonsterAI.tick(f.world, m)
	assert_eq(m.target_id, 2, "until someone passes it by the margin")
	assert_true(is_instance_valid(dps))


func test_all_effect_types_known() -> void:
	for t: String in ["status", "trap", "stealth", "cleanse", "revive", "taunt"]:
		assert_has(Effects.TYPES, t)
