extends GutTest


func test_flicker_stays_in_range() -> void:
	for phase: float in [0.0, 1.7, 4.2]:
		for i in 1000:
			var f := Torch.flicker(i * 0.06, phase)
			assert_true(f >= 0.85 and f <= 1.15, "flicker %f at t=%f" % [f, i * 0.06])
			if f < 0.85 or f > 1.15:
				return


func test_flicker_varies() -> void:
	var lo := 10.0
	var hi := -10.0
	for i in 200:
		var f := Torch.flicker(i * 0.05, 0.3)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	assert_gt(hi - lo, 0.02)


func test_phase_changes_flicker() -> void:
	assert_ne(Torch.flicker(1.0, 0.0), Torch.flicker(1.0, 2.0))


func test_shadows_only_on_high() -> void:
	var torch: Torch = add_child_autofree(Torch.new())
	torch.set_quality(GraphicsQuality.LOW)
	assert_false(torch.light.shadow_enabled)
	torch.set_quality(GraphicsQuality.MEDIUM)
	assert_false(torch.light.shadow_enabled)
	torch.set_quality(GraphicsQuality.HIGH)
	assert_true(torch.light.shadow_enabled)


func test_low_fades_with_distance() -> void:
	var torch: Torch = add_child_autofree(Torch.new())
	torch.set_quality(GraphicsQuality.LOW)
	assert_true(torch.light.distance_fade_enabled)
	assert_almost_eq(torch.light.distance_fade_begin, 18.0, 0.01)
	torch.set_quality(GraphicsQuality.HIGH)
	assert_false(torch.light.distance_fade_enabled)


func test_torch_has_model_and_flame() -> void:
	assert_true(FileAccess.file_exists(Torch.VOX_PATH))
	var torch: Torch = add_child_autofree(Torch.new())
	assert_not_null(torch.flame)
	assert_not_null(torch.model.mesh)
	assert_almost_eq(torch.light.position.y, 1.55, 0.01)


func test_energy_scale_and_no_fog_scattering() -> void:
	var torch: Torch = add_child_autofree(Torch.new())
	torch.energy_scale = 0.25
	torch._process(0.1)
	assert_lt(torch.light.light_energy, Torch.LIGHT_ENERGY * 0.25 * 1.16)
	assert_eq(torch.light.light_volumetric_fog_energy, 0.0)


func test_model_does_not_shadow_its_own_light() -> void:
	var torch: Torch = add_child_autofree(Torch.new())
	assert_eq(torch.model.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(torch.light.omni_shadow_mode, OmniLight3D.SHADOW_CUBE)
