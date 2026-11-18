class_name CharacterWindow
extends Control
## Character window (C): the character's 3D model between the equipment slots (empty until
## items exist), name, class, level and experience, the five attributes with their "+"
## buttons (the ones recommended for the class in gold) and the computed stats. The host
## does the spending; this window only reports `attribute_spent`.

signal attribute_spent(attr: String)

const SLOTS_LEFT := ["head", "chest", "hands", "feet"]
const SLOTS_RIGHT := ["weapon", "offhand", "ring", "neck"]
const SLOT_SIZE := 60.0
const PREVIEW_SIZE := Vector2(220, 330)

var _panel: PanelContainer
var _name_label: Label
var _level_label: Label
var _xp_label: Label
var _points_label: Label
var _attr_names: Dictionary = {} # attr -> Label
var _attr_values: Dictionary = {} # attr -> Label
var _attr_plus: Dictionary = {} # attr -> Button
var _stats_grid: GridContainer
var _free: int = 0
var _rows: Array = []
var _recommended: Array = []
var _preview: CharacterPreview
var _preview_key: String = ""
var _slot_boxes: Dictionary = {} # slot id -> PanelContainer


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.03, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(16))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(HoloTheme.title(tr("CHAR_TITLE")))
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)
	box.add_child(HoloTheme.divider())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	box.add_child(body)

	# Model flanked by the equipment slots.
	var model := HBoxContainer.new()
	model.add_theme_constant_override("separation", 8)
	body.add_child(model)
	model.add_child(_slot_column(SLOTS_LEFT))
	_preview = CharacterPreview.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	model.add_child(_preview)
	model.add_child(_slot_column(SLOTS_RIGHT))

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", HoloTheme.ACCENT)
	left.add_child(_name_label)
	_level_label = Label.new()
	left.add_child(_level_label)
	_xp_label = Label.new()
	_xp_label.modulate = Color(1, 1, 1, 0.75)
	left.add_child(_xp_label)
	left.add_child(HoloTheme.divider())
	left.add_child(HoloTheme.section(tr("CHAR_ATTRIBUTES")))
	_points_label = Label.new()
	_points_label.add_theme_color_override("font_color", HoloTheme.ACCENT)
	left.add_child(_points_label)
	for a: String in PlayerProgress.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		var name_label := Label.new()
		name_label.text = tr("ATTR_" + a.to_upper())
		name_label.tooltip_text = tr("ATTR_%s_DESC" % a.to_upper())
		name_label.mouse_filter = MOUSE_FILTER_STOP
		name_label.custom_minimum_size.x = 130
		row.add_child(name_label)
		_attr_names[a] = name_label
		var value := Label.new()
		value.custom_minimum_size.x = 56
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_attr_values[a] = value
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(40, 0)
		plus.pressed.connect(press_plus.bind(a))
		row.add_child(plus)
		_attr_plus[a] = plus

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	right.add_child(HoloTheme.section(tr("CHAR_STATS")))
	right.add_child(HoloTheme.divider())
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 16)
	_stats_grid.add_theme_constant_override("v_separation", 3)
	right.add_child(_stats_grid)

	box.add_child(HoloTheme.divider())
	var hint := Label.new()
	hint.text = tr("CHAR_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window and opens it. `stats` are the computed stats of the character.
func show_for(char_name: String, class_id: String, progress: PlayerProgress, stats: CombatStats, balance: Balance,
		appearance: Dictionary = {}) -> void:
	var def := CharacterCatalog.load_default().class_def(class_id)
	_name_label.text = "%s · %s" % [char_name, tr(str(def.get("name", class_id)))]
	_level_label.text = tr("CHAR_LEVEL") % progress.level
	_xp_label.text = tr("CHAR_XP") % [progress.xp, Xp.to_next(progress.level, balance)]
	_free = Attributes.free_points(progress, balance)
	_points_label.text = tr("CHAR_FREE_POINTS") % _free
	_recommended = (def.get("main_attributes", []) as Array).duplicate()
	var totals := Attributes.totals(progress, def, balance)
	for a: String in PlayerProgress.ATTRIBUTES:
		var rec := a in _recommended
		(_attr_values[a] as Label).text = str(totals[a])
		(_attr_plus[a] as Button).disabled = _free <= 0
		for l: Label in [_attr_names[a], _attr_values[a]]:
			l.add_theme_color_override("font_color", HoloTheme.ACCENT if rec else HoloTheme.TEXT)
		(_attr_names[a] as Label).tooltip_text = tr("ATTR_%s_DESC" % a.to_upper()) \
			+ ("\n" + tr("CHAR_RECOMMENDED") if rec else "")
	_rows = _stat_rows(stats, str((def.get("resource", {}) as Dictionary).get("kind", "")), balance)
	for child in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()
	for r: Array in _rows:
		var name_label := Label.new()
		name_label.text = r[0]
		name_label.modulate = Color(1, 1, 1, 0.8)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		_stats_grid.add_child(name_label)
		var value := Label.new()
		value.text = r[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats_grid.add_child(value)
	# The model is rebuilt only when the class or the look changes (progress updates keep it turning).
	var key := class_id + JSON.stringify(appearance)
	if key != _preview_key:
		_preview_key = key
		_preview.show_character(class_id, appearance)
	visible = true


func _stat_rows(s: CombatStats, resource_kind: String, balance: Balance) -> Array:
	var rows: Array = [[tr("STAT_ROW_HP"), str(roundi(s.max_hp))]]
	if s.max_resource > 0.0 and resource_kind != "none":
		rows.append([tr("STAT_ROW_RESOURCE"), str(roundi(s.max_resource))])
	rows.append_array([
		[tr("STAT_ROW_ATTACK"), str(roundi(s.attack_power))],
		[tr("STAT_ROW_SPELL"), str(roundi(s.spell_power))],
		[tr("STAT_ROW_ARMOR"), str(roundi(s.armor))],
		[tr("STAT_ROW_CRIT"), _pct(s.crit_chance)],
		[tr("STAT_ROW_CRIT_DAMAGE"), _pct(balance.crit_multiplier + s.crit_damage)],
		[tr("STAT_ROW_DODGE"), _pct(s.dodge_chance)],
		[tr("STAT_ROW_BLOCK"), _pct(s.block_chance)],
		[tr("STAT_ROW_SPEED"), _pct(s.move_speed_mult)],
		[tr("STAT_ROW_COOLDOWN"), _pct(s.cooldown_reduction)],
		[tr("STAT_ROW_LIFESTEAL"), _pct(s.lifesteal)],
		[tr("STAT_ROW_REGEN"), "%s" % snappedf(s.hp_regen, 0.1)],
	])
	return rows


static func _pct(v: float) -> String:
	return "%s %%" % snappedf(v * 100.0, 0.1)


# --- Equipment slots (reserved: items come in a later plan) ---

func _slot_column(ids: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for id: String in ids:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", HoloTheme.box_style())
		slot.tooltip_text = "%s\n%s" % [tr("EQUIP_" + id.to_upper()), tr("EQUIP_EMPTY")]
		slot.mouse_filter = MOUSE_FILTER_STOP
		var l := Label.new()
		l.text = tr("EQUIP_" + id.to_upper()).left(4)
		l.modulate = Color(1, 1, 1, 0.35)
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(l)
		col.add_child(slot)
		_slot_boxes[id] = slot
	return col


# --- Readable state (tests) ---

func free_points() -> int:
	return _free


func stat_rows() -> Array:
	return _rows.duplicate(true)


func level_text() -> String:
	return _level_label.text


func attribute_value(attr: String) -> int:
	return int((_attr_values[attr] as Label).text)


func plus_enabled(attr: String) -> bool:
	return not (_attr_plus[attr] as Button).disabled


func press_plus(attr: String) -> void:
	if _free > 0:
		attribute_spent.emit(attr)


## Attributes shown in gold (the class's main ones).
func recommended_attributes() -> Array:
	return _recommended.duplicate()


func attribute_color(attr: String) -> Color:
	return (_attr_names[attr] as Label).get_theme_color("font_color")


func slot_ids() -> Array:
	return _slot_boxes.keys()


func has_model() -> bool:
	return _preview.rig != null


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
