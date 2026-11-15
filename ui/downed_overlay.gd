class_name DownedOverlay
extends Control
## Downed and revive feedback: while downed, a banner with the bleed-out countdown;
## while reviving an ally (holding E), a progress bar; near a downed ally, a hint to
## hold E. Driven by the client's state and its "downed" / "revive_*" events.

const BAR_WIDTH := 320.0

var _client: ClientSession
var _clock := 0.0
var _downed_at := -1.0
var _reviving := 0 # ally being revived, 0 = none
var _revive_started := 0.0

var _banner: PanelContainer
var _banner_label: Label
var _revive: VBoxContainer
var _revive_label: Label
var _revive_bar: ProgressBar
var _prompt: Label


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_banner = PanelContainer.new()
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(PRESET_CENTER)
	_banner.grow_horizontal = GROW_DIRECTION_BOTH
	_banner.grow_vertical = GROW_DIRECTION_BOTH
	_banner.offset_top = -190
	_banner.offset_bottom = -110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.03, 0.02, 0.82)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	_banner.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.add_child(col)
	var title := Label.new()
	title.text = tr("DOWNED_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#ff8a5b"))
	col.add_child(title)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_banner_label)
	_banner.visible = false
	add_child(_banner)

	_revive = VBoxContainer.new()
	_revive.mouse_filter = MOUSE_FILTER_IGNORE
	_revive.anchor_left = 0.5
	_revive.anchor_right = 0.5
	_revive.anchor_top = 0.5
	_revive.anchor_bottom = 0.5
	_revive.offset_left = -BAR_WIDTH / 2.0
	_revive.offset_right = BAR_WIDTH / 2.0
	_revive.offset_top = 70
	_revive_label = Label.new()
	_revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_revive_label.add_theme_constant_override("outline_size", 5)
	_revive.add_child(_revive_label)
	_revive_bar = ProgressBar.new()
	_revive_bar.show_percentage = false
	_revive_bar.custom_minimum_size = Vector2(0, 14)
	_revive_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#f2d16b")
	_revive_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.08, 0.85)
	_revive_bar.add_theme_stylebox_override("background", bg)
	_revive.add_child(_revive_bar)
	_revive.visible = false
	add_child(_revive)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_left = -BAR_WIDTH / 2.0
	_prompt.offset_right = BAR_WIDTH / 2.0
	_prompt.offset_top = 70
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.visible = false
	add_child(_prompt)


func bind(client: ClientSession) -> void:
	unbind()
	_client = client
	_client.combat_event.connect(_on_event)


func unbind() -> void:
	if _client != null and _client.combat_event.is_connected(_on_event):
		_client.combat_event.disconnect(_on_event)
	_client = null
	_downed_at = -1.0
	_reviving = 0
	_banner.visible = false
	_revive.visible = false
	_prompt.visible = false


func _process(delta: float) -> void:
	advance(delta)


func advance(dt: float) -> void:
	_clock += dt
	if _client == null:
		return
	var me: Dictionary = _client.combat.get(_client.my_id, {})
	var downed := int(me.get("life", CombatEntity.ALIVE)) == CombatEntity.DOWNED
	if downed and _downed_at < 0.0:
		_downed_at = _clock
	elif not downed:
		_downed_at = -1.0
	_banner.visible = downed
	if downed:
		var left := maxi(0, ceili(_client.balance.downed_s - (_clock - _downed_at)))
		_banner_label.text = tr("DOWNED_HINT") % left
	_revive.visible = _reviving != 0
	if _reviving != 0:
		var name := str(_client.roster[_reviving].name) if _client.roster.has(_reviving) else "?"
		_revive_label.text = tr("REVIVING") % name
		_revive_bar.value = clampf((_clock - _revive_started) / maxf(_client.balance.revive_hold_s, 0.01), 0.0, 1.0)
	var near := _downed_ally_near() if not downed and _reviving == 0 else 0
	_prompt.visible = near != 0
	if near != 0:
		_prompt.text = tr("REVIVE_PROMPT") % str(_client.roster[near].name)


func _on_event(ev: Array) -> void:
	if ev.size() < 2 or _client == null:
		return
	match str(ev[0]):
		"downed":
			if int(ev[1]) == _client.my_id:
				_downed_at = _clock
		"revive_start":
			if int(ev[1]) == _client.my_id and ev.size() >= 3:
				_reviving = int(ev[2])
				_revive_started = _clock
		"revive_cancel":
			if int(ev[1]) == _client.my_id:
				_reviving = 0
		"revived":
			if int(ev[1]) == _reviving:
				_reviving = 0


## An ally lying within revive_range of my drawn position, or 0.
func _downed_ally_near() -> int:
	var mine: Dictionary = _client.render_state(_client.my_id)
	if mine.is_empty():
		return 0
	for id: int in _client.combat:
		if id == _client.my_id or int(_client.combat[id].get("life", 0)) != CombatEntity.DOWNED:
			continue
		var other: Dictionary = _client.render_state(id)
		if other.is_empty() or not _client.roster.has(id):
			continue
		var a: Vector3 = mine.position
		var b: Vector3 = other.position
		if Vector2(a.x - b.x, a.z - b.z).length() <= _client.balance.revive_range:
			return id
	return 0


# --- Readable state (tests) ---

func downed_visible() -> bool:
	return _banner.visible


func downed_text() -> String:
	return _banner_label.text


func revive_visible() -> bool:
	return _revive.visible


func revive_fraction() -> float:
	return _revive_bar.value


func revive_text() -> String:
	return _revive_label.text


func prompt_visible() -> bool:
	return _prompt.visible
