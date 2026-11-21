class_name MenuScene
extends Node3D
## The black sun altar behind the menus (Plan 7): ruins at night, cultists praying around
## the altar, braziers and a red glow. Built from data (data/scenes/title_altar.json); the
## title, character select and create screens only move its camera (set_shot) and show the
## chosen character in front of the altar (show_character).

const DEFAULT_PATH := "res://data/scenes/title_altar.json"
const PROPS_DIR := "res://assets/props/"
const PROP_SCALE := 0.5 # props are made of 5 cm voxels, like the torch
const SHOT_BLEND_S := 1.0

var camera: Camera3D
var hero: HumanRig
var cultists: Array[HumanRig] = []
var lights: Array[OmniLight3D] = []

var _data: Dictionary = {}
var _quality: int = GraphicsQuality.MEDIUM
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _particles: GPUParticles3D
var _light_energy: Dictionary = {} # OmniLight3D -> base energy (the flickering ones)
var _time: float = 0.0
var _shot: Dictionary = {}
var _from := Transform3D.IDENTITY
var _blend: float = 1.0


func build(path: String = DEFAULT_PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_data = parsed if parsed is Dictionary else {}
	_add_ground()
	for p: Dictionary in _data.get("props", []):
		_add_prop(p)
	_add_cultists()
	for l: Dictionary in _data.get("lights", []):
		_add_light(l)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 38
	add_child(camera)
	_apply_ambience()
	set_shot("title", true)


## Moves the camera to a shot of the data ("title" orbits the altar), in SHOT_BLEND_S.
func set_shot(id: String, instant: bool = false) -> void:
	_shot = (_data.get("shots", {}) as Dictionary).get(id, {})
	if camera == null:
		return
	_from = camera.transform
	_blend = 1.0 if instant else 0.0
	_place_camera(0.0)


## The character standing in front of the altar ({} = nobody). Returns it.
func show_character(look: Dictionary) -> HumanRig:
	if hero != null:
		remove_child(hero)
		hero.free()
		hero = null
	if look.is_empty():
		return null
	hero = HumanRig.build(look)
	var spot: Array = _data.get("hero_spot", [0, 0, 0])
	hero.position = _vec(spot)
	add_child(hero)
	return hero


## Turns the character in front of the altar (dragged with the mouse).
func turn_hero(deg: float) -> void:
	if hero != null:
		hero.rotation_degrees.y += deg


func set_quality(q: int) -> void:
	_quality = GraphicsQuality.clamp_level(q)
	_apply_ambience()
	for l: OmniLight3D in lights:
		l.shadow_enabled = _quality == GraphicsQuality.HIGH


func _process(delta: float) -> void:
	_time += delta
	for l: OmniLight3D in _light_energy:
		l.light_energy = float(_light_energy[l]) * Torch.flicker(_time, l.position.x)
	_place_camera(delta)


func _place_camera(delta: float) -> void:
	if camera == null or _shot.is_empty():
		return
	var target: Transform3D
	if _shot.has("orbit"):
		var o: Dictionary = _shot.orbit
		var a := _time / maxf(float(o.get("period_s", 60.0)), 1.0) * TAU
		var c := _vec(o.get("center", [0, 0, 0]))
		var r := float(o.get("radius", 7.0))
		var pos := c + Vector3(sin(a) * r, float(o.get("height", 3.0)) - c.y, cos(a) * r)
		target = Transform3D.IDENTITY.translated(pos).looking_at(c, Vector3.UP)
	else:
		target = Transform3D.IDENTITY.translated(_vec(_shot.get("pos", [0, 2, 8]))).looking_at(_vec(_shot.get("look", [0, 1, 0])), Vector3.UP)
	_blend = minf(1.0, _blend + delta / SHOT_BLEND_S)
	var k := _blend * _blend * (3.0 - 2.0 * _blend) # smoothstep
	camera.transform = _from.interpolate_with(target, k) if _blend < 1.0 else target


func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(str(_data.get("ground", "#1b1916")))
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	ground.position.y = -0.01
	add_child(ground)


func _add_prop(p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	var mesh := VoxMesher.cached(PROPS_DIR + id + ".vox", {})
	if mesh == null:
		push_error("MenuScene: missing prop " + id)
		return
	var pivot := Node3D.new()
	pivot.name = id
	pivot.position = _vec(p.get("pos", [0, 0, 0]))
	pivot.rotation_degrees.y = float(p.get("rot", 0.0))
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.scale = Vector3.ONE * PROP_SCALE
	var size := mesh.get_aabb().size * PROP_SCALE
	model.position = Vector3(-size.x * 0.5, 0, -size.z * 0.5) # standing on its centre
	pivot.add_child(model)
	add_child(pivot)


## The cultists in a ring around the altar, facing it, praying out of step.
func _add_cultists() -> void:
	var ring: Dictionary = _data.get("ring", {})
	var center := _vec(ring.get("center", [0, 0, 0]))
	var radius := float(ring.get("radius", 2.5))
	var monsters := MonsterDB.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for c: Dictionary in _data.get("cultists", []):
		var type := monsters.get_type(str(c.get("type", "cultist")))
		if type.is_empty():
			continue
		var rig := HumanRig.build(MonsterAvatar.look_of(type))
		var a := deg_to_rad(float(c.get("angle", 0.0)))
		rig.position = center + Vector3(sin(a), 0, cos(a)) * radius
		rig.rotation.y = a + PI # facing the centre
		rig.scale *= float(type.get("scale", 1.0))
		add_child(rig)
		rig.play_action("pray")
		rig.update(rng.randf() * 4.0) # each one in its own breath
		cultists.append(rig)


func _add_light(l: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.position = _vec(l.get("pos", [0, 1, 0]))
	light.light_color = Color(str(l.get("color", "#ffffff")))
	light.light_energy = float(l.get("energy", 1.0))
	light.omni_range = float(l.get("range", 6.0))
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 0.0
	add_child(light)
	lights.append(light)
	if bool(l.get("flicker", false)):
		_light_energy[light] = light.light_energy


func _apply_ambience() -> void:
	var a := Ambience.load_id(str(_data.get("ambience", Ambience.DEFAULT_ID)))
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "Moon"
		add_child(_sun)
	AmbienceBuilder.configure_sun(_sun, a, _quality)
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "Environment"
		add_child(_world_env)
	_world_env.environment = AmbienceBuilder.make_environment(a, _quality)
	_world_env.camera_attributes = AmbienceBuilder.camera_attributes(a, _quality)
	if _particles != null:
		remove_child(_particles)
		_particles.free()
	_particles = AmbienceBuilder.make_particles(a, _quality)
	if _particles != null:
		_particles.position = Vector3(0, 0, 1.5)
		add_child(_particles)


static func _vec(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
