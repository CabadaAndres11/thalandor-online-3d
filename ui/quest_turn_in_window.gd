class_name QuestTurnInWindow
extends Control
## Handing in a quest (Plan 8.2): its rewards and, when it has a choice, the items to pick
## from (with their tooltip). Confirm is only possible once one is chosen.

signal confirmed(choice: String)

var _quest: Dictionary = {}
var _choice: int = -1
var _panel: PanelContainer
var _title: Label
var _rewards: Label
var _choices: HBoxContainer
var _confirm: Button
var _slots: Array = []


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(18))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = HoloTheme.title("", 26)
	box.add_child(_title)
	_rewards = Label.new()
	_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rewards)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 12)
	box.add_child(_choices)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_confirm = Button.new()
	_confirm.text = tr("UI_QUEST_CONFIRM")
	_confirm.pressed.connect(confirm)
	row.add_child(_confirm)
	var cancel := Button.new()
	cancel.text = tr("BTN_CANCEL")
	cancel.pressed.connect(func() -> void: visible = false)
	row.add_child(cancel)


func show_for(quest: Dictionary, items: ItemDB, class_id: String = "", level: int = 1) -> void:
	_quest = quest
	_choice = -1
	_title.text = tr(str(quest.get("name", "")))
	var r: Dictionary = quest.get("rewards", {})
	var parts: Array = []
	if int(r.get("levels", 0)) > 0:
		parts.append(tr("UI_QUEST_REWARD_LEVELS") % int(r.levels))
	if int(r.get("gold", 0)) > 0:
		parts.append(tr("UI_QUEST_REWARD_GOLD") % int(r.gold))
	for b: Variant in r.get("items", []):
		parts.append(tr(str(items.base(str(b)).get("name", b))))
	_rewards.text = ", ".join(parts)
	for c: Node in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_slots.clear()
	var list: Array = r.get("choice", [])
	for i in list.size():
		var slot := ItemSlot.new()
		slot.class_id = class_id
		slot.level = level
		slot.set_item(ItemRoll.new_item(str(list[i]), maxi(1, int(items.base(str(list[i])).get("min_level", 1)))))
		slot.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				pick(i))
		_choices.add_child(slot)
		_slots.append(slot)
	_choices.visible = not list.is_empty()
	visible = true
	_refresh()


func pick(i: int) -> void:
	_choice = i
	_refresh()


func can_confirm() -> bool:
	var list: Array = _quest.get("rewards", {}).get("choice", [])
	return list.is_empty() or (_choice >= 0 and _choice < list.size())


func _refresh() -> void:
	_confirm.disabled = not can_confirm()
	for i in _slots.size():
		(_slots[i] as Control).modulate = Color.WHITE if i == _choice or _choice < 0 else Color(1, 1, 1, 0.45)


func confirm() -> void:
	if not can_confirm():
		return
	var list: Array = _quest.get("rewards", {}).get("choice", [])
	visible = false
	confirmed.emit(str(list[_choice]) if _choice >= 0 else "")


func panel_rect() -> Rect2:
	return _panel.get_global_rect()
