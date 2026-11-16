class_name CharacterWindow
extends Control
## Character window (C): name, class, level and experience, the five attributes with
## their "+" buttons (free points to spend) and the computed stats. The host does the
## spending; this window only reports `attribute_spent`.

signal attribute_spent(attr: String)

var _panel: PanelContainer
var _name_label: Label
var _level_label: Label
var _xp_label: Label
var _points_label: Label
var _attr_values: Dictionary = {} # attr -> Label
var _attr_plus: Dictionary = {} # attr -> Button
var _stats_grid: GridContainer
var _free: int = 0
var _rows: Array = []


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
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = tr("CHAR_TITLE")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	box.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	left.add_child(_name_label)
	_level_label = Label.new()
	left.add_child(_level_label)
	_xp_label = Label.new()
	_xp_label.modulate = Color(1, 1, 1, 0.75)
	left.add_child(_xp_label)
	left.add_child(_section(tr("CHAR_ATTRIBUTES")))
	_points_label = Label.new()
	_points_label.add_theme_color_override("font_color", Color("#ffd27a"))
	left.add_child(_points_label)
	for a: String in PlayerProgress.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left.add_child(row)
		var name_label := Label.new()
		name_label.text = tr("ATTR_" + a.to_upper())
		name_label.tooltip_text = tr("ATTR_%s_DESC" % a.to_upper())
		name_label.mouse_filter = MOUSE_FILTER_STOP
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
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
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	right.add_child(_section(tr("CHAR_STATS")))
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 16)
	_stats_grid.add_theme_constant_override("v_separation", 3)
	right.add_child(_stats_grid)

	var hint := Label.new()
	hint.text = tr("CHAR_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window and opens it. `stats` are the computed stats of the character.
func show_for(char_name: String, class_id: String, progress: PlayerProgress, stats: CombatStats, balance: Balance) -> void:
	var def := CharacterCatalog.load_default().class_def(class_id)
	_name_label.text = "%s · %s" % [char_name, tr(str(def.get("name", class_id)))]
	_level_label.text = tr("CHAR_LEVEL") % progress.level
	_xp_label.text = tr("CHAR_XP") % [progress.xp, Xp.to_next(progress.level, balance)]
	_free = Attributes.free_points(progress, balance)
	_points_label.text = tr("CHAR_FREE_POINTS") % _free
	var totals := Attributes.totals(progress, def, balance)
	for a: String in PlayerProgress.ATTRIBUTES:
		(_attr_values[a] as Label).text = str(totals[a])
		(_attr_plus[a] as Button).disabled = _free <= 0
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


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.modulate = Color("#e8c66a")
	return l
