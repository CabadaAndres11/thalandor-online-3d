class_name PartyFrames
extends Control
## Allies' frames on the left (GDD §9, simple until Plan 7): name, health bar and
## "Derribado" / "Caído". Built from the client's roster and combat state.

const WIDTH := 210.0
const TOP := 120.0
const LEFT := 16.0
const SLOT_COLORS := PlayerAvatar.SLOT_COLORS

var _client: ClientSession
var _box: VBoxContainer
var _frames: Dictionary = {} # id -> {"panel", "name", "hp", "status"}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.mouse_filter = MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	_box.position = Vector2(LEFT, TOP)
	_box.custom_minimum_size.x = WIDTH
	add_child(_box)


func bind(client: ClientSession) -> void:
	_client = client
	_clear()


func unbind() -> void:
	_client = null
	_clear()


func _process(delta: float) -> void:
	advance(delta)


func advance(_dt: float) -> void:
	if _client == null:
		return
	var ids := frame_ids_wanted()
	for id: int in _frames.keys():
		if not id in ids:
			(_frames[id].panel as Node).queue_free()
			_box.remove_child(_frames[id].panel)
			_frames.erase(id)
	for id: int in ids:
		if not _frames.has(id):
			_frames[id] = _make_frame(id)
		_box.move_child(_frames[id].panel, ids.find(id))
		var f: Dictionary = _frames[id]
		var c: Dictionary = _client.combat.get(id, {})
		var hp := float(c.get("hp", 0.0))
		var max_hp := maxf(1.0, float(c.get("max_hp", 1.0)))
		(f.hp as ProgressBar).max_value = max_hp
		(f.hp as ProgressBar).value = hp
		var life := int(c.get("life", CombatEntity.ALIVE))
		var status := ""
		if life == CombatEntity.DOWNED:
			status = tr("PARTY_DOWNED")
		elif life == CombatEntity.DEAD:
			status = tr("PARTY_DEAD")
		(f.status as Label).text = status
		(f.panel as Control).modulate = Color(1, 1, 1, 0.6) if life != CombatEntity.ALIVE else Color.WHITE


## Allies (everyone in the roster but me), in slot order.
func frame_ids_wanted() -> Array:
	var ids: Array = []
	for id: int in _client.roster:
		if id != _client.my_id:
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool: return int(_client.roster[a].slot) < int(_client.roster[b].slot))
	return ids


# --- Readable state (tests) ---

func frame_ids() -> Array:
	var ids := _frames.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(_client.roster[a].slot) < int(_client.roster[b].slot))
	return ids


func frame_name(id: int) -> String:
	return (_frames[id].name as Label).text


func frame_fraction(id: int) -> float:
	var bar: ProgressBar = _frames[id].hp
	return bar.value / maxf(1.0, bar.max_value)


func frame_status(id: int) -> String:
	return (_frames[id].status as Label).text


func frame_rect(id: int) -> Rect2:
	return (_frames[id].panel as Control).get_global_rect()


# --- Building ---

func _clear() -> void:
	for id: int in _frames:
		(_frames[id].panel as Node).queue_free()
	_frames.clear()


func _make_frame(id: int) -> Dictionary:
	var r: Dictionary = _client.roster[id]
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.75)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.border_color = SLOT_COLORS[clampi(int(r.slot), 0, SLOT_COLORS.size() - 1)]
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(row)
	var name_label := Label.new()
	name_label.text = str(r.name)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("#ff7a6b"))
	row.add_child(status)
	var hp := ProgressBar.new()
	hp.mouse_filter = MOUSE_FILTER_IGNORE
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	hp.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CombatHud.HP_COLOR
	hp.add_theme_stylebox_override("fill", fill)
	col.add_child(hp)
	_box.add_child(panel)
	return {"panel": panel, "name": name_label, "hp": hp, "status": status}
