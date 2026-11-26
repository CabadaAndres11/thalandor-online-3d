class_name CutsceneOverlay
extends Control
## What a cutscene puts on screen (Plan 8.2): black bars above and below, the subtitle with
## who speaks, a fade to and from black, and "hold Esc to skip" with its progress.

signal skip_requested()

const BAR_SHARE := 0.12
const HOLD_S := 0.5

var skippable: bool = true
var _top: ColorRect
var _bottom: ColorRect
var _black: ColorRect
var _speaker: Label
var _text: Label
var _skip_hint: Label
var _skip_bar: ProgressBar
var _hold: float = 0.0
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _fade_t: float = 0.0
var _fade_s: float = 0.0


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_black = _rect(Color(0, 0, 0, 0))
	_top = _rect(Color.BLACK)
	_bottom = _rect(Color.BLACK)
	var sub := VBoxContainer.new()
	sub.name = "Subtitle"
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	sub.add_theme_constant_override("separation", 2)
	_bottom.add_child(sub)
	sub.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_speaker = Label.new()
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_color_override("font_color", StoneTheme.GOLD)
	_speaker.add_theme_font_size_override("font_size", 20)
	sub.add_child(_speaker)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", StoneTheme.TEXT)
	sub.add_child(_text)
	_skip_hint = Label.new()
	_skip_hint.text = tr("UI_SCENE_SKIP")
	_skip_hint.add_theme_font_size_override("font_size", 14)
	_skip_hint.add_theme_color_override("font_color", StoneTheme.TEXT_DIM)
	_top.add_child(_skip_hint)
	_skip_bar = ProgressBar.new()
	_skip_bar.show_percentage = false
	_skip_bar.max_value = 1.0
	_skip_bar.custom_minimum_size = Vector2(120, 6)
	_top.add_child(_skip_bar)


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var h := size.y * BAR_SHARE
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, h)
	_bottom.position = Vector2(0, size.y - h)
	_bottom.size = Vector2(size.x, h)
	_black.position = Vector2.ZERO
	_black.size = size
	_skip_hint.position = Vector2(size.x - 220, 8)
	_skip_bar.position = Vector2(size.x - 220, 32)


func open(can_skip: bool) -> void:
	skippable = can_skip
	_skip_hint.visible = can_skip
	_skip_bar.visible = can_skip
	_hold = 0.0
	_skip_bar.value = 0.0
	show_line("", "")
	visible = true
	_layout()


func close() -> void:
	visible = false
	_black.color.a = 0.0
	_fade_s = 0.0


func show_line(speaker_name: String, text: String) -> void:
	_speaker.text = speaker_name
	_text.text = text


## Fades to black (true) or back from it over `seconds`.
func set_fade(to_black: bool, seconds: float) -> void:
	_fade_from = _black.color.a
	_fade_to = 1.0 if to_black else 0.0
	_fade_t = 0.0
	_fade_s = maxf(0.0, seconds)
	if _fade_s == 0.0:
		_black.color.a = _fade_to


## The clock (the game calls it every frame): the fade and the held Esc.
func step(delta: float, esc_held: bool) -> void:
	if _fade_s > 0.0:
		_fade_t = minf(_fade_s, _fade_t + delta)
		_black.color.a = lerpf(_fade_from, _fade_to, _fade_t / _fade_s)
	if not skippable:
		return
	_hold = _hold + delta if esc_held else 0.0
	_skip_bar.value = clampf(_hold / HOLD_S, 0.0, 1.0)
	if _hold >= HOLD_S:
		_hold = 0.0
		skip_requested.emit()


func _process(delta: float) -> void:
	if visible:
		step(delta, Input.is_action_pressed("menu"))


# --- Readable state (tests) ---

func bar_height() -> float:
	return _top.size.y


func subtitle() -> String:
	return ("%s: %s" % [_speaker.text, _text.text]) if _speaker.text != "" else _text.text


func black() -> float:
	return _black.color.a
