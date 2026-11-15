class_name AbilitiesWindow
extends Control
## Abilities window (K): the class's mouse attacks (CI, CD), actives and passives with
## their description and computed details (AbilityDetails), and
## the bar of slots 1-4. Click an active, then a slot; an ability already on the bar
## swaps places. Clicking a slot with nothing selected picks its ability up.

signal bar_changed(bar: Array)

const CARD := Vector2(124, 86)
const BAR_SLOT := 64.0
const DESC_LINES := 9

var _abilities: AbilityDB
var _class_id: String = ""
var _stats: CombatStats
var _resource_kind: String = "mana"
var _bar: Array = []
var _attacks: Array = [] # basic and secondary (always on the mouse)
var _actives: Array = []
var _passives: Array = []
var _selected: String = ""
var _panel: PanelContainer
var _attack_row: HBoxContainer
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

	# Row 1: the mouse attacks (CI, CD) and the actives; row 2: passives and the bar.
	var row1 := _row(box)
	_attack_row = _block(row1, tr("ABILITIES_ATTACKS"))
	_active_row = _block(row1, tr("ABILITIES_ACTIVES"))
	var row2 := _row(box)
	_passive_row = _block(row2, tr("ABILITIES_PASSIVES"))
	_bar_row = _block(row2, tr("ABILITIES_BAR"))
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
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.custom_minimum_size = Vector2(7 * CARD.x + 6 * 6 + 24, DESC_LINES * 21)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_desc)
	var hint := Label.new()
	hint.text = tr("ABILITIES_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window for a class and opens it. The details use the class's base stats
## (equipment and levels come in later plans).
func show_for(class_id: String, p_bar: Array, abilities: AbilityDB) -> void:
	_abilities = abilities
	_class_id = class_id
	var def := CharacterCatalog.load_default().class_def(class_id)
	_stats = CombatStats.from_dict(def.get("stats", {}))
	var res: Variant = def.get("resource", {})
	_resource_kind = str((res as Dictionary).get("kind", "mana")) if res is Dictionary else "mana"
	_bar = abilities.sanitize_bar(class_id, p_bar)
	_attacks = [abilities.kind_of(class_id, "basic"), abilities.kind_of(class_id, "secondary")].filter(
		func(id: String) -> bool: return id != "")
	_actives = abilities.actives(class_id)
	_passives = abilities.class_abilities(class_id).filter(
		func(a: Dictionary) -> bool: return a.get("kind") == "passive").map(
		func(a: Dictionary) -> String: return a.id)
	_cards.clear()
	for row: HBoxContainer in [_attack_row, _active_row, _passive_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	for id: String in _attacks:
		_attack_row.add_child(_card(id))
	for id: String in _actives:
		_active_row.add_child(_card(id))
	for id: String in _passives:
		_passive_row.add_child(_card(id))
	_selected = ""
	_show_description(_attacks[0] if not _attacks.is_empty() else "")
	_refresh()
	visible = true


## Selects an ability of the class (actives can then go to a slot; attacks and
## passives only show their description). Anything else clears the selection.
func select_ability(id: String) -> void:
	_selected = id if (id in _attacks or id in _actives or id in _passives) else ""
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


func attack_ids() -> Array:
	return _attacks.duplicate()


func description_text() -> String:
	return _desc.text


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
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	return row


## A labelled group of cards inside a row; returns the cards' row.
func _block(row: HBoxContainer, title: String) -> HBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	col.add_child(_section(title))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	col.add_child(cards)
	return cards


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
	var title := "%s — %s" % [tr(str(a.get("name", id))), tr("ABILITIES_LEVEL") % int(a.get("level", 1))]
	if id in _attacks:
		title += " · " + tr("HUD_KEY_LMB" if a.get("kind") == "basic" else "HUD_KEY_RMB")
	_name_label.text = title
	var details := AbilityDetails.lines(a, _stats, _resource_kind)
	_desc.text = tr(str(a.get("desc", ""))) + "\n" + "\n".join(details)


func _refresh() -> void:
	for id: String in _cards:
		(_cards[id] as Button).modulate = Color(1.35, 1.2, 0.6) if id == _selected else Color.WHITE
	for i in _slots.size():
		var slot: Button = _slots[i]
		var id := str(_bar[i]) if i < _bar.size() else ""
		slot.icon = _icon(id)
		slot.tooltip_text = tr(str(_abilities.get_ability(id).get("name", ""))) if id != "" and _abilities.has(id) else ""
