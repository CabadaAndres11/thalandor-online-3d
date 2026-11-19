class_name OptionsWindow
extends Control
## Options: Video (quality, resolution scale, fullscreen, VSync, FPS cap) and Sound
## (bus volumes and mute). Edits the given SettingsStore live and emits settings_changed
## on every change; the owner applies and saves. Esc or Close closes it.

signal settings_changed()
signal closed()

const PANEL_WIDTH := 640.0
const LABEL_WIDTH := 300.0
const VOLUME_KEYS := {"Master": "OPTIONS_VOL_MASTER", "Music": "OPTIONS_VOL_MUSIC",
	"SFX": "OPTIONS_VOL_SFX", "UI": "OPTIONS_VOL_UI"}

var close_button: Button
var reset_button: Button
var _store: SettingsStore
var _panel: PanelContainer
var _tabs: TabContainer
var _quality: OptionButton
var _scale: HSlider
var _scale_label: Label
var _fullscreen: CheckButton
var _vsync: CheckButton
var _fps: OptionButton
var _volume_sliders := {}
var _volume_labels := {}
var _mute: CheckButton
var _syncing: bool = false


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(20))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	box.add_child(HoloTheme.title(tr("OPTIONS_TITLE")))

	_tabs = TabContainer.new()
	box.add_child(_tabs)
	_tabs.add_child(_video_tab())
	_tabs.set_tab_title(0, tr("OPTIONS_TAB_VIDEO"))
	_tabs.add_child(_sound_tab())
	_tabs.set_tab_title(1, tr("OPTIONS_TAB_SOUND"))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	reset_button = Button.new()
	reset_button.text = tr("BTN_RESET")
	reset_button.pressed.connect(press_reset)
	buttons.add_child(reset_button)
	close_button = Button.new()
	close_button.text = tr("BTN_CLOSE")
	close_button.custom_minimum_size.x = 140
	close_button.pressed.connect(close)
	buttons.add_child(close_button)


func open(s: SettingsStore) -> void:
	_store = s
	_sync_from_store()
	show_tab(0)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_tab(i: int) -> void:
	_tabs.current_tab = clampi(i, 0, _tabs.get_tab_count() - 1)


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


func set_quality(q: int) -> void:
	_store.quality = GraphicsQuality.clamp_level(q)
	_sync_from_store()
	settings_changed.emit()


func set_volume(bus: String, v: float) -> void:
	if not _store.volumes.has(bus):
		return
	_store.volumes[bus] = clampf(v, 0.0, 1.0)
	_sync_from_store()
	settings_changed.emit()


func press_reset() -> void:
	_store.reset_video_audio()
	_sync_from_store()
	settings_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("menu"):
		close()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _video_tab() -> Control:
	var v := _tab_box()
	v.name = "Video"
	_quality = OptionButton.new()
	for key: String in GraphicsQuality.NAMES:
		_quality.add_item(tr(key))
	_quality.item_selected.connect(func(i: int) -> void: set_quality(i))
	v.add_child(_row("OPTIONS_QUALITY", _quality))

	var scale_box := HBoxContainer.new()
	_scale = HSlider.new()
	_scale.min_value = SettingsStore.MIN_RENDER_SCALE * 100.0
	_scale.max_value = 100.0
	_scale.step = SettingsStore.RENDER_SCALE_STEP * 100.0
	_scale.size_flags_horizontal = SIZE_EXPAND_FILL
	_scale.size_flags_vertical = SIZE_SHRINK_CENTER
	_scale.value_changed.connect(_on_scale)
	scale_box.add_child(_scale)
	_scale_label = Label.new()
	_scale_label.custom_minimum_size.x = 64
	_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scale_box.add_child(_scale_label)
	v.add_child(_row("OPTIONS_RENDER_SCALE", scale_box))

	_fullscreen = CheckButton.new()
	_fullscreen.toggled.connect(func(on: bool) -> void: _edit(func() -> void: _store.fullscreen = on))
	v.add_child(_row("OPTIONS_FULLSCREEN", _fullscreen))
	_vsync = CheckButton.new()
	_vsync.toggled.connect(func(on: bool) -> void: _edit(func() -> void: _store.vsync = on))
	v.add_child(_row("OPTIONS_VSYNC", _vsync))

	_fps = OptionButton.new()
	for fps: int in SettingsStore.FPS_CHOICES:
		_fps.add_item(tr("OPTIONS_FPS_UNLIMITED") if fps == 0 else str(fps))
	_fps.item_selected.connect(func(i: int) -> void:
		_edit(func() -> void: _store.max_fps = SettingsStore.FPS_CHOICES[i]))
	v.add_child(_row("OPTIONS_MAX_FPS", _fps))
	return v


func _sound_tab() -> Control:
	var v := _tab_box()
	v.name = "Sound"
	for bus: String in VOLUME_KEYS:
		var line := HBoxContainer.new()
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = SIZE_EXPAND_FILL
		slider.size_flags_vertical = SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(value: float) -> void:
			if not _syncing:
				set_volume(bus, value / 100.0))
		line.add_child(slider)
		var label := Label.new()
		label.custom_minimum_size.x = 64
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(label)
		_volume_sliders[bus] = slider
		_volume_labels[bus] = label
		v.add_child(_row(VOLUME_KEYS[bus], line))
	_mute = CheckButton.new()
	_mute.toggled.connect(func(on: bool) -> void: _edit(func() -> void: _store.muted = on))
	v.add_child(_row("OPTIONS_MUTE", _mute))
	return v


func _tab_box() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	return v


func _row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(label_key)
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _on_scale(value: float) -> void:
	_scale_label.text = "%d %%" % roundi(value)
	if not _syncing:
		_edit(func() -> void: _store.render_scale = SettingsStore.clamp_render_scale(value / 100.0))


## Applies a change from a control (ignored while the controls are being filled in).
func _edit(change: Callable) -> void:
	if _syncing or _store == null:
		return
	change.call()
	settings_changed.emit()


func _sync_from_store() -> void:
	if _store == null:
		return
	_syncing = true
	_quality.select(_store.quality)
	_scale.value = _store.render_scale * 100.0
	_scale_label.text = "%d %%" % roundi(_store.render_scale * 100.0)
	_fullscreen.button_pressed = _store.fullscreen
	_vsync.button_pressed = _store.vsync
	_fps.select(maxi(0, SettingsStore.FPS_CHOICES.find(_store.max_fps)))
	for bus: String in _volume_sliders:
		var v := float(_store.volumes.get(bus, 1.0))
		_volume_sliders[bus].value = v * 100.0
		_volume_labels[bus].text = "%d %%" % roundi(v * 100.0)
	_mute.button_pressed = _store.muted
	_syncing = false
