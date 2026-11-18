extends GutTest
## The class upgrade framework: choosing, its abilities and passives, the evolution of a
## base ability and resetting.

var f: CombatFixture
var ups: UpgradeDB


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))
	var hit := {"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 10, "coef": 0, "kind": "magic", "can_crit": false}}
	f.world.abilities = AbilityDB.from_list([
		{"id": "w_hit", "class": "warrior", "kind": "active", "level": 1, "cost": 0, "cooldown_s": 5, "gcd": false, "effects": [hit]},
		{"id": "w_up_a", "class": "warrior", "kind": "active", "level": 50, "upgrade": "berserker", "cost": 0, "cooldown_s": 1, "gcd": false, "effects": [hit]},
		{"id": "w_up_p", "class": "warrior", "kind": "passive", "level": 50, "upgrade": "berserker",
			"passive": [{"type": "stat", "stat": "armor_pct", "value": 0.5}]},
		{"id": "w_other_p", "class": "warrior", "kind": "passive", "level": 50, "upgrade": "protector",
			"passive": [{"type": "stat", "stat": "max_hp_pct", "value": 0.5}]},
	])
	ups = UpgradeDB.from_list([
		{"id": "berserker", "class": "warrior", "actives": ["w_up_a"], "passives": ["w_up_p"],
			"evolves": {"ability": "w_hit", "set": {"cooldown_s": 2}, "effects": [
				{"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 99, "coef": 0, "kind": "magic", "can_crit": false}}]}},
		{"id": "protector", "class": "warrior", "actives": [], "passives": ["w_other_p"], "evolves": {}},
		{"id": "healer", "class": "cleric", "actives": [], "passives": [], "evolves": {}}])
	f.world.upgrades = ups


func _hero(level: int, class_id := "warrior") -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	p.stats.crit_chance = 0.0
	return p


func test_choose_needs_level_50() -> void:
	var p := _hero(49)
	assert_false(ProgressRequests.choose_upgrade(f.world, p, "berserker", true))
	assert_eq(p.progress.upgrade, "")


func test_first_choice_needs_no_trainer() -> void:
	var p := _hero(50)
	assert_true(ProgressRequests.choose_upgrade(f.world, p, "berserker", false))


func test_choose_rejects_other_class() -> void:
	var p := _hero(50)
	assert_false(ProgressRequests.choose_upgrade(f.world, p, "healer", true))
	assert_false(ProgressRequests.choose_upgrade(f.world, p, "nonsense", true))
	p.life = CombatEntity.DEAD
	assert_false(ProgressRequests.choose_upgrade(f.world, p, "berserker", true), "dead")


func test_choose_twice_rejected() -> void:
	var p := _hero(50)
	assert_true(ProgressRequests.choose_upgrade(f.world, p, "berserker", true))
	assert_true(p.progress_dirty)
	assert_false(ProgressRequests.choose_upgrade(f.world, p, "protector", true))
	assert_eq(p.progress.upgrade, "berserker")


func test_chosen_upgrade_passives_apply() -> void:
	var p := _hero(50)
	var armor := p.stats.armor
	ProgressRequests.choose_upgrade(f.world, p, "berserker", true)
	assert_almost_eq(p.stats.armor, armor * 1.5, 0.001)
	assert_eq(Passives.collect(f.world.abilities, "warrior", 50, "protector").size(), 1)
	assert_eq(Passives.collect(f.world.abilities, "warrior", 50, "").size(), 0)


func test_upgrade_actives_appear_in_unlocked() -> void:
	var db := f.world.abilities
	assert_eq(db.unlocked("warrior", 50), ["w_hit"])
	assert_eq(db.unlocked("warrior", 50, "berserker"), ["w_hit", "w_up_a"])
	assert_eq(db.unlocked("warrior", 50, "protector"), ["w_hit"])


func test_evolution_changes_resolved_ability() -> void:
	var db := f.world.abilities
	assert_eq(db.resolved("w_hit", "", ups).cooldown_s, 5)
	var evolved := db.resolved("w_hit", "berserker", ups)
	assert_eq(evolved.cooldown_s, 2)
	assert_eq(evolved.effects[0].damage.base, 99)
	assert_eq(db.resolved("w_hit", "protector", ups).cooldown_s, 5, "another upgrade evolves nothing here")
	assert_eq(db.get_ability("w_hit").effects[0].damage.base, 10, "the data is not modified")


func test_cast_uses_the_evolution() -> void:
	var p := _hero(50)
	var t := f.dummy(2000, Vector3(11, 0, 10), 1000.0)
	assert_true(Combat.try_cast(f.world, p, "w_hit", t.position))
	assert_eq(t.hp, 990.0)
	ProgressRequests.choose_upgrade(f.world, p, "berserker", true)
	p.cooldowns.clear()
	assert_true(Combat.try_cast(f.world, p, "w_hit", t.position))
	assert_eq(t.hp, 891.0, "99 more")
	assert_eq(p.cooldowns["w_hit"], f.world.tick + f.world.ticks(2.0))


func test_reset_upgrade_clears_upgrade_and_ring2() -> void:
	var p := _hero(60)
	ProgressRequests.choose_upgrade(f.world, p, "berserker", true)
	for id: String in ["might_1", "might_2", "might_3", "might_4", "might_key", "might_5"]:
		assert_true(ProgressRequests.buy_talent(f.world, p, id), id)
	assert_true(ProgressRequests.reset(f.world, p, "upgrade", true))
	assert_eq(p.progress.upgrade, "")
	assert_does_not_have(p.progress.talents, "might_5")
	assert_has(p.progress.talents, "might_key")
	assert_false(p.passives.any(func(m: Dictionary) -> bool: return m.get("stat") == "armor_pct" and m.get("value") == 0.5), "the upgrade passives are gone")


func test_reset_upgrade_cancels_channel() -> void:
	var p := _hero(50)
	ProgressRequests.choose_upgrade(f.world, p, "berserker", true)
	var pc := PendingCast.new()
	pc.caster_id = p.id
	pc.channel = true
	pc.left = 5
	pc.ability = f.world.abilities.get_ability("w_up_a")
	f.world.pending_casts.append(pc)
	assert_true(ProgressRequests.reset(f.world, p, "upgrade", true))
	assert_eq(f.world.pending_casts.size(), 0)
	assert_eq(f.events_of("channel_end").size(), 1)
