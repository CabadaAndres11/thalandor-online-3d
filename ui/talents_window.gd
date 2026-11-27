class_name TalentsWindow
extends Control
## Talent window (T, Plan 8.3g): full screen and holographic. The ring tree is drawn on a
## canvas you zoom (wheel) and drag; each node is its stat's icon in a frame that says what
## kind it is; the class's recommended route is a gold path with gold borders on its nodes;
## the node under the mouse shows its detail. A click on a node you can buy buys it, any other click selects it.
## It only reports `talent_bought` and `mastery_bought`; the host validates.

signal talent_bought(id: String)
signal mastery_bought(dir: String)

const MARGIN := 20.0
## Pixels per unit of the tree's coordinates at zoom 1 (ring 7 sits at 0.91).
const UNIT_PX := 285.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
## A press and release closer than this is a click; farther, a drag.
const CLICK_SLOP := 4.0
const ICON_DIR := "res://assets/icons/talents/"
## Sizes at zoom 1, small enough that neighbours on a ring (23 px apart) never touch.
const NODE_RADIUS := {"start": 10.0, "minor": 7.0, "notable": 8.5, "keystone": 10.0}
## What a frame adds round a node: a notable's ticks, a keystone's halo.
const NODE_EXTRA := {"start": 1.0, "minor": 1.0, "notable": 2.5, "keystone": 2.0}
const DIR_COLORS := {"might": Color("#e0564f"), "celerity": Color("#e8c547"), "vitality": Color("#4fc46a"),
	"bastion": Color("#5f8fe0"), "arcane": Color("#b46ae0")}
const DIR_KEYS := {"might": "TALENT_DIR_MIGHT", "celerity": "TALENT_DIR_CELERITY", "vitality": "TALENT_DIR_VITALITY",
	"bastion": "TALENT_DIR_BASTION", "arcane": "TALENT_DIR_ARCANE"}
const ROUTE_COLOR := Color("#ffd27a")
const OWNED_COLOR := Color("#7ff3ff")

var buy_button: Button

var _panel: PanelContainer
var _canvas: TalentCanvas
var _points_label: Label
var _reset_label: Label
var _route_check: CheckBox
var _detail: PanelContainer
var _title: Label
var _kind: Label
var _desc: Label
var _mastery_box: HBoxContainer
var _mastery_rows: Dictionary = {} # dir -> {"rank": Label, "button": Button}
var _progress: PlayerProgress
var _db: TalentDB
var _balance: Balance
var _route: Array = []
var _route_index: Dictionary = {} # id -> step (1-based)
var _selected: String = ""
var _hover: String = ""
var _icons: Dictionary = {} # icon name -> Texture2D or null
var _zoom := 1.0
var _pan := Vector2.ZERO
var _press: Variant = null # where the left button went down (Vector2) or null
var _dragging := false # the press became a drag: its release is not a click


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	HoloTheme.add_shine(_panel)
	_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: Side in [SIDE_LEFT, SIDE_TOP]:
		_panel.set_offset(side, MARGIN)
	for side: Side in [SIDE_RIGHT, SIDE_BOTTOM]:
		_panel.set_offset(side, -MARGIN)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	box.add_child(header)
	var title := Label.new()
	title.text = tr("TALENTS_TITLE")
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_color_override("font_color", HoloTheme.ACCENT)
	_points_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_points_label)
	_route_check = CheckBox.new()
	_route_check.text = tr("UI_TALENTS_ROUTE")
	_route_check.button_pressed = true
	_route_check.toggled.connect(func(_on: bool) -> void: _canvas.queue_redraw())
	header.add_child(_route_check)
	_reset_label = Label.new()
	_reset_label.modulate = Color(1, 1, 1, 0.7)
	_reset_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_reset_label)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)

	_canvas = TalentCanvas.new()
	_canvas.window = self
	_canvas.size_flags_vertical = SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	box.add_child(_canvas)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	box.add_child(footer)
	var hint := Label.new()
	hint.text = tr("TALENTS_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	footer.add_child(hint)
	_mastery_box = HBoxContainer.new()
	_mastery_box.add_theme_constant_override("separation", 10)
	footer.add_child(_mastery_box)
	var mt := Label.new()
	mt.text = tr("MASTERIES_TITLE")
	mt.modulate = HoloTheme.SECTION
	mt.tooltip_text = tr("MASTERIES_HINT")
	mt.mouse_filter = MOUSE_FILTER_PASS
	_mastery_box.add_child(mt)
	for dir: String in DIR_KEYS:
		var rank := Label.new()
		rank.add_theme_color_override("font_color", DIR_COLORS[dir])
		_mastery_box.add_child(rank)
		var b := Button.new()
		b.text = tr("MASTERY_BUY")
		b.pressed.connect(press_mastery.bind(dir))
		_mastery_box.add_child(b)
		_mastery_rows[dir] = {"rank": rank, "button": b}

	# The detail of the hovered (or selected) node, floating beside it.
	_detail = PanelContainer.new()
	_detail.add_theme_stylebox_override("panel", HoloTheme.panel_style(10))
	_detail.mouse_filter = MOUSE_FILTER_IGNORE
	_detail.visible = false
	add_child(_detail)
	var dbox := VBoxContainer.new()
	dbox.custom_minimum_size.x = 260
	_detail.add_child(dbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	dbox.add_child(_title)
	_kind = Label.new()
	_kind.modulate = Color(1, 1, 1, 0.7)
	_kind.add_theme_font_size_override("font_size", 13)
	dbox.add_child(_kind)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 260
	_desc.add_theme_font_size_override("font_size", 15)
	dbox.add_child(_desc)
	buy_button = Button.new() # kept for the keyboard: buys the selected node
	buy_button.text = tr("TALENT_BUY")
	buy_button.visible = false
	buy_button.pressed.connect(press_buy)
	add_child(buy_button)


## Fills the window with this progress and opens it; `class_id` picks the route shown.
func show_for(progress: PlayerProgress, db: TalentDB, balance: Balance, class_id: String = "") -> void:
	_progress = progress
	_db = db
	_balance = balance
	_route = db.route(class_id)
	_route_index.clear()
	for i in _route.size():
		_route_index[_route[i]] = i + 1
	if _selected != "" and not db.has(_selected):
		_selected = ""
	refresh()
	visible = true


## Redraws after the progress changed (a purchase answered by the host).
func refresh() -> void:
	if _progress == null:
		return
	var spent := Talents.spent(_progress)
	var free := Talents.points(_progress.level) - spent
	_points_label.text = tr("UI_TALENTS_POINTS") % [free, _progress.talents.size(), _db.ids().size() - 1]
	if _balance != null:
		_reset_label.text = tr("UI_TALENTS_RESET") % ProgressRequests.reset_cost(_progress.level, _balance)
	for dir: String in _mastery_rows:
		(_mastery_rows[dir].rank as Label).text = "%s %d" % [tr(DIR_KEYS[dir]), int(_progress.masteries.get(dir, 0))]
		(_mastery_rows[dir].button as Button).disabled = not Talents.can_buy_mastery(_progress, dir, _db)
	_mastery_box.visible = masteries_visible()
	_show_detail(_hover)
	_canvas.queue_redraw()


func select(id: String) -> void:
	if _db == null or not _db.has(id):
		return
	_selected = id
	_canvas.queue_redraw()


func selected() -> String:
	return _selected


## "owned", "available" (touches the start or a bought node) or "locked".
func node_state(id: String) -> String:
	if _progress.talents.has(id):
		return "owned"
	for other: String in _db.node(id).get("links", []):
		if other == _db.start_id() or _progress.talents.has(other):
			return "available"
	return "locked"


func description_text() -> String:
	return _desc.text


func points_text() -> String:
	return _points_label.text


func buy_enabled() -> bool:
	return _selected != "" and Talents.can_buy(_progress, _selected, _db)


func press_buy() -> void:
	if buy_enabled():
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


func canvas_rect() -> Rect2:
	return _canvas.get_global_rect()


func detail_visible() -> bool:
	return _detail.visible


## How far a node reaches from its centre on screen (its frame, ticks or halo included).
func node_extent(id: String) -> float:
	var kind := str(_db.node(id).get("kind", "minor"))
	return (float(NODE_RADIUS.get(kind, 7.0)) + float(NODE_EXTRA.get(kind, 1.0))) * _zoom


func detail_rect() -> Rect2:
	return _detail.get_global_rect()


## Where a node is drawn, in global coordinates.
func node_screen_position(id: String) -> Vector2:
	return _canvas.get_global_rect().position + _canvas.node_position(id)


func zoom() -> float:
	return _zoom


func zoom_to(z: float) -> void:
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_canvas.queue_redraw()


func pan_by(delta: Vector2) -> void:
	_pan += delta
	_canvas.queue_redraw()


func set_route_visible(on: bool) -> void:
	_route_check.button_pressed = on


func route_visible() -> bool:
	return _route_check.button_pressed


## The step of a node on the class's route (1-based), 0 when it is not on it.
func route_step(id: String) -> int:
	return int(_route_index.get(id, 0))


## The icon of a stat (assets/icons/talents/<name>.png), or null when there is none.
func icon_texture(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path := ICON_DIR + icon_name + ".png"
		_icons[icon_name] = load(path) if icon_name != "" and ResourceLoader.exists(path) else null
	return _icons[icon_name]


## A click at a global point (what a mouse click does): buys a node you can buy, else selects.
func click_at(global_point: Vector2) -> void:
	var id := _canvas.pick(global_point - _canvas.get_global_rect().position)
	if id == "":
		return
	select(id)
	if id != _db.start_id() and Talents.can_buy(_progress, id, _db):
		talent_bought.emit(id)


## The left button down at a global point; release_at decides between a click and a drag.
func press_at(global_point: Vector2) -> void:
	_press = global_point


## The mouse moved with the left button down: once past CLICK_SLOP it is a drag that pans.
func drag_to(global_point: Vector2) -> void:
	if _press == null:
		return
	var from: Vector2 = _press
	if _dragging or from.distance_to(global_point) > CLICK_SLOP:
		_dragging = true
		pan_by(global_point - from)
		_press = global_point


func release_at(global_point: Vector2) -> void:
	if _press == null:
		return
	var from: Vector2 = _press
	var dragged := _dragging
	_press = null
	_dragging = false
	if dragged:
		pan_by(global_point - from) # the rest of the drag
	elif from.distance_to(global_point) <= CLICK_SLOP:
		click_at(global_point)
	else:
		pan_by(global_point - from)


## The mouse over a global point: the node there shows its detail.
func hover_at(global_point: Vector2) -> void:
	var id := _canvas.pick(global_point - _canvas.get_global_rect().position)
	if id != _hover:
		_hover = id
		_show_detail(id) # only while the mouse is over a node
		_canvas.queue_redraw()


func _show_detail(id: String) -> void:
	if id == "" or _db == null or not _db.has(id):
		_detail.visible = false
		_desc.text = ""
		return
	var node := _db.node(id)
	_title.text = node_title(node)
	_kind.text = tr("TALENT_KIND_" + str(node.get("kind", "minor")).to_upper())
	var lines: Array = []
	if not (node.get("mods", []) as Array).is_empty():
		lines.append(StatText.describe_all(node.get("mods", [])))
	if id != _db.start_id():
		lines.append(tr("TALENT_STATE_" + node_state(id).to_upper()))
	if route_step(id) > 0 and route_visible():
		lines.append(tr("UI_TALENTS_ON_ROUTE"))
	_desc.text = "\n".join(lines)
	_detail.visible = true
	_detail.reset_size()
	_place_detail(id)


## Puts the detail beside its node, kept inside the window (again whenever the tree moves).
func _place_detail(id: String) -> void:
	if not _detail.visible or id == "" or _db == null or not _db.has(id):
		return
	var at := node_screen_position(id) + Vector2(24, -12)
	var sz := _detail.get_combined_minimum_size()
	var screen := get_global_rect()
	if at.x + sz.x > screen.end.x - 4:
		at.x = node_screen_position(id).x - 24 - sz.x
	at.x = clampf(at.x, screen.position.x + 4, screen.end.x - sz.x - 4)
	at.y = clampf(at.y, screen.position.y + 4, screen.end.y - sz.y - 4)
	_detail.global_position = at


## "Poderío", or "Poderío / Celeridad" for the nodes where two directions mix.
static func node_title(node: Dictionary) -> String:
	var dir := str(node.get("dir", ""))
	if dir == "":
		return TranslationServer.translate("TALENT_KIND_START")
	var parts: Array = [TranslationServer.translate(DIR_KEYS.get(dir, ""))]
	var mix := str(node.get("mix", ""))
	if mix != "":
		parts.append(TranslationServer.translate(DIR_KEYS.get(mix, "")))
	return " / ".join(parts)


## The drawn tree: links, the route, nodes as icons in frames by kind and state.
class TalentCanvas extends Control:
	var window: TalentsWindow


	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP


	func node_position(id: String) -> Vector2:
		var n := window._db.node(id)
		return size / 2.0 + window._pan + Vector2(float(n.get("x", 0.0)), float(n.get("y", 0.0))) * UNIT_PX * window._zoom


	func radius_of(id: String) -> float:
		return float(NODE_RADIUS.get(str(window._db.node(id).get("kind", "minor")), 11.0)) * window._zoom


	## The node at a point (local), or "".
	func pick(point: Vector2) -> String:
		if window._db == null:
			return ""
		var best := ""
		var best_d := INF
		for id: String in window._db.ids():
			var d := node_position(id).distance_to(point)
			if d <= maxf(radius_of(id), 8.0) + 2.0 and d < best_d:
				best = id
				best_d = d
		return best


	func _gui_input(event: InputEvent) -> void:
		var origin := get_global_rect().position
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					window.press_at(origin + mb.position)
				else:
					window.release_at(origin + mb.position)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				window.zoom_to(window._zoom * 1.12)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				window.zoom_to(window._zoom / 1.12)
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				window.drag_to(origin + mm.position)
			window.hover_at(origin + mm.position)


	func _draw() -> void:
		if window == null or window._db == null or window._progress == null:
			return
		var db := window._db
		var owned := window._progress.talents
		var line := Color(HoloTheme.SECTION, 0.35)
		for id: String in db.ids():
			var a := node_position(id)
			for other: String in db.node(id).get("links", []):
				if other > id:
					var lit := (owned.has(id) or id == db.start_id()) and (owned.has(other) or other == db.start_id())
					draw_line(a, node_position(other), OWNED_COLOR if lit else line, 2.0 if lit else 1.0)
		if window.route_visible() and not window._route.is_empty():
			var prev := db.start_id()
			for i in window._route.size():
				var id: String = window._route[i]
				var linked := (db.node(id).get("links", []) as Array).has(prev)
				if linked: # a solid gold path
					draw_line(node_position(prev), node_position(id), ROUTE_COLOR, 3.0)
				prev = id
		for id: String in db.ids():
			_draw_node(id)
		window._place_detail(window._hover)


	func _draw_node(id: String) -> void:
		var n := window._db.node(id)
		var p := node_position(id)
		var r := radius_of(id)
		var kind := str(n.get("kind", "minor"))
		var dir_color: Color = DIR_COLORS.get(str(n.get("dir", "")), HoloTheme.SECTION)
		var state := "owned" if id == window._db.start_id() else window.node_state(id)
		var tint := Color.WHITE if state != "locked" else Color(0.4, 0.4, 0.45)
		if kind == "keystone":
			draw_circle(p, r + float(NODE_EXTRA.keystone) * window._zoom, Color(dir_color, 0.45)) # the halo
		var tex := window.icon_texture(str(n.get("icon", "")))
		if tex != null:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				pts.append(p + Vector2(cos(a), sin(a)) * r)
				uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
			draw_polygon(pts, PackedColorArray([tint]), uvs, tex)
		else:
			draw_circle(p, r, Color(dir_color, 0.9) * tint) # no icon: the direction's colour
		var on_route := window.route_visible() and window.route_step(id) > 0
		var frame := OWNED_COLOR if state == "owned" else (ROUTE_COLOR if on_route else (Color(1, 1, 1, 0.9) if state == "available" else Color(0.45, 0.5, 0.6, 0.8)))
		var width := {"minor": 1.5, "notable": 2.0, "keystone": 2.5, "start": 2.0}.get(kind, 1.5) as float
		if on_route:
			width += 1.0 # the recommended nodes: a thicker gold border
		draw_arc(p, r, 0.0, TAU, 32, frame, width)
		if kind == "notable":
			for k in 4: # four ticks round a notable's frame
				var a := TAU * k / 4.0 + PI / 4.0
				draw_line(p + Vector2(cos(a), sin(a)) * r, p + Vector2(cos(a), sin(a)) * (r + float(NODE_EXTRA.notable) * window._zoom), frame, 1.5)
		if id == window._hover:
			draw_arc(p, r + 1.0, 0.0, TAU, 32, Color.WHITE, 1.5)
