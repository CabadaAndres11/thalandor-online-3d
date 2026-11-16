class_name TalentsWindow
extends Control
## Talent window (T): the circular tree (drawn, no scrolling), a panel with the selected
## node and a Buy button, and the masteries of the directions whose nodes are all bought.
## It only reports `talent_bought` and `mastery_bought`; the host validates.

signal talent_bought(id: String)
signal mastery_bought(dir: String)

const CANVAS := 520.0
const NODE_RADIUS := {"start": 11.0, "minor": 7.0, "notable": 10.0, "keystone": 12.0}
const STATE_COLORS := {
	"owned": Color("#e8c66a"), "available": Color("#6fd08c"), "locked": Color("#4a4a55"), "ring_locked": Color("#2c2c36"),
}
const DIR_KEYS := {"might": "TALENT_DIR_MIGHT", "celerity": "TALENT_DIR_CELERITY", "vitality": "TALENT_DIR_VITALITY",
	"bastion": "TALENT_DIR_BASTION", "arcane": "TALENT_DIR_ARCANE"}

var buy_button: Button

var _panel: PanelContainer
var _canvas: TalentCanvas
var _points_label: Label
var _title: Label
var _kind: Label
var _desc: Label
var _mastery_box: VBoxContainer
var _mastery_rows: Dictionary = {} # dir -> {"rank": Label, "button": Button}
var _progress: PlayerProgress
var _db: TalentDB
var _balance: Balance
var _selected: String = ""


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	style.border_color = Color("#8a6d2f")
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = tr("TALENTS_TITLE")
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_color_override("font_color", Color("#ffd27a"))
	header.add_child(_points_label)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	box.add_child(body)
	_canvas = TalentCanvas.new()
	_canvas.window = self
	_canvas.custom_minimum_size = Vector2(CANVAS, CANVAS)
	body.add_child(_canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 0)
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_title)
	_kind = Label.new()
	_kind.modulate = Color(1, 1, 1, 0.7)
	_kind.add_theme_font_size_override("font_size", 14)
	side.add_child(_kind)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(320, 110)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	side.add_child(_desc)
	buy_button = Button.new()
	buy_button.text = tr("TALENT_BUY")
	buy_button.custom_minimum_size = Vector2(160, 36)
	buy_button.pressed.connect(press_buy)
	side.add_child(buy_button)

	_mastery_box = VBoxContainer.new()
	_mastery_box.add_theme_constant_override("separation", 3)
	side.add_child(_mastery_box)
	var mt := Label.new()
	mt.text = tr("MASTERIES_TITLE")
	mt.modulate = Color("#e8c66a")
	_mastery_box.add_child(mt)
	var mh := Label.new()
	mh.text = tr("MASTERIES_HINT")
	mh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mh.custom_minimum_size.x = 320
	mh.add_theme_font_size_override("font_size", 13)
	mh.modulate = Color(1, 1, 1, 0.7)
	_mastery_box.add_child(mh)
	for dir: String in DIR_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_mastery_box.add_child(row)
		var name_label := Label.new()
		name_label.text = tr(DIR_KEYS[dir])
		name_label.custom_minimum_size.x = 120
		row.add_child(name_label)
		var rank := Label.new()
		rank.custom_minimum_size.x = 90
		row.add_child(rank)
		var b := Button.new()
		b.text = tr("MASTERY_BUY")
		b.custom_minimum_size = Vector2(48, 0)
		b.pressed.connect(press_mastery.bind(dir))
		row.add_child(b)
		_mastery_rows[dir] = {"rank": rank, "button": b}

	var hint := Label.new()
	hint.text = tr("TALENTS_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)


## Fills the window with this progress and opens it (keeps the selected node).
func show_for(progress: PlayerProgress, db: TalentDB, balance: Balance) -> void:
	_progress = progress
	_db = db
	_balance = balance
	if _selected == "" or not db.has(_selected):
		_selected = ""
	refresh()
	visible = true


## Redraws after the progress changed (a purchase answered by the host).
func refresh() -> void:
	if _progress == null:
		return
	var free := Talents.points(_progress.level) - Talents.spent(_progress)
	_points_label.text = tr("TALENTS_POINTS") % free
	for dir: String in _mastery_rows:
		var rank := int(_progress.masteries.get(dir, 0))
		(_mastery_rows[dir].rank as Label).text = tr("MASTERY_RANK") % rank
		(_mastery_rows[dir].button as Button).disabled = not Talents.can_buy_mastery(_progress, dir, _db)
	_mastery_box.visible = masteries_visible()
	_show_selected()
	_canvas.queue_redraw()


func select(id: String) -> void:
	if _db == null or not _db.has(id):
		return
	_selected = id
	_show_selected()
	_canvas.queue_redraw()


func selected() -> String:
	return _selected


## "owned", "available" (touches the start or a bought node), "ring_locked" (outer ring
## without an upgrade) or "locked".
func node_state(id: String) -> String:
	if _progress.talents.has(id):
		return "owned"
	var node := _db.node(id)
	if int(node.get("ring", 1)) == 2 and _progress.upgrade == "":
		return "ring_locked"
	for other: String in node.get("links", []):
		if other == _db.start_id() or _progress.talents.has(other):
			return "available"
	return "locked"


func description_text() -> String:
	return _desc.text


func points_text() -> String:
	return _points_label.text


func buy_enabled() -> bool:
	return not buy_button.disabled


func press_buy() -> void:
	if _selected != "" and Talents.can_buy(_progress, _selected, _db):
		talent_bought.emit(_selected)


## The masteries show once some direction is complete (or already has ranks).
func masteries_visible() -> bool:
	if _progress == null:
		return false
	for dir: String in _mastery_rows:
		if int(_progress.masteries.get(dir, 0)) > 0 or Talents.direction_complete(_progress, dir, _db):
			return true
	return false


func mastery_enabled(dir: String) -> bool:
	return _mastery_rows.has(dir) and not (_mastery_rows[dir].button as Button).disabled


func press_mastery(dir: String) -> void:
	if Talents.can_buy_mastery(_progress, dir, _db):
		mastery_bought.emit(dir)


func panel_rect() -> Rect2:
	return _panel.get_global_rect()


## Where a node is drawn, in the window's global coordinates.
func node_screen_position(id: String) -> Vector2:
	return _canvas.get_global_rect().position + _canvas.node_position(id)


## A click at a global point on the canvas (what a mouse click does).
func click_at(global_point: Vector2) -> void:
	_canvas.pick(global_point - _canvas.get_global_rect().position)


func _show_selected() -> void:
	if _selected == "" or _db == null:
		_title.text = tr("TALENT_NONE")
		_kind.text = ""
		_desc.text = ""
		buy_button.disabled = true
		return
	var node := _db.node(_selected)
	_title.text = node_title(node)
	var kind := "TALENT_KIND_" + str(node.get("kind", "minor")).to_upper()
	_kind.text = tr(kind) + (" · " + tr("TALENT_RING_OUTER") if int(node.get("ring", 1)) == 2 else "")
	var state := node_state(_selected)
	_desc.text = StatText.describe_all(node.get("mods", [])) + "\n\n" + tr("TALENT_STATE_" + state.to_upper())
	buy_button.disabled = not Talents.can_buy(_progress, _selected, _db)


## "Poderío", or "Poderío / Celeridad" for the hybrid spokes.
static func node_title(node: Dictionary) -> String:
	var dir := str(node.get("dir", ""))
	if dir == "":
		return TranslationServer.translate("TALENT_KIND_START")
	var parts: Array = []
	for part: String in dir.split("_"):
		parts.append(TranslationServer.translate(DIR_KEYS.get(part, "")))
	return " / ".join(parts)


## The drawn circle: links, nodes by state and the selection ring. Clicks pick a node.
class TalentCanvas extends Control:
	var window: TalentsWindow


	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP


	func node_position(id: String) -> Vector2:
		var n := window._db.node(id)
		var radius := CANVAS / 2.0 - 16.0
		return Vector2(CANVAS, CANVAS) / 2.0 + Vector2(float(n.get("x", 0.0)), float(n.get("y", 0.0))) * radius


	func pick(point: Vector2) -> void:
		var best := ""
		var best_d := 16.0
		for id: String in window._db.ids():
			var d := node_position(id).distance_to(point)
			if d < best_d:
				best = id
				best_d = d
		if best != "":
			window.select(best)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pick((event as InputEventMouseButton).position)


	func _draw() -> void:
		if window == null or window._db == null or window._progress == null:
			return
		var db := window._db
		draw_arc(Vector2(CANVAS, CANVAS) / 2.0, CANVAS / 2.0 - 8.0, 0.0, TAU, 96, Color(0.25, 0.22, 0.14, 0.5), 1.0)
		for id: String in db.ids():
			var a := node_position(id)
			for other: String in db.node(id).get("links", []):
				if other > id:
					var both := window._progress.talents.has(id) or id == db.start_id()
					both = both and (window._progress.talents.has(other) or other == db.start_id())
					draw_line(a, node_position(other), Color("#b79a45") if both else Color(0.3, 0.3, 0.35, 0.8), 2.0 if both else 1.0)
		for id: String in db.ids():
			var n := db.node(id)
			var state := "owned" if id == db.start_id() else window.node_state(id)
			var r: float = NODE_RADIUS.get(str(n.get("kind", "minor")), 7.0)
			var p := node_position(id)
			draw_circle(p, r, STATE_COLORS[state])
			draw_arc(p, r, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 1.5)
			if id == window._selected:
				draw_arc(p, r + 4.0, 0.0, TAU, 24, Color.WHITE, 2.0)
