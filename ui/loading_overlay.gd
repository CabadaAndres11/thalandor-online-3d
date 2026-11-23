class_name LoadingOverlay
extends Control
## The loading screen (Plan 8.1): the zone's name in gold over a dark screen. Since Plan
## 8.1.1 it waits for every reason it was shown for (the zone built, the first snapshot of
## the new zone), stays at least MIN_SHOW_S so it never just flickers, then fades out.

const MIN_SHOW_S := 0.6
const FADE_S := 0.2

var title: Label
var _waiting: Array = []
var _shown_s := 0.0
var _fade := -1.0 # seconds into the fade, -1 while not fading


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 0.96)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	title = StoneTheme.title("", 56)
	title.set_anchors_preset(PRESET_CENTER)
	title.grow_horizontal = GROW_DIRECTION_BOTH
	title.grow_vertical = GROW_DIRECTION_BOTH
	add_child(title)


## Shows the zone's name until every reason in `waits` is done (done()).
func show_zone(name_key: String, waits: Array = ["ready"]) -> void:
	title.text = tr(name_key)
	if not visible or _fade >= 0.0:
		_shown_s = 0.0
	for w: Variant in waits:
		if not w in _waiting:
			_waiting.append(w)
	_fade = -1.0
	modulate.a = 1.0
	visible = true


func done(reason: String) -> void:
	_waiting.erase(reason)


## Everything is ready: it goes once its minimum time is over.
func hide_overlay() -> void:
	_waiting.clear()


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
