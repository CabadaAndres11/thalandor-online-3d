class_name SettingsApplier
extends RefCounted
## Applies the video and audio settings (SettingsStore) to the window, the viewport,
## the rendering server and the audio buses. The ambience lighting itself is rebuilt by
## the arena (Arena.set_quality).

const BUSES := ["Master", "Music", "SFX", "UI"]
const SUN_ATLAS := [2048, 4096, 4096]


## Creates the Music, SFX and UI buses (sending to Master) if they are missing.
static func ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, &"Master")


static func apply_audio(s: SettingsStore) -> void:
	for bus: String in BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var v := float(s.volumes.get(bus, 1.0))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.0 or (bus == "Master" and s.muted))


static func apply_viewport(s: SettingsStore, vp: Viewport) -> void:
	if s.render_scale < 1.0:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = s.render_scale
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_2X if s.quality == GraphicsQuality.HIGH else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


static func apply_quality_globals(q: int) -> void:
	q = GraphicsQuality.clamp_level(q)
	RenderingServer.directional_shadow_atlas_set_size(SUN_ATLAS[q], true)
	var ssao: Array = [RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_LOW,
		RenderingServer.ENV_SSAO_QUALITY_HIGH]
	RenderingServer.environment_set_ssao_quality(ssao[q], true, 0.5, 2, 50.0, 300.0)
	var soft: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[q])


## Window mode and VSync (skipped when headless) and the FPS cap.
static func apply_window(s: SettingsStore) -> void:
	Engine.max_fps = s.max_fps
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.vsync
		else DisplayServer.VSYNC_DISABLED)


static func apply_all(s: SettingsStore, vp: Viewport) -> void:
	apply_window(s)
	apply_viewport(s, vp)
	apply_quality_globals(s.quality)
	apply_audio(s)
