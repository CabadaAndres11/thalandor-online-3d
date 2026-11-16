extends GutTest

var f: CombatFixture
var db: TalentDB


func before_each() -> void:
	f = CombatFixture.new()
	db = TalentDB.load_default()


func _hero(level: int, class_id := "warrior") -> PlayerState:
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	p.progress_dirty = false
	return p


# --- Attributes -------------------------------------------------------------------------

func test_spend_attribute_accepted() -> void:
	var p := _hero(5)
	var before := p.stats.max_hp
	assert_true(ProgressRequests.spend_attribute(f.world, p, "stamina"))
	assert_eq(p.progress.attributes.stamina, 1)
	assert_gt(p.stats.max_hp, before, "rebuilt")
	assert_true(p.progress_dirty)


func test_spend_attribute_rejections() -> void:
	var p := _hero(1)
	assert_false(ProgressRequests.spend_attribute(f.world, p, "stamina"), "no points")
	var q := _hero(5)
	assert_false(ProgressRequests.spend_attribute(f.world, q, "luck"))
	q.life = CombatEntity.DEAD
	assert_false(ProgressRequests.spend_attribute(f.world, q, "stamina"), "dead")
	assert_eq(q.progress.attributes.stamina, 0)
	assert_false(q.progress_dirty)


func test_spend_allowed_in_combat() -> void:
	var p := _hero(5)
	p.last_combat_tick = f.world.tick
	assert_true(ProgressRequests.spend_attribute(f.world, p, "strength"))


# --- Talents ----------------------------------------------------------------------------

func test_buy_talent_accepted() -> void:
	var p := _hero(5)
	var armor := p.stats.armor
	assert_true(ProgressRequests.buy_talent(f.world, p, "bastion_1"))
	assert_eq(p.progress.talents, ["bastion_1"])
	assert_gt(p.stats.armor, armor)
	assert_true(p.progress_dirty)


func test_buy_talent_rejections() -> void:
	var p := _hero(5)
	assert_false(ProgressRequests.buy_talent(f.world, p, "bastion_3"), "unlinked")
	assert_false(ProgressRequests.buy_talent(f.world, p, "nope"))
	var dead := _hero(5)
	dead.life = CombatEntity.DEAD
	assert_false(ProgressRequests.buy_talent(f.world, dead, "bastion_1"))
	assert_eq(p.progress.talents, [])
	assert_false(p.progress_dirty)


func test_buy_mastery() -> void:
	var p := _hero(10)
	for id: String in ["might_1", "might_2", "might_3", "might_4", "might_key"]:
		assert_true(ProgressRequests.buy_talent(f.world, p, id))
	assert_true(ProgressRequests.buy_mastery(f.world, p, "might"))
	assert_eq(p.progress.masteries.might, 1)
	assert_false(ProgressRequests.buy_mastery(f.world, p, "celerity"))
	p.life = CombatEntity.DEAD
	assert_false(ProgressRequests.buy_mastery(f.world, p, "might"))


# --- Reset ------------------------------------------------------------------------------

func test_reset_attributes_and_talents() -> void:
	var p := _hero(10)
	ProgressRequests.spend_attribute(f.world, p, "strength")
	ProgressRequests.buy_talent(f.world, p, "might_1")
	p.progress_dirty = false
	assert_true(ProgressRequests.reset(f.world, p, "attributes", true))
	assert_eq(p.progress.attributes.strength, 0)
	assert_true(p.progress_dirty)
	assert_true(ProgressRequests.reset(f.world, p, "talents", true))
	assert_eq(p.progress.talents, [])


func test_reset_rejections() -> void:
	var p := _hero(10)
	ProgressRequests.spend_attribute(f.world, p, "strength")
	assert_false(ProgressRequests.reset(f.world, p, "attributes", false), "far from the trainer")
	assert_false(ProgressRequests.reset(f.world, p, "nothing", true), "unknown")
	p.last_combat_tick = f.world.tick
	assert_false(ProgressRequests.reset(f.world, p, "attributes", true), "in combat")
	p.last_combat_tick = -100000
	p.life = CombatEntity.DOWNED
	assert_false(ProgressRequests.reset(f.world, p, "attributes", true), "downed")
	p.life = CombatEntity.DEAD
	assert_false(ProgressRequests.reset(f.world, p, "attributes", true), "dead")
	assert_eq(p.progress.attributes.strength, 1)


func test_reset_upgrade_drops_ring2() -> void:
	var p := _hero(60)
	p.progress.upgrade = "berserker"
	for id: String in ["might_1", "might_2", "might_3", "might_4", "might_key", "might_5", "might_6"]:
		assert_true(ProgressRequests.buy_talent(f.world, p, id), id)
	assert_true(ProgressRequests.reset(f.world, p, "upgrade", true))
	assert_eq(p.progress.upgrade, "")
	assert_eq(p.progress.talents, ["might_1", "might_2", "might_3", "might_4", "might_key"])
	assert_false(ProgressRequests.reset(f.world, p, "upgrade", true), "nothing to reset")


# --- Sanitizing -------------------------------------------------------------------------

func _san(d: Dictionary, class_id := "warrior") -> PlayerProgress:
	return ProgressRequests.sanitize(PlayerProgress.from_dict(d), class_id, f.world)


func test_sanitize_keeps_a_good_progress() -> void:
	var pr := _san({"level": 12, "xp": 50, "attributes": {"strength": 20, "stamina": 35}, "talents": ["might_1", "might_2"]})
	assert_eq(pr.level, 12)
	assert_eq(pr.xp, 50)
	assert_eq(pr.attributes.strength, 20)
	assert_eq(pr.talents, ["might_1", "might_2"])


func test_sanitize_too_many_attribute_points() -> void:
	var pr := _san({"level": 3, "attributes": {"strength": 50}})
	for a: String in PlayerProgress.ATTRIBUTES:
		assert_eq(pr.attributes[a], 0)
	assert_eq(_san({"level": 3, "attributes": {"strength": 10}}).attributes.strength, 10, "exactly the points is fine")


func test_sanitize_orphan_talents() -> void:
	var pr := _san({"level": 20, "talents": ["might_3"], "masteries": {"might": 2}})
	assert_eq(pr.talents, [])
	assert_eq(pr.masteries, {})
	pr = _san({"level": 3, "talents": ["might_1", "might_2", "might_3"]})
	assert_eq(pr.talents, [], "more than the points")


func test_sanitize_foreign_upgrade() -> void:
	f.world.upgrades = UpgradeDB.from_list([
		{"id": "berserker", "class": "warrior"}, {"id": "healer", "class": "cleric"}])
	assert_eq(_san({"level": 50, "upgrade": "berserker"}).upgrade, "berserker")
	assert_eq(_san({"level": 50, "upgrade": "healer"}).upgrade, "")
	assert_eq(_san({"level": 50, "upgrade": "nonsense"}).upgrade, "")


func test_sanitize_upgrade_below_50() -> void:
	f.world.upgrades = UpgradeDB.from_list([{"id": "berserker", "class": "warrior"}])
	assert_eq(_san({"level": 49, "upgrade": "berserker"}).upgrade, "")


func test_sanitize_negative_and_huge_numbers() -> void:
	var pr := _san({"level": 1e12, "xp": -5, "attributes": {"strength": -3, "agility": 1e15}})
	assert_eq(pr.level, 65535)
	assert_eq(pr.xp, 0)
	assert_eq(pr.attributes.strength, 0)
	assert_lt(pr.attributes.agility, 2_000_000_001)
	var big := _san({"level": 10, "xp": 1e15})
	assert_lt(big.xp, Xp.to_next(10, f.world.balance))


func test_sanitize_xp_over_level() -> void:
	var pr := _san({"level": 1, "xp": 5000})
	assert_eq(pr.xp, 99)


func test_sanitize_ring2_talents_without_upgrade() -> void:
	var ids := ["might_1", "might_2", "might_3", "might_4", "might_key", "might_5"]
	var pr := _san({"level": 30, "talents": ids})
	assert_eq(pr.talents, [], "ring 2 needs an upgrade")


func test_sanitize_returns_a_copy() -> void:
	var src := PlayerProgress.from_dict({"level": 5, "attributes": {"strength": 2}})
	var out := ProgressRequests.sanitize(src, "warrior", f.world)
	out.attributes.strength = 4
	assert_eq(src.attributes.strength, 2)
