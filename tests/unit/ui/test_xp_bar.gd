extends GutTest

var bar: XpBar


func before_each() -> void:
	bar = XpBar.new()
	add_child_autofree(bar)


func test_shows_the_fraction_and_the_numbers() -> void:
	bar.set_progress(5, 50, 200)
	assert_almost_eq(bar.fraction(), 0.25, 0.0001)
	assert_eq(bar.text(), tr("XP_BAR_TEXT") % [5, 50, 200])


func test_zero_to_next_is_empty_not_a_crash() -> void:
	bar.set_progress(1, 0, 0)
	assert_eq(bar.fraction(), 0.0)


func test_is_thin_and_does_not_steal_the_mouse() -> void:
	assert_lte(bar.custom_minimum_size.y, 16.0)
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_hud_has_an_xp_bar_fed_by_the_client() -> void:
	var hud := CombatHud.new()
	add_child_autofree(hud)
	var c := ClientSession.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [5, 5], "blocks": []}), "0", "Ana", "warrior")
	c.my_id = 1
	c.progress = PlayerProgress.from_dict({"level": 3, "xp": 50})
	c.combat[1] = {"hp": 10.0, "max_hp": 10.0, "resource": 0.0, "max_resource": 0.0, "life": 0, "status_bits": 0, "combo": 0, "charge": 0.0, "level": 3}
	hud.bind(c, ["warrior_charge", "", "", ""], AbilityDB.load_default())
	hud.advance(0.1)
	assert_eq(hud.xp_bar.text(), tr("XP_BAR_TEXT") % [3, 50, Xp.to_next(3, c.balance)])
