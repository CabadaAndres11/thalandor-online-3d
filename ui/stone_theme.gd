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


## The big gold call to action (Play).
static func primary_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _button(BLOOD.darkened(0.35), GOLD, 3))
	b.add_theme_stylebox_override("hover", _button(BLOOD, GOLD.lightened(0.2), 3))
	b.add_theme_stylebox_override("pressed", _button(BLOOD.lightened(0.15), Color.WHITE, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", STONE_DARK)
	b.add_theme_constant_override("outline_size", 6)


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
