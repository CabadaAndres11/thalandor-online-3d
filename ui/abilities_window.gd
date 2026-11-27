class_name AbilitiesWindow
extends Control
## Abilities window (K): the class's abilities as lists (mouse attacks and actives, then
## passives; the lists grow with abilities from outside the class later) with the selected
## one's description and computed details (AbilityDetails) and the bar of slots 1-4.
## Click an active, then a slot; an ability already on the bar swaps places. Clicking a
## slot with nothing selected picks its ability up.

signal bar_changed(bar: Array)

const ROW := Vector2(270, 42)
const ICON := 32
const BAR_SLOT := 56.0
const DESC_LINES := 11

var _abilities: AbilityDB
var _class_id: String = ""
var _villager_hint: Label
var _stats: CombatStats
var _resource_kind: String = "mana"
var _bar: Array = []
var _attacks: Array = [] # basic and secondary (always on the mouse)
var _actives: Array = []
var _passives: Array = []
var _selected: String = ""
var _panel: PanelContainer
var _attack_row: VBoxContainer
var _active_row: VBoxContainer
var _passive_row: VBoxContainer
var _bar_row: HBoxContainer
var _cards: Dictionary = {} # ability id -> Button
var _slots: Array = [] # Button per bar slot
var _name_label: Label
var _desc: Label
var _level: int = 65535
var _upgrade: String = ""


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
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(16))
	HoloTheme.add_shine(_panel)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(HoloTheme.title(tr("ABILITIES_TITLE")))
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)
	box.add_child(HoloTheme.divider())

	# Lists on the left, the bar and the description of the selected ability on the right.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	box.add_child(body)
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 4)
	body.add_child(list_col)
	_attack_row = _list(list_col, tr("ABILITIES_ATTACKS"))
	_active_row = _list(list_col, tr("ABILITIES_ACTIVES"))
	var passive_col := VBoxContainer.new()
	passive_col.add_theme_constant_override("separation", 4)
	body.add_child(passive_col)
	_passive_row = _list(passive_col, tr("ABILITIES_PASSIVES"))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)
	side.add_child(HoloTheme.section(tr("ABILITIES_BAR")))
	_bar_row = HBoxContainer.new()
	_bar_row.add_theme_constant_override("separation", 6)
	side.add_child(_bar_row)
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
	side.add_child(HoloTheme.divider())
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", HoloTheme.ACCENT)
	side.add_child(_name_label)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.custom_minimum_size = Vector2(560, DESC_LINES * 21)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	side.add_child(_desc)
	_villager_hint = Label.new()
	_villager_hint.text = tr("ABILITIES_VILLAGER_HINT")
	_villager_hint.add_theme_font_size_override("font_size", 16)
	_villager_hint.add_theme_color_override("font_color", HoloTheme.ACCENT)
	_villager_hint.visible = false
	box.add_child(_villager_hint)
	var hint := Label.new()
	hint.text = tr("ABILITIES_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window for a class and opens it. The details use the class's base stats
## (equipment and levels come in later plans).
func show_for(class_id: String, p_bar: Array, abilities: AbilityDB, level: int = 65535, upgrade: String = "") -> void:
	_abilities = abilities
	_class_id = class_id
	var def := CharacterCatalog.load_default().class_def(class_id)
	_stats = CombatStats.from_dict(def.get("stats", {}))
	var res: Variant = def.get("resource", {})
	_resource_kind = str((res as Dictionary).get("kind", "mana")) if res is Dictionary else "mana"
	_bar = abilities.sanitize_bar(class_id, p_bar, level, upgrade)
	_attacks = [abilities.kind_of(class_id, "basic"), abilities.kind_of(class_id, "secondary")].filter(
		func(id: String) -> bool: return id != "")
	_level = level
	_upgrade = upgrade
	_actives = abilities.actives(class_id, upgrade)
	_passives = abilities.class_abilities(class_id).filter(
		func(a: Dictionary) -> bool: return a.get("kind") == "passive" and AbilityDB.upgrade_ok(a, upgrade) 			and (AbilityDB.is_variant(a) or abilities.variant_for(str(a.id), upgrade).is_empty())).map(
		func(a: Dictionary) -> String: return a.id)
	_cards.clear()
	for row: VBoxContainer in [_attack_row, _active_row, _passive_row]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	for id: String in _attacks:
		_attack_row.add_child(_card(id))
	for id: String in _actives:
		_active_row.add_child(_card(id))
	for id: String in _passives:
		_passive_row.add_child(_card(id))
	_villager_hint.visible = not CharacterCatalog.load_default().is_selectable(class_id)
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
	if _selected == "" or not _selected in _actives or is_locked(_selected):
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


## True for a villager: the window tells them to talk to Brann.
func villager_hint_visible() -> bool:
	return _villager_hint.visible


func attack_ids() -> Array:
	return _attacks.duplicate()


func description_text() -> String:
	return _desc.text


func active_ids() -> Array:
	return _actives.duplicate()


func passive_ids() -> Array:
	return _passives.duplicate()


## Abilities and passives above the player's level: shown with a lock, never assignable.
func is_locked(id: String) -> bool:
	return _abilities != null and _abilities.has(id) and int(_abilities.get_ability(id).get("level", 1)) > _level


func locked_ids() -> Array:
	var out: Array = []
	for id: String in _attacks + _actives + _passives:
		if is_locked(id):
			out.append(id)
	return out


func card_text(id: String) -> String:
	return (_cards[id] as Button).text if _cards.has(id) else ""


func has_lock_icon(id: String) -> bool:
	return _cards.has(id) and (_cards[id] as Button).find_child("Lock", false, false) != null


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func description_fits() -> bool:
	return _desc.get_line_count() <= DESC_LINES


# --- Building ---

## A titled vertical list of ability rows; returns the rows' container.
func _list(col: VBoxContainer, title: String) -> VBoxContainer:
	col.add_child(HoloTheme.section(title))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	col.add_child(rows)
	return rows


func _card(id: String) -> Button:
	var a := _shown(id)
	var b := Button.new()
	b.custom_minimum_size = ROW
	b.icon = _icon(id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", ICON)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = tr(str(a.get("name", id)))
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = tr(str(a.get("desc", "")))
	if is_locked(id):
		b.text += "\n" + tr("ABILITIES_LEVEL") % int(a.get("level", 1))
		b.modulate = Color(0.55, 0.55, 0.6)
		var lock := LockIcon.new()
		lock.name = "Lock"
		b.add_child(lock)
	b.pressed.connect(select_ability.bind(id))
	_cards[id] = b
	return b


## The ability as this player casts it: its upgrade's variant and evolution (Plan 8.3h).
func _shown(id: String) -> Dictionary:
	return _abilities.resolved(id, _upgrade)


func _icon(id: String) -> Texture2D:
	if _abilities == null or not _abilities.has(id):
		return null
	var path := CombatHud.ICON_DIR % str(_shown(id).get("icon", ""))
	return load(path) if ResourceLoader.exists(path) else null


func _show_description(id: String) -> void:
	if id == "" or not _abilities.has(id):
		_name_label.text = ""
		_desc.text = ""
		return
	var a := _shown(id)
	var title := "%s — %s" % [tr(str(a.get("name", id))), tr("ABILITIES_LEVEL") % int(a.get("level", 1))]
	if id in _attacks:
		title += " · " + tr("HUD_KEY_LMB" if a.get("kind") == "basic" else "HUD_KEY_RMB")
	_name_label.text = title
	var details := AbilityDetails.lines(a, _stats, _resource_kind)
	_desc.text = tr(str(a.get("desc", ""))) + "\n" + "\n".join(details)


func _refresh() -> void:
	for id: String in _cards:
		(_cards[id] as Button).modulate = Color(1.35, 1.2, 0.6) if id == _selected \
			else (Color(0.55, 0.55, 0.6) if is_locked(id) else Color.WHITE)
	for i in _slots.size():
		var slot: Button = _slots[i]
		var id := str(_bar[i]) if i < _bar.size() else ""
		slot.icon = _icon(id)
		slot.tooltip_text = tr(str(_shown(id).get("name", ""))) if id != "" and _abilities.has(id) else ""
