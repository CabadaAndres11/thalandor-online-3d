class_name TitleScreen
extends Control
## Title screen (Plan 7): the logo over the black sun altar scene (MenuScene, behind the
## UI), Play in the bottom-left corner, settings, credits and quit icons in the top-right
## one and the version in the bottom-right. No background of its own: the scene shows.

signal play_requested()
signal quit_requested()
signal options_requested()
signal credits_requested()

const MARGIN := 40
const ICON_SIZE := 48
const ICONS := "res://assets/icons/ui/"

var play_button: Button
var quit_button: Button
var options_button: Button
var credits_button: Button
var logo: TextureRect
var version_label: Label


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE # the scene behind takes no input, but nothing here blocks it either

	logo = TextureRect.new()
	logo.texture = load("res://assets/brand/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.tooltip_text = tr("GAME_TITLE")
	logo.set_anchors_preset(PRESET_CENTER_TOP)
	logo.offset_left = -330
	logo.offset_right = 330
	logo.offset_top = 56
	logo.offset_bottom = 56 + 220
	add_child(logo)

	play_button = Button.new()
	play_button.name = "Play"
	play_button.text = tr("BTN_PLAY")
	StoneTheme.primary_button(play_button)
	play_button.set_anchors_preset(PRESET_BOTTOM_LEFT)
	play_button.offset_left = MARGIN
	play_button.offset_right = MARGIN + 300
	play_button.offset_top = -MARGIN - 76
	play_button.offset_bottom = -MARGIN
	play_button.pressed.connect(play_requested.emit)
	add_child(play_button)

	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 10)
	icons.set_anchors_preset(PRESET_TOP_RIGHT)
	icons.offset_left = -MARGIN - 3 * (ICON_SIZE + 12) - 20
	icons.offset_right = -MARGIN + 10
	icons.offset_top = MARGIN - 16
	icons.offset_bottom = MARGIN - 16 + ICON_SIZE + 12
	icons.alignment = BoxContainer.ALIGNMENT_END
	add_child(icons)
	options_button = _icon(icons, "Options", "ui_gear", "MENU_OPTIONS", options_requested.emit)
	credits_button = _icon(icons, "Credits", "ui_star", "MENU_CREDITS", credits_requested.emit)
	quit_button = _icon(icons, "Quit", "ui_exit", "BTN_QUIT", quit_requested.emit)

	version_label = Label.new()
	version_label.text = tr("VERSION_LABEL") % GameSession.game_version()
	version_label.modulate = Color(1, 1, 1, 0.6)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	version_label.offset_left = -MARGIN - 300
	version_label.offset_right = -MARGIN
	version_label.offset_top = -MARGIN - 34
	version_label.offset_bottom = -MARGIN
	add_child(version_label)


func _icon(parent: Control, node_name: String, icon: String, tip: String, handler: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.icon = load(ICONS + icon + ".png")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(ICON_SIZE + 12, ICON_SIZE + 12)
	b.tooltip_text = tr(tip)
	b.pressed.connect(handler)
	parent.add_child(b)
	return b
