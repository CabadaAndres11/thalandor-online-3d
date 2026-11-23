class_name LoadingOverlay
extends Control
## The loading screen (Plan 8.1, 8.1.2): a picture of the zone being entered (a real shot of
## the game, data/loading.json), its name in stone and gold, and at the bottom a tip and a
## thin golden bar that follows the build. It waits for every reason it was shown for (the
## zone built, the first snapshot of the new zone), stays at least MIN_SHOW_S so it never
## just flickers, then fades out.

const MIN_SHOW_S := 0.6
const FADE_S := 0.2
const DATA := "res://data/loading.json"
const BAND_H := 92.0

var title: Label
var picture: TextureRect
var tip: Label
var bar: ProgressBar
## The picture shown (a path from data/loading.json).
var image_path: String = ""
var _waiting: Array = []
var _shown_s := 0.0
var _fade := -1.0 # seconds into the fade, -1 while not fading
var _rng := RandomNumberGenerator.new()
var _zone_id: String = ""

static var _data: Dictionary = {}


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_rng.randomize()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	picture = TextureRect.new()
	picture.set_anchors_preset(PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(picture)
	var top := ColorRect.new() # a shade behind the title
	top.color = Color(0, 0, 0, 0.35)
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 110
	add_child(top)
	title = StoneTheme.title("", 56)
	title.set_anchors_preset(PRESET_CENTER_TOP)
	title.grow_horizontal = GROW_DIRECTION_BOTH
	title.position.y = 24
	add_child(title)
	var band := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(StoneTheme.STONE_DARK, 0.88)
	style.border_color = StoneTheme.GOLD_DIM
	style.border_width_top = 2
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	band.add_theme_stylebox_override("panel", style)
	band.set_anchors_preset(PRESET_BOTTOM_WIDE)
	band.offset_top = -BAND_H
	add_child(band)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	band.add_child(box)
	tip = Label.new()
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", StoneTheme.TEXT)
	box.add_child(tip)
	bar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = StoneTheme.GOLD
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.border_color = StoneTheme.GOLD_DIM
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_data = parsed if parsed is Dictionary else {"images": {}, "tips": []}
	return _data


## Shows the zone's name (and, given its id, one of its pictures and a tip) until every
## reason in `waits` is done (done()).
func show_zone(name_key: String, waits: Array = ["ready"], zone_id: String = "") -> void:
	title.text = tr(name_key)
	var fresh := not visible or _fade >= 0.0
	if fresh:
		_shown_s = 0.0
		bar.value = 0.0
	if fresh or zone_id != _zone_id: # another zone while still loading: its own picture
		_zone_id = zone_id
		_pick(zone_id)
	for w: Variant in waits:
		if not w in _waiting:
			_waiting.append(w)
	_fade = -1.0
	modulate.a = 1.0
	visible = true


## The load so far (0..1); the bar never goes back.
func set_progress(p: float) -> void:
	bar.value = maxf(bar.value, clampf(p, 0.0, 1.0))


func done(reason: String) -> void:
	_waiting.erase(reason)


## Everything is ready: it goes once its minimum time is over.
func hide_overlay() -> void:
	_waiting.clear()


func _pick(zone_id: String) -> void:
	var images: Dictionary = data().get("images", {})
	var list: Array = images.get(zone_id, [])
	if list.is_empty():
		list = images.get("default", [])
	image_path = str(list[_rng.randi_range(0, list.size() - 1)]) if not list.is_empty() else ""
	picture.texture = load(image_path) as Texture2D if image_path != "" and ResourceLoader.exists(image_path) else null
	var tips: Array = data().get("tips", [])
	tip.text = tr(str(tips[_rng.randi_range(0, tips.size() - 1)])) if not tips.is_empty() else ""


func _process(delta: float) -> void:
	if not visible:
		return
	_shown_s += delta
	if _fade < 0.0:
		if not (_waiting.is_empty() and _shown_s >= MIN_SHOW_S):
			return
		_fade = 0.0
		delta = minf(delta, _shown_s - MIN_SHOW_S) # only the time past the minimum fades
	_fade += delta
	modulate.a = clampf(1.0 - _fade / FADE_S, 0.0, 1.0)
	if _fade >= FADE_S:
		visible = false
		_fade = -1.0
		modulate.a = 1.0
