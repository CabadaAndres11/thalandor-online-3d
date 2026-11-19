class_name AmbienceBuilder
extends RefCounted
## Turns an Ambience and a GraphicsQuality level into Godot rendering objects. The only
## place that crosses both: an effect is on when the ambience asks for it and the
## quality level can afford it.

const SHADOW_MODES := [
	DirectionalLight3D.SHADOW_ORTHOGONAL,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
	DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
]
const SHADOW_DISTANCES := [40.0, 60.0, 80.0]
## Ambient particles fill a box this big around the camera.
const PARTICLE_BOX := Vector3(20, 3, 20)


static func make_environment(a: Ambience, q: int) -> Environment:
	q = GraphicsQuality.clamp_level(q)
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = a.sky_top
	sky_mat.sky_horizon_color = a.sky_horizon
	sky_mat.ground_horizon_color = a.sky_horizon
	sky_mat.ground_bottom_color = a.sky_horizon.darkened(0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = a.ambient_color
	env.ambient_light_energy = a.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if a.tonemap == "filmic" else Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = a.exposure

	env.fog_enabled = true
	env.fog_light_color = a.fog_color
	env.fog_density = a.fog_density
	env.fog_sky_affect = 0.0
	env.fog_height = a.fog_height
	env.fog_height_density = a.fog_height_density if q >= GraphicsQuality.MEDIUM else 0.0
	env.volumetric_fog_enabled = q == GraphicsQuality.HIGH and a.volumetric_density > 0.0
	env.volumetric_fog_density = a.volumetric_density
	env.volumetric_fog_albedo = a.volumetric_albedo

	env.glow_enabled = a.glow
	env.glow_intensity = a.glow_intensity
	env.glow_hdr_threshold = a.glow_threshold
	env.glow_bloom = a.glow_bloom

	env.ssao_enabled = a.ssao and q >= GraphicsQuality.MEDIUM
	env.ssao_radius = a.ssao_radius
	env.ssao_intensity = a.ssao_intensity

	env.ssr_enabled = a.ssr and q == GraphicsQuality.HIGH

	env.adjustment_enabled = true
	env.adjustment_brightness = a.brightness
	env.adjustment_contrast = a.contrast
	env.adjustment_saturation = a.saturation
	return env


## Far depth of field (background blur), only on High.
static func camera_attributes(a: Ambience, q: int) -> CameraAttributesPractical:
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = a.dof and GraphicsQuality.clamp_level(q) == GraphicsQuality.HIGH
	attrs.dof_blur_far_distance = a.dof_distance
	attrs.dof_blur_far_transition = a.dof_distance * 0.5
	attrs.dof_blur_amount = a.dof_amount
	return attrs


static func configure_sun(sun: DirectionalLight3D, a: Ambience, q: int) -> void:
	q = GraphicsQuality.clamp_level(q)
	sun.rotation_degrees = Vector3(-a.sun_elevation, a.sun_azimuth, 0)
	sun.light_color = a.sun_color
	sun.light_energy = a.sun_energy
	sun.shadow_enabled = a.sun_shadows
	sun.directional_shadow_mode = SHADOW_MODES[q]
	sun.directional_shadow_max_distance = SHADOW_DISTANCES[q]


## Floating embers or dust around the camera; null when the ambience has none.
static func make_particles(a: Ambience, q: int) -> GPUParticles3D:
	if a.particles == "none" or a.particle_amount <= 0:
		return null
	q = GraphicsQuality.clamp_level(q)
	var embers := a.particles == "embers"
	var p := GPUParticles3D.new()
	p.name = "AmbientParticles"
	p.amount = maxi(1, roundi(a.particle_amount * GraphicsQuality.PARTICLE_SCALE[q]))
	p.lifetime = 5.0 if embers else 8.0
	p.preprocess = p.lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-PARTICLE_BOX * 1.5, PARTICLE_BOX * 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = PARTICLE_BOX
	pm.direction = Vector3.UP
	pm.spread = 25.0 if embers else 180.0
	pm.initial_velocity_min = 0.3 if embers else 0.02
	pm.initial_velocity_max = 0.9 if embers else 0.12
	pm.gravity = Vector3(0, 0.15, 0) if embers else Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6 if embers else 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.05 if embers else 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = a.particle_color
	if embers:
		mat.emission_enabled = true
		mat.emission = a.particle_color
		mat.emission_energy_multiplier = 4.0
	quad.material = mat
	p.draw_pass_1 = quad
	return p
