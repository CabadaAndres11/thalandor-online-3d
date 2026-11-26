extends GutTest
## Dialogue window (Plan 8.2): a wide stone panel at the bottom with who speaks and the text
## letter by letter; E or a click completes or moves on, 1-4 choose; nothing scrolls at 1280×720.

const DIALOGUES := "res://tests/data/dialogues/"

var win: DialogueWindow


func before_each() -> void:
	DialogueRunner.dir = DIALOGUES
	get_tree().root.size = Vector2i(1280, 720)
	win = DialogueWindow.new()
	var theme := Theme.new()
	StoneTheme.apply(theme)
	win.theme = theme
	add_child_autofree(win)


func after_each() -> void:
	DialogueRunner.dir = DialogueRunner.DIR


func _open(flags: Array = []) -> void:
	var log := QuestLog.new()
	log.flags = flags
	var r := DialogueRunner.load_id("d_test")
	r.start(log)
	win.show_for(r, "Brann", "Aren", "")


func _to_choices() -> void:
	for i in 10:
		if not win.choice_texts().is_empty():
			return
		win.press_continue() # completes the line
		win.press_continue() # next line


func test_shows_speaker_and_types() -> void:
	_open()
	assert_true(win.visible)
	assert_eq(win.speaker_text(), "Brann")
	assert_eq(win.shown_text(), "", "the text appears letter by letter")
	win.advance_time(0.1)
	assert_eq(win.shown_text().length(), 4, "40 letters a second")
	win.press_continue()
	assert_eq(win.shown_text(), tr("ITEM_Q_PAQUETE"), "a press completes the line")
	win.press_continue()
	assert_eq(win.speaker_text(), "Aren", "the player speaks with their own name")


func test_advance_and_choose() -> void:
	_open()
	watch_signals(win)
	_to_choices()
	assert_eq(win.choice_texts().size(), 2)
	win.press_choice(1) # back to the hub with the once choice taken
	assert_signal_emitted_with_parameters(win, "flags_set", [["pregunto"]], 0)
	_to_choices()
	assert_eq(win.choice_texts().size(), 1)
	win.press_choice(1)
	assert_signal_emitted_with_parameters(win, "action", ["accept", ""])
	assert_signal_emitted_with_parameters(win, "finished", ["d_test"])
	assert_false(win.visible)


func test_fits_without_scroll() -> void:
	_open(["visto"])
	_to_choices()
	assert_eq(win.choice_texts().size(), 3)
	await get_tree().process_frame
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "panel %s inside the screen" % r)
	assert_eq(find_child_of_type(win, ScrollContainer), null)


func test_interrupt_closes_without_finishing() -> void:
	_open()
	watch_signals(win)
	win.interrupt()
	assert_false(win.visible)
	assert_signal_emitted(win, "closed")
	assert_signal_not_emitted(win, "finished")


static func find_child_of_type(n: Node, t: Variant) -> Node:
	for c: Node in n.get_children():
		if is_instance_of(c, t):
			return c
		var deep := find_child_of_type(c, t)
		if deep != null:
			return deep
	return null
