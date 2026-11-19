extends GutTest

var _fps: int


func before_each() -> void:
	_fps = Engine.max_fps
	SettingsApplier.ensure_buses()


func after_each() -> void:
	Engine.max_fps = _fps
	SettingsApplier.apply_audio(SettingsStore.new())


func test_buses_created_and_routed() -> void:
	for bus: String in SettingsApplier.BUSES:
		assert_ne(AudioServer.get_bus_index(bus), -1, bus)
	for bus: String in ["Music", "SFX", "UI"]:
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"Master")
	SettingsApplier.ensure_buses()
	assert_eq(AudioServer.bus_count, 4, "calling it twice adds nothing")


func test_volume_applied_in_db() -> void:
	var s := SettingsStore.new()
	s.volumes.SFX = 0.5
	SettingsApplier.apply_audio(s)
	var i := AudioServer.get_bus_index("SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(i), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(i))


func test_volume_zero_mutes_bus() -> void:
	var s := SettingsStore.new()
	s.volumes.Music = 0.0
	SettingsApplier.apply_audio(s)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))


func test_master_mute() -> void:
	var s := SettingsStore.new()
	s.muted = true
	SettingsApplier.apply_audio(s)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))


func test_scale_below_one_uses_fsr() -> void:
	var vp: SubViewport = add_child_autofree(SubViewport.new())
	var s := SettingsStore.new()
	s.render_scale = 0.7
	SettingsApplier.apply_viewport(s, vp)
	assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	assert_almost_eq(vp.scaling_3d_scale, 0.7, 0.001)
	s.render_scale = 1.0
	SettingsApplier.apply_viewport(s, vp)
	assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)
	assert_almost_eq(vp.scaling_3d_scale, 1.0, 0.001)


func test_msaa_only_on_high() -> void:
	var vp: SubViewport = add_child_autofree(SubViewport.new())
	var s := SettingsStore.new()
	for q: int in [GraphicsQuality.LOW, GraphicsQuality.MEDIUM]:
		s.quality = q
		SettingsApplier.apply_viewport(s, vp)
		assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)
		assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	s.quality = GraphicsQuality.HIGH
	SettingsApplier.apply_viewport(s, vp)
	assert_eq(vp.msaa_3d, Viewport.MSAA_2X)


func test_max_fps_applied() -> void:
	var s := SettingsStore.new()
	s.max_fps = 60
	SettingsApplier.apply_window(s)
	assert_eq(Engine.max_fps, 60)
