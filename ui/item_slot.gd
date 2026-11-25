class_name ItemSlot
extends PanelContainer
## One item square: the item's icon with a border in its rarity color, the stack count,
## red when broken, on a red background when the viewer cannot equip it. Right click reports `right_clicked`; hovering shows ItemTooltip.

signal right_clicked()

const SIZE := 48.0
## Background of an item the viewer cannot equip (another class's, or above their level).
const UNUSABLE_BG := Color(0.55, 0.08, 0.08, 0.55)
## Quest items (Plan 8.2) wear a gold border.
const QUEST_BORDER := Color("#e0b84a")

var item: Item
## For the tooltip: who looks at it and what they wear in that slot.
var class_id: String = ""
var level: int = 1
var worn: Item
var _icon: TextureRect
var _count: Label
var _hint: Label


func _init(hint: String = "") -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", HoloTheme.box_style())
	_hint = Label.new()
	_hint.text = hint
	_hint.modulate = Color(1, 1, 1, 0.35)
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_constant_override("outline_size", 4)
	_count.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_count)


func set_item(it: Item) -> void:
	item = it
	_hint.visible = it == null
	_icon.texture = ItemIcons.icon(it.base_id) if it != null else null
	_count.text = str(it.count) if it != null and it.count > 1 else ""
	var style := HoloTheme.box_style()
	if it != null:
		style.border_color = QUEST_BORDER if ItemDB.load_default().is_quest(it.base_id) else ItemIcons.rarity_color(it.rarity)
		style.set_border_width_all(2)
		if unusable():
			style.bg_color = UNUSABLE_BG
		_icon.modulate = Color(1, 0.45, 0.45) if it.durability <= 0 and not ItemDB.load_default().is_consumable(it.base_id) else Color.WHITE
	add_theme_stylebox_override("panel", style)
	tooltip_text = " " if it != null else _hint.text


## True when the viewer (class_id, level) could not equip this item; never for potions,
## nor when no viewer class is set.
func unusable() -> bool:
	var db := ItemDB.load_default()
	if item == null or class_id == "" or db.is_consumable(item.base_id) or db.is_quest(item.base_id):
		return false
	return not db.can_use(class_id, item.base_id) or item.level > level


func border_color() -> Color:
	var sb := get_theme_stylebox("panel") as StyleBoxFlat
	return sb.border_color if sb != null else Color.TRANSPARENT


func count_text() -> String:
	return _count.text


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit()
		accept_event()


func _make_custom_tooltip(_for_text: String) -> Object:
	if item == null:
		return null
	return ItemTooltip.build(item, class_id, level, worn, ItemDB.load_default())
