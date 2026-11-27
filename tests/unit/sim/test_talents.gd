extends GutTest

var db: TalentDB
var b: Balance
var f: CombatFixture


func before_each() -> void:
	db = TalentDB.load_default()
	f = CombatFixture.new()
	b = f.world.balance


func _pr(level: int, upgrade := "") -> PlayerProgress:
	var pr := PlayerProgress.new()
	pr.level = level
	pr.upgrade = upgrade
	return pr


func _buy_all(pr: PlayerProgress, ids: Array) -> void:
	for id: String in ids:
		assert_true(Talents.buy(pr, id, db), "buy " + id)


## The nodes of a direction in an order where each touches the start or an earlier one.
func _direction_in_order(dir: String) -> Array:
	var out: Array = []
	var have := {db.start_id(): true}
	var grew := true
	while grew:
		grew = false
		for id: String in db.ids():
			if have.has(id) or str(db.node(id).get("dir", "")) != dir:
				continue
			for n: String in db.node(id).links:
				if have.has(n):
					have[id] = true
					out.append(id)
					grew = true
					break
	return out


func test_points_by_level() -> void:
	assert_eq(Talents.points(1), 0)
	assert_eq(Talents.points(11), 10)
	assert_eq(Talents.points(0), 0)


func test_buy_needs_link() -> void:
	var pr := _pr(5)
	assert_false(Talents.can_buy(pr, "r2_0", db), "not linked to the start")
	assert_true(Talents.buy(pr, "r1_0", db))
	assert_true(Talents.can_buy(pr, "r2_0", db))
	assert_false(Talents.can_buy(pr, "start", db))
	assert_false(Talents.can_buy(pr, "nope", db))


func test_buy_needs_point() -> void:
	var pr := _pr(2)
	assert_true(Talents.buy(pr, "r1_0", db))
	assert_false(Talents.buy(pr, "r1_1", db))
	assert_eq(pr.talents, ["r1_0"])


func test_cannot_buy_twice() -> void:
	var pr := _pr(5)
	assert_true(Talents.buy(pr, "r1_0", db))
	assert_false(Talents.buy(pr, "r1_0", db))


## Plan 8.3g: every ring is open from the start, with or without a class upgrade.
func test_outer_ring_needs_no_upgrade() -> void:
	var pr := _pr(300)
	_buy_all(pr, ["r1_0", "r2_0", "r3_0", "r4_0", "r5_0", "r6_0", "r7_0"])
	assert_eq(pr.upgrade, "")
	assert_true(Talents.valid(pr, db))


func test_mastery_after_owning_a_whole_direction() -> void:
	var pr := _pr(300)
	var arcane := _direction_in_order("arcane")
	_buy_all(pr, arcane.slice(0, arcane.size() - 1))
	assert_false(Talents.can_buy_mastery(pr, "arcane", db), "one node left")
	_buy_all(pr, [arcane[-1]])
	assert_true(Talents.can_buy_mastery(pr, "arcane", db))
	assert_true(Talents.buy_mastery(pr, "arcane", db))
	assert_true(Talents.valid(pr, db))


func test_mastery_needs_a_point() -> void:
	var might := _direction_in_order("might")
	var pr := _pr(might.size() + 2) # one point left over
	_buy_all(pr, might)
	assert_true(Talents.buy_mastery(pr, "might", db))
	assert_false(Talents.buy_mastery(pr, "might", db))


func test_mastery_diminishing() -> void:
	var pr := _pr(300)
	pr.masteries = {"might": 100}
	var half := float(Talents.mods(pr, db, b)[0].value)
	assert_almost_eq(half, 0.001 * 100.0 * 0.5, 0.0001)
	pr.masteries = {"might": 200}
	var more := float(Talents.mods(pr, db, b)[0].value)
	assert_gt(more, half)
	assert_lt(more, 2.0 * half)


func test_valid_rejects_orphan_node() -> void:
	var pr := _pr(20)
	pr.talents = ["r3_0"]
	assert_false(Talents.valid(pr, db))
	pr.talents = ["r1_0", "r2_0"]
	assert_true(Talents.valid(pr, db))
	pr.talents = ["r1_0", "r1_0"]
	assert_false(Talents.valid(pr, db), "repeated")
	pr.talents = ["start"]
	assert_false(Talents.valid(pr, db))
	pr.talents = ["might_1"]
	assert_false(Talents.valid(pr, db), "an id of the old tree")
	pr = _pr(2)
	pr.talents = ["r1_0", "r2_0", "r3_0"]
	assert_false(Talents.valid(pr, db), "more than the points")


func test_mods_reach_stats() -> void:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	ClassRules.setup_player(p, "warrior", null, f.world)
	p.progress.level = 5
	Progression.rebuild(p, f.world)
	var before := p.stats.max_hp
	assert_true(Talents.buy(p.progress, "r1_6", db)) # bastion, ring 1: +3 % max health
	assert_true(Talents.buy(p.progress, "r2_12", db)) # bastion, ring 2: block (only with a shield)
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.max_hp, before * 1.03, 0.001)
	assert_true(Talents.mods(p.progress, db, b).any(func(m: Dictionary) -> bool: return m.stat == "block_add"))


func test_reset_returns_points() -> void:
	var pr := _pr(10)
	_buy_all(pr, ["r1_0", "r2_0", "r3_0"])
	Talents.reset(pr)
	assert_eq(pr.talents, [])
	assert_eq(pr.masteries, {})
	assert_eq(Talents.spent(pr), 0)


func test_prune_orphans_drops_what_lost_its_way_to_the_start() -> void:
	var pr := _pr(30)
	pr.talents = ["r1_0", "r2_0", "r3_0", "r5_0"]
	Talents.prune_orphans(pr, db)
	assert_eq(pr.talents, ["r1_0", "r2_0", "r3_0"])
