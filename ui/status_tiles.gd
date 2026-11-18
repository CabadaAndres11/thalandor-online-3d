class_name StatusTiles
extends HBoxContainer
## Soft translucent tiles with an icon for each effect on the player: buffs and effects left
## by abilities (green edge) and harmful ones from enemies (red edge). A tile whose effect is
## about to end blinks.

const TILE := 34.0
const BLINK_S := 3.0
const DEBUFFS := ["stun", "root", "freeze", "slow", "poison", "burn", "mark", "taunted", "bleed", "vulnerable",
	"attack_slow", "weaken", "contagion"]
const ICON_DIR := "res://assets/icons/status/%s.png"

var _tiles: Dictionary = {} # kind -> {panel, icon, label, remaining}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 5)
	visible = false


static func is_debuff(kind: String) -> bool:
	return kind in DEBUFFS


## The name of the effect and, when it has one, a very short line on what it does.
func tooltip_of(kind: String) -> String:
	var name_key := "STATUS_" + kind.to_upper()
	var desc_key := name_key + "_DESC"
	var desc := tr(desc_key)
	return tr(name_key) if desc == desc_key else "%s\n%s" % [tr(name_key), desc]


func tooltip(kind: String) -> String:
	return (_tiles[kind].panel as Control).tooltip_text if _tiles.has(kind) else ""


## entries: kind -> seconds left. `clock` drives the blinking.
func show_statuses(entries: Dictionary, clock: float) -> void:
	for kind: String in _tiles.keys():
		if not entries.has(kind):
			(_tiles[kind].panel as Node).queue_free()
			_tiles.erase(kind)
	for kind: String in entries:
		if not _tiles.has(kind):
			_tiles[kind] = _make_tile(kind)
		var t: Dictionary = _tiles[kind]
		t.remaining = float(entries[kind])
		var soon := float(entries[kind]) < BLINK_S
		t.blinking = soon
		(t.panel as Control).modulate.a = (0.35 + 0.65 * absf(sin(clock * 6.0))) if soon else 0.9
	visible = not _tiles.is_empty()


func kinds() -> Array:
	return _tiles.keys()


func is_blinking(kind: String) -> bool:
	return _tiles.has(kind) and bool(_tiles[kind].blinking)


func tile_alpha(kind: String) -> float:
	return (_tiles[kind].panel as Control).modulate.a if _tiles.has(kind) else 0.0


func edge_color(kind: String) -> Color:
	return ((_tiles[kind].panel as Panel).get_theme_stylebox("panel") as StyleBoxFlat).border_color if _tiles.has(kind) else Color.BLACK


func _make_tile(kind: String) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(TILE, TILE)
	panel.mouse_filter = MOUSE_FILTER_STOP # for the tooltip
	panel.tooltip_text = tooltip_of(kind)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.1, 0.2, 0.4)
	s.set_corner_radius_all(7)
	s.border_color = Color(1.0, 0.35, 0.3, 0.85) if is_debuff(kind) else Color(0.4, 0.9, 0.55, 0.85)
	s.set_border_width_all(1)
	s.shadow_color = Color(s.border_color, 0.3) # a soft haze around the edge
	s.shadow_size = 5
	panel.add_theme_stylebox_override("panel", s)
	add_child(panel)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	var path := ICON_DIR % kind
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	panel.add_child(icon)
	var label := Label.new() # kinds without a drawing show their first letters
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.text = "" if icon.texture != null else tr("STATUS_" + kind.to_upper()).left(3)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return {"panel": panel, "icon": icon, "label": label, "remaining": 0.0, "blinking": false}
