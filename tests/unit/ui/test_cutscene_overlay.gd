extends GutTest
## Cutscene overlay (Plan 8.2): black bars, subtitles, fades and holding Esc to skip.

var o: CutsceneOverlay


func before_each() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	o = CutsceneOverlay.new()
	add_child_autofree(o)
	o.open(true)
	o.size = Vector2(1280, 720)
	o._layout()


func test_bars_and_subtitle() -> void:
	assert_almost_eq(o.bar_height(), 720 * 0.12, 0.5)
	o.show_line("Brann", "Id a casa.")
	assert_eq(o.subtitle(), "Brann: Id a casa.")


func test_hold_to_skip() -> void:
	watch_signals(o)
	o.step(0.3, true)
	o.step(0.1, false)
	o.step(0.3, true)
	assert_signal_not_emitted(o, "skip_requested", "letting go starts again")
	o.step(0.25, true)
	assert_signal_emitted(o, "skip_requested")


func test_not_skippable() -> void:
	o.open(false)
	watch_signals(o)
	o.step(2.0, true)
	assert_signal_not_emitted(o, "skip_requested")


func test_fade() -> void:
	o.set_fade(true, 1.0)
	o.step(0.5, false)
	assert_almost_eq(o.black(), 0.5, 0.01)
	o.step(0.6, false)
	assert_eq(o.black(), 1.0)
	o.set_fade(false, 0.0)
	assert_eq(o.black(), 0.0)


func test_flash() -> void:
	o.flash()
	assert_gt(o.white(), 0.9)
	o.step(0.45, false)
	assert_eq(o.white(), 0.0)
