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


func test_points_by_level() -> void:
	assert_eq(Talents.points(1), 0)
	assert_eq(Talents.points(11), 10)
	assert_eq(Talents.points(0), 0)


func test_buy_needs_link() -> void:
	var pr := _pr(20)
	assert_false(Talents.can_buy(pr, "might_2", db), "not linked to the start")
	assert_true(Talents.buy(pr, "might_1", db))
	assert_true(Talents.can_buy(pr, "might_2", db))
	assert_true(Talents.can_buy(pr, "celerity_1", db), "start links every spoke")
	assert_false(Talents.can_buy(pr, "nonsense", db))
	assert_false(Talents.can_buy(pr, "start", db))


func test_buy_needs_point() -> void:
	var pr := _pr(2)
	assert_true(Talents.buy(pr, "might_1", db))
	assert_false(Talents.buy(pr, "might_2", db))
	assert_eq(pr.talents, ["might_1"])


func test_cannot_buy_twice() -> void:
	var pr := _pr(5)
	assert_true(Talents.buy(pr, "might_1", db))
	assert_false(Talents.buy(pr, "might_1", db))
	assert_eq(pr.talents.size(), 1)


func test_ring2_needs_upgrade() -> void:
	var order := ["might_1", "might_2", "might_3", "might_4", "might_key"]
	var pr := _pr(30)
	_buy_all(pr, order)
	assert_false(Talents.can_buy(pr, "might_5", db))
	pr.upgrade = "berserker"
	assert_true(Talents.can_buy(pr, "might_5", db))
	assert_true(Talents.buy(pr, "might_5", db))
	assert_true(Talents.buy(pr, "might_6", db))


func test_mastery_only_when_all_bought() -> void:
	var pr := _pr(30)
	assert_false(Talents.can_buy_mastery(pr, "might", db))
	_buy_all(pr, ["might_1", "might_2", "might_3", "might_4"])
	assert_false(Talents.can_buy_mastery(pr, "might", db), "the keystone is missing")
	_buy_all(pr, ["might_key"])
	assert_true(Talents.can_buy_mastery(pr, "might", db))
	assert_true(Talents.buy_mastery(pr, "might", db))
	assert_eq(pr.masteries.might, 1)
	assert_false(Talents.can_buy_mastery(pr, "celerity", db))
	assert_false(Talents.can_buy_mastery(pr, "nope", db))
	# with an upgrade, ring 2 becomes available and must be bought too
	pr.upgrade = "berserker"
	assert_false(Talents.can_buy_mastery(pr, "might", db))
	_buy_all(pr, ["might_5", "might_6"])
	assert_true(Talents.can_buy_mastery(pr, "might", db))


func test_mastery_needs_a_point() -> void:
	var pr := _pr(7)
	_buy_all(pr, ["might_1", "might_2", "might_3", "might_4", "might_key"])
	assert_eq(Talents.spent(pr), 5)
	assert_true(Talents.buy_mastery(pr, "might", db))
	assert_false(Talents.buy_mastery(pr, "might", db))
	assert_eq(Talents.spent(pr), 6)


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
	pr.talents = ["might_3"]
	assert_false(Talents.valid(pr, db))
	pr.talents = ["might_1", "might_2"]
	assert_true(Talents.valid(pr, db))
	pr.talents = ["might_1", "might_1"]
	assert_false(Talents.valid(pr, db), "repeated")
	pr.talents = ["start"]
	assert_false(Talents.valid(pr, db))
	pr.talents = ["nope"]
	assert_false(Talents.valid(pr, db))
	pr = _pr(2)
	pr.talents = ["might_1", "might_2", "might_3"]
	assert_false(Talents.valid(pr, db), "more than the points")
	pr = _pr(30)
	pr.talents = ["might_1", "might_2", "might_3", "might_4", "might_key", "might_5"]
	assert_false(Talents.valid(pr, db), "ring 2 without upgrade")
	pr.upgrade = "berserker"
	assert_true(Talents.valid(pr, db))


func test_mods_reach_stats() -> void:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	ClassRules.setup_player(p, "warrior", null, f.world)
	p.progress.level = 5
	Progression.rebuild(p, f.world)
	var before := p.stats.max_hp
	assert_true(Talents.buy(p.progress, "bastion_1", db))
	assert_true(Talents.buy(p.progress, "bastion_2", db))
	Progression.rebuild(p, f.world)
	assert_almost_eq(p.stats.max_hp, before * 1.03, 0.001)
	assert_gt(p.stats.armor, 40.0)


func test_reset_returns_points() -> void:
	var pr := _pr(10)
	_buy_all(pr, ["might_1", "might_2", "might_3", "might_4", "might_key"])
	Talents.buy_mastery(pr, "might", db)
	Talents.reset(pr)
	assert_eq(pr.talents, [])
	assert_eq(pr.masteries, {})
	assert_eq(Talents.spent(pr), 0)
