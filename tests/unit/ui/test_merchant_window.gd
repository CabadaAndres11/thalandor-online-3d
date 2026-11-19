extends GutTest
## Merchant window: buy potions and common items, sell from the inventory (rare or better
## asks first), repair everything worn; it fits beside the inventory at 1280×720.

var win: MerchantWindow
var db: ItemDB


func before_each() -> void:
	db = ItemDB.load_default()
	win = MerchantWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	win.theme = theme
	add_child_autofree(win)


func _stock() -> Array:
	return [ItemRoll.new_item("mage_chest_t1", 10), ItemRoll.new_item("wand_t1", 10),
		ItemRoll.new_item("orb_t1", 10), ItemRoll.new_item("staff_t1", 10)]


func _inv(worn_durability := 100) -> Inventory:
	var inv := Inventory.starter("mage", db)
	for it: Item in inv.equipment.values():
		it.durability = worn_durability
	inv.gold = 500
	return inv


func test_buy_tab_lists_potions_and_items() -> void:
	win.show_for(_stock(), _inv(), "mage", 10)
	assert_eq(win.stock_count(), 4)
	assert_eq(win.potion_price_text(), str(Merchant.potion_price(10, db)))
	watch_signals(win)
	win.buy(Merchant.BUY_HEALTH)
	assert_signal_emitted_with_parameters(win, "buy_requested", [Merchant.BUY_HEALTH])
	win.buy(2)
	assert_signal_emitted_with_parameters(win, "buy_requested", [2])


func test_tabs_switch_sell_mode() -> void:
	win.show_for(_stock(), _inv(), "mage", 10)
	watch_signals(win)
	win.set_tab("sell")
	assert_signal_emitted_with_parameters(win, "tab_changed", [true])
	win.set_tab("buy")
	assert_signal_emitted_with_parameters(win, "tab_changed", [false])


func test_sell_confirms_rare() -> void:
	assert_false(MerchantWindow.needs_confirm(ItemRoll.new_item("sword_t1", 1, "uncommon")))
	assert_true(MerchantWindow.needs_confirm(ItemRoll.new_item("sword_t1", 1, "rare")))
	assert_true(MerchantWindow.needs_confirm(ItemRoll.new_item("sword_t1", 1, "unique")))


func test_repair_button_price() -> void:
	var inv := _inv(50)
	win.show_for(_stock(), inv, "mage", 10)
	win.set_tab("sell")
	var cost := 0
	for it: Item in inv.equipment.values():
		cost += Merchant.repair_cost(it, db)
	assert_string_contains(win.repair_text(), str(cost))
	assert_true(win.repair_enabled())
	watch_signals(win)
	win.press_repair()
	assert_signal_emitted(win, "repair_requested")


func test_nothing_to_repair_disables_it() -> void:
	win.show_for(_stock(), _inv(100), "mage", 10)
	assert_false(win.repair_enabled())


func test_fits_with_inventory_720() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var inv_win := InventoryWindow.new()
	add_child_autofree(inv_win)
	var inv := _inv()
	inv_win.show_for(inv, "mage", 10)
	win.show_for(_stock(), inv, "mage", 10)
	win.set_right_margin(inv_win.reserved_width())
	await wait_process_frames(3)
	var screen := Rect2(0, 0, 1280, 720)
	assert_true(screen.encloses(win.panel_rect()), "%s" % win.panel_rect())
	assert_false(win.panel_rect().intersects(inv_win.panel_rect()))
