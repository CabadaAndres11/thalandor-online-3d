class_name QuestJournal
extends Control
## The quest journal (J, Plan 8.2): the quests on the left (Active and Done tabs, story first,
## PAGE quests a page) and the chosen one on the right: summary, step, objectives, quest
## items and rewards, with Track and Abandon. No scroll: more quests go to more pages.

signal track_requested(id: String)
signal abandon_requested(id: String)

const PAGE := 8
const LIST_W := 330.0
const DETAIL_W := 520.0

var _log := QuestLog.new()
var _quests: QuestDB
var _items: ItemDB
var _bag: Inventory
var _done_tab: bool = false
var _page: int = 0
var _selected: String = ""
var _panel: PanelContainer
var _list: VBoxContainer
var _page_label: Label
var _detail: Label
var _title: Label
var _track_b: Button
var _abandon_b: Button
var _tab_active: Button
var _tab_done: Button


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(14))
	_panel.mouse_filter = MOUSE_FILTER_STOP
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)
	outer.add_child(HoloTheme.title(tr("UI_QUEST_JOURNAL"), 26))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	outer.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_W, 0)
	cols.add_child(left)
	var tabs := HBoxContainer.new()
	left.add_child(tabs)
	_tab_active = Button.new()
	_tab_active.text = tr("UI_QUEST_ACTIVE")
	_tab_active.toggle_mode = true
	_tab_active.pressed.connect(show_done.bind(false))
	tabs.add_child(_tab_active)
	_tab_done = Button.new()
	_tab_done.text = tr("UI_QUEST_DONE")
	_tab_done.toggle_mode = true
	_tab_done.pressed.connect(show_done.bind(true))
	tabs.add_child(_tab_done)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_W, 8 * 38)
	left.add_child(_list)
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(pager)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(prev_page)
	pager.add_child(prev)
	_page_label = Label.new()
	pager.add_child(_page_label)
	var nxt := Button.new()
	nxt.text = ">"
	nxt.pressed.connect(next_page)
	pager.add_child(nxt)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(DETAIL_W, 0)
	cols.add_child(right)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 25)
	_title.add_theme_color_override("font_color", Color("#ffd27a"))
	right.add_child(_title)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(DETAIL_W, 300)
	_detail.add_theme_font_size_override("font_size", 19)
	right.add_child(_detail)
	var buttons := HBoxContainer.new()
	right.add_child(buttons)
	_track_b = Button.new()
	_track_b.text = tr("UI_QUEST_TRACK")
	_track_b.pressed.connect(press_track)
	buttons.add_child(_track_b)
	_abandon_b = Button.new()
	_abandon_b.text = tr("UI_QUEST_ABANDON")
	_abandon_b.pressed.connect(func() -> void:
		if _selected != "":
			abandon_requested.emit(_selected))
	buttons.add_child(_abandon_b)


func show_for(log: QuestLog, quests: QuestDB, items: ItemDB, bag: Inventory) -> void:
	_log = log
	_quests = quests
	_items = items
	_bag = bag
	if _selected != "" and not (log.is_active(_selected) or log.is_done(_selected)):
		_selected = ""
	visible = true
	_rebuild()


func _ids() -> Array:
	if _quests == null:
		return []
	var ids: Array = _log.done.duplicate() if _done_tab else _log.active.keys()
	ids = ids.filter(func(id: String) -> bool: return not _quests.quest(id).is_empty())
	ids.sort_custom(func(a: String, b: String) -> bool:
		var sa := bool(_quests.quest(a).story)
		var sb := bool(_quests.quest(b).story)
		return sa and not sb if sa != sb else a < b)
	return ids


func page_count() -> int:
	return maxi(1, ceili(_ids().size() / float(PAGE)))


func list_size() -> int:
	return _list.get_child_count()


func next_page() -> void:
	_page = mini(_page + 1, page_count() - 1)
	_rebuild()


func prev_page() -> void:
	_page = maxi(0, _page - 1)
	_rebuild()


func show_done(done: bool) -> void:
	_done_tab = done
	_page = 0
	_selected = ""
	_rebuild()


func select(id: String) -> void:
	_selected = id
	_rebuild()


func press_track() -> void:
	if _selected != "" and _log.is_active(_selected):
		track_requested.emit(_selected)


func _rebuild() -> void:
	_tab_active.button_pressed = not _done_tab
	_tab_done.button_pressed = _done_tab
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var ids := _ids()
	_page = clampi(_page, 0, page_count() - 1)
	if _selected == "" and not ids.is_empty():
		_selected = ids[0]
	for id: String in ids.slice(_page * PAGE, (_page + 1) * PAGE):
		var b := Button.new()
		var q := _quests.quest(id)
		b.text = ("★ " if bool(q.story) else "") + tr(str(q.name)) + ("  ◆" if id == _log.tracked else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(LIST_W, 34)
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(select.bind(id))
		_list.add_child(b)
	_page_label.text = "%d / %d" % [_page + 1, page_count()]
	_show_detail()
	_place()


func _show_detail() -> void:
	var q := _quests.quest(_selected) if _quests != null else {}
	_title.text = tr(str(q.get("name", ""))) if not q.is_empty() else tr("UI_QUEST_NONE")
	_track_b.visible = not q.is_empty() and _log.is_active(_selected)
	_abandon_b.visible = _track_b.visible and not bool(q.get("story", false))
	if q.is_empty():
		_detail.text = ""
		return
	var lines: Array = [tr(str(q.get("summary", ""))), ""]
	if _log.is_active(_selected):
		lines.append(QuestText.step_text(_log, _quests, _selected))
		for l: String in QuestText.objective_lines(_log, _quests, _selected, _bag):
			lines.append("  · " + l)
	else:
		lines.append(tr("UI_QUEST_COMPLETED"))
	var r: Dictionary = q.rewards
	var rewards: Array = []
	if int(r.get("levels", 0)) > 0:
		rewards.append(tr("UI_QUEST_REWARD_LEVELS") % int(r.levels))
	if int(r.get("gold", 0)) > 0:
		rewards.append(tr("UI_QUEST_REWARD_GOLD") % int(r.gold))
	for b: Variant in (r.get("items", []) as Array):
		rewards.append(tr(str(_items.base(str(b)).get("name", b))))
	if not (r.get("choice", []) as Array).is_empty():
		rewards.append(tr("UI_QUEST_REWARD_CHOICE") % (r.choice as Array).size())
	if not rewards.is_empty():
		lines.append("")
		lines.append(tr("UI_QUEST_REWARDS") + " " + ", ".join(rewards))
	_detail.text = "\n".join(lines)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.position = ((size if size != Vector2.ZERO else Vector2(1280, 720)) - sz) / 2.0


# --- Readable state (tests) ---

func detail_text() -> String:
	return _detail.text


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)
