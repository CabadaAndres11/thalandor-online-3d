class_name BeastRig
extends Node3D
## A voxel monster made of parts (assets/monsters/vox/<name>.json): each part is a
## .vox mesh hanging from a pivot node (optionally under a "parent" part), animated
## by code: legs swing in diagonal pairs, the head bobs, the tail sways; bite: the head
## snaps down while the beast lunges (MonsterAvatar).

const DIR := "res://assets/monsters/vox/%s.json"
const LEG_SWING := 0.6
const STRIDE := 1.4 # meters per full leg cycle at walking pace

var _parts: Dictionary = {} # name -> Node3D (pivot)
var _phase: float = 0.0
var _time: float = 0.0
## While true the head is driven by the attack tween, not by the walk cycle.
var biting: bool = false


static func build(rig_name: String, tint: Color) -> BeastRig:
	var rig := BeastRig.new()
	rig.name = "Beast"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR % rig_name)) if FileAccess.file_exists(DIR % rig_name) else null
	if not data is Dictionary:
		push_error("BeastRig: missing or bad rig %s" % rig_name)
		return rig
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


## Called every frame with the ground speed (m/s).
func animate(speed: float, delta: float) -> void:
	_time += delta
	_phase += speed * delta / STRIDE * TAU
	var amount := clampf(speed / 3.0, 0.0, 1.0)
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


func _set_rot(part_name: String, angle: float) -> void:
	var p := part(part_name)
	if p != null:
		p.rotation.x = angle
