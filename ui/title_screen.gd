class_name TitleScreen
extends Control
## Title screen: game name, version, player name, Play, Join with a code, Quit.

signal play_requested(player_name: String)
signal join_requested(player_name: String, code: String)
signal quit_requested()

var name_edit: LineEdit
var code_edit: LineEdit
var play_button: Button
var join_button: Button
var quit_button: Button
var version_label: Label


func _init() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1d2233")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	version_label = Label.new()
	version_label.text = tr("VERSION_LABEL") % GameSession.game_version()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(version_label)

	box.add_child(_spacer(16))
	var name_label := Label.new()
	name_label.text = tr("NAME_LABEL")
	box.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = tr("NAME_PLACEHOLDER")
	name_edit.max_length = HostSession.NAME_MAX
	name_edit.text_changed.connect(_on_name_changed)
	box.add_child(name_edit)

	play_button = Button.new()
	play_button.text = tr("BTN_PLAY")
	play_button.custom_minimum_size.y = 44
	play_button.pressed.connect(_on_play)
	box.add_child(play_button)

	box.add_child(_spacer(8))
	var join_row := HBoxContainer.new()
	box.add_child(join_row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = tr("CODE_PLACEHOLDER")
	code_edit.max_length = 12
	code_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	code_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	join_row.add_child(code_edit)
	join_button = Button.new()
	join_button.text = tr("BTN_JOIN")
	join_button.pressed.connect(_on_join)
	join_row.add_child(join_button)

	box.add_child(_spacer(8))
	quit_button = Button.new()
	quit_button.text = tr("BTN_QUIT")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)
	_on_name_changed("")


func set_defaults(player_name: String, code: String) -> void:
	name_edit.text = player_name
	code_edit.text = code
	_on_name_changed(player_name)


func _on_name_changed(_text: String) -> void:
	var ok := HostSession.is_valid_name(name_edit.text)
	play_button.disabled = not ok
	join_button.disabled = not ok


func _on_play() -> void:
	if not play_button.disabled:
		play_requested.emit(name_edit.text.strip_edges())


func _on_join() -> void:
	if not join_button.disabled:
		join_requested.emit(name_edit.text.strip_edges(), code_edit.text.strip_edges())


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
