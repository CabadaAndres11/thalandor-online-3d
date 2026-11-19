class_name MerchantWindow
extends Control
## The merchant (provisionally next to Brann): a "Buy" tab with both potions and the common
## items for sale (right click buys) and a "Sell and repair" tab (right click in the
## inventory sells; one button repairs everything worn). It sits left of the inventory.
## The host checks every trade; this window only reports what the player asks.

signal buy_requested(index: int)
signal repair_requested()
## true when the sell tab opens (the inventory's right click sells), false otherwise.
signal tab_changed(selling: bool)

## Rarities that ask before being sold.
const CONFIRM_FROM := ["rare", "epic", "legendary", "unique"]

var _panel: PanelContainer
var _center: CenterContainer
var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _stock_grid: GridContainer
var _potion_price: Label
var _repair: Button
var _stock: Array = []
var _repair_cost: int = 0


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	HoloTheme.add_shine(_panel)
	_center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 380
	_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(HoloTheme.title(tr("NPC_MERCHANT"), 24))
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	var buy_tab := Button.new()
	buy_tab.text = tr("MERCHANT_BUY")
	buy_tab.pressed.connect(set_tab.bind("buy"))
	tabs.add_child(buy_tab)
	var sell_tab := Button.new()
	sell_tab.text = tr("MERCHANT_SELL")
	sell_tab.pressed.connect(set_tab.bind("sell"))
	tabs.add_child(sell_tab)
	box.add_child(HoloTheme.divider())

	_buy_box = VBoxContainer.new()
	_buy_box.add_theme_constant_override("separation", 6)
	box.add_child(_buy_box)
	var potions := HBoxContainer.new()
	potions.add_theme_constant_override("separation", 8)
	_buy_box.add_child(potions)
	for kind: String in ["health", "resource"]:
		var slot := ItemSlot.new()
		slot.set_item(ItemRoll.new_item("potion_" + kind, 1))
		slot.right_clicked.connect(buy.bind(Merchant.BUY_HEALTH if kind == "health" else Merchant.BUY_RESOURCE))
		potions.add_child(slot)
	_potion_price = Label.new()
	_potion_price.add_theme_color_override("font_color", HoloTheme.ACCENT)
	potions.add_child(_potion_price)
	var price_hint := Label.new()
	price_hint.text = tr("MERCHANT_EACH")
	price_hint.modulate = Color(1, 1, 1, 0.7)
	potions.add_child(price_hint)
	_stock_grid = GridContainer.new()
	_stock_grid.columns = 2
	_stock_grid.add_theme_constant_override("h_separation", 10)
	_stock_grid.add_theme_constant_override("v_separation", 6)
	_buy_box.add_child(_stock_grid)
	var buy_hint := Label.new()
	buy_hint.text = tr("MERCHANT_BUY_HINT")
	buy_hint.add_theme_font_size_override("font_size", 13)
	buy_hint.modulate = Color(1, 1, 1, 0.7)
	_buy_box.add_child(buy_hint)

	_sell_box = VBoxContainer.new()
	_sell_box.add_theme_constant_override("separation", 8)
	_sell_box.visible = false
	box.add_child(_sell_box)
	var sell_hint := Label.new()
	sell_hint.text = tr("MERCHANT_SELL_HINT")
	sell_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sell_box.add_child(sell_hint)
	_repair = Button.new()
	_repair.pressed.connect(press_repair)
	_sell_box.add_child(_repair)


## Opens (or refreshes) the window: `stock` are the Items for sale to this player.
func show_for(stock: Array, inv: Inventory, class_id: String, level: int) -> void:
	_stock = stock
	var db := ItemDB.load_default()
	for c: Node in _stock_grid.get_children():
		_stock_grid.remove_child(c)
		c.queue_free()
	for i in stock.size():
		var it: Item = stock[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var slot := ItemSlot.new()
		slot.class_id = class_id
		slot.level = level
		slot.worn = InventoryWindow._worn_for(it, inv, db)
		slot.set_item(it)
		slot.right_clicked.connect(buy.bind(i))
		row.add_child(slot)
		var price := Label.new()
		price.text = tr("INV_GOLD") % ItemRoll.value(it, db)
		price.add_theme_color_override("font_color", HoloTheme.ACCENT)
		price.add_theme_font_size_override("font_size", 15)
		row.add_child(price)
		_stock_grid.add_child(row)
	_potion_price.text = str(Merchant.potion_price(level, db))
	_repair_cost = 0
	var worn := false
	for it: Item in inv.equipment.values():
		_repair_cost += Merchant.repair_cost(it, db)
		worn = worn or it.durability < 100
	_repair.text = tr("MERCHANT_REPAIR") % _repair_cost
	_repair.disabled = not worn or inv.gold < _repair_cost
	if not visible:
		set_tab("buy")
	visible = true


func set_tab(tab: String) -> void:
	var selling := tab == "sell"
	_buy_box.visible = not selling
	_sell_box.visible = selling
	tab_changed.emit(selling)


func buy(index: int) -> void:
	buy_requested.emit(index)


func press_repair() -> void:
	if not _repair.disabled:
		repair_requested.emit()


## Rare or better asks before it is sold.
static func needs_confirm(it: Item) -> bool:
	return it != null and it.rarity in CONFIRM_FROM


## Leaves `px` free on the right (the inventory docked there).
func set_right_margin(px: float) -> void:
	_center.offset_right = -px


# --- Readable state (tests) ---

func stock_count() -> int:
	return _stock.size()


func potion_price_text() -> String:
	return _potion_price.text


func repair_text() -> String:
	return _repair.text


func repair_enabled() -> bool:
	return not _repair.disabled


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
