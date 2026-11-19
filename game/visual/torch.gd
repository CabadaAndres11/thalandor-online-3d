class_name Torch
extends Node3D
## Standing torch prop: voxel model, a warm flickering OmniLight3D and a small flame.
## Decoration only (no collision). Shadows only on High quality.

const VOX_PATH := "res://assets/props/torch.vox"
const MODEL_SCALE := 0.5
const LIGHT_HEIGHT := 1.55
const LIGHT_COLOR := Color("#ff9548")
const LIGHT_ENERGY := 3.0
const LIGHT_RANGE := 9.0

var model: MeshInstance3D
var light: OmniLight3D
var flame: GPUParticles3D
## Set by the ambience (Ambience.torch_energy): torches barely show by day.
var energy_scale: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0


## Light multiplier in [0.85, 1.15]: three sines of unrelated frequencies.
static func flicker(t: float, phase: float) -> float:
	return 1.0 + 0.07 * sin(t * 7.0 + phase) + 0.05 * sin(t * 11.3 + phase * 1.7) \
		+ 0.03 * sin(t * 17.9 + phase * 2.3)


func _init() -> void:
	_phase = randf() * TAU
	model = MeshInstance3D.new()
	model.name = "Model"
	model.mesh = VoxMesher.cached(VOX_PATH, {})
	model.scale = Vector3.ONE * MODEL_SCALE
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # the bowl would hide its own light
	if model.mesh != null:
		var size := model.mesh.get_aabb().size * MODEL_SCALE
		model.position = Vector3(-size.x * 0.5, 0, -size.z * 0.5)
	add_child(model)

	light = OmniLight3D.new()
	light.name = "Light"
	light.position.y = LIGHT_HEIGHT
	light.light_color = LIGHT_COLOR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.2
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.light_volumetric_fog_energy = 0.0 # shadowed lights in volumetric fog leave artefacts
	add_child(light)

	flame = _make_flame()
	flame.position.y = LIGHT_HEIGHT - 0.05
	add_child(flame)
	set_quality(GraphicsQuality.MEDIUM)


func set_quality(q: int) -> void:
	q = GraphicsQuality.clamp_level(q)
	light.shadow_enabled = q == GraphicsQuality.HIGH
	light.distance_fade_enabled = q == GraphicsQuality.LOW
	light.distance_fade_begin = 18.0
	light.distance_fade_length = 6.0


func _process(delta: float) -> void:
	_time += delta
	var f := flicker(_time, _phase)
	light.light_energy = LIGHT_ENERGY * energy_scale * f
	light.omni_range = LIGHT_RANGE * (0.97 + 0.03 * f)


func _make_flame() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Flame"
	p.amount = 14
	p.lifetime = 0.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.07
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = curve
	pm.scale_curve = scale_tex
	var grad := Gradient.new()
	grad.set_color(0, Color("#fff2a0"))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.35, 0.1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.6, 1.2, 0.8)
	quad.material = mat
	p.draw_pass_1 = quad
	return p
