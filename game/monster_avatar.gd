class_name MonsterAvatar
extends Node3D
## A monster on screen, built from its type (data/monsters "model"):
##   "rig:<name>"    a voxel rig of animated parts (BeastRig: beasts, the skeleton);
##   "vox:<name>"    a voxel body from assets/monsters/vox (tint on index 251);
##   "humanoid:<id>" a voxel humanoid (HumanRig) from the type's "look".
## Elites are bigger, have an ember aura on the ground and "élite" in their name.
## Attacks (lunge, bite) and deaths (fall over) are tweens on the body holder.


const VOX_PATH := "res://assets/monsters/vox/%s.vox"
const SPEED_SMOOTHING_S := 0.1
const TELEPORT_DISTANCE := 2.0

var body: Node3D
var bar: OverheadBar
var dying: bool = false
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
var _time: float = 0.0
var _rest: Vector3 = Vector3.ZERO


func setup(type: Dictionary, elite: bool = false, elite_scale: float = 1.3) -> void:
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
		_height = 1.9 * scale_f
	elif model.begins_with("vox:"):
		_kind = "vox"
		body = _vox(model.trim_prefix("vox:"), tint)
		body.scale = Vector3.ONE * scale_f
		_height = 0.9 * scale_f
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
	bar.setup(_display_name, true)


## A HumanRig look (see HumanRig.build) from a monster's "look" data.
static func look_of(type: Dictionary) -> Dictionary:
	var look: Dictionary = type.get("look", {})
	var catalog := CharacterCatalog.load_default()
	var skin := Color(str(look.get("skin", "#ffffff")))
	var pieces: Array = []
	for id: String in look.get("pieces", []):
		var p := catalog.piece(id)
		if not p.is_empty():
			pieces.append({"id": id, "file": p.get("file", ""), "part": p.get("part", ""), "offset": p.get("offset", [0, 0, 0])})
	return {
		"skin_color": skin,
		"eyes_color": Color(str(look.get("eyes", "#000000"))),
		"hair_color": Color(str(look.get("hair", look.get("skin", "#000000")))),
		"voxel_hair_color": skin, # monster pieces tinted like hair take the skin color (ears)
		"primary": Color(str(look.get("primary", "#808080"))),
		"secondary": Color(str(look.get("secondary", "#808080"))),
		"body_scale": look.get("body_scale", {}),
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
	elif _kind == "vox":
		var hop := absf(sin(_time * 9.0)) * 0.18 if _speed >= 0.2 else 0.0
		body.position.y = _rest.y + hop


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
	if _rig != null and _rig.is_biped():
		_rig.shoot(t)
	elif _kind == "humanoid":
		t.tween_interval(maxf(_humanoid.play_action(kind if HumanRig.ACTIONS.has(kind) else "melee"), 0.05))
	elif _kind == "vox":
		var base := body.scale
		t.tween_property(body, "scale", base * Vector3(1.25, 0.7, 1.25), 0.1)
		t.tween_property(body, "scale", base, 0.15)
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




## Falls over and shrinks (humanoids play their death animation); the node is removed
## when the monster leaves the snapshot.
func play_death() -> Tween:
	if dying or body == null:
		return null
	dying = true
	bar.visible = false
	if _aura != null:
		_aura.visible = false
	var t := create_tween().set_parallel()
	if _rig != null and _rig.is_biped():
		_rig.collapse(t)
		return t
	if _humanoid != null:
		_humanoid.play_action("die")
		t.tween_property(body, "position:y", _rest.y - 0.05, 0.9)
		return t
	t.tween_property(body, "rotation_degrees:z", 90.0, 0.5)
	t.tween_property(body, "scale:y", body.scale.y * 0.2, 0.9)
	t.tween_property(body, "position:y", _rest.y - 0.2, 0.9)
	return t


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


func _vox(name_id: String, tint: Color) -> Node3D:
	var holder := Node3D.new()
	var mesh := VoxMesher.cached(VOX_PATH % name_id, {VoxMesher.TINT_PRIMARY: tint})
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mesh != null:
		var box := mesh.get_aabb()
		mi.position = Vector3(-box.size.x / 2.0, 0, -box.size.z / 2.0)
	holder.add_child(mi)
	return holder


func _end_bite() -> void:
	if _rig != null:
		_rig.biting = false
