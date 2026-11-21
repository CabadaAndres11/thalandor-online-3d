class_name CreditsWindow
extends PanelContainer
## Credits (Plan 7, opened from the title screen): who made what and under which licence.

signal close_requested()

var body: Label
var close_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", StoneTheme.panel(24))
	set_anchors_preset(PRESET_CENTER)
	custom_minimum_size = Vector2(620, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(StoneTheme.title(tr("CREDITS_TITLE")))
	body = Label.new()
	body.text = tr("CREDITS_BODY")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	close_button = Button.new()
	close_button.text = tr("BTN_CLOSE")
	close_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(160, 44)
	close_button.pressed.connect(close_requested.emit)
	box.add_child(close_button)


## Centred on the screen at its own size.
func _ready() -> void:
	resized.connect(_center)
	_center()


func _center() -> void:
	var parent := get_parent_area_size()
	position = (parent - size) / 2.0
