class_name IconBar
extends HBoxContainer
## The game's windows as icons in the top-right corner (Plan 8.1.1): character, bag,
## abilities, talents, quests (from Plan 8.2), map and menu, each with its key. A button
## glows when hovered and stays lit while its window is open.

signal pressed_entry(id: String)

const ENTRIES := ["character", "inventory", "abilities", "talents", "quests", "map", "menu"]
const ACTIONS := {
	"character": "window_character", "inventory": "window_inventory", "abilities": "abilities_window",
	"talents": "window_talents", "quests": "window_quests", "map": "window_map", "menu": "menu",
}
const NAMES := {
	"character": "ICON_CHARACTER", "inventory": "ICON_INVENTORY", "abilities": "ICON_ABILITIES",
	"talents": "ICON_TALENTS", "quests": "ICON_QUESTS", "map": "ICON_MAP", "menu": "ICON_MENU",
}
const BUTTON := 46.0
const LIT := Color(1.0, 0.82, 0.4)

var _buttons: Dictionary = {}
var _open: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = MOUSE_FILTER_IGNORE
	for id: String in ENTRIES:
		var b := Button.new()
		b.name = id
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr("QUESTS_SOON") if id == "quests" else "%s (%s)" % [tr(NAMES[id]), key_text(id)]
		b.disabled = id == "quests" # the quest log arrives with the missions (Plan 8.2)
		b.add_theme_stylebox_override("normal", _style(false, false))
		b.add_theme_stylebox_override("hover", _style(true, false))
		b.add_theme_stylebox_override("pressed", _style(true, true))
		b.add_theme_stylebox_override("disabled", _style(false, false))
		b.pressed.connect(func() -> void: pressed_entry.emit(id))
		b.draw.connect(_draw_icon.bind(b, id))
		add_child(b)
		_buttons[id] = b


func button(id: String) -> Button:
	return _buttons.get(id)


## The key of an entry ("C", "Esc"…), from the current key bindings.
func key_text(id: String) -> String:
	var d := KeyIcon.describe(str(ACTIONS.get(id, "")))
	return "Esc" if str(d.text) == "Escape" else str(d.text)


func set_open(id: String, open: bool) -> void:
	if bool(_open.get(id, false)) == open or not _buttons.has(id):
		return
	_open[id] = open
	var b: Button = _buttons[id]
	b.add_theme_stylebox_override("normal", _style(false, open))
	b.queue_redraw()


func is_open(id: String) -> bool:
	return bool(_open.get(id, false))


static func _style(hover: bool, lit: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = HoloTheme.BG_DARK.lightened(0.12 if hover else 0.0)
	s.border_color = LIT if lit else (HoloTheme.BORDER if hover else HoloTheme.BORDER.darkened(0.35))
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(LIT if lit else HoloTheme.BORDER, 0.45 if (hover or lit) else 0.0)
	s.shadow_size = 6 if (hover or lit) else 0
	return s


## A small vector icon per entry and its key in the corner.
func _draw_icon(b: Button, id: String) -> void:
	var c := Vector2(BUTTON, BUTTON) / 2.0 - Vector2(0, 2)
	var col := HoloTheme.TEXT if not b.disabled else HoloTheme.TEXT_DIM.darkened(0.3)
	if is_open(id):
		col = LIT
	match id:
		"character": # head and shoulders
			b.draw_circle(c + Vector2(0, -6), 6, col)
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 12), c + Vector2(-8, 2), c + Vector2(8, 2), c + Vector2(11, 12)]), col)
		"inventory": # a bag
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -2), c + Vector2(10, -2), c + Vector2(12, 12), c + Vector2(-12, 12)]), col)
			b.draw_arc(c + Vector2(0, -4), 5, PI, TAU, 10, col, 2.5)
		"abilities": # a spark
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -13), c + Vector2(-7, 2), c + Vector2(0, 2), c + Vector2(-3, 13), c + Vector2(8, -3), c + Vector2(1, -3)]), col)
		"talents": # a star
			var pts := PackedVector2Array()
			for i in 10:
				var r := 12.0 if i % 2 == 0 else 5.0
				pts.append(c + Vector2(0, -r).rotated(i * TAU / 10.0))
			b.draw_colored_polygon(pts, col)
		"quests": # a scroll
			b.draw_rect(Rect2(c + Vector2(-9, -11), Vector2(18, 22)), col, false, 2.5)
			for y: float in [-5.0, 0.0, 5.0]:
				b.draw_line(c + Vector2(-5, y), c + Vector2(5, y), col, 2.0)
		"map": # a folded map
			b.draw_polyline(PackedVector2Array([c + Vector2(-12, -9), c + Vector2(-4, -12), c + Vector2(4, -9), c + Vector2(12, -12),
				c + Vector2(12, 9), c + Vector2(4, 12), c + Vector2(-4, 9), c + Vector2(-12, 12), c + Vector2(-12, -9)]), col, 2.5)
			b.draw_line(c + Vector2(-4, -12), c + Vector2(-4, 9), col, 2.0)
			b.draw_line(c + Vector2(4, -9), c + Vector2(4, 12), col, 2.0)
		"menu": # three bars
			for y: float in [-7.0, 0.0, 7.0]:
				b.draw_rect(Rect2(c + Vector2(-11, y - 1.5), Vector2(22, 3)), col)
	b.draw_string(HoloTheme.font(), Vector2(BUTTON - 4, BUTTON - 3) - Vector2(HoloTheme.font().get_string_size(key_text(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 0),
		key_text(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HoloTheme.ACCENT)
