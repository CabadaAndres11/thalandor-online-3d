extends GutTest
## Inventory window (I): 30 slots and gold; right click equips or uses; it fits next to
## the character window at 1280×720.

var inv_win: InventoryWindow
var db: ItemDB


func before_each() -> void:
	db = ItemDB.load_default()
	inv_win = InventoryWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	inv_win.theme = theme
	add_child_autofree(inv_win)


func _inv() -> Inventory:
	var inv := Inventory.new()
	inv.gold = 1234
	inv.add(ItemRoll.new_item("sword_t1", 1, "rare"), db)
	var pot := ItemRoll.new_item("potion_health", 1)
	pot.count = 5
	inv.add(pot, db)
	return inv


func test_shows_slots_and_gold() -> void:
	inv_win.show_for(_inv(), "warrior", 5)
	assert_eq(inv_win.slot_count(), 30)
	assert_string_contains(inv_win.gold_text(), "1234")
	assert_eq(inv_win.slot_count_text(1), "5")


func test_right_click_equips() -> void:
	inv_win.show_for(_inv(), "warrior", 5)
	watch_signals(inv_win)
	inv_win.right_click(0)
	assert_signal_emitted_with_parameters(inv_win, "item_action", ["equip", [0]])
	inv_win.right_click(1)
	assert_signal_emitted_with_parameters(inv_win, "item_action", ["use", [1]])
	inv_win.right_click(5)
	assert_signal_emit_count(inv_win, "item_action", 2, "an empty slot does nothing")


func test_sell_mode() -> void:
	inv_win.show_for(_inv(), "warrior", 5)
	inv_win.sell_mode = true
	watch_signals(inv_win)
	inv_win.right_click(0)
	assert_signal_emitted_with_parameters(inv_win, "sell_requested", [0])
	assert_signal_not_emitted(inv_win, "item_action")


func test_extra_slots_shown() -> void:
	var inv := _inv()
	inv.bag.append(ItemRoll.new_item("ring_t1", 1))
	inv_win.show_for(inv, "warrior", 5)
	assert_eq(inv_win.slot_count(), 31)


func test_windows_fit_720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var c := CharacterWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	c.theme = theme
	add_child_autofree(c)
	inv_win.show_for(_inv(), "warrior", 60)
	var pr := PlayerProgress.from_dict({"level": 60, "attributes": {"strength": 100, "agility": 100, "intellect": 100, "stamina": 100, "spirit": 100}})
	var full := Inventory.starter("warrior", db)
	c.show_for("Ana", "warrior", pr, Progression.preview_stats("warrior", pr, Balance.load_from(), full), Balance.load_from(), {}, full)
	c.set_right_margin(inv_win.reserved_width())
	await wait_process_frames(3)
	var screen := Rect2(0, 0, 1280, 720)
	assert_true(screen.encloses(inv_win.panel_rect()), "inventory %s" % inv_win.panel_rect())
	assert_true(screen.encloses(c.panel_rect()), "character %s" % c.panel_rect())
	assert_false(inv_win.panel_rect().intersects(c.panel_rect()), "side by side: %s %s" % [inv_win.panel_rect(), c.panel_rect()])
