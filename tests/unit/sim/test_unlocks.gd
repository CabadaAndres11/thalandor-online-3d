extends GutTest
## Abilities and passives unlock by level; upgrade abilities need their upgrade.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()


func _db() -> AbilityDB:
	return AbilityDB.load_default()


func _hero(class_id: String, level: int) -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	p.resource = p.stats.max_resource
	return p


func test_level1_has_three_actives() -> void:
	# basic, secondary and one active at level 1
	assert_eq(_db().unlocked("warrior", 1), ["warrior_charge"])
	assert_ne(_db().kind_of("warrior", "basic"), "")
	assert_ne(_db().kind_of("warrior", "secondary"), "")
	assert_eq(_db().unlocked("warrior", 6), ["warrior_charge", "warrior_battle_cry", "warrior_whirlwind"])


func test_sanitize_clears_locked() -> void:
	assert_eq(_db().sanitize_bar("warrior", ["warrior_charge", "warrior_battle_cry", "", ""], 1), ["warrior_charge", "", "", ""])
	assert_eq(_db().sanitize_bar("warrior", ["warrior_charge", "warrior_battle_cry", "", ""], 3), ["warrior_charge", "warrior_battle_cry", "", ""])
	assert_eq(_db().sanitize_bar("warrior", [], 6), ["warrior_charge", "warrior_battle_cry", "warrior_whirlwind", ""])
	assert_eq(_db().default_bar("warrior"), ["warrior_charge", "", "", ""])


func test_cast_locked_refused() -> void:
	var p := _hero("warrior", 1)
	assert_false(Combat.try_cast(f.world, p, "warrior_battle_cry", p.position + Vector3(1, 0, 0)))
	var q := f.world.add_player(2, Vector3(9, 0, 5))
	q.progress.level = 3
	ClassRules.setup_player(q, "warrior", null, f.world)
	q.resource = 100.0
	assert_true(Combat.try_cast(f.world, q, "warrior_battle_cry", q.position + Vector3(1, 0, 0)))


func test_passive_turns_on_at_level() -> void:
	assert_false(Passives.has_hook(_hero("warrior", 5), "rage_decay_mult").is_empty())
	f.world.players.clear()
	assert_true(Passives.has_hook(_hero("warrior", 4), "rage_decay_mult").is_empty())


func test_place_unlocked_fills_free_slot() -> void:
	assert_eq(_db().place_unlocked(["warrior_charge", "", "", ""], "warrior", 1, 3, ""), ["warrior_charge", "warrior_battle_cry", "", ""])
	assert_eq(_db().place_unlocked(["warrior_charge", "", "", ""], "warrior", 1, 10, ""),
		["warrior_charge", "warrior_battle_cry", "warrior_whirlwind", "warrior_taunt"])


func test_place_unlocked_keeps_full_bar() -> void:
	var full := ["warrior_charge", "warrior_battle_cry", "warrior_whirlwind", "warrior_taunt"]
	assert_eq(_db().place_unlocked(full, "warrior", 10, 20, ""), full)
	assert_eq(_db().place_unlocked(["warrior_charge", "", "", ""], "warrior", 3, 3, ""), ["warrior_charge", "", "", ""])


func test_upgrade_abilities_need_their_upgrade() -> void:
	var db := AbilityDB.from_list([
		{"id": "a1", "class": "warrior", "kind": "active", "level": 1, "effects": []},
		{"id": "u1", "class": "warrior", "kind": "active", "level": 50, "upgrade": "protector", "effects": []},
		{"id": "u2", "class": "warrior", "kind": "active", "level": 50, "upgrade": "berserker", "effects": []}])
	assert_eq(db.unlocked("warrior", 50), ["a1"])
	assert_eq(db.unlocked("warrior", 50, "protector"), ["a1", "u1"])
	assert_eq(db.unlocked("warrior", 49, "protector"), ["a1"])
	assert_eq(db.place_unlocked(["a1", "", "", ""], "warrior", 49, 50, "berserker"), ["a1", "u2", "", ""])
	assert_eq(db.sanitize_bar("warrior", ["u1", "u2", "", ""], 50, "protector"), ["u1", "", "", ""])


func test_cast_of_foreign_upgrade_refused() -> void:
	f.world.abilities = AbilityDB.from_list([
		{"id": "u1", "class": "warrior", "kind": "active", "level": 50, "upgrade": "protector", "cost": 0, "cooldown_s": 0,
			"gcd": false, "effects": [{"type": "shield", "amount": {"base": 5, "coef": 0}, "duration_s": 3}]}])
	var p := _hero("warrior", 50)
	assert_false(Combat.try_cast(f.world, p, "u1", p.position))
	p.progress.upgrade = "protector"
	assert_true(Combat.try_cast(f.world, p, "u1", p.position))
