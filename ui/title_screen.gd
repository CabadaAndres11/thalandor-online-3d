class_name TitleScreen
extends Control
## Title screen: game name, version, Play (opens the character list) and Quit.

signal play_requested()
signal quit_requested()
signal options_requested()

var play_button: Button
var quit_button: Button
var options_button: Button
var logo: TextureRect
var version_label: Label


func _init() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1d2233")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	logo = TextureRect.new()
	logo.texture = load("res://assets/brand/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(480, 160)
	logo.tooltip_text = tr("GAME_TITLE")
	box.add_child(logo)

	version_label = Label.new()
	version_label.text = tr("VERSION_LABEL") % GameSession.game_version()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(version_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	box.add_child(spacer)
	play_button = Button.new()
	play_button.text = tr("BTN_PLAY")
	play_button.custom_minimum_size.y = 48
	play_button.pressed.connect(play_requested.emit)
	box.add_child(play_button)
	options_button = Button.new()
	options_button.text = tr("MENU_OPTIONS")
	options_button.pressed.connect(options_requested.emit)
	box.add_child(options_button)
	quit_button = Button.new()
	quit_button.text = tr("BTN_QUIT")
	quit_button.pressed.connect(quit_requested.emit)
	box.add_child(quit_button)
