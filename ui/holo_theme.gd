class_name HoloTheme
extends RefCounted
## The blue holographic look of the windows: translucent blue panels with a thin glowing
## border, centred titles, thin dividers and gold for what matters.

const BG := Color(0.09, 0.17, 0.33, 0.93)
const BG_DARK := Color(0.05, 0.11, 0.24, 0.9)
const BORDER := Color("#7cc4ff")
const TEXT := Color("#e6f3ff")
const TEXT_DIM := Color(0.78, 0.88, 1.0, 0.72)
const ACCENT := Color("#ffd27a") # class, recommended stats, warnings
const SECTION := Color("#8fd0ff")
const FONT_PATH := "res://assets/fonts/Teko.ttf" # Teko, SIL OFL (assets/fonts/Teko-OFL.txt)
const SHINE_SHADER := preload("res://assets/ui/holo_shine.gdshader")


## Panel of a window: dark translucent blue, thin light border and a soft glow.
static func panel_style(margin: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.set_corner_radius_all(4)
	s.set_content_margin_all(margin)
	s.border_color = BORDER
	s.set_border_width_all(2)
	s.shadow_color = Color(0.3, 0.65, 1.0, 0.35)
	s.shadow_size = 10
	return s


## A glow that drifts across a window panel, under its content (never takes the mouse).
static func add_shine(panel: Container) -> ColorRect:
	var r := ColorRect.new()
	r.name = "Shine"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHINE_SHADER
	r.material = m
	panel.add_child(r)
	panel.move_child(r, 0)
	return r


## A box inside a window (item slots, ability rows): darker, thin border.
static func box_style(selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.3, 0.5, 0.8, 0.35) if selected else BG_DARK
	s.set_corner_radius_all(3)
	s.set_content_margin_all(5)
	s.border_color = ACCENT if selected else Color(0.49, 0.77, 1.0, 0.55)
	s.set_border_width_all(1)
	return s


## Centred window title with a dark outline.
static func title(text: String, size: int = 30) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", SECTION)
	return l


## Thin light-blue line between groups.
static func divider() -> HSeparator:
	var d := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color(0.49, 0.77, 1.0, 0.5)
	line.thickness = 1
	d.add_theme_stylebox_override("separator", line)
	return d


## Colours and button looks for every control under a theme.
static func apply(theme: Theme) -> void:
	var font := font()
	if font != null:
		theme.default_font = font
	for c: String in ["Label", "Button", "CheckBox", "LineEdit"]:
		theme.set_color("font_color", c, TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_stylebox("normal", "Button", _button(Color(0.2, 0.4, 0.72, 0.45), 0.55))
	theme.set_stylebox("hover", "Button", _button(Color(0.3, 0.55, 0.9, 0.6), 0.9))
	theme.set_stylebox("pressed", "Button", _button(Color(0.4, 0.65, 1.0, 0.7), 1.0))
	theme.set_stylebox("disabled", "Button", _button(Color(0.15, 0.25, 0.45, 0.35), 0.25))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())


## The condensed holographic font (null if the file is missing).
static func font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var v := FontVariation.new()
	v.base_font = load(FONT_PATH)
	v.variation_opentype = {"wght": 500}
	return v


static func _button(bg: Color, border_alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.border_color = Color(0.49, 0.77, 1.0, border_alpha)
	s.set_border_width_all(1)
	return s
