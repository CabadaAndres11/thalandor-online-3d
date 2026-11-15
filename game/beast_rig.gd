class_name BeastRig
extends Node3D
## A voxel monster made of parts (assets/monsters/vox/<name>.json): each part is a
## .vox mesh hanging from a pivot node (optionally under a "parent" part), animated
## by code. Two gaits:
##   quadruped (wolf, boar): legs swing in diagonal pairs, head bobs, tail sways;
##     bite: the head snaps down while the beast lunges (MonsterAvatar);
##   biped (skeleton): legs and arms swing against each other, the skull rattles and
##     the jaw chatters; shoot raises the bow and draws; collapse falls to pieces.

const DIR := "res://assets/monsters/vox/%s.json"
const LEG_SWING := 0.6
const STRIDE := 1.4 # meters per full leg cycle at walking pace
const ARM_SWING := 0.45

var gait: String = "quadruped"
var _parts: Dictionary = {} # name -> Node3D (pivot)
var _phase: float = 0.0
var _time: float = 0.0
## While true the head is driven by the attack tween, not by the walk cycle.
var biting: bool = false
## While true the arms are driven by the shoot tween.
var shooting: bool = false
var _body_rest_y: float = 0.0


static func build(rig_name: String, tint: Color) -> BeastRig:
	var rig := BeastRig.new()
	rig.name = "Beast"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR % rig_name)) if FileAccess.file_exists(DIR % rig_name) else null
	if not data is Dictionary:
		push_error("BeastRig: missing or bad rig %s" % rig_name)
		return rig
	rig.gait = str((data as Dictionary).get("gait", "quadruped"))
	var body_pivot: Array = ((data.get("parts", {}) as Dictionary).get("body", {}) as Dictionary).get("pivot", [0, 0, 0])
	rig._body_rest_y = float(body_pivot[1]) * VoxMesher.VOXEL_SIZE
	var parts: Dictionary = data.get("parts", {})
	var pivots := {} # name -> absolute pivot (voxels)
	for part_name: String in parts:
		var p: Dictionary = parts[part_name]
		var pv: Array = p.get("pivot", [0, 0, 0])
		pivots[part_name] = Vector3(pv[0], pv[1], pv[2])
		var pivot := Node3D.new()
		pivot.name = part_name
		var mesh := MeshInstance3D.new()
		mesh.mesh = VoxMesher.cached(str(p.get("file", "")), {VoxMesher.TINT_PRIMARY: tint})
		var off: Array = p.get("offset", [0, 0, 0])
		mesh.position = Vector3(off[0], off[1], off[2]) * VoxMesher.VOXEL_SIZE
		pivot.add_child(mesh)
		rig._parts[part_name] = pivot
	# Parents first (file order lists them first): a child's pivot is relative to its
	# parent's, so it follows the parent's animation.
	for part_name: String in parts:
		var parent_name := str((parts[part_name] as Dictionary).get("parent", ""))
		var pivot: Node3D = rig._parts[part_name]
		if parent_name != "" and rig._parts.has(parent_name):
			pivot.position = (pivots[part_name] - pivots[parent_name]) * VoxMesher.VOXEL_SIZE
			(rig._parts[parent_name] as Node3D).add_child(pivot)
		else:
			pivot.position = pivots[part_name] * VoxMesher.VOXEL_SIZE
			rig.add_child(pivot)
	return rig


func part(part_name: String) -> Node3D:
	return _parts.get(part_name)


func is_biped() -> bool:
	return gait == "biped"


## Called every frame with the ground speed (m/s).
func animate(speed: float, delta: float) -> void:
	_time += delta
	_phase += speed * delta / STRIDE * TAU
	var amount := clampf(speed / 3.0, 0.0, 1.0)
	if is_biped():
		_animate_biped(amount)
		return
	var swing := sin(_phase) * LEG_SWING * amount
	_set_rot("leg_front_left", swing)
	_set_rot("leg_back_right", swing)
	_set_rot("leg_front_right", -swing)
	_set_rot("leg_back_left", -swing)
	var head := part("head")
	if head != null and not biting:
		head.rotation.x = sin(_phase * 2.0) * 0.06 * amount + sin(_time * 1.6) * 0.03
	var tail := part("tail")
	if tail != null:
		tail.rotation.y = sin(_time * (3.0 + 6.0 * amount)) * 0.35
		tail.rotation.x = -0.35
	var body := part("body")
	if body != null:
		body.position.y = absf(sin(_phase)) * 0.04 * amount + sin(_time * 1.6) * 0.008


func _animate_biped(amount: float) -> void:
	var swing := sin(_phase) * LEG_SWING * amount
	_set_rot("leg_left", swing)
	_set_rot("leg_right", -swing)
	if not shooting:
		_set_rot("arm_left", -swing * ARM_SWING / LEG_SWING)
		_set_rot("arm_right", swing * ARM_SWING / LEG_SWING)
	var head := part("head")
	if head != null:
		# A loose skull: it rattles with each step and nods slowly when standing.
		head.rotation.z = sin(_phase * 2.0) * 0.08 * amount
		head.rotation.x = sin(_time * 1.3) * 0.05
	var jaw := part("jaw")
	if jaw != null:
		# Hangs a little open in a sneer; chatters when standing, clacks while walking.
		jaw.rotation.x = 0.12 + (maxf(0.0, sin(_time * 7.0)) * 0.16 if amount < 0.1 else absf(sin(_phase * 2.0)) * 0.1)
	var torso := part("torso")
	if torso != null:
		torso.rotation.z = sin(_time * 1.1) * 0.03 + sin(_phase) * 0.05 * amount
	var body := part("body")
	if body != null:
		body.position.y = _body_rest_y + absf(sin(_phase)) * 0.05 * amount


## Shoot: the bow arm swings up level, the bow turns upright, the right hand draws
## the string back and lets go; then both arms come down. Added to `t`.
func shoot(t: Tween) -> void:
	var bow_arm := part("arm_left")
	var draw_arm := part("arm_right")
	var bow := part("bow")
	if bow_arm == null or draw_arm == null:
		return
	shooting = true
	t.tween_property(bow_arm, "rotation:x", -PI / 2.0, 0.12)
	t.parallel().tween_property(draw_arm, "rotation:x", -PI / 2.0, 0.12)
	if bow != null:
		t.parallel().tween_property(bow, "rotation:x", PI / 2.0, 0.12)
	t.tween_property(draw_arm, "rotation:x", -1.1, 0.25) # draw
	t.parallel().tween_property(draw_arm, "rotation:y", 0.5, 0.25)
	t.tween_interval(0.08)
	t.tween_property(draw_arm, "rotation:x", -PI / 2.0, 0.05) # release
	t.tween_interval(0.2)
	t.tween_property(bow_arm, "rotation:x", 0.0, 0.25)
	t.parallel().tween_property(draw_arm, "rotation:x", 0.0, 0.25)
	t.parallel().tween_property(draw_arm, "rotation:y", 0.0, 0.25)
	if bow != null:
		t.parallel().tween_property(bow, "rotation:x", 0.0, 0.25)
	t.tween_callback(func() -> void: shooting = false)


## Death: the bones come apart. Every part is moved under the rig (keeping where it
## is), then drops to the ground with a tumble; the skull rolls further. Tweens are
## added in parallel to `t`.
func collapse(t: Tween) -> void:
	shooting = true
	var i := 0
	for part_name: String in _parts:
		var p: Node3D = _parts[part_name]
		var xf := p.transform
		var n := p.get_parent()
		while n != null and n != self:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		if p.get_parent() != self:
			p.get_parent().remove_child(p)
			add_child(p)
		p.transform = xf
		var angle := float(i) * 2.399 # golden angle: pieces spread all around
		i += 1
		var drift := Vector3(sin(angle), 0, cos(angle)) * (0.8 if part_name == "head" else 0.3)
		var target := Vector3(xf.origin.x, 0.05, xf.origin.z) + drift
		var delay := 0.05 * float(i % 4)
		t.tween_property(p, "position", target, 0.55).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "rotation", Vector3(sin(angle) * 1.4, angle, cos(angle) * 1.4), 0.55).set_delay(delay)


func _set_rot(part_name: String, angle: float) -> void:
	var p := part(part_name)
	if p != null:
		p.rotation.x = angle
