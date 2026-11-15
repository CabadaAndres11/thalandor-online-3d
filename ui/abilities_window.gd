class_name AbilitiesWindow
extends Control
## Abilities window (K): the class's actives and passives with their descriptions, and
## the bar of slots 1-4. Click an active, then a slot; an ability already on the bar
## swaps places. Clicking a slot with nothing selected picks its ability up.

signal bar_changed(bar: Array)

const CARD := Vector2(124, 92)
const BAR_SLOT := 64.0
const DESC_LINES := 3

var _abilities: AbilityDB
var _class_id: String = ""
var _bar: Array = []
var _actives: Array = []
var _passives: Array = []
var _selected: String = ""
var _panel: PanelContainer
var _active_row: HBoxContainer
var _passive_row: HBoxContainer
var _bar_row: HBoxContainer
var _cards: Dictionary = {} # ability id -> Button
var _slots: Array = [] # Button per bar slot
var _name_label: Label
var _desc: Label


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	style.border_color = Color("#8a6d2f")
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = tr("ABILITIES_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	box.add_child(_section(tr("ABILITIES_ACTIVES")))
	_active_row = _row(box)
	box.add_child(_section(tr("ABILITIES_PASSIVES")))
	_passive_row = _row(box)
	box.add_child(_section(tr("ABILITIES_BAR")))
	_bar_row = _row(box)
	for i in AbilityDB.BAR_SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(BAR_SLOT, BAR_SLOT)
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.text = str(i + 1)
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.pressed.connect(click_slot.bind(i))
		_bar_row.add_child(slot)
		_slots.append(slot)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_name_label)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 16)
	_desc.custom_minimum_size = Vector2(5 * CARD.x + 4 * 6, 3 * 22)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_desc)
	var hint := Label.new()
	hint.text = tr("ABILITIES_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window for a class and opens it.
func show_for(class_id: String, p_bar: Array, abilities: AbilityDB) -> void:
	_abilities = abilities
	_class_id = class_id
	_bar = abilities.sanitize_bar(class_id, p_bar)
	_actives = abilities.actives(class_id)
	_passives = abilities.class_abilities(class_id).filter(
		func(a: Dictionary) -> bool: return a.get("kind") == "passive").map(
		func(a: Dictionary) -> String: return a.id)
	_cards.clear()
	for row: HBoxContainer in [_active_row, _passive_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	for id: String in _actives:
		_active_row.add_child(_card(id))
	for id: String in _passives:
		_passive_row.add_child(_card(id))
	_selected = ""
	_show_description(_actives[0] if not _actives.is_empty() else "")
	_refresh()
	visible = true


## Selects an ability of the class (actives can then go to a slot). Anything else
## clears the selection.
func select_ability(id: String) -> void:
	_selected = id if (id in _actives or id in _passives) else ""
	if _selected != "":
		_show_description(_selected)
	_refresh()


func click_slot(i: int) -> void:
	if i < 0 or i >= _bar.size():
		return
	if _selected == "" or not _selected in _actives:
		_selected = ""
		if str(_bar[i]) != "":
			select_ability(_bar[i])
		return
	var id := _selected
	_selected = ""
	var before := _bar.duplicate()
	var at := _bar.find(id)
	if at >= 0:
		_bar[at] = _bar[i]
	_bar[i] = id
	_refresh()
	if _bar != before:
		bar_changed.emit(_bar.duplicate())


# --- Readable state (tests) ---

func bar() -> Array:
	return _bar.duplicate()


func active_ids() -> Array:
	return _actives.duplicate()


func passive_ids() -> Array:
	return _passives.duplicate()


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func description_fits() -> bool:
	return _desc.get_line_count() <= DESC_LINES


# --- Building ---

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.modulate = Color("#e8c66a")
	return l


func _row(box: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	return row


func _card(id: String) -> Button:
	var a := _abilities.get_ability(id)
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.icon = _icon(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = tr(str(a.get("name", id)))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.tooltip_text = tr(str(a.get("desc", "")))
	b.pressed.connect(select_ability.bind(id))
	_cards[id] = b
	return b


func _icon(id: String) -> Texture2D:
	if _abilities == null or not _abilities.has(id):
		return null
	var path := CombatHud.ICON_DIR % str(_abilities.get_ability(id).get("icon", ""))
	return load(path) if ResourceLoader.exists(path) else null


func _show_description(id: String) -> void:
	if id == "" or not _abilities.has(id):
		_name_label.text = ""
		_desc.text = ""
		return
	var a := _abilities.get_ability(id)
	_name_label.text = "%s — %s" % [tr(str(a.get("name", id))), tr("ABILITIES_LEVEL") % int(a.get("level", 1))]
	var cost_line := ""
	if a.get("kind") == "active":
		var cd := float(a.get("cooldown_s", 0))
		var cd_text := str(int(cd)) if is_equal_approx(cd, roundf(cd)) else str(snappedf(cd, 0.1)).replace(".", ",")
		cost_line = "\n" + tr("ABILITIES_COST") % [int(a.get("cost", 0)), cd_text]
	_desc.text = tr(str(a.get("desc", ""))) + cost_line


func _refresh() -> void:
	for id: String in _cards:
		(_cards[id] as Button).modulate = Color(1.35, 1.2, 0.6) if id == _selected else Color.WHITE
	for i in _slots.size():
		var slot: Button = _slots[i]
		var id := str(_bar[i]) if i < _bar.size() else ""
		slot.icon = _icon(id)
		slot.tooltip_text = tr(str(_abilities.get_ability(id).get("name", ""))) if id != "" and _abilities.has(id) else ""
