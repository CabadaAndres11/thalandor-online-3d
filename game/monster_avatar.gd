class_name MonsterAvatar
extends Node3D
## A monster on screen, built from its type (data/monsters "model"):
##   "rig:<name>"    a voxel beast made of animated parts (BeastRig);
##   "vox:<name>"    a voxel body from assets/monsters/vox (tint on index 251).
## Attacks (lunge, bite) and deaths (fall over) are tweens on the body holder.


const VOX_PATH := "res://assets/monsters/vox/%s.vox"
const SPEED_SMOOTHING_S := 0.1
const TELEPORT_DISTANCE := 2.0

var body: Node3D
var bar: OverheadBar
var dying: bool = false
var animation_player: AnimationPlayer
var _rig: BeastRig

var _kind: String = ""
var _height: float = 1.0
var _last_position: Variant = null
var _speed: float = 0.0
var _time: float = 0.0
var _rest: Vector3 = Vector3.ZERO


func setup(type: Dictionary) -> void:
	var model := str(type.get("model", ""))
	var tint := Color(str(type.get("tint", "#ffffff")))
	var scale_f := float(type.get("scale", 1.0))
	if model.begins_with("rig:"):
		_kind = "rig"
		body = Node3D.new()
		_rig = BeastRig.build(model.trim_prefix("rig:"), tint)
		body.add_child(_rig)
		body.scale = Vector3.ONE * scale_f
		_height = 1.6 * scale_f
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
	bar = OverheadBar.new()
	bar.position.y = _height + 0.35
	add_child(bar)
	bar.setup(tr(str(type.get("name", ""))), true)


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
	if dying:
		return
	if _rig != null:
		_rig.animate(_speed, delta)
	elif animation_player != null:
		var anim := "idle"
		if _speed >= 3.5:
			anim = "run"
		elif _speed >= 0.2:
			anim = "walk"
		if animation_player.current_animation != anim and animation_player.has_animation(anim):
			animation_player.play(anim, 0.15)
	elif _kind == "vox":
		var hop := absf(sin(_time * 9.0)) * 0.18 if _speed >= 0.2 else 0.0
		body.position.y = _rest.y + hop


func current_animation() -> String:
	if animation_player != null:
		return animation_player.current_animation
	return "walk" if _speed >= 0.2 else "idle"


## A short lunge forward and back (or a squash for jelly bodies).
func play_attack() -> Tween:
	if dying or body == null:
		return null
	var t := create_tween()
	if _kind == "vox":
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


## Falls over and shrinks; the node is removed when the monster leaves the snapshot.
func play_death() -> Tween:
	if dying or body == null:
		return null
	dying = true
	bar.visible = false
	if animation_player != null:
		animation_player.stop()
	var t := create_tween().set_parallel()
	t.tween_property(body, "rotation_degrees:z", 90.0, 0.5)
	t.tween_property(body, "scale:y", body.scale.y * 0.2, 0.9)
	t.tween_property(body, "position:y", _rest.y - 0.2, 0.9)
	return t


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
