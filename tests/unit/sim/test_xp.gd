extends GutTest

var b: Balance


func before_each() -> void:
	b = Balance.load_from()


func test_curve() -> void:
	assert_eq(Xp.to_next(1, b), 100)
	assert_eq(Xp.to_next(2, b), 303)
	assert_eq(Xp.to_next(10, b), 3981)
	assert_eq(Xp.to_next(50, b), roundi(100.0 * pow(50.0, 1.6)))
	assert_eq(Xp.to_next(51, b), Xp.to_next(50, b) + 2500)
	assert_eq(Xp.to_next(60, b), Xp.to_next(50, b) + 25000)


func test_monster_xp() -> void:
	assert_eq(Xp.monster_xp(1, false, false, b), 8)
	assert_eq(Xp.monster_xp(10, false, false, b), 127)
	assert_eq(Xp.monster_xp(1, true, false, b), 32)
	assert_eq(Xp.monster_xp(1, false, true, b), 80)


func test_level_factor() -> void:
	assert_almost_eq(Xp.level_factor(5, 3, b), 1.0, 0.0001)
	assert_almost_eq(Xp.level_factor(6, 3, b), 0.8, 0.0001)
	assert_almost_eq(Xp.level_factor(13, 3, b), 0.1, 0.0001)
	assert_almost_eq(Xp.level_factor(1, 10, b), 1.0, 0.0001)


func test_group_share() -> void:
	assert_eq(Xp.group_share(100, 1, b), 100)
	assert_eq(Xp.group_share(100, 4, b), 33)


func test_add_many_levels() -> void:
	var p := PlayerProgress.new()
	var gained := Xp.add(p, 500, b)
	assert_eq(gained, 2)
	assert_eq(p.level, 3)
	assert_eq(p.xp, 97)


func test_add_huge_amount_ends() -> void:
	var p := PlayerProgress.new()
	Xp.add(p, 2_000_000_000, b)
	assert_true(p.level <= 65535)
	assert_true(p.level > 1)


func test_add_negative_ignored() -> void:
	var p := PlayerProgress.new()
	assert_eq(Xp.add(p, -50, b), 0)
	assert_eq(p.xp, 0)
