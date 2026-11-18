class_name SlashFx
extends MeshInstance3D
## The cut of a melee swing. While the weapon travels through its swing the points of its
## blade (hand to tip) are recorded each frame; they become a ribbon, an arc along the whole
## path of the weapon. A streak texture and a mask (see assets/fx/slash.gdshader) make the cut
## appear and fade with the movement. It removes itself after the swing.

const SHADER := preload("res://assets/fx/slash.gdshader")
const MAX_SAMPLES := 30
const START_K := 0.26 # of the melee animation: the swing starts here
const END_K := 0.72
const FADE_S := 0.22
const WAIT_LIMIT_S := 0.8

static var _texture: ImageTexture

var _rig: HumanRig
var _samples: Array = [] # [base: Vector3, tip: Vector3]
var _phase: String = "wait" # wait -> record -> fade
var _t: float = 0.0
var _mat: ShaderMaterial
var _im: ImmediateMesh


func setup(rig: HumanRig, color: Color) -> void:
	_rig = rig
	top_level = true # points are in world space
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("slash_tex", slash_texture())
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("fade", 1.0)
	material_override = _mat
	extra_cull_margin = 8.0 # the mesh is rebuilt every frame: never culled by a stale box


func _process(delta: float) -> void:
	advance(delta)


func advance(dt: float) -> void:
	_t += dt
	var melee := is_instance_valid(_rig) and _rig.current_action() == "melee"
	var k := _rig.action_progress() if melee else 0.0
	match _phase:
		"wait":
			if melee and k >= START_K:
				_phase = "record"
			elif _t > WAIT_LIMIT_S or not is_instance_valid(_rig):
				queue_free()
				return
	if _phase == "record":
		var pts: Array = _rig.weapon_points() if is_instance_valid(_rig) else []
		if not pts.is_empty():
			_samples.append(pts)
			if _samples.size() > MAX_SAMPLES:
				_samples.pop_front()
		if not melee or k >= END_K:
			_phase = "fade"
			_t = 0.0
	elif _phase == "fade":
		var f := 1.0 - _t / FADE_S
		_mat.set_shader_parameter("fade", maxf(f, 0.0))
		if f <= 0.0:
			queue_free()
			return
	_rebuild()


func sample_count() -> int:
	return _samples.size()


func phase() -> String:
	return _phase


## The ribbon: one strip across the blade for each sample, u along the swing.
func _rebuild() -> void:
	_im.clear_surfaces()
	if _samples.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _samples.size()
	for i in n:
		var u := float(i) / float(n - 1)
		_im.surface_set_uv(Vector2(u, 0.0))
		_im.surface_add_vertex((_samples[i][0] as Vector3))
		_im.surface_set_uv(Vector2(u, 1.0))
		_im.surface_add_vertex((_samples[i][1] as Vector3))
	_im.surface_end()


## The streak: a bright thin core near the blade's tip with a soft glow, jagged at the edges.
static func slash_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var jag: Array[float] = []
	for x in w:
		jag.append(rng.randf_range(-0.04, 0.04))
	for x in w:
		var u := float(x) / float(w - 1)
		var taper := pow(sin(u * PI), 0.6) # thin at both ends, full in the middle
		for y in h:
			var v := float(y) / float(h - 1)
			var core := exp(-pow((v - 0.86 + jag[x]) / (0.07 + 0.05 * taper), 2.0))
			var body := 0.4 * smoothstep(0.1, 0.9, v) * exp(-pow((v - 0.7) / 0.35, 2.0))
			img.set_pixel(x, y, Color(clampf((core + body) * taper, 0.0, 1.0), 0, 0))
	_texture = ImageTexture.create_from_image(img)
	return _texture
