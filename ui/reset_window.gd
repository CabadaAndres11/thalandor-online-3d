class_name ResetWindow
extends Control
## The trainer of the capital (Plan 8.3b): resets attributes or talents for gold, the price
## in sight. A button is off, with the reason, when there is nothing to reset or not enough gold.

signal reset_requested(what: String)

var attributes_button: Button
var talents_button: Button
var _price: Label
var _why: Label


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(18))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(HoloTheme.title(tr("UI_RESET_TITLE"), 24))
	_price = Label.new()
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_price)
	attributes_button = Button.new()
	attributes_button.pressed.connect(func() -> void: _ask("attributes"))
	box.add_child(attributes_button)
	talents_button = Button.new()
	talents_button.pressed.connect(func() -> void: _ask("talents"))
	box.add_child(talents_button)
	_why = Label.new()
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.add_theme_color_override("font_color", Color(0.9, 0.6, 0.5))
	box.add_child(_why)
	var close := Button.new()
	close.text = tr("BTN_CANCEL")
	close.pressed.connect(func() -> void: visible = false)
	box.add_child(close)


## Shows the price and which resets this player can buy right now.
func show_for(pr: PlayerProgress, gold: int, b: Balance) -> void:
	var cost := ProgressRequests.reset_cost(pr.level, b)
	_price.text = tr("UI_RESET_PRICE") % cost
	var attrs_spent := Attributes.free_points(pr, b) < int(b.attributes.get("points_per_level", 5)) * (pr.level - 1)
	var talents_spent := not pr.talents.is_empty() or not pr.masteries.is_empty()
	var rich := gold >= cost
	attributes_button.text = tr("UI_RESET_ATTRIBUTES") % cost
	talents_button.text = tr("UI_RESET_TALENTS") % cost
	attributes_button.disabled = not rich or not attrs_spent
	talents_button.disabled = not rich or not talents_spent
	var why: Array = []
	if not rich:
		why.append(tr("UI_RESET_NO_GOLD"))
	elif not attrs_spent and not talents_spent:
		why.append(tr("UI_RESET_NOTHING"))
	_why.text = " ".join(why)
	visible = true


func reason() -> String:
	return _why.text


func _ask(what: String) -> void:
	reset_requested.emit(what)
	visible = false
