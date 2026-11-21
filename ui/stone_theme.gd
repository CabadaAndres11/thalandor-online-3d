class_name StoneTheme
extends RefCounted
## The look of the menus (title, character select and create, Plan 7), in the colours of
## the logo: dark stone panels, gold borders and titles, blood red for what is pressed or
## chosen. The in-game windows keep HoloTheme.

const STONE := Color("#2a2522")
const STONE_DARK := Color("#17130f")
const GOLD := Color("#e3b45a")
const GOLD_DIM := Color("#9c7a3c")
const BLOOD := Color("#8e1b1b")
const TEXT := Color("#f1e4c8")
const TEXT_DIM := Color(0.95, 0.89, 0.78, 0.6)
const PILL := "res://assets/icons/ui/play_%s.png"
const PLAY_ICON := "res://assets/icons/ui/ui_play.png"


## A stone panel with a gold border and a carved inner edge.
static func panel(margin: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = STONE # opaque: it must read over the moving scene
	s.set_corner_radius_all(2)
	s.set_content_margin_all(margin)
	s.border_color = GOLD_DIM
	s.set_border_width_all(2)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 12
	return s


## Centred gold title with a dark outline.
static func title(text: String, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", STONE_DARK)
	l.add_theme_constant_override("outline_size", 8)
	return l


## Colours, buttons, panels and fields for every control under a theme.
static func apply(theme: Theme) -> void:
	var font := HoloTheme.font()
	if font != null:
		theme.default_font = font
	for c: String in ["Label", "Button", "CheckBox", "LineEdit"]:
		theme.set_color("font_color", c, TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_stylebox("normal", "Button", _button(STONE, GOLD_DIM))
	theme.set_stylebox("hover", "Button", _button(STONE.lightened(0.12), GOLD))
	theme.set_stylebox("pressed", "Button", _button(BLOOD, GOLD))
	theme.set_stylebox("disabled", "Button", _button(STONE_DARK, GOLD_DIM.darkened(0.5)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", panel())
	var field := _button(STONE_DARK, GOLD_DIM)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _button(STONE_DARK, GOLD))


## The call to action (Play): a rounded ember pill, blood red to orange with a gold rim,
## a white play triangle and white text (tools/art/make_icons.mjs draws the textures).
static func primary_button(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, _pill(state))
	b.add_theme_stylebox_override("disabled", _pill("pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# The triangle right before the word, the pair centred (a Button would put its icon at
	# the edge or under the text), drawn by children that let the clicks through.
	var group := HBoxContainer.new()
	group.name = "PlayGroup"
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 12)
	group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(group)
	var icon := TextureRect.new()
	icon.name = "PlayIcon"
	icon.texture = load(PLAY_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon)
	var label := Label.new()
	label.name = "PlayText"
	label.text = b.text
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.02))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(label)
	b.text = ""
	b.tooltip_text = label.text


static func _pill(state: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(PILL % state)
	s.texture_margin_left = 40 # half the height: the round ends never stretch
	s.texture_margin_right = 40
	s.texture_margin_top = 20
	s.texture_margin_bottom = 20
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	return s


## A carved button: a flat face, a gold border, a lighter top edge and a darker bottom one.
static func _button(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.border_color = border
	s.set_border_width_all(width)
	s.border_width_bottom = width + 2 # the carved bevel
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 3
	return s
