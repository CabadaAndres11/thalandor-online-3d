extends SceneTree
## Times each step of a zone build (Plan 8.1.1 profiling): Godot --headless -s tests/helpers/time_build.gd -- --zone=aldea

func _initialize() -> void:
	var zone := "aldea"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone = arg.trim_prefix("--zone=")
	var t0 := Time.get_ticks_msec()
	var layout := ZoneLayout.load_id(zone)
	print("layout %d ms (%d pieces, %d margin)" % [Time.get_ticks_msec() - t0, layout.pieces.size(), layout.margin_pieces.size()])
	var view := ZoneView.new()
	root.add_child(view)
	var i := 0
	for step: Callable in view.build_steps(layout, GraphicsQuality.HIGH):
		var t := Time.get_ticks_msec()
		step.call()
		print("step %d: %d ms" % [i, Time.get_ticks_msec() - t])
		i += 1
	var t1 := Time.get_ticks_msec()
	ZoneMapImage.make(layout)
	print("map image %d ms" % (Time.get_ticks_msec() - t1))
	var k := 0
	for st: Callable in MonsterAvatar.prewarm_steps():
		var t2 := Time.get_ticks_msec()
		st.call()
		print("prewarm %d: %d ms" % [k, Time.get_ticks_msec() - t2])
		k += 1
	quit()
