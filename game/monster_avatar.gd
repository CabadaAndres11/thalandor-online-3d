class_name MonsterAvatar
extends Node3D
## A monster on screen, built from its type (data/monsters "model"):
##   "rig:<name>"    a voxel rig of animated parts (BeastRig: beasts);
##   "humanoid:<id>" a voxel humanoid (HumanRig) from the type's "look".
## Elites are bigger, have an ember aura on the ground and "élite" in their name.
## Attacks (lunge, bite) and deaths (fall over) are tweens on the body holder.
## "hover" (meters): the humanoid floats that high above the ground, bobbing gently;
## "hide_parts": HumanRig parts not drawn (legs under a floating robe).


const SPEED_SMOOTHING_S := 0.1
const TELEPORT_DISTANCE := 2.0
const DISSOLVE_S := 1.1
const HIT_FLASH_S := 0.14
const HIT_RECOIL := 0.28
const BINARY_DIGITS := 36
const HOVER_BOB := 0.07 # meters up and down
const HOVER_BOB_SPEED := 1.8 # radians per second

var body: Node3D
var bar: OverheadBar
var dying: bool = false
var _binary: Array[Label3D] = []
var _recoil: Tween
var _rig: BeastRig
var _humanoid: HumanRig
var _aura: Node3D
var _display_name: String = ""
## Seconds left of an attack animation (humanoids: idle/walk wait for it).
var _leap: Tween

var _kind: String = ""
var _height: float = 1.0
var _last_position: Variant = null
var _speed: float = 0.0
var _move_speed: float = 3.0
var _hover: float = 0.0
var _scale: float = 1.0
var _time: float = 0.0
var _rest: Vector3 = Vector3.ZERO


func setup(type: Dictionary, elite: bool = false, elite_scale: float = 1.3, ally: bool = false) -> void:
	var model := str(type.get("model", ""))
	var tint := Color(str(type.get("tint", "#ffffff")))
	var scale_f := float(type.get("scale", 1.0)) * (elite_scale if elite else 1.0)
	if model.begins_with("rig:"):
		_kind = "rig"
		body = Node3D.new()
		_rig = BeastRig.build(model.trim_prefix("rig:"), tint)
		body.add_child(_rig)
		body.scale = Vector3.ONE * scale_f
		_height = float(type.get("bar_height", 1.6)) * scale_f
	elif model.begins_with("humanoid:"):
		_kind = "humanoid"
		body = Node3D.new()
		_humanoid = HumanRig.build(look_of(type))
		_humanoid.auto_update = false
		body.add_child(_humanoid)
		body.scale = Vector3.ONE * scale_f
		_move_speed = float(type.get("speed", 3.0))
		_hover = float(type.get("hover", 0.0))
		_scale = scale_f
		_humanoid.position.y = _hover / scale_f
		for part_name: String in type.get("hide_parts", []): # e.g. legs under a floating robe
			var mesh := _humanoid.part_mesh(part_name)
			if mesh != null:
				mesh.visible = false
		_height = float(type.get("bar_height", 1.9)) * scale_f + _hover
	else:
		_kind = "box"
		body = MeshInstance3D.new()
		(body as MeshInstance3D).mesh = BoxMesh.new()
	add_child(body)
	_rest = body.position
	if elite:
		_aura = _make_aura(float(type.get("radius", 0.5)) * elite_scale)
		add_child(_aura)
	_display_name = tr(str(type.get("name", "")))
	if elite:
		_display_name = tr("MON_ELITE_NAME") % _display_name
	bar = OverheadBar.new()
	bar.position.y = _height + 0.35
	add_child(bar)
	bar.setup(_display_name, true, Color(0.3, 0.85, 0.35) if ally else Color(0.85, 0.2, 0.2)) # allies: green bar


## A HumanRig look (see HumanRig.build) from a monster's "look" data.
## Builds the humanoid bosses' models and every beast once (their meshes stay in VoxMesher's
## cache), so a boss's huge pieces (Nhazar's head) and a summoned wolf are made while the
## game loads, not mid-fight.
static func prewarm_bosses() -> void:
	for step: Callable in prewarm_steps():
		step.call()


## The same, one monster model per step, so a loading game keeps answering the network
## between them (Plan 8.1.1).
static func prewarm_steps() -> Array[Callable]:
	var steps: Array[Callable] = []
	var db := MonsterDB.load_default()
	for id: String in db.type_ids():
		var type := db.get_type(id)
		var model := str(type.get("model", ""))
		if bool(type.get("boss", false)) and model.begins_with("humanoid:"):
			steps.append(func() -> void: HumanRig.build(look_of(type)).free())
		elif model.begins_with("rig:"):
			steps.append(func() -> void: BeastRig.build(model.trim_prefix("rig:"), Color(str(type.get("tint", "#ffffff")))).free())
	return steps


static func look_of(type: Dictionary) -> Dictionary:
	var look: Dictionary = type.get("look", {})
	var catalog := CharacterCatalog.load_default()
	var skin := Color(str(look.get("skin", "#ffffff")))
	var pieces: Array = []
	for id: String in look.get("pieces", []):
		if catalog.piece(id).is_empty() and catalog.piece_v2(id).is_empty():
			continue
		pieces.append(catalog.piece_entry(id)) # the v2 piece (Plan 6.4.1), or v1 drawn twice as big
	return {
		"body": CharacterCatalog.BODY, # cult humanoids wear the v2 body like the players
		"skin_color": skin,
		"eyes_color": Color(str(look.get("eyes", "#000000"))),
		"hair_color": Color(str(look.get("hair", look.get("skin", "#000000")))),
		"voxel_hair_color": skin, # monster pieces tinted like hair take the skin color (ears)
		"primary": Color(str(look.get("primary", "#808080"))),
		"secondary": Color(str(look.get("secondary", "#808080"))),
		"trousers": Color(str(look.trousers)) if look.has("trousers") else Color(str(look.get("primary", "#808080"))).darkened(HumanRig.TROUSERS_DARKEN),
		"body_scale": look.get("body_scale", {}),
		"grip": str(look.get("grip", "")),
		"pieces": pieces,
	}


func apply_state(state: Dictionary, info: Dictionary, delta: float) -> void:
	if state.is_empty():
		return
	var pos: Vector3 = state.position
	var measured := 0.0
	if _last_position != null and delta > 0.0:
		var step := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length()
		measured = 0.0 if step > TELEPORT_DISTANCE else step / delta
	_last_position = pos
	position = pos
	if not dying:
		rotation.y = state.facing
	if delta > 0.0:
		_speed = lerpf(_speed, measured, 1.0 - exp(-delta / SPEED_SMOOTHING_S))
		_time += delta
	bar.set_health(float(info.get("hp", 1.0)), float(info.get("max_hp", 1.0)))
	if info.has("level"):
		bar.set_level(int(info.level))
	bar.set_statuses(int(info.get("status_bits", 0)))
	if _aura != null:
		var pulse := 1.0 + sin(_time * 3.0) * 0.06
		_aura.scale = Vector3(pulse, 1, pulse)
	if dying:
		if _humanoid != null:
			_humanoid.update(delta) # the fall plays on
		return
	if _rig != null:
		_rig.animate(_speed, delta)
	elif _humanoid != null:
		_humanoid.set_moving_speed(_speed, _move_speed)
		_humanoid.update(delta)
		if _hover > 0.0:
			_humanoid.position.y = (_hover + sin(_time * HOVER_BOB_SPEED) * HOVER_BOB) / _scale


## Meters the body floats above the ground (0 = it stands on it).
func hover_height() -> float:
	return _humanoid.position.y * _scale if _humanoid != null else 0.0


func current_animation() -> String:
	if _humanoid != null:
		return _humanoid.current_animation()
	return "walk" if _speed >= 0.2 else "idle"


## Name above the bar ("Lobo élite" for elites).
func display_name() -> String:
	return _display_name


func has_aura() -> bool:
	return _aura != null


## The attack of an ability "anim" kind (melee, shoot, cast, dash): humanoids play
## the matching animation; beasts lunge (biting), jelly bodies squash.
func play_attack(kind: String = "melee") -> Tween:
	if dying or body == null:
		return null
	var t := create_tween()
	if _kind == "humanoid":
		t.tween_interval(maxf(_humanoid.play_action(kind if HumanRig.ACTIONS.has(kind) else "melee"), 0.05))
	else:
		var head := _rig.part("head") if _rig != null else null
		if head != null:
			_rig.biting = true
		t.tween_property(body, "position", _rest + Vector3(0, 0, 0.35), 0.1)
		if head != null:
			t.parallel().tween_property(head, "rotation:x", 0.5, 0.1)
		t.tween_property(body, "position", _rest, 0.15)
		if head != null:
			t.parallel().tween_property(head, "rotation:x", 0.0, 0.15)
			t.tween_callback(_end_bite)
	return t


## A big jump (the boss leap): the body rises during the warning (`rise_s`) and stays
## up until land(); the position itself jumps with the snapshots when it lands.
func play_leap(rise_s: float) -> Tween:
	if dying or body == null:
		return null
	if _leap != null:
		_leap.kill()
	_leap = create_tween()
	_leap.tween_property(body, "position:y", _rest.y + 3.0, maxf(rise_s * 0.8, 0.05)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	return _leap


## The slam down after a leap.
func land() -> Tween:
	if body == null:
		return null
	if _leap != null:
		_leap.kill()
	_leap = create_tween()
	_leap.tween_property(body, "position:y", _rest.y, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return _leap




## A hit lands: a white flash, a spray of blood and a small step back away from the attacker.
func react_to_hit(from: Variant = null) -> void:
	if dying or body == null:
		return
	# 1. White flash over the whole body.
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(1, 1, 1, 0.85)
	var meshes := body.find_children("*", "GeometryInstance3D", true, false)
	var cloth_flash := HumanRig.cloth_flash_material() # robes and capes flash bent like the cloth
	cloth_flash.set_shader_parameter("flash", Color(1, 1, 1, 0.85))
	for n: Node in meshes:
		var cloth := n is MeshInstance3D and (n as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial
		(n as GeometryInstance3D).material_overlay = cloth_flash if cloth else overlay
	var flash := create_tween()
	flash.set_parallel()
	flash.tween_property(overlay, "albedo_color:a", 0.0, HIT_FLASH_S)
	flash.tween_property(cloth_flash, "shader_parameter/flash:a", 0.0, HIT_FLASH_S)
	flash.chain()
	flash.tween_callback(func() -> void:
		for n: Node in meshes:
			if is_instance_valid(n):
				(n as GeometryInstance3D).material_overlay = null)
	# 2. Blood.
	var away := Vector3.ZERO
	if from is Vector3:
		away = position - (from as Vector3)
		away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.ZERO
	_blood(away)
	# 3. A small step back (visual only), eased out.
	if away != Vector3.ZERO and not dying:
		var local := away.rotated(Vector3.UP, -rotation.y) * HIT_RECOIL
		if _recoil != null and _recoil.is_valid():
			_recoil.kill()
		body.position = _rest + local
		_recoil = create_tween()
		_recoil.tween_property(body, "position", _rest, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _blood(away: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = (away + Vector3.UP).normalized() if away != Vector3.ZERO else Vector3.UP
	p.spread = 45.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.0, 0)
	var drop := SphereMesh.new() # round drops, not squares
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	p.mesh = drop
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.72, 0.05, 0.07)
	p.material_override = m
	p.position = Vector3(0, _height * 0.55, 0)
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free) if is_inside_tree() else p.queue_free()


## The body dissolves into binary code: it fades out in place while 0s and 1s rise from it
## (humanoids also play their fall). The node is removed when the monster leaves the snapshot.
func play_death() -> Tween:
	if dying or body == null:
		return null
	dying = true
	bar.visible = false
	if _aura != null:
		_aura.visible = false
	if _humanoid != null:
		_humanoid.play_action("die")
	var t := create_tween().set_parallel()
	for n: Node in body.find_children("*", "GeometryInstance3D", true, false):
		t.tween_property(n, "transparency", 1.0, DISSOLVE_S).set_delay(0.1)
	_spawn_binary(t)
	return t


## Digits (green 0 and 1) that appear on the body's own surface and fade as it dissolves, so
## they stay inside its silhouette.
func _spawn_binary(t: Tween) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 73.0 + position.z * 131.0) # visual only: not the simulation's rng
	var points := _surface_points(rng, BINARY_DIGITS)
	for from: Vector3 in points:
		var l := Label3D.new()
		l.text = "1" if rng.randf() < 0.5 else "0"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.006
		l.font_size = 40
		l.outline_size = 6
		l.modulate = Color(0.35, 1.0, 0.65, 0.0)
		l.position = from
		add_child(l)
		_binary.append(l)
		var delay := rng.randf_range(0.0, 0.7)
		t.tween_property(l, "modulate:a", 1.0, 0.15).set_delay(delay)
		t.tween_property(l, "position:y", from.y + rng.randf_range(0.1, 0.3), 0.7).set_delay(delay)
		t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(delay + 0.5)


## Random points on the model's surface, in this node's space.
func _surface_points(rng: RandomNumberGenerator, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var verts: Array = [] # [MeshInstance3D, PackedVector3Array]
	for n: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.visible:
			var faces := mi.mesh.get_faces()
			if faces.size() > 0:
				verts.append([mi, faces])
	if verts.is_empty():
		for i in count:
			out.append(Vector3(0, rng.randf_range(0.2, _height), 0))
		return out
	for i in count:
		var pick: Array = verts[rng.randi() % verts.size()]
		var faces: PackedVector3Array = pick[1]
		var v := faces[rng.randi() % faces.size()]
		var mi := pick[0] as MeshInstance3D
		# Up to the avatar: through every transform between the mesh and this node.
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != null and node != self:
			if node is Node3D:
				xf = (node as Node3D).transform * xf
			node = node.get_parent()
		out.append(xf * v)
	return out


func binary_digit_count() -> int:
	return _binary.size()


## Elite aura: a glowing ember ring on the ground, a soft inner glow and a warm light.
func _make_aura(radius: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "EliteAura"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius + 0.35
	torus.outer_radius = radius + 0.5
	torus.rings = 48
	ring.mesh = torus
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.04
	ring.material_override = _glow_material(Color(1.0, 0.55, 0.1), 0.9)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius + 0.42
	cyl.bottom_radius = radius + 0.42
	cyl.height = 0.01
	disc.mesh = cyl
	disc.position.y = 0.03
	disc.material_override = _glow_material(Color(1.0, 0.35, 0.05), 0.22)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.2
	light.omni_range = radius + 2.5
	light.position.y = 0.6
	holder.add_child(light)
	return holder


static func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


func _end_bite() -> void:
	if _rig != null:
		_rig.biting = false
