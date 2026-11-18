class_name CombatHud
extends Control
## Combat HUD, bottom centre: health and resource bars with numbers, the seven
## slots (CI, CD, 1-4, Espacio) with icon, key, cooldown sweep and dimming when the
## resource is short, the assassin's combo pips, the archer's charge and the
## "you have fallen" countdown. Cooldowns come from this player's "cast" events
## (the host does not send them); the dodge cooldown comes from the client's
## prediction. A fighting boss gets a big bar at the top with its name and phase.

const SLOT := 46.0
const GAP := 4.0
const SLOTS := 2 + AbilityDB.BAR_SIZE + 1 # CI, CD, the bar and the dodge
const DODGE_SLOT := SLOTS - 1
const MARGIN_BOTTOM := 16.0
const ICON_DIR := "res://assets/icons/%s.png"
const RESOURCE_COLORS := {
	"rage": Color("#c0392b"), "mana": Color("#3a6fd8"), "focus": Color("#d8a93a"), "energy": Color("#e8d34a"),
}
const HP_COLOR := Color("#3fae49")
const BOSS_COLOR := Color("#b3261e")
const BOSS_WIDTH := 560.0
const BOSS_TOP := 52.0
const DIM := Color(0.35, 0.35, 0.4)

## Thin experience bar under the slots.
var xp_bar: XpBar

var _client: ClientSession
var _abilities: AbilityDB
var _slot_ids: Array[String] = []
var _clock := 0.0
var _cd_end: Dictionary = {} # ability id -> _clock when ready
var _cd_total: Dictionary = {}
var _gcd_end := 0.0
var _respawn_at := -1.0

var _column: VBoxContainer
var _combo_row: HBoxContainer
var _pips: Array[ColorRect] = []
var _charge: ProgressBar
## Tiles for the effects on this player (buffs, effects left by abilities, enemy debuffs).
var status_tiles: StatusTiles
var _statuses: Dictionary = {} # kind -> end tick, from the host's status events
var _cast: ProgressBar # cast time and channels of this player
var _cast_label: Label
var _cast_start: float = 0.0
var _cast_total: float = 0.0
var _hp: ProgressBar
var _hp_label: Label
var _res: ProgressBar
var _res_label: Label
var _slots: Array[Dictionary] = [] # {"panel", "icon", "key", "sweep"}
var _death: PanelContainer
var _death_label: Label
var _boss: VBoxContainer
var _boss_label: Label
var _boss_hp: ProgressBar


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var width := SLOTS * SLOT + (SLOTS - 1) * GAP
	_column = VBoxContainer.new()
	_column.mouse_filter = MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 4)
	_column.anchor_left = 0.5
	_column.anchor_right = 0.5
	_column.anchor_top = 1.0
	_column.anchor_bottom = 1.0
	_column.offset_left = -width / 2.0
	_column.offset_right = width / 2.0
	_column.offset_bottom = -MARGIN_BOTTOM
	_column.grow_vertical = GROW_DIRECTION_BEGIN
	_column.alignment = BoxContainer.ALIGNMENT_END
	add_child(_column)

	_combo_row = HBoxContainer.new()
	_combo_row.mouse_filter = MOUSE_FILTER_IGNORE
	_combo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_combo_row.add_theme_constant_override("separation", 6)
	for i in 5:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 10)
		pip.mouse_filter = MOUSE_FILTER_IGNORE
		_combo_row.add_child(pip)
		_pips.append(pip)
	_column.add_child(_combo_row)

	_charge = _bar(Color("#f2e6a0"), 8)
	_charge.custom_minimum_size.x = width * 0.5
	_charge.size_flags_horizontal = SIZE_SHRINK_CENTER
	_column.add_child(_charge)

	_cast = _bar(Color("#c07bff"), 18)
	_cast.custom_minimum_size.x = width * 0.6
	_cast.size_flags_horizontal = SIZE_SHRINK_CENTER
	_cast_label = _bar_label(_cast)
	_cast.visible = false
	_column.add_child(_cast)

	status_tiles = StatusTiles.new()
	_column.add_child(status_tiles)

	_hp = _bar(HP_COLOR, 18)
	_hp_label = _bar_label(_hp)
	_column.add_child(_hp)
	_res = _bar(RESOURCE_COLORS.mana, 14)
	_res_label = _bar_label(_res)
	_column.add_child(_res)

	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(GAP))
	_column.add_child(row)
	for i in SLOTS:
		_slots.append(_make_slot(row))
	xp_bar = XpBar.new()
	_column.add_child(xp_bar)

	_death = PanelContainer.new()
	_death.mouse_filter = MOUSE_FILTER_IGNORE
	_death.set_anchors_preset(PRESET_CENTER)
	_death.grow_horizontal = GROW_DIRECTION_BOTH
	_death.grow_vertical = GROW_DIRECTION_BOTH
	_death.offset_top = -170
	_death.offset_bottom = -110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.02, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_death.add_theme_stylebox_override("panel", style)
	_death_label = Label.new()
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 26)
	_death_label.add_theme_color_override("font_color", Color("#ff6b5e"))
	_death.add_child(_death_label)
	_death.visible = false
	add_child(_death)

	_boss = VBoxContainer.new()
	_boss.mouse_filter = MOUSE_FILTER_IGNORE
	_boss.add_theme_constant_override("separation", 2)
	_boss.anchor_left = 0.5
	_boss.anchor_right = 0.5
	_boss.offset_left = -BOSS_WIDTH / 2.0
	_boss.offset_right = BOSS_WIDTH / 2.0
	_boss.offset_top = BOSS_TOP
	_boss_label = Label.new()
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 22)
	_boss_label.add_theme_color_override("font_color", Color("#ffd27a"))
	_boss_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_boss_label.add_theme_constant_override("outline_size", 6)
	_boss.add_child(_boss_label)
	_boss_hp = _bar(BOSS_COLOR, 20)
	_boss.add_child(_boss_hp)
	_boss.visible = false
	add_child(_boss)


func bind(client: ClientSession, bar: Array, abilities: AbilityDB) -> void:
	InputSetup.ensure_actions() # the slots show the icons of the keys bound to their actions
	if _client != null and _client.combat_event.is_connected(_on_combat_event):
		_client.combat_event.disconnect(_on_combat_event)
	_client = client
	_abilities = abilities
	_client.combat_event.connect(_on_combat_event)
	_slot_ids = [abilities.kind_of(client.class_id, "basic"), abilities.kind_of(client.class_id, "secondary")]
	for i in AbilityDB.BAR_SIZE:
		_slot_ids.append(str(bar[i]) if i < bar.size() else "")
	_slot_ids.append("dodge")
	var keys := [tr("HUD_KEY_LMB"), tr("HUD_KEY_RMB")]
	for i in AbilityDB.BAR_SIZE:
		keys.append(str(i + 1))
	keys.append(tr("HUD_KEY_SPACE"))
	# The mouse buttons and the dodge show the icon of what they are bound to; the bar slots, their number.
	var actions := {0: "attack_basic", 1: "attack_secondary", DODGE_SLOT: "dodge"}
	for i in SLOTS:
		var s: Dictionary = _slots[i]
		var id := _slot_ids[i]
		var icon := "dodge" if id == "dodge" else str(abilities.get_ability(id).get("icon", "")) if abilities.has(id) else ""
		(s.icon as TextureRect).texture = load(ICON_DIR % icon) if icon != "" and ResourceLoader.exists(ICON_DIR % icon) else null
		(s.key as Label).text = keys[i]
		(s.key as Label).visible = not actions.has(i)
		(s.key_icon as KeyIcon).visible = actions.has(i)
		if actions.has(i):
			(s.key_icon as KeyIcon).show_action(actions[i])
	_combo_row.visible = false
	_res.add_theme_stylebox_override("fill", _fill(RESOURCE_COLORS.get(_resource_kind(client.class_id), RESOURCE_COLORS.mana)))


## Forgets the client (leaving the game); the HUD keeps its last picture until shown again.
func unbind() -> void:
	if _client != null and _client.combat_event.is_connected(_on_combat_event):
		_client.combat_event.disconnect(_on_combat_event)
	_client = null
	_cd_end.clear()
	_gcd_end = 0.0
	_respawn_at = -1.0


func _process(delta: float) -> void:
	if _client != null:
		advance(delta)


## Moves the HUD clock and redraws from the client's latest state.
func advance(dt: float) -> void:
	_clock += dt
	if _client == null:
		return
	_update_boss()
	_update_cast()
	_update_statuses()
	xp_bar.set_progress(_client.progress.level, _client.progress.xp, Xp.to_next(_client.progress.level, _client.balance))
	var me: Dictionary = _client.combat.get(_client.my_id, {})
	if me.is_empty():
		return
	_hp.max_value = maxf(1.0, float(me.max_hp))
	_hp.value = float(me.hp)
	_hp_label.text = "%d / %d" % [ceili(float(me.hp)), roundi(float(me.max_hp))]
	_res.visible = float(me.max_resource) > 0.0
	_res.max_value = maxf(1.0, float(me.max_resource))
	_res.value = float(me.resource)
	_res_label.text = "%d / %d" % [floori(float(me.resource)), roundi(float(me.max_resource))]
	_combo_row.visible = _client.class_id == "assassin"
	for i in _pips.size():
		_pips[i].color = Color("#ff5f6d") if i < int(me.combo) else Color(0.2, 0.2, 0.25, 0.85)
	_charge.visible = float(me.charge) > 0.0
	_charge.value = float(me.charge) * 100.0
	for i in SLOTS:
		var s: Dictionary = _slots[i]
		var ratio := slot_cooldown(i)
		var sweep: ColorRect = s.sweep
		sweep.visible = ratio > 0.0
		sweep.anchor_top = 1.0 - ratio
		sweep.offset_top = 0.0
		(s.icon as TextureRect).modulate = DIM if slot_dimmed(i) else Color.WHITE
	var dead := int(me.life) == CombatEntity.DEAD
	if dead and _respawn_at < 0.0:
		_respawn_at = _clock + _client.balance.respawn_s
	elif not dead:
		_respawn_at = -1.0
	_death.visible = dead
	if dead:
		_death_label.text = tr("HUD_FALLEN") % maxi(0, ceili(_respawn_at - _clock))


func _on_combat_event(ev: Array) -> void:
	if ev.size() < 2 or int(ev[1]) != _client.my_id:
		return
	match str(ev[0]):
		"cast":
			var id := str(ev[2]) if ev.size() > 2 else ""
			if not _abilities.has(id):
				return
			var ab := _abilities.get_ability(id)
			# The host sends the cooldown it applied (Sigilo is longer in combat).
			var cd := float(ev[4]) if ev.size() > 4 else float(ab.get("cooldown_s", 0.0))
			_cd_end[id] = _clock + cd
			_cd_total[id] = cd
			if bool(ab.get("gcd", false)):
				_gcd_end = _clock + _client.balance.gcd_s
		"status":
			_statuses[str(ev[2])] = int(ev[3])
		"channel":
			var cid := str(ev[2]) if ev.size() > 2 else ""
			_cast_start = _clock
			_cast_total = maxf(float(ev[3]) if ev.size() > 3 else 0.0, 0.01)
			_cast_label.text = tr(str(_abilities.get_ability(cid).get("name", cid))) if _abilities.has(cid) else ""
			var col := CombatFX.ELEMENT_COLORS.get(CombatFX.element_of(_abilities.get_ability(cid).get("effects", [])), Color("#c07bff")) as Color
			_cast.add_theme_stylebox_override("fill", _fill(col))
			_cast.visible = true
			_update_cast()
		"channel_end":
			_cast.visible = false
		"died":
			_cast.visible = false
			_statuses.clear()
			_respawn_at = _clock + _client.balance.respawn_s
		"respawned":
			_respawn_at = -1.0
			_cd_end.clear()
			_gcd_end = 0.0


## Keeps the tiles of the effects that are still on the player: an effect goes when its time
## is up or when the host's snapshot no longer lists it.
func _update_statuses() -> void:
	var now := _client.latest_tick()
	var rate := float(_client.balance.tick_rate)
	var me: Dictionary = _client.combat.get(_client.my_id, {})
	var bits := int(me.get("status_bits", 0))
	var shown := {}
	for kind: String in _statuses.keys():
		var left := 99.0 if now < 0 else (float(int(_statuses[kind]) - now) / rate)
		var gone := now >= 0 and left <= 0.0
		if not gone and not me.is_empty() and kind in StatusEffect.BIT_KINDS and not StatusEffect.has_bit(bits, kind):
			gone = true
		if gone:
			_statuses.erase(kind)
		else:
			shown[kind] = left
	status_tiles.show_statuses(shown, _clock)


## Fills the cast bar as the time passes; it hides itself when the time is up.
func _update_cast() -> void:
	if not _cast.visible:
		return
	var k := (_clock - _cast_start) / _cast_total
	if k >= 1.0:
		_cast.visible = false
		return
	_cast.max_value = 1.0
	_cast.value = k


# --- Readable state (tests and tooltips) ---

func cast_visible() -> bool:
	return _cast.visible


func cast_text() -> String:
	return _cast_label.text


func cast_fraction() -> float:
	return _cast.value / _cast.max_value


func slot_count() -> int:
	return SLOTS


func slot_ability(i: int) -> String:
	return _slot_ids[i]


func slot_key(i: int) -> String:
	return (_slots[i].key as Label).text


## The icon kind a slot shows instead of text ("" = just its number).
func slot_key_icon(i: int) -> String:
	return (_slots[i].key_icon as KeyIcon).kind if (_slots[i].key_icon as KeyIcon).visible else ""


## 0 when ready, 1 just after casting.
func slot_cooldown(i: int) -> float:
	var id := _slot_ids[i] if i < _slot_ids.size() else ""
	if id == "dodge":
		return _client.dodge_cooldown_ratio() if _client != null else 0.0
	if id == "" or _abilities == null or not _abilities.has(id):
		return 0.0
	var ratio := 0.0
	if _cd_end.has(id) and float(_cd_total[id]) > 0.0:
		ratio = clampf((float(_cd_end[id]) - _clock) / float(_cd_total[id]), 0.0, 1.0)
	if bool(_abilities.get_ability(id).get("gcd", false)) and _client != null and _client.balance.gcd_s > 0.0:
		ratio = maxf(ratio, clampf((_gcd_end - _clock) / _client.balance.gcd_s, 0.0, 1.0))
	return ratio


func slot_dimmed(i: int) -> bool:
	var id := _slot_ids[i] if i < _slot_ids.size() else ""
	if id == "" or id == "dodge" or _abilities == null or not _abilities.has(id) or _client == null:
		return false
	_update_boss()
	var me: Dictionary = _client.combat.get(_client.my_id, {})
	return not me.is_empty() and float(_abilities.get_ability(id).get("cost", 0.0)) > float(me.resource)


func hp_text() -> String:
	return _hp_label.text


func hp_fraction() -> float:
	return _hp.value / _hp.max_value


func resource_text() -> String:
	return _res_label.text


func combo_visible() -> bool:
	return _combo_row.visible


func combo_lit() -> int:
	return _pips.filter(func(p: ColorRect) -> bool: return p.color == Color("#ff5f6d")).size()


func charge_visible() -> bool:
	return _charge.visible


func charge_fraction() -> float:
	return _charge.value / 100.0


func death_visible() -> bool:
	return _death.visible


func death_text() -> String:
	return _death_label.text


func bar_rect() -> Rect2:
	return _column.get_global_rect()


func death_rect() -> Rect2:
	return _death.get_global_rect()


## The first boss in sight that is fighting someone (it has a target).
func _update_boss() -> void:
	var found: Dictionary = {}
	var ids := _client.monsters.keys()
	ids.sort()
	for id: int in ids:
		var info: Dictionary = _client.monsters[id]
		var def := MonsterDB.load_default().get_type(str(info.get("type", "")))
		if bool(def.get("boss", false)) and int(info.get("target", 0)) != 0 and float(info.get("hp", 0.0)) > 0.0:
			found = info.duplicate()
			found["name"] = tr(str(def.get("name", "")))
			break
	_boss.visible = not found.is_empty()
	if found.is_empty():
		return
	var max_hp := maxf(1.0, float(found.max_hp))
	_boss_hp.max_value = max_hp
	_boss_hp.value = float(found.hp)
	var phase := MonsterAI.phase_for(float(found.hp) / max_hp)
	_boss_label.text = "%s — %s" % [found.name, tr("HUD_BOSS_PHASE") % phase]


func boss_bar_visible() -> bool:
	return _boss.visible


func boss_bar_text() -> String:
	return _boss_label.text


func boss_fraction() -> float:
	return _boss_hp.value / maxf(1.0, _boss_hp.max_value)


func boss_bar_rect() -> Rect2:
	return _boss.get_global_rect()


# --- Building blocks ---

func _resource_kind(class_id: String) -> String:
	var res: Variant = CharacterCatalog.load_default().class_def(class_id).get("resource", {})
	return str((res as Dictionary).get("kind", "mana")) if res is Dictionary else "mana"


func _fill(color: Color) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	return fill


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.08, 0.85)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(0, 0, 0, 0.9)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", _fill(color))
	return bar


func _bar_label(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(bar.custom_minimum_size.y) - 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	bar.add_child(label)
	return label


func _make_slot(row: HBoxContainer) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT, SLOT)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var sweep := ColorRect.new()
	sweep.color = Color(0, 0, 0, 0.62)
	sweep.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sweep.mouse_filter = MOUSE_FILTER_IGNORE
	sweep.visible = false
	panel.add_child(sweep)
	var key := Label.new()
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_outline_color", Color.BLACK)
	key.add_theme_constant_override("outline_size", 4)
	key.position = Vector2(4, 1)
	key.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(key)
	var key_icon := KeyIcon.new()
	key_icon.position = Vector2(3, 2)
	key_icon.visible = false
	panel.add_child(key_icon)
	return {"panel": panel, "icon": icon, "key": key, "key_icon": key_icon, "sweep": sweep}
