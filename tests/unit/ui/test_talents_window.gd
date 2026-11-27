extends GutTest
## Plan 8.3g: the talent window, full screen, holographic: the ring tree drawn on a canvas
## with zoom and drag, stat icons in frames, the class's recommended route and the detail
## of the node under the mouse.

var win: TalentsWindow
var balance: Balance
var db: TalentDB


func before_each() -> void:
	balance = Balance.load_from()
	db = TalentDB.load_default()
	win = TalentsWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	win.theme = theme
	add_child_autofree(win)
	win.set_anchors_preset(Control.PRESET_TOP_LEFT) # the test screen is 1280×720, whatever GUT's viewport is
	win.position = Vector2.ZERO
	win.size = Vector2(1280, 720)


func _show(level: int, talents := [], masteries := {}, class_id := "warrior") -> PlayerProgress:
	var pr := PlayerProgress.from_dict({"level": level, "talents": talents, "masteries": masteries})
	win.show_for(pr, db, balance, class_id)
	return pr


func test_node_states() -> void:
	_show(10, ["r1_0"])
	assert_eq(win.node_state("r1_0"), "owned")
	assert_eq(win.node_state("r2_0"), "available")
	assert_eq(win.node_state("r1_5"), "available", "the start touches the whole first ring")
	assert_eq(win.node_state("r3_0"), "locked")
	assert_eq(win.node_state("r7_0"), "locked", "no ring is closed by level or upgrade, only by its neighbours")


func test_fits_1280x720_and_starts_centred() -> void:
	_show(10)
	await wait_frames(2)
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), str(r))
	var canvas := win.canvas_rect()
	assert_almost_eq(win.node_screen_position("start").x, canvas.get_center().x, 1.0)
	assert_almost_eq(win.node_screen_position("start").y, canvas.get_center().y, 1.0)


func test_click_buys_an_available_node() -> void:
	_show(5)
	await wait_frames(2)
	watch_signals(win)
	win.click_at(win.node_screen_position("r1_0"))
	assert_signal_emitted_with_parameters(win, "talent_bought", ["r1_0"])
	assert_eq(win.selected(), "r1_0")


func test_click_on_locked_or_owned_only_selects() -> void:
	_show(5, ["r1_0"])
	await wait_frames(2)
	watch_signals(win)
	win.click_at(win.node_screen_position("r3_0"))
	assert_signal_not_emitted(win, "talent_bought")
	assert_eq(win.selected(), "r3_0")
	win.click_at(win.node_screen_position("r1_0"))
	assert_signal_not_emitted(win, "talent_bought", "already owned")


func test_no_points_no_purchase() -> void:
	_show(2, ["r1_0"])
	await wait_frames(2)
	watch_signals(win)
	win.click_at(win.node_screen_position("r2_0"))
	assert_signal_not_emitted(win, "talent_bought")


func test_drag_pans_instead_of_buying() -> void:
	_show(5)
	await wait_frames(2)
	watch_signals(win)
	var p := win.node_screen_position("r1_0")
	win.press_at(p)
	win.release_at(p + Vector2(30, 0))
	assert_signal_not_emitted(win, "talent_bought")
	assert_almost_eq(win.node_screen_position("r1_0").x, p.x + 30.0, 0.5)


func test_zoom_is_clamped() -> void:
	_show(5)
	win.zoom_to(9.0)
	assert_eq(win.zoom(), 2.5)
	win.zoom_to(0.0)
	assert_eq(win.zoom(), 0.5)


func test_route_marks_steps() -> void:
	_show(5, [], {}, "warrior")
	var route := db.route("warrior")
	assert_eq(win.route_step(route[0]), 1)
	assert_eq(win.route_step(route[9]), 10)
	assert_eq(win.route_step("start"), 0)
	assert_true(win.route_visible())
	win.set_route_visible(false)
	assert_false(win.route_visible())


func test_detail_shows_the_node() -> void:
	_show(5, [], {}, "warrior")
	await wait_frames(2)
	var first: String = db.route("warrior")[0]
	win.hover_at(win.node_screen_position(first))
	var text := win.description_text()
	assert_string_contains(text, StatText.describe_all(db.node(first).mods))
	assert_string_contains(text, tr("UI_TALENTS_ON_ROUTE"))


func test_missing_icon_falls_back() -> void:
	var tiny := TalentDB.from_dict({"start": "start", "directions": ["might"], "nodes": {
		"start": {"kind": "start", "dir": "", "mix": "", "ring": 0, "x": 0, "y": 0, "icon": "", "mods": [], "links": ["a"]},
		"a": {"kind": "minor", "dir": "might", "mix": "", "ring": 1, "x": 0, "y": -0.13, "icon": "nope",
			"mods": [{"type": "stat", "stat": "crit_add", "value": 0.01}], "links": ["start"]}}})
	win.show_for(PlayerProgress.from_dict({"level": 3}), tiny, balance, "warrior")
	await wait_frames(2)
	assert_null(win.icon_texture("nope"))
	assert_not_null(win.icon_texture("crit"))
	assert_eq(win.node_state("a"), "available")


func test_detail_stays_on_screen() -> void:
	_show(5)
	await wait_frames(2)
	var edge := "r7_17" # on the right of ring 7
	win.pan_by(Vector2(1270, 360) - win.node_screen_position(edge))
	win.hover_at(win.node_screen_position(edge))
	assert_true(Rect2(0, 0, 1280, 720).encloses(win.detail_rect()), str(win.detail_rect()))


func test_masteries_appear_when_a_direction_is_complete() -> void:
	var might: Array = []
	var have := {db.start_id(): true}
	var grew := true
	while grew:
		grew = false
		for id: String in db.ids():
			if not have.has(id) and str(db.node(id).dir) == "might" and (db.node(id).links as Array).any(func(n: String) -> bool: return have.has(n)):
				have[id] = true
				might.append(id)
				grew = true
	_show(might.size() + 2, might.slice(0, might.size() - 1))
	assert_false(win.masteries_visible())
	_show(might.size() + 2, might)
	assert_true(win.masteries_visible())
	assert_true(win.mastery_enabled("might"))
	watch_signals(win)
	win.press_mastery("might")
	assert_signal_emitted_with_parameters(win, "mastery_bought", ["might"])


func test_points_text() -> void:
	_show(10, ["r1_0", "r2_0"])
	assert_eq(win.points_text(), tr("UI_TALENTS_POINTS") % [7, 2, db.ids().size() - 1])


## A real drag sends motion between press and release: letting go after dragging is not a click.
func test_release_after_a_drag_does_not_buy() -> void:
	_show(5)
	await wait_frames(2)
	watch_signals(win)
	var p := win.node_screen_position("r1_0")
	win.press_at(p + Vector2(-40, 0))
	win.drag_to(p)
	win.release_at(p)
	assert_signal_not_emitted(win, "talent_bought")


## The detail only shows while the mouse is over a node, even after clicking one.
func test_detail_only_while_hovering() -> void:
	_show(5)
	await wait_frames(2)
	var p := win.node_screen_position("r1_0")
	win.click_at(p)
	win.hover_at(p)
	assert_true(win.detail_visible())
	win.hover_at(win.canvas_rect().position + Vector2(5, 5))
	assert_false(win.detail_visible(), "it goes away with the mouse")


## No two nodes overlap at zoom 1 (frames and halos included).
func test_nodes_do_not_overlap() -> void:
	_show(5)
	await wait_frames(2)
	for id: String in db.ids():
		for other: String in db.node(id).links:
			if other > id:
				var d := win.node_screen_position(id).distance_to(win.node_screen_position(other))
				assert_gt(d, win.node_extent(id) + win.node_extent(other), "%s and %s overlap" % [id, other])
