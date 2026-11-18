extends GutTest

const CLASSES := ["warrior", "cleric", "mage", "archer", "assassin"]

var abilities: AbilityDB
var win: AbilitiesWindow
var changes: Array = []


func before_each() -> void:
	abilities = AbilityDB.load_default()
	win = AbilitiesWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20 # as in Main
	win.theme = theme
	add_child_autofree(win)
	changes = []
	win.bar_changed.connect(func(b: Array) -> void: changes.append(b))


func test_lists_the_class_actives_and_passives() -> void:
	win.show_for("mage", abilities.default_bar("mage"), abilities)
	assert_true(win.visible)
	assert_eq(win.active_ids(), abilities.actives("mage"))
	assert_eq(win.passive_ids().size(), 4)
	assert_eq(win.bar(), abilities.default_bar("mage"))


func test_assign_and_swap_slots() -> void:
	var start := ["warrior_charge", "warrior_battle_cry", "warrior_whirlwind", ""]
	win.show_for("warrior", start, abilities)
	win.select_ability("warrior_shield_wall")
	win.click_slot(3)
	assert_eq(win.bar(), ["warrior_charge", "warrior_battle_cry", "warrior_whirlwind", "warrior_shield_wall"])
	win.select_ability("warrior_whirlwind")
	win.click_slot(0)
	assert_eq(win.bar(), ["warrior_whirlwind", "warrior_battle_cry", "warrior_charge", "warrior_shield_wall"],
		"an ability already on the bar swaps places")
	win.click_slot(1) # picks the slot's ability up...
	win.click_slot(3) # ...and drops it on another slot
	assert_eq(win.bar(), ["warrior_whirlwind", "warrior_shield_wall", "warrior_charge", "warrior_battle_cry"])
	assert_eq(changes.size(), 3)
	assert_eq(changes[-1], win.bar())


func test_slot_click_without_change_emits_nothing() -> void:
	win.show_for("warrior", abilities.default_bar("warrior"), abilities)
	win.select_ability(win.bar()[2])
	win.click_slot(2)
	win.select_ability("not_an_ability")
	win.click_slot(0)
	assert_eq(changes.size(), 0)
	assert_eq(win.bar(), abilities.default_bar("warrior"))


func test_window_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	for class_id: String in CLASSES:
		win.show_for(class_id, abilities.default_bar(class_id), abilities)
		for id: String in win.attack_ids() + win.active_ids() + win.passive_ids():
			win.select_ability(id)
			await wait_process_frames(1)
			var r := win.panel_rect()
			assert_true(Rect2(0, 0, 1280, 720).encloses(r), "%s %s: panel %s" % [class_id, id, r])
			assert_gt(r.size.x, 700.0, "the panel is laid out (7 cards wide)")
			assert_true(win.description_fits(), "%s: the description fits its box" % id)


func test_attacks_row_shows_basic_and_secondary() -> void:
	win.show_for("warrior", abilities.default_bar("warrior"), abilities)
	assert_eq(win.attack_ids(), ["warrior_slash", "warrior_brutal"])
	win.select_ability("warrior_brutal")
	assert_string_contains(win.description_text(), tr("AB_WARRIOR_BRUTAL_DESC"))
	assert_string_contains(win.description_text(), "28 + 120 % de tu poder de ataque (20) = 52", "with the class's base stats")
	win.click_slot(0)
	assert_eq(win.bar(), abilities.default_bar("warrior"), "attacks stay on the mouse")
	assert_eq(changes.size(), 0)


func test_description_has_the_computed_details() -> void:
	win.show_for("mage", abilities.default_bar("mage"), abilities)
	win.select_ability("mage_fireball")
	var t := win.description_text()
	assert_string_contains(t, tr("AB_MAGE_FIREBALL_DESC"))
	assert_string_contains(t, "Explosión")
	assert_string_contains(t, "45 de maná")


func test_villager_sees_the_strike_and_the_hint() -> void:
	win.show_for("villager", ["", "", "", ""], abilities)
	assert_eq(win.attack_ids(), ["villager_strike"])
	assert_eq(win.active_ids(), [])
	assert_true(win.villager_hint_visible())
	assert_true(win.panel_rect().size.y <= 720.0 and win.panel_rect().size.x <= 1280.0)
	win.show_for("warrior", abilities.default_bar("warrior"), abilities)
	assert_false(win.villager_hint_visible())


func test_locked_abilities_are_marked_and_listed() -> void:
	win.show_for("warrior", ["warrior_charge", "", "", ""], abilities, 3)
	assert_has(win.locked_ids(), "warrior_whirlwind")
	assert_has(win.locked_ids(), "warrior_contained_fury", "passives unlock by level too")
	assert_does_not_have(win.locked_ids(), "warrior_battle_cry")
	assert_does_not_have(win.locked_ids(), "warrior_charge")
	assert_eq(win.card_text("warrior_whirlwind"), tr(str(abilities.get_ability("warrior_whirlwind").name)) + "\n" + tr("ABILITIES_LEVEL") % 6)
	assert_eq(win.card_text("warrior_battle_cry"), tr(str(abilities.get_ability("warrior_battle_cry").name)))
	assert_true(win.has_lock_icon("warrior_whirlwind"))
	assert_false(win.has_lock_icon("warrior_battle_cry"))


func test_locked_cannot_be_assigned() -> void:
	win.show_for("warrior", ["warrior_charge", "", "", ""], abilities, 3)
	changes.clear()
	win.select_ability("warrior_whirlwind")
	win.click_slot(1)
	assert_eq(win.bar(), ["warrior_charge", "", "", ""])
	assert_eq(changes.size(), 0)
	win.select_ability("warrior_battle_cry")
	win.click_slot(1)
	assert_eq(win.bar(), ["warrior_charge", "warrior_battle_cry", "", ""])


func test_a_locked_bar_slot_is_cleared() -> void:
	win.show_for("warrior", ["warrior_whirlwind", "warrior_charge", "", ""], abilities, 1)
	assert_eq(win.bar(), ["", "warrior_charge", "", ""])


func test_assassin_with_an_upgrade_fits_1280x720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	win.show_for("assassin", abilities.default_bar("assassin", 50, "shadow"), abilities, 50, "shadow")
	await wait_process_frames(2)
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "panel %s" % r)
	assert_eq(win.active_ids().size(), 9, "7 base actives and the 2 of the upgrade")
