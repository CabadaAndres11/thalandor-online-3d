class_name HumanRig
extends Node3D
## A voxel humanoid made by code (assets/characters/vox/human.json, from
## tools/art/make_humans.mjs): parts hanging from pivots like BeastRig, colored by tint
## channels (skin, eyes, hair, primary, secondary), with voxel pieces (hair, beards,
## headgear, weapons) attached to its parts. Animated by code: idle and walk from the
## ground speed, and actions (melee, shoot, cast, dash, downed, die) as poses over
## their progress, so they are deterministic and testable (update(delta)).

const RIG := "res://assets/characters/vox/human.json"
## Fine voxels: the 49-voxel body is about 1.76 m tall.
const MODEL_SCALE := 0.36
const PARTS := ["hips", "torso", "head", "arm_left", "arm_right", "forearm_left", "forearm_right",
	"hand_left", "hand_right", "leg_left", "leg_right", "shin_left", "shin_right"]
## Which body_scale entry applies to each part.
const SCALE_GROUP := {
	"hips": "torso", "torso": "torso", "arm_left": "arm", "arm_right": "arm",
	"forearm_left": "arm", "forearm_right": "arm", "hand_left": "arm", "hand_right": "arm",
	"leg_left": "leg", "leg_right": "leg", "shin_left": "leg", "shin_right": "leg",
}
## Seconds each action lasts; downed and die then stay.
const ACTIONS := {"melee": 0.45, "shoot": 0.65, "cast": 0.6, "dash": 0.35, "downed": 0.5, "die": 0.7, "cast_long": 1.0}
const LASTING := ["downed", "die"]
## Actions that repeat until another one starts (a long cast: arms up, the staff spinning).
const LOOPING := ["cast_long"]
## Trousers default to the primary color this much darker.
const TROUSERS_DARKEN := 0.45
const WALK_MIN_SPEED := 0.2 # m/s
const STRIDE := 2.6 # meters per full leg cycle (two steps): about 2 strides/s at 5 m/s
const LEG_SWING := 0.8
const ARM_SWING := 0.5

static var _rig_data: Dictionary = {}

var _body: Node3D # everything hangs from it; it tips over for downed and die
var _parts: Dictionary = {} # name -> Node3D (pivot)
var _meshes: Dictionary = {} # name -> MeshInstance3D
var _rest: Dictionary = {} # name -> rest position of the pivot
var _pieces: Dictionary = {} # piece id -> MeshInstance3D
var _speed: float = 0.0
var _rate: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0
var _action: String = "idle"
var _action_t: float = 0.0
## How the right hand holds its weapon at rest ("staff": leaning forward over the arm).
var _grip: String = ""
## False when an avatar drives update() itself (from its state updates).
var auto_update: bool = true


## look: skin_color, eyes_color, hair_color, voxel_hair_color, primary, secondary,
## trousers (Color; trousers default to a darker primary); body_scale ({"torso"|"arm"|"leg": [x, y, z]}); pieces ([{id, file, part,
## offset: [x, y, z] voxels from the part's pivot}]).
## A character of a class with an appearance (ids; untrusted values are sanitized).
static func create(class_id: String, appearance: Dictionary, catalog: CharacterCatalog = null, upgrade: String = "") -> HumanRig:
	var cat := catalog if catalog != null else CharacterCatalog.load_default()
	return build(cat.resolve(class_id, appearance, upgrade))


static func build(look: Dictionary) -> HumanRig:
	var rig := HumanRig.new()
	rig.name = "Human"
	rig._setup(look)
	return rig


func part(part_name: String) -> Node3D:
	return _parts.get(part_name)


func part_mesh(part_name: String) -> MeshInstance3D:
	return _meshes.get(part_name)


func piece_node(id: String) -> MeshInstance3D:
	return _pieces.get(id)


func pieces() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_pieces.keys())
	return ids


## Walks at this ground speed (the stride follows speed / move_speed).
func set_moving_speed(speed_mps: float, move_speed: float) -> void:
	_speed = speed_mps
	_rate = clampf(speed_mps / maxf(move_speed, 0.01), 0.2, 2.0)


## Starts an action (see ACTIONS; "idle" cancels and stands up). Returns its seconds.
func play_action(kind: String) -> float:
	if kind == "idle":
		_action = "idle"
		_action_t = 0.0
		_pose()
		return 0.0
	if not ACTIONS.has(kind):
		return 0.0
	_action = kind
	_action_t = 0.0
	return ACTIONS[kind]


## How far the current action has gone (0 to 1; 0 when idle).
func action_progress() -> float:
	if _action == "idle":
		return 0.0
	return clampf(_action_t / float(ACTIONS[_action]), 0.0, 1.0)


## Where the weapon in the right hand is now: [hand, tip] in global space ([] without one).
## The tip is the corner of the weapon's box farthest from the hand.
func weapon_points() -> Array:
	var hand := part("hand_right")
	if hand == null or not hand.is_inside_tree():
		return []
	for id: String in _pieces:
		var mi: MeshInstance3D = _pieces[id]
		if not id.begins_with("weapon_") or mi.get_parent() != hand or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		var origin := hand.global_position
		var tip := origin
		var best := -1.0
		for i in 8:
			var corner := mi.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
			if corner.distance_to(origin) > best:
				best = corner.distance_to(origin)
				tip = corner
		return [origin, tip]
	return []


## How fast the walk cycle runs (speed / move_speed, clamped).
func walk_rate() -> float:
	return _rate


func current_action() -> String:
	return _action


## The action, or walk/idle when there is none.
func current_animation() -> String:
	if _action != "idle":
		return _action
	return "walk" if _speed >= WALK_MIN_SPEED else "idle"


func _process(delta: float) -> void:
	if auto_update:
		update(delta)


func update(delta: float) -> void:
	_time += delta
	if _speed >= WALK_MIN_SPEED:
		_phase += _speed * delta / STRIDE * TAU
	if _action != "idle":
		_action_t += delta
		if LOOPING.has(_action):
			_action_t = fmod(_action_t, float(ACTIONS[_action]))
		elif _action_t >= ACTIONS[_action] and not LASTING.has(_action):
			_action = "idle"
			_action_t = 0.0
	_pose()


func _setup(look: Dictionary) -> void:
	scale = Vector3.ONE * MODEL_SCALE
	_grip = str(look.get("grip", ""))
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var data := _load_rig()
	var parts: Dictionary = data.get("parts", {})
	var tints := {
		VoxMesher.TINT_SKIN: look.get("skin_color", Color.WHITE),
		VoxMesher.TINT_EYES: look.get("eyes_color", Color.BLACK),
		VoxMesher.TINT_HAIR: look.get("voxel_hair_color", look.get("hair_color", Color.BLACK)),
		VoxMesher.TINT_PRIMARY: look.get("primary", Color.GRAY),
		VoxMesher.TINT_SECONDARY: look.get("secondary", Color.GRAY),
		VoxMesher.TINT_TROUSERS: look.get("trousers", (look.get("primary", Color.GRAY) as Color).darkened(TROUSERS_DARKEN)),
	}
	var body_scale: Dictionary = look.get("body_scale", {})
	var torso_f := _factor(body_scale, "torso")
	var pivots := {}
	for part_name: String in parts:
		var p: Dictionary = parts[part_name]
		var pv: Array = p.get("pivot", [0, 0, 0])
		pivots[part_name] = Vector3(pv[0], pv[1], pv[2])
		var pivot := Node3D.new()
		pivot.name = part_name
		var scaler := Node3D.new()
		scaler.name = "Scale"
		scaler.scale = _factor(body_scale, SCALE_GROUP.get(part_name, ""))
		pivot.add_child(scaler)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = VoxMesher.cached(str(p.get("file", "")), tints)
		var off: Array = p.get("offset", [0, 0, 0])
		mesh.position = Vector3(off[0], off[1], off[2]) * VoxMesher.VOXEL_SIZE
		scaler.add_child(mesh)
		_parts[part_name] = pivot
		_meshes[part_name] = mesh
	for part_name: String in parts:
		var parent_name := str((parts[part_name] as Dictionary).get("parent", ""))
		var pivot: Node3D = _parts[part_name]
		var pos: Vector3 = pivots[part_name]
		if _in_arm(part_name):
			pos.x *= torso_f.x # broad shoulders carry the arms out
		if parent_name != "" and _parts.has(parent_name):
			var parent_pos: Vector3 = pivots[parent_name]
			if _in_arm(parent_name):
				parent_pos.x *= torso_f.x
			pivot.position = (pos - parent_pos) * VoxMesher.VOXEL_SIZE
			(_parts[parent_name] as Node3D).add_child(pivot)
		else:
			pivot.position = pos * VoxMesher.VOXEL_SIZE
			_body.add_child(pivot)
		_rest[part_name] = pivot.position
	for p: Dictionary in look.get("pieces", []):
		_attach_piece(p, tints)
	_pose()


func _attach_piece(p: Dictionary, tints: Dictionary) -> void:
	var host := part(str(p.get("part", "")))
	var mesh := VoxMesher.cached(str(p.get("file", "")), tints)
	if host == null or mesh == null:
		push_error("HumanRig: cannot attach piece %s" % p.get("id", "?"))
		return
	var node := MeshInstance3D.new()
	node.name = str(p.id)
	node.mesh = mesh
	var o: Array = p.get("offset", [0, 0, 0])
	node.position = Vector3(o[0], o[1], o[2]) * VoxMesher.VOXEL_SIZE
	host.add_child(node)
	_pieces[str(p.id)] = node


static func _in_arm(part_name: String) -> bool:
	return part_name.begins_with("arm_") or part_name.begins_with("forearm_") or part_name.begins_with("hand_")


static func _factor(body_scale: Dictionary, group: String) -> Vector3:
	var f: Array = body_scale.get(group, [1, 1, 1])
	return Vector3(f[0], f[1], f[2])


static func _load_rig() -> Dictionary:
	if _rig_data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIG))
		if parsed is Dictionary:
			_rig_data = parsed
		else:
			push_error("HumanRig: missing or bad %s" % RIG)
	return _rig_data


# --- Poses ---------------------------------------------------------------------------

func _pose() -> void:
	for part_name: String in _parts:
		var p: Node3D = _parts[part_name]
		p.rotation = Vector3.ZERO
		p.position = _rest[part_name]
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	var walk := clampf(_speed / 3.0, 0.0, 1.0) if _speed >= WALK_MIN_SPEED else 0.0
	_locomotion(walk)
	var k := clampf(_action_t / float(ACTIONS.get(_action, 1.0)), 0.0, 1.0)
	match _action:
		"melee": _melee(k)
		"shoot": _shoot(k)
		"cast": _cast(k)
		"cast_long": _cast_long()
		"dash": _dash(k)
		"downed": _fall(_ease(k), true)
		"die": _fall(_ease(k), false)


func _locomotion(walk: float) -> void:
	var swing := sin(_phase) * LEG_SWING * walk
	_rot("leg_left", swing)
	_rot("leg_right", -swing)
	_rot("arm_left", -swing * ARM_SWING / LEG_SWING)
	_rot("arm_right", swing * ARM_SWING / LEG_SWING)
	# The leg swinging forward bends at the knee; the elbows stay a little bent.
	_rot("shin_left", maxf(0.0, -sin(_phase)) * 0.9 * walk + 0.05)
	_rot("shin_right", maxf(0.0, sin(_phase)) * 0.9 * walk + 0.05)
	_rot("forearm_left", -0.18 - 0.25 * walk)
	_rot("forearm_right", -0.18 - 0.25 * walk)
	var breath := sin(_time * 2.0)
	(_parts["torso"] as Node3D).position.y += breath * 0.004 * (1.0 - walk)
	(_parts["torso"] as Node3D).rotation.y = sin(_phase) * 0.08 * walk
	(_parts["head"] as Node3D).rotation.x = sin(_time * 1.3) * 0.03
	(_parts["hips"] as Node3D).position.y += absf(sin(_phase)) * 0.04 * walk
	_rot("hand_left", 0.1)
	_rot("hand_right", 0.1)
	if _grip == "staff":
		# The staff leans forward and out, resting across the body like a walking stick
		# held at an angle, not standing straight up from the fist.
		_rot("hand_right", 1.3)
		(_parts["hand_right"] as Node3D).rotation.z = -0.25


## A full-body swing: weight back and the arm cocked over the shoulder, then a step forward with
## the hips and torso turning through the blow, the other arm swinging back, and a recovery.
## Keys at 0, 0.3 (cocked), 0.55 (end of the swing) and 1 (recovered).
func _melee(k: float) -> void:
	var arm := _keys(k, 0.0, -2.5, 0.6, 0.0)
	var twist := _keys(k, 0.0, 0.55, -0.6, 0.0)
	_rot("arm_right", arm)
	_rot("forearm_right", -1.1 * clampf(-arm / 2.5, 0.0, 1.0)) # cocked back, then straight
	(_parts["arm_right"] as Node3D).rotation.z = -absf(twist) * 0.6
	(_parts["torso"] as Node3D).rotation.y = twist
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.14, 0.36, 0.0) # leans back, then into the blow
	(_parts["hips"] as Node3D).rotation.y = _keys(k, 0.0, 0.25, -0.3, 0.0) # the hips lead the turn
	_rot("arm_left", _keys(k, 0.0, -0.7, 1.0, 0.0)) # the free arm balances the swing
	_rot("leg_left", _keys(k, 0.0, 0.2, -0.7, 0.0)) # the front leg steps forward
	_rot("leg_right", _keys(k, 0.0, -0.25, 0.55, 0.0))
	_rot("shin_left", _keys(k, 0.05, 0.1, 0.25, 0.05))
	_rot("shin_right", _keys(k, 0.05, 0.5, 0.75, 0.05)) # the back leg bends and pushes
	(_parts["head"] as Node3D).rotation.x = _keys(k, 0.0, 0.05, -0.14, 0.0)
	(_parts["head"] as Node3D).rotation.y = -twist * 0.5 # the eyes stay on the target
	_body.position.z = _keys(k, 0.0, -0.04, 0.18, 0.0) # a lunge
	_body.position.y = _keys(k, 0.0, 0.0, -0.07, 0.0) # sinking into the stance


## Eased interpolation through values at k = 0, 0.3, 0.55 and 1.
static func _keys(k: float, v0: float, v1: float, v2: float, v3: float) -> float:
	if k < 0.3:
		return lerpf(v0, v1, _ease(k / 0.3))
	if k < 0.55:
		return lerpf(v1, v2, _ease((k - 0.3) / 0.25))
	return lerpf(v2, v3, _ease((k - 0.55) / 0.45))


## Bow arm up level, draw the string back, hold, let go, lower.
func _shoot(k: float) -> void:
	var up := _ease(minf(k / 0.2, 1.0)) * (1.0 - _ease(clampf((k - 0.8) / 0.2, 0.0, 1.0)))
	var draw := _ease(clampf((k - 0.15) / 0.4, 0.0, 1.0)) if k < 0.7 else 0.0
	_rot("arm_left", -PI / 2.0 * up)
	_rot("forearm_left", -0.18 * (1.0 - up)) # the bow arm straightens
	_rot("hand_left", PI / 2.0 * up + 0.1 * (1.0 - up)) # the bow stays upright
	_rot("forearm_right", -1.7 * draw) # the string comes back to the cheek
	_rot("arm_right", -PI / 2.0 * up)
	(_parts["arm_right"] as Node3D).rotation.y = 0.7 * draw
	(_parts["torso"] as Node3D).rotation.y = 0.25 * up


## Both arms raised high gathering power, then thrust forward, then lowered.
func _cast(k: float) -> void:
	var arms := 0.0
	if k < 0.35:
		arms = lerpf(0.0, -2.8, _ease(k / 0.35))
	elif k < 0.6:
		arms = lerpf(-2.8, -1.5, _ease((k - 0.35) / 0.25))
	else:
		arms = lerpf(-1.5, 0.0, _ease((k - 0.6) / 0.4))
	_rot("arm_left", arms)
	_rot("arm_right", arms)
	_rot("forearm_left", 0.0)
	_rot("forearm_right", 0.0)
	_rot("hand_left", -arms) # staves and maces stay upright
	_rot("hand_right", -arms)
	(_parts["hand_right"] as Node3D).rotation.z = 0.0
	(_parts["head"] as Node3D).rotation.x = -0.15 * sin(k * PI)


## A long cast: both arms up gathering power, the staff spinning over the head, a slow sway.
func _cast_long() -> void:
	var sway := sin(_time * 3.0)
	_rot("arm_left", -2.7 + 0.12 * sway)
	_rot("arm_right", -2.7 - 0.12 * sway)
	_rot("forearm_left", 0.0)
	_rot("forearm_right", 0.0)
	_rot("hand_left", 2.7)
	_rot("hand_right", 2.7)
	(_parts["hand_right"] as Node3D).rotation.z = 0.0
	(_parts["hand_right"] as Node3D).rotation.y = _time * 7.0 # the staff spins
	(_parts["torso"] as Node3D).rotation.y = 0.18 * sway
	(_parts["head"] as Node3D).rotation.x = -0.2
	_body.position.y = 0.03 * sin(_time * 5.0)


## A low lunge: lean forward, arms back, legs in a long stride.
func _dash(k: float) -> void:
	var e := sin(k * PI)
	(_parts["torso"] as Node3D).rotation.x = 0.55 * e
	_rot("arm_left", 1.0 * e)
	_rot("arm_right", 1.0 * e)
	_rot("leg_left", -0.7 * e)
	_rot("leg_right", 0.8 * e)
	_rot("shin_left", 0.7 * e)
	_rot("shin_right", 0.3 * e)
	_body.position.y = -0.12 * e


## Tips over backwards onto the ground. Downed keeps an arm raised and the head up.
func _fall(e: float, downed: bool) -> void:
	_body.rotation.x = -PI / 2.0 * e
	_body.position.y = 0.25 * e
	_rot("leg_left", -0.25 * e)
	_rot("leg_right", 0.1 * e)
	_rot("shin_left", 0.6 * e if downed else 0.1 * e)
	if downed:
		_rot("arm_right", -1.2 * e)
		(_parts["head"] as Node3D).rotation.x = 0.5 * e
	else:
		(_parts["arm_left"] as Node3D).rotation.z = 0.9 * e
		(_parts["arm_right"] as Node3D).rotation.z = -0.9 * e
		(_parts["head"] as Node3D).rotation.y = 0.6 * e


func _rot(part_name: String, angle: float) -> void:
	(_parts[part_name] as Node3D).rotation.x = angle


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
