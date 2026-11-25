class_name InventoryWindow
extends Control
## Inventory (I): the bag's slots (5 × 6, more only if old saves needed them) and the gold,
## docked on the right so the character and merchant windows fit beside it. Right click
## equips or drinks (`item_action`); at the merchant it sells instead (`sell_requested`).

signal item_action(action: String, args: Array)
signal sell_requested(index: int)
## Asks the host to sort the bag (Plan 8.1.1).
var sort_button: Button

const COLUMNS := 5
const MARGIN := 24.0

## True while the merchant's sell tab is open: right click sells.
var sell_mode: bool = false
var _panel: PanelContainer
var _grid: GridContainer
var _gold: Label
var _slots: Array = []
var _inv: Inventory


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	_panel.mouse_filter = MOUSE_FILTER_STOP
	HoloTheme.add_shine(_panel)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	box.add_child(HoloTheme.title(tr("INV_TITLE"), 24))
	box.add_child(HoloTheme.divider())
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)
	box.add_child(HoloTheme.divider())
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", HoloTheme.ACCENT)
	sort_button = Button.new()
	sort_button.text = tr("BTN_SORT")
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.pressed.connect(func() -> void: item_action.emit("sort", []))
	var row := HBoxContainer.new()
	row.add_child(_gold)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sort_button)
	box.add_child(row)
	var hint := Label.new()
	hint.text = tr("INV_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window with the player's inventory and opens it.
func show_for(inv: Inventory, class_id: String, level: int) -> void:
	_inv = inv
	while _slots.size() < inv.bag.size():
		var slot := ItemSlot.new()
		slot.right_clicked.connect(right_click.bind(_slots.size()))
		_grid.add_child(slot)
		_slots.append(slot)
	while _slots.size() > inv.bag.size():
		var s: Node = _slots.pop_back()
		_grid.remove_child(s)
		s.queue_free()
	var db := ItemDB.load_default()
	for i in _slots.size():
		var slot: ItemSlot = _slots[i]
		var it: Item = inv.bag[i]
		slot.class_id = class_id
		slot.level = level
		slot.worn = _worn_for(it, inv, db)
		slot.set_item(it)
	_gold.text = tr("INV_GOLD") % inv.gold
	visible = true
	_place()


## What is worn where `it` would go (for the comparison in its tooltip).
static func _worn_for(it: Item, inv: Inventory, db: ItemDB) -> Item:
	if it == null:
		return null
	var slot := str(db.base(it.base_id).get("slot", ""))
	if slot == "ring":
		slot = "ring_1"
	return inv.equipment.get(slot)


func _place() -> void:
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_panel.position = Vector2(view.x - size.x - MARGIN, (view.y - size.y) / 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_place()


## Space other windows leave free on the right while this one is open.
func reserved_width() -> float:
	return _panel.get_combined_minimum_size().x + MARGIN * 2.0


func right_click(index: int) -> void:
	if _inv == null or index < 0 or index >= _inv.bag.size() or _inv.bag[index] == null:
		return
	if ItemDB.load_default().is_quest((_inv.bag[index] as Item).base_id):
		return # quest items stay in the bag until their quest takes them
	if sell_mode:
		sell_requested.emit(index)
		return
	var it: Item = _inv.bag[index]
	item_action.emit("use" if ItemDB.load_default().is_consumable(it.base_id) else "equip", [index])


# --- Readable state (tests) ---

func slot_count() -> int:
	return _slots.size()


func slot_count_text(i: int) -> String:
	return (_slots[i] as ItemSlot).count_text()


func gold_text() -> String:
	return _gold.text


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
