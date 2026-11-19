extends GutTest

var night: Ambience


func before_each() -> void:
	night = Ambience.load_id("mazmorra_noche")


func test_low_strips_expensive_effects() -> void:
	var env := AmbienceBuilder.make_environment(night, GraphicsQuality.LOW)
	assert_false(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_eq(env.fog_height_density, 0.0)
	assert_true(env.fog_enabled)
	assert_true(env.glow_enabled)
	assert_true(env.adjustment_enabled)
	assert_false(AmbienceBuilder.camera_attributes(night, GraphicsQuality.LOW).dof_blur_far_enabled)


func test_medium_adds_ssao_only() -> void:
	var env := AmbienceBuilder.make_environment(night, GraphicsQuality.MEDIUM)
	assert_true(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_almost_eq(env.fog_height_density, night.fog_height_density, 0.001)
	assert_false(AmbienceBuilder.camera_attributes(night, GraphicsQuality.MEDIUM).dof_blur_far_enabled)


func test_high_has_everything_the_ambience_asks() -> void:
	var env := AmbienceBuilder.make_environment(night, GraphicsQuality.HIGH)
	assert_true(env.ssao_enabled)
	assert_true(env.ssr_enabled)
	assert_true(env.volumetric_fog_enabled)
	assert_true(env.glow_enabled)
	var attrs := AmbienceBuilder.camera_attributes(night, GraphicsQuality.HIGH)
	assert_true(attrs.dof_blur_far_enabled)
	assert_almost_eq(attrs.dof_blur_far_distance, night.dof_distance, 0.001)


func test_quality_never_adds_what_ambience_lacks() -> void:
	var bare := Ambience.from_dict("x", {})
	var env := AmbienceBuilder.make_environment(bare, GraphicsQuality.HIGH)
	assert_false(env.glow_enabled)
	assert_false(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_false(AmbienceBuilder.camera_attributes(bare, GraphicsQuality.HIGH).dof_blur_far_enabled)
	assert_null(AmbienceBuilder.make_particles(bare, GraphicsQuality.HIGH))


func test_sun_shadows_per_quality() -> void:
	var sun: DirectionalLight3D = autofree(DirectionalLight3D.new())
	var expected := {
		GraphicsQuality.LOW: [DirectionalLight3D.SHADOW_ORTHOGONAL, 40.0],
		GraphicsQuality.MEDIUM: [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 60.0],
		GraphicsQuality.HIGH: [DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 80.0],
	}
	for q: int in expected:
		AmbienceBuilder.configure_sun(sun, night, q)
		assert_eq(sun.directional_shadow_mode, expected[q][0], "quality %d" % q)
		assert_almost_eq(sun.directional_shadow_max_distance, expected[q][1], 0.01)
		assert_true(sun.shadow_enabled)
		assert_almost_eq(sun.light_energy, night.sun_energy, 0.001)


func test_particles_scale_with_quality() -> void:
	var amounts := []
	for q: int in [GraphicsQuality.LOW, GraphicsQuality.MEDIUM, GraphicsQuality.HIGH]:
		var p: GPUParticles3D = autofree(AmbienceBuilder.make_particles(night, q))
		amounts.append(p.amount)
	assert_eq(amounts, [40, 96, 160])


func test_clamp_level() -> void:
	assert_eq(GraphicsQuality.clamp_level(-3), GraphicsQuality.LOW)
	assert_eq(GraphicsQuality.clamp_level(7), GraphicsQuality.HIGH)
	assert_eq(GraphicsQuality.clamp_level(1), GraphicsQuality.MEDIUM)


func _glow_levels(env: Environment) -> int:
	var n := 0
	for i in 7:
		if env.get_glow_level(i) > 0.0:
			n += 1
	return n


func test_low_glow_uses_fewer_levels() -> void:
	var low := AmbienceBuilder.make_environment(night, GraphicsQuality.LOW)
	var high := AmbienceBuilder.make_environment(night, GraphicsQuality.HIGH)
	assert_true(low.glow_enabled)
	assert_lt(_glow_levels(low), _glow_levels(high))
	assert_gt(_glow_levels(low), 0)
