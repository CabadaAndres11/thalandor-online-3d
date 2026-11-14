class_name DebugOverlay
extends Label
## F3 overlay: FPS, ping, tick, pending inputs and last correction.

var client: ClientSession


func _init() -> void:
	visible = false
	position = Vector2(12, 8)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_font_size_override("font_size", 16)
	mouse_filter = MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	if client == null:
		text = "FPS %d" % Engine.get_frames_per_second()
		return
	text = tr("DEBUG_LINE") % [
		Engine.get_frames_per_second(), roundi(client.ping_ms()), client.latest_tick(),
		client.pending_count(), client.last_correction,
	]
