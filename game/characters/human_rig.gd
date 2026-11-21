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
## The two bodies (look.body): v1, 49 voxels (monsters until Plan 6.4), and v2, 98 voxels
## of 1.8 cm (players and NPCs, Plan 6.2). Both are about 1.76 m tall.
const BODIES := {
	"v1": {"rig": RIG, "scale": MODEL_SCALE},
	"v2": {"rig": "res://assets/characters/vox_v2/human_v2.json", "scale": 0.18},
}
const DEFAULT_BODY := "v1"
const PARTS := ["hips", "torso", "head", "arm_left", "arm_right", "forearm_left", "forearm_right",
	"hand_left", "hand_right", "leg_left", "leg_right", "shin_left", "shin_right"]
## Which body_scale entry applies to each part.
const SCALE_GROUP := {
	"hips": "torso", "torso": "torso", "arm_left": "arm", "arm_right": "arm",
	"forearm_left": "arm", "forearm_right": "arm", "hand_left": "arm", "hand_right": "arm",
	"leg_left": "leg", "leg_right": "leg", "shin_left": "leg", "shin_right": "leg",
}
## Seconds each action lasts; downed and die then stay.
const ACTIONS := {"melee": 0.45, "shoot": 0.65, "cast": 0.6, "dash": 0.35, "downed": 0.5, "die": 0.7, "cast_long": 1.0,
	"stab_right": 0.32, "stab_left": 0.32, "overhead": 0.6, "spin": 0.6, "flurry": 0.7,
	"heavy": 0.55, "thrust": 0.45, "stab": 0.32}
const LASTING := ["downed", "die"]
## Melee swings (the weapon's path is traced by a SlashFx): action -> [start, end] of the swing in
## the animation, as a share of its length.
const SWINGS := {
	"melee": [0.26, 0.72], "stab_right": [0.2, 0.7], "stab_left": [0.2, 0.7], "overhead": [0.28, 0.75],
	"spin": [0.05, 0.97], "flurry": [0.04, 0.98], "heavy": [0.26, 0.72], "thrust": [0.26, 0.7], "stab": [0.2, 0.7],
}
## Basic melee attacks that chain three different swings (the same hit each time: only the
## animation changes). A pause longer than COMBO_RESET_S starts the chain over.
const COMBO_ACTIONS := ["melee", "heavy", "thrust", "stab"]
const COMBO_RESET_S := 1.2
## Actions that repeat until another one starts (a long cast: arms up, the staff spinning).
const LOOPING := ["cast_long"]
## Trousers default to the primary color this much darker.
const TROUSERS_DARKEN := 0.45
const WALK_MIN_SPEED := 0.2 # m/s
const STRIDE := 2.6 # meters per full leg cycle (two steps): about 2 strides/s at 5 m/s
const LEG_SWING := 0.8
const ARM_SWING := 0.5
const BOW_ARM := -0.75 # bow arm raised forward at rest...
const BOW_FOREARM := -0.55 # ...and bent, so the bow stands in front of the chest

static var _rig_data: Dictionary = {} # body -> parsed rig json

## Which body this rig uses (a key of BODIES).
var body: String = DEFAULT_BODY

var _body: Node3D # everything hangs from it; it tips over for downed and die
var _parts: Dictionary = {} # name -> Node3D (pivot)
var _meshes: Dictionary = {} # name -> MeshInstance3D
var _rest: Dictionary = {} # name -> rest position of the pivot
var _pieces: Dictionary = {} # piece id -> MeshInstance3D
## Race proportions (Plan 7): group -> [x, y, z]; they also scale the pieces of each part.
var _race_scale: Dictionary = {}
## Fit of the pieces worn on a race head of its own: {scale, offset (voxels)}.
var _head_fit: Dictionary = {}
## Cloth that follows the body (Plan 6.4.3): piece id -> {mode, node, anchor, span, drape, drape_v}.
var _cloth: Dictionary = {}
var _dt: float = 0.0 # the last update's step (the capes' spring)
var _speed: float = 0.0
var _rate: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0
var _action: String = "idle"
var _action_t: float = 0.0
## How the right hand holds its weapon at rest ("staff": leaning forward over the arm;
## "blade_down": a long sword held away from the robe, point down and forward).
var _grip: String = ""
var _bow_charging: bool = false
var _bow_drawn: bool = true # starts in the hand; _update_bow stows it
var _bow_hand_pos: Vector3 = Vector3.ZERO
## Step of the basic melee chain (0, 1, 2) and when the last link started (_time).
var _combo_step: int = 0
var _last_combo_time: float = -1000.0
## False when an avatar drives update() itself (from its state updates).
var auto_update: bool = true


## look: skin_color, eyes_color, hair_color, voxel_hair_color, primary, secondary,
## trousers (Color; trousers default to a darker primary); body_scale ({"torso"|"arm"|"leg": [x, y, z]}); pieces ([{id, file, part,
## offset: [x, y, z] voxels from the part's pivot}]).
## A character of a class with an appearance (ids; untrusted values are sanitized).
static func create(class_id: String, appearance: Dictionary, catalog: CharacterCatalog = null, upgrade: String = "",
		gear: Array = []) -> HumanRig:
	var cat := catalog if catalog != null else CharacterCatalog.load_default()
	return build(cat.resolve(class_id, appearance, upgrade, gear))


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
## combo: a basic melee attack, which chains three different swings (COMBO_ACTIONS).
func play_action(kind: String, combo: bool = false) -> float:
	if kind == "idle":
		_action = "idle"
		_action_t = 0.0
		_pose()
		return 0.0
	if not ACTIONS.has(kind):
		return 0.0
	if combo and kind in COMBO_ACTIONS:
		_combo_step = (_combo_step + 1) % 3 if _time - _last_combo_time <= COMBO_RESET_S else 0
		_last_combo_time = _time
	else:
		_combo_step = 0
		_last_combo_time = -1000.0
	_action = kind
	_action_t = 0.0
	return ACTIONS[kind]


## How far the current action has gone (0 to 1; 0 when idle).
func action_progress() -> float:
	if _action == "idle":
		return 0.0
	return clampf(_action_t / float(ACTIONS[_action]), 0.0, 1.0)


## Where the weapon in the hand ("right" or "left") is now: [hand, tip] in global space ([] without one).
## The tip is the corner of the weapon's box farthest from the hand.
func weapon_points(side: String = "right") -> Array:
	var hand := part("hand_" + side)
	if hand == null or not hand.is_inside_tree():
		return []
	for id: String in _pieces:
		var mi: MeshInstance3D = _pieces[id]
		if not (id.begins_with("weapon_") or id.begins_with("w_")) or mi.get_parent() != hand or mi.mesh == null:
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


## Step of the basic melee chain: 0, 1 or 2.
func combo_step() -> int:
	return _combo_step


## The hands whose weapons swing in the current attack (for the slash trails).
func combo_hands() -> Array:
	if _action == "stab":
		return [["right"], ["left"], ["right", "left"]][_combo_step]
	if _action == "stab_left":
		return ["left"]
	if _action in ["spin", "flurry"]:
		return ["right", "left"]
	return ["right"]


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
	_dt = delta
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
	body = str(look.get("body", DEFAULT_BODY))
	if not BODIES.has(body):
		body = DEFAULT_BODY
	scale = Vector3.ONE * float(BODIES[body].scale) * float(look.get("race_height", 1.0))
	_race_scale = look.get("race_scale", {})
	_head_fit = look.get("head_fit", {})
	_grip = str(look.get("grip", ""))
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var data := _load_rig(body)
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
		scaler.scale = _factor(body_scale, SCALE_GROUP.get(part_name, "")) * _factor(_race_scale, _group(part_name))
		pivot.add_child(scaler)
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var file := str(p.get("file", ""))
		var off: Array = p.get("offset", [0, 0, 0])
		if part_name == "head" and str(look.get("head_file", "")) != "":
			file = str(look.head_file) # a race head of its own (Plan 7)
			var ho: Array = look.get("head_offset", [])
			if ho.size() == 3:
				off = ho
		mesh.mesh = VoxMesher.cached(file, tints)
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
			# A race stretches each segment: the joint moves with the part it hangs from.
			pivot.position = (pos - parent_pos) * _factor(_race_scale, _group(parent_name)) * VoxMesher.VOXEL_SIZE
			(_parts[parent_name] as Node3D).add_child(pivot)
		else:
			pos.y *= _factor(_race_scale, "leg").y # the hips stand on the legs
			pivot.position = pos * VoxMesher.VOXEL_SIZE
			_body.add_child(pivot)
		_rest[part_name] = pivot.position
	for p: Dictionary in look.get("pieces", []):
		_attach_piece(p, tints)
	if _pieces.has("weapon_bow"):
		_bow_hand_pos = (_pieces["weapon_bow"] as Node3D).position
	var auras: Array = look.get("auras", [])
	if not auras.is_empty():
		_add_aura(auras[0])
	_pose()


## The glow of a tier 3 set: motes of light rising around the body and a faint ring on
## the ground, in the set's color. It does not follow the body's poses (it stays upright).
func _add_aura(color: Color) -> void:
	var aura := Node3D.new()
	aura.name = "Aura"
	add_child(aura)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	var motes := CPUParticles3D.new()
	motes.name = "Motes"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.09
	cube.material = mat
	motes.mesh = cube
	motes.amount = 34
	motes.lifetime = 1.6
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 1.7
	motes.emission_ring_inner_radius = 1.2
	motes.emission_ring_height = 0.1
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 2.6
	motes.initial_velocity_max = 4.2
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.9))
	fade.set_color(1, Color(color, 0.0))
	motes.color_ramp = fade
	motes.position.y = 0.3
	aura.add_child(motes)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 2.0
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.06
	var ring_mat := mat.duplicate() as StandardMaterial3D
	ring_mat.vertex_color_use_as_albedo = false
	ring_mat.albedo_color = Color(color, 0.35)
	ring.material_override = ring_mat
	aura.add_child(ring)


func _attach_piece(p: Dictionary, tints: Dictionary) -> void:
	var host := part(str(p.get("part", "")))
	var mesh := VoxMesher.cached(str(p.get("file", "")), tints)
	if host == null or mesh == null:
		push_error("HumanRig: cannot attach piece %s" % p.get("id", "?"))
		return
	var node := MeshInstance3D.new()
	node.name = str(p.id)
	node.mesh = mesh
	# A v1 piece worn by the v2 body is drawn twice as big (voxel_scale 2) until it has its v2 version.
	var vs := float(p.get("voxel_scale", 1.0))
	var part_name := str(p.get("part", ""))
	var f := _factor(_race_scale, _group(part_name)) # pieces follow the race, not the body type
	var fit := 1.0
	var fit_off := Vector3.ZERO
	var fit_def: Dictionary = p.get("fit", _head_fit) # a piece fitted to the race head, or the head fit
	if part_name == "head" and not fit_def.is_empty():
		fit = float(fit_def.get("scale", 1.0))
		var fo: Array = fit_def.get("offset", [0, 0, 0])
		fit_off = Vector3(fo[0], fo[1], fo[2])
	node.scale = Vector3.ONE * vs * fit * f
	var o: Array = p.get("offset", [0, 0, 0])
	node.position = (Vector3(o[0], o[1], o[2]) * vs * fit + fit_off) * VoxMesher.VOXEL_SIZE * f
	host.add_child(node)
	_pieces[str(p.id)] = node
	_setup_cloth(str(p.id), str(p.get("part", "")), node, o)


## The proportion group of a part (SCALE_GROUP, and the head of its own).
static func _group(part_name: String) -> String:
	return "head" if part_name == "head" else str(SCALE_GROUP.get(part_name, ""))


## The extra heads of a body (Plan 7 races): id -> {file, offset}.
static func rig_heads(body_id: String) -> Dictionary:
	if not BODIES.has(body_id):
		return {}
	return _load_rig(body_id).get("heads", {})


## Height of the standing model in metres, from its origin to the top of its highest part.
func height() -> float:
	var top := 0.0
	for part_name: String in _meshes:
		var mi: MeshInstance3D = _meshes[part_name]
		var t := Transform3D(Basis.from_scale(scale))
		var chain: Array[Node3D] = []
		var n: Node = mi
		while n != null and n != self:
			chain.push_front(n as Node3D)
			n = n.get_parent()
		for c: Node3D in chain:
			t = t * c.transform
		top = maxf(top, (t * mi.get_aabb()).end.y)
	return top


## Where the name and the bar float over the head.
func overhead_height() -> float:
	return height() + 0.5


static func _in_arm(part_name: String) -> bool:
	return part_name.begins_with("arm_") or part_name.begins_with("forearm_") or part_name.begins_with("hand_")


static func _factor(body_scale: Dictionary, group: String) -> Vector3:
	var f: Array = body_scale.get(group, [1, 1, 1])
	return Vector3(f[0], f[1], f[2])


static func _load_rig(body_id: String) -> Dictionary:
	if not _rig_data.has(body_id):
		var path := str(BODIES[body_id].rig)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_rig_data[body_id] = parsed
		else:
			push_error("HumanRig: missing or bad %s" % path)
			return {}
	return _rig_data[body_id]


# --- Poses ---------------------------------------------------------------------------

## The archer holds the bow only while charging a shot (and during the shot); otherwise it rides
## on the back.
func set_bow_charging(on: bool) -> void:
	_bow_charging = on


func bow_in_hand() -> bool:
	return _bow_drawn


func _update_bow() -> void:
	if _grip != "bow":
		return
	var bow: MeshInstance3D = _pieces.get("weapon_bow")
	if bow == null:
		return
	var want := _bow_charging or _action == "shoot"
	if want == _bow_drawn and bow.get_parent() != null:
		return
	_bow_drawn = want
	bow.get_parent().remove_child(bow)
	if want:
		(part("hand_left") as Node3D).add_child(bow)
		bow.basis = Basis.IDENTITY
		bow.position = _bow_hand_pos
	else:
		var torso := part("torso")
		torso.add_child(bow)
		# Flat across the back, slanted, with the belly of the bow facing away from the body.
		var b := Basis(Vector3.BACK, 0.55) * Basis(Vector3.UP, PI)
		var box := bow.mesh.get_aabb()
		var centre := box.position + box.size / 2.0
		var tm := _meshes["torso"] as MeshInstance3D
		var tbox := tm.mesh.get_aabb()
		var sc := (tm.get_parent() as Node3D).scale
		var target := tm.position + (tbox.position + tbox.size / 2.0) * sc
		target.z = tm.position.z + tbox.position.z * sc.z - box.size.z * 0.5 - 0.02
		bow.basis = b
		bow.position = target - b * centre


func _pose() -> void:
	_update_bow()
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
		# The basic chain: a side slash to the left, one back to the right, then a blow from above.
		"melee":
			match _combo_step:
				1: _side_slash(k, -1.0, false)
				2: _chop(k)
				_: _side_slash(k, 1.0, false)
		"heavy":
			match _combo_step:
				1: _side_slash(k, -1.0, true)
				2: _overhead(k)
				_: _side_slash(k, 1.0, true)
		"thrust":
			match _combo_step:
				1: _sweep(k)
				2: _thrust(k, 1.4)
				_: _thrust(k, 1.0)
		"stab":
			match _combo_step:
				1: _stab(k, false)
				2: _cross_stab(k)
				_: _stab(k, true)
		"shoot": _shoot(k)
		"cast": _cast(k)
		"cast_long": _cast_long()
		"stab_right": _stab(k, true)
		"stab_left": _stab(k, false)
		"overhead": _overhead(k)
		"spin": _spin(k)
		"flurry": _flurry(k)
		"dash": _dash(k)
		"downed": _fall(_ease(k), true)
		"die": _fall(_ease(k), false)
	_to_metres()
	_two_hand_ik()
	_update_cloth()
	_dt = 0.0


## Two-handed weapons (two_hand, polearm): how far below the right fist the left one holds
## the grip, in the hand's voxels along the weapon (toward the pommel).
const TWO_HAND_SPACING := {"two_hand": 7.0, "polearm": 12.0}


## Where the left fist should be on the weapon, in global space.
func _grip_point() -> Vector3:
	var hand := part("hand_right")
	var spacing := float(TWO_HAND_SPACING[_grip]) * VoxMesher.VOXEL_SIZE * (hand.get_child(0) as Node3D).scale.z
	return hand.global_transform * (_fist_centre("right") + Vector3(0, 0, -spacing))


## The centre of a fist in its hand's own space.
func _fist_centre(side: String) -> Vector3:
	var mesh := part_mesh("hand_" + side)
	var scaler := mesh.get_parent() as Node3D
	return (scaler.transform * mesh.transform) * mesh.get_aabb().get_center()


## The left arm reaches for the grip below the right fist (two-bone IK: the elbow bends
## down and out), and the left hand takes the right hand's angle so both close on the grip.
func _two_hand_ik() -> void:
	if not TWO_HAND_SPACING.has(_grip) or not is_inside_tree() or _action in LASTING:
		return
	var arm := part("arm_left")
	var fore := part("forearm_left")
	var hand := part("hand_left")
	var s := arm.global_position
	var l1 := fore.global_position.distance_to(s)
	var l2 := hand.global_position.distance_to(fore.global_position)
	# When the grip is out of the left arm's reach, the right arm swings in toward the left
	# shoulder (the weapon comes in front of the chest) until it is not.
	var arm_r := part("arm_right")
	var reach := (l1 + l2) * 0.97
	var wrist := _left_wrist_target()
	if wrist.distance_to(s) > reach:
		# The smallest turn that brings the grip in reach, found by bisection so it changes
		# smoothly from frame to frame (fixed steps made the arms flicker).
		var a := arm_r.global_position
		var axis := (wrist - a).cross(s - a)
		if not axis.is_zero_approx():
			axis = axis.normalized()
			var start := arm_r.global_basis
			var lo := 0.0
			var hi := 1.6
			for i in 14:
				var mid := (lo + hi) * 0.5
				arm_r.global_basis = Basis(axis, mid) * start
				if _left_wrist_target().distance_to(s) > reach:
					lo = mid
				else:
					hi = mid
			arm_r.global_basis = Basis(axis, hi) * start
			wrist = _left_wrist_target()
	var right_basis := part("hand_right").global_basis
	var to := wrist - s
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := to.normalized()
	var b := _body.global_basis
	var left := (b * Vector3(signf((_rest["arm_left"] as Vector3).x), 0, 0)).normalized()
	var pole := (b * Vector3.DOWN).normalized() + left * 0.7 - (b * Vector3.BACK).normalized() * 0.2
	var side := (pole - u * pole.dot(u)).normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var elbow := s + u * l1 * cos_a + side * l1 * sqrt(1.0 - cos_a * cos_a)
	_aim_bone(arm, fore.position, elbow - s)
	_aim_bone(fore, hand.position, s + u * d - elbow)
	hand.global_basis = right_basis


## Where the left wrist must be for the left fist to close on the grip (global).
func _left_wrist_target() -> Vector3:
	return _grip_point() - part("hand_right").global_basis * _fist_centre("left")


## Turns a bone so the direction to its child (`child_pos`, in its own space) points along
## `want` (global), keeping its scale.
func _aim_bone(bone: Node3D, child_pos: Vector3, want: Vector3) -> void:
	var have := (bone.global_basis * child_pos).normalized()
	if have.is_zero_approx() or want.is_zero_approx() or have.is_equal_approx(want.normalized()):
		return
	bone.global_basis = Basis(Quaternion(have, want.normalized())) * bone.global_basis


## How far the left fist is from its place on a two-handed grip (metres); -1 when the weapon
## is not held in two hands.
func left_grip_error() -> float:
	if not TWO_HAND_SPACING.has(_grip) or not is_inside_tree():
		return -1.0
	return (part("hand_left").global_transform * _fist_centre("left")).distance_to(_grip_point())


## The poses move the body, hips and torso in v1 rig units (lunges, breathing, the walk
## bob, falling); a finer body has a smaller rig scale, so its moves are scaled up to
## travel the same distance in metres.
func _to_metres() -> void:
	var f := MODEL_SCALE / float(BODIES[body].scale)
	if is_equal_approx(f, 1.0):
		return
	_body.position *= f
	for part_name: String in ["hips", "torso"]:
		var p: Node3D = _parts.get(part_name)
		if p != null:
			p.position = _rest[part_name] + (p.position - _rest[part_name]) * f


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
	if _grip == "bow" and _bow_drawn:
		# The bow is held out in front at chest height, upright, not dangling from the hand.
		_rot("arm_left", BOW_ARM - swing * 0.15)
		_rot("forearm_left", BOW_FOREARM)
		_rot("hand_left", -(BOW_ARM + BOW_FOREARM))
	if _grip == "staff":
		# The staff leans forward and out, resting across the body like a walking stick
		# held at an angle, not standing straight up from the fist.
		_rot("hand_right", 1.3)
		(_parts["hand_right"] as Node3D).rotation.z = -0.25
	elif _grip == "two_hand":
		# Both hands on the hilt in front of the hips, the blade raised forward.
		_rot("arm_right", -0.45)
		_rot("forearm_right", -0.9)
		_rot("arm_left", -0.55)
		_rot("forearm_left", -0.85)
		(_parts["arm_left"] as Node3D).rotation.z = -0.35
		_rot("hand_right", 0.55)
	elif _grip == "polearm":
		# The haft held across the body, the head up and forward.
		_rot("arm_right", -0.3)
		_rot("forearm_right", -0.7)
		_rot("hand_right", 0.35)
		_rot("arm_left", -0.6)
		_rot("forearm_left", -0.6)
		(_parts["arm_left"] as Node3D).rotation.z = -0.3
	elif _grip == "crossbow":
		# Carried low in both hands, pointing forward.
		_rot("arm_right", -0.35)
		_rot("forearm_right", -1.05)
		_rot("hand_right", 1.1)
		_rot("arm_left", -0.45)
		_rot("forearm_left", -0.9)
		(_parts["arm_left"] as Node3D).rotation.z = -0.3
	elif _grip == "blade_down":
		# The arm held a little away from the robe, the blade angled down and forward.
		(_parts["arm_right"] as Node3D).rotation.z = -0.35
		_rot("hand_right", 0.75 - 0.15 * walk)


## A side slash, the blade level and pointing out: wound up on one side, then swept across
## to the other by the hips, the torso and the arm (dir 1: toward the character's left,
## -1: back toward the right), with a step into it. both: the two hands on the hilt.
## Keys at 0, 0.3 (wound up), 0.55 (end of the slash) and 1 (recovered).
func _side_slash(k: float, dir: float, both: bool) -> void:
	var left := signf((_rest["arm_left"] as Vector3).x) # the character's left, in rig x
	var sweep := left * dir
	var arm := _keys(k, 0.0, -1.45, -1.45, 0.0) # raised level in front
	_rot("arm_right", arm)
	_rot("forearm_right", _keys(k, -0.18, -0.35, -0.1, -0.18))
	_rot("hand_right", _keys(k, 0.1, 1.35, 1.35, 0.1)) # the blade points out, not up
	(_parts["arm_right"] as Node3D).rotation.y = _keys(k, 0.0, -0.6 * sweep, 0.7 * sweep, 0.0)
	# Wound up far round (about 70 degrees), then the whole body turns through the blow.
	var twist := _keys(k, 0.0, -1.2 * sweep, 1.0 * sweep, 0.0)
	(_parts["torso"] as Node3D).rotation.y = twist
	(_parts["hips"] as Node3D).rotation.y = twist * 0.55 # the hips lead the turn
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.15, 0.32, 0.0) # weight back, then into it
	(_parts["torso"] as Node3D).rotation.z = sweep * _keys(k, 0.0, 0.12, -0.15, 0.0) # the shoulders tilt with the swing
	if both:
		_rot("arm_left", arm)
		_rot("forearm_left", _keys(k, -0.85, -0.6, -0.3, -0.85))
		(_parts["arm_left"] as Node3D).rotation.y = _keys(k, 0.0, -0.6 * sweep, 0.7 * sweep, 0.0)
	else:
		_rot("arm_left", _keys(k, 0.0, 0.5, -0.6, 0.0)) # the free arm balances the slash
	var front := "leg_left" if dir > 0.0 else "leg_right"
	var back := "leg_right" if dir > 0.0 else "leg_left"
	_rot(front, _keys(k, 0.0, 0.25, -0.9, 0.0)) # a long step into the slash
	_rot(back, _keys(k, 0.0, -0.3, 0.7, 0.0))
	_rot("shin_" + back.trim_prefix("leg_"), _keys(k, 0.05, 0.55, 0.95, 0.05))
	(_parts["head"] as Node3D).rotation.y = -twist * 0.5 # the eyes stay on the target
	_body.position.z = _keys(k, 0.0, -0.06, 0.26, 0.0)
	_body.position.y = _keys(k, 0.0, 0.0, -0.12 if not both else -0.15, 0.0)


## The third link: a downward blow with one hand, the weight dropping into it.
func _chop(k: float) -> void:
	_rot("arm_right", _keys(k, 0.0, -2.9, 0.3, 0.0))
	_rot("forearm_right", _keys(k, -0.18, -0.8, -0.05, -0.18))
	_rot("arm_left", _keys(k, 0.0, -0.4, 0.6, 0.0))
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.45, 0.65, 0.0) # far back, then far into it
	(_parts["torso"] as Node3D).rotation.y = _keys(k, 0.0, 0.3, -0.15, 0.0)
	(_parts["head"] as Node3D).rotation.x = _keys(k, 0.0, 0.12, -0.18, 0.0)
	_rot("leg_left", _keys(k, 0.0, 0.15, -0.6, 0.0))
	_rot("leg_right", _keys(k, 0.0, -0.1, 0.5, 0.0))
	_rot("shin_right", _keys(k, 0.05, 0.3, 0.8, 0.05))
	_body.position.y = _keys(k, 0.0, 0.04, -0.15, 0.0)
	_body.position.z = _keys(k, 0.0, -0.06, 0.26, 0.0)


## A straight two-handed thrust with a polearm; reach > 1 lunges deeper.
func _thrust(k: float, reach: float) -> void:
	var arms := _keys(k, -0.3, 0.3, -1.45, -0.3)
	_rot("arm_right", arms)
	_rot("arm_left", arms - 0.2)
	_rot("forearm_right", _keys(k, -0.7, -1.4, -0.05, -0.7))
	_rot("forearm_left", _keys(k, -0.6, -1.2, -0.05, -0.6))
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.1, 0.3 * reach, 0.0)
	(_parts["torso"] as Node3D).rotation.y = _keys(k, 0.0, 0.3, -0.2, 0.0)
	_rot("leg_left", _keys(k, 0.0, 0.15, -0.65 * reach, 0.0))
	_rot("leg_right", _keys(k, 0.0, -0.2, 0.5 * reach, 0.0))
	_rot("shin_right", _keys(k, 0.05, 0.45, 0.8, 0.05))
	_body.position.z = _keys(k, 0.0, -0.06, 0.24 * reach, 0.0)
	_body.position.y = _keys(k, 0.0, 0.0, -0.08 * reach, 0.0)


## A low sweep of the polearm from side to side.
func _sweep(k: float) -> void:
	var twist := _keys(k, 0.0, 0.75, -0.8, 0.0)
	_rot("arm_right", _keys(k, -0.3, -1.0, -0.8, -0.3))
	_rot("arm_left", _keys(k, -0.6, -1.1, -0.9, -0.6))
	(_parts["arm_right"] as Node3D).rotation.z = _keys(k, 0.0, 0.4, -0.8, 0.0)
	(_parts["torso"] as Node3D).rotation.y = twist
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, 0.05, 0.35, 0.0)
	(_parts["hips"] as Node3D).rotation.y = twist * 0.5
	_rot("leg_left", _keys(k, 0.0, 0.2, -0.5, 0.0))
	_rot("shin_right", _keys(k, 0.05, 0.6, 0.9, 0.05))
	_body.position.y = _keys(k, 0.0, -0.04, -0.14, 0.0)


## Both daggers driven in together, crossing in front of the chest.
func _cross_stab(k: float) -> void:
	for side: String in ["right", "left"]:
		_rot("arm_" + side, _keys(k, 0.0, 0.5, -1.45, 0.0))
		_rot("forearm_" + side, _keys(k, -0.18, -1.2, -0.1, -0.18))
	(_parts["arm_right"] as Node3D).rotation.z = _keys(k, 0.0, -0.3, 0.35, 0.0)
	(_parts["arm_left"] as Node3D).rotation.z = _keys(k, 0.0, 0.3, -0.35, 0.0)
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.1, 0.35, 0.0)
	_rot("leg_left", _keys(k, 0.0, 0.1, -0.6, 0.0))
	_rot("leg_right", _keys(k, 0.0, -0.2, 0.45, 0.0))
	_rot("shin_right", _keys(k, 0.05, 0.45, 0.7, 0.05))
	_body.position.z = _keys(k, 0.0, -0.04, 0.24, 0.0)
	_body.position.y = _keys(k, 0.0, 0.0, -0.06, 0.0)


## A quick thrust with one hand (the other guards), a step into it and a turn of the torso.
func _stab(k: float, right: bool) -> void:
	var s := 1.0 if right else -1.0
	var arm := "arm_right" if right else "arm_left"
	var fore := "forearm_right" if right else "forearm_left"
	var guard := "arm_left" if right else "arm_right"
	_rot(arm, _keys(k, 0.0, 0.5, -1.55, 0.0)) # the elbow pulls back, then the arm shoots out
	_rot(fore, _keys(k, -0.18, -1.2, -0.1, -0.18))
	_rot(guard, _keys(k, 0.0, 0.5, 0.7, 0.0))
	(_parts["torso"] as Node3D).rotation.y = s * _keys(k, 0.0, 0.3, -0.38, 0.0)
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.06, 0.3, 0.0)
	(_parts["hips"] as Node3D).rotation.y = s * _keys(k, 0.0, 0.18, -0.22, 0.0)
	_rot("leg_left" if right else "leg_right", _keys(k, 0.0, 0.1, -0.55, 0.0))
	_rot("leg_right" if right else "leg_left", _keys(k, 0.0, -0.2, 0.4, 0.0))
	_rot("shin_right" if right else "shin_left", _keys(k, 0.05, 0.4, 0.6, 0.05))
	(_parts["head"] as Node3D).rotation.y = -s * _keys(k, 0.0, 0.1, -0.3, 0.0)
	_body.position.z = _keys(k, 0.0, -0.03, 0.22, 0.0)
	_body.position.y = _keys(k, 0.0, 0.0, -0.05, 0.0)


## A heavy blow from above with both arms: up, a wide stance, then down with the whole weight.
func _overhead(k: float) -> void:
	var arms := _keys(k, 0.0, -2.9, 0.5, 0.0)
	_rot("arm_right", arms)
	_rot("arm_left", arms)
	_rot("forearm_right", _keys(k, -0.18, -0.5, -0.1, -0.18))
	_rot("forearm_left", _keys(k, -0.18, -0.5, -0.1, -0.18))
	(_parts["torso"] as Node3D).rotation.x = _keys(k, 0.0, -0.45, 0.65, 0.0)
	(_parts["head"] as Node3D).rotation.x = _keys(k, 0.0, 0.15, -0.2, 0.0)
	_rot("leg_left", _keys(k, 0.0, 0.2, -0.5, 0.0))
	_rot("leg_right", _keys(k, 0.0, -0.1, 0.45, 0.0))
	_rot("shin_right", _keys(k, 0.05, 0.3, 0.9, 0.05))
	_body.position.y = _keys(k, 0.0, 0.04, -0.17, 0.0)
	_body.position.z = _keys(k, 0.0, -0.06, 0.26, 0.0)


## A full turn on the spot with the arms out, the weapons sweeping a circle around the body.
func _spin(k: float) -> void:
	var out := sin(clampf(k, 0.0, 1.0) * PI) # arms open and close with the turn
	_body.rotation.y = TAU * _ease(clampf((k - 0.05) / 0.9, 0.0, 1.0))
	(_parts["arm_right"] as Node3D).rotation.z = -1.45 * out
	(_parts["arm_left"] as Node3D).rotation.z = 1.45 * out
	_rot("arm_right", -0.25 * out)
	_rot("arm_left", -0.25 * out)
	(_parts["torso"] as Node3D).rotation.x = 0.22 * out
	_rot("leg_left", -0.35 * out)
	_rot("leg_right", 0.3 * out)
	_rot("shin_right", 0.5 * out)
	_body.position.y = -0.06 * out


## Four quick strikes, hand after hand: each one a short thrust, the body riding from one to the next.
func _flurry(k: float) -> void:
	var phase := clampf(k, 0.0, 0.9999) * 4.0
	var index := int(floor(phase))
	_stab(phase - float(index), index % 2 == 0)
	_body.rotation.y = 0.12 * sin(phase * PI)


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
	var bow_rest := _grip == "bow"
	var arm_rest := BOW_ARM if bow_rest else 0.0
	var fore_rest := BOW_FOREARM if bow_rest else -0.18
	var hand_rest := -(BOW_ARM + BOW_FOREARM) if bow_rest else 0.1
	_rot("arm_left", lerpf(arm_rest, -PI / 2.0, up))
	_rot("forearm_left", fore_rest * (1.0 - up)) # the bow arm straightens
	_rot("hand_left", lerpf(hand_rest, PI / 2.0, up)) # the bow stays upright
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


# --- Cloth that follows the body (Plan 6.4.3) ------------------------------------------------

const CLOTH_NONE := 0
const CLOTH_SKIRT := 1 ## below the waist each side turns with its leg (robes, skirts, tabards)
const CLOTH_CAPE := 2 ## behind and below its anchor it swings back as the body moves
## Pieces that hang like a cape, with their anchor in their part's frame (voxels): where the
## cloth starts to hang (the shoulders, the nape).
const CAPE_ANCHORS := {"hood_archer": Vector3(0, -2, -6), "hood_cleric": Vector3(0, 26, -6), "vaelthar_mane": Vector3(0, 4, -7)}
const CAPE_ANCHOR_TORSO := Vector3(0, 24, -5) # every "*_cape" of the gear
## A torso piece reaching this far below the waist (voxels) is a skirt.
const SKIRT_BELOW := -6
static var _cloth_material: ShaderMaterial
static var _cloth_glow_material: ShaderMaterial


static func cloth_material(glow: bool) -> ShaderMaterial:
	if _cloth_material == null:
		_cloth_material = ShaderMaterial.new()
		_cloth_material.shader = load("res://game/characters/cloth.gdshader")
		_cloth_glow_material = ShaderMaterial.new()
		_cloth_glow_material.shader = load("res://game/characters/cloth_glow.gdshader")
	return _cloth_glow_material if glow else _cloth_material


static func _cloth_mode_for(id: String, part_name: String, offset: Array) -> int:
	if CAPE_ANCHORS.has(id) or id.ends_with("_cape"):
		return CLOTH_CAPE
	if part_name == "hips":
		return CLOTH_SKIRT
	if part_name == "torso" and float(offset[1]) < SKIRT_BELOW:
		return CLOTH_SKIRT
	return CLOTH_NONE


func _setup_cloth(id: String, part_name: String, node: MeshInstance3D, offset: Array) -> void:
	var mode := _cloth_mode_for(id, part_name, offset)
	if mode == CLOTH_NONE:
		return
	for i in node.mesh.get_surface_count():
		node.set_surface_override_material(i, cloth_material(node.mesh.surface_get_material(i) == VoxMesher.glow_material()))
	var c := {"mode": mode, "node": node, "anchor": Vector3.ZERO, "span": 1.0, "drape": 0.0, "drape_v": 0.0}
	if mode == CLOTH_CAPE:
		var a: Vector3 = CAPE_ANCHORS.get(id, CAPE_ANCHOR_TORSO)
		c.anchor = (a * VoxMesher.VOXEL_SIZE - node.position) / node.scale.x # into the mesh's own space
		c.span = maxf(c.anchor.y - node.mesh.get_aabb().position.y, 0.1)
	node.set_instance_shader_parameter("cloth_mode", mode)
	_cloth[id] = c


## How a piece moves with the body: CLOTH_NONE, CLOTH_SKIRT or CLOTH_CAPE.
func cloth_mode(id: String) -> int:
	return int(_cloth[id].mode) if _cloth.has(id) else CLOTH_NONE


## The parameters the cloth shader got for a piece this frame (in the piece's mesh space).
func cloth_params(id: String) -> Dictionary:
	if not _cloth.has(id):
		return {}
	var node: MeshInstance3D = _cloth[id].node
	var out := {"mode": int(_cloth[id].mode)}
	for key: String in ["hip_l", "hip_r", "ang_l", "ang_r", "waist_y", "span", "anchor", "drape"]:
		out[key] = node.get_instance_shader_parameter(key)
	return out


func _update_cloth() -> void:
	if _cloth.is_empty() or not is_inside_tree():
		return
	for id: String in _cloth:
		var c: Dictionary = _cloth[id]
		var node: MeshInstance3D = c.node
		var to_mesh := node.global_transform.affine_inverse()
		if int(c.mode) == CLOTH_SKIRT:
			var hips := {}
			for side: String in ["left", "right"]:
				var leg := part("leg_" + side)
				var hip := to_mesh * leg.global_position
				var down := (to_mesh.basis * (leg.global_basis * Vector3.DOWN)).normalized()
				hips[side] = [hip, atan2(-down.z, -down.y)]
				if side == "left":
					node.set_instance_shader_parameter("span", (to_mesh * part("shin_left").global_position).distance_to(hip))
			node.set_instance_shader_parameter("hip_l", hips.left[0])
			node.set_instance_shader_parameter("hip_r", hips.right[0])
			node.set_instance_shader_parameter("ang_l", hips.left[1])
			node.set_instance_shader_parameter("ang_r", hips.right[1])
			node.set_instance_shader_parameter("waist_y", maxf((hips.left[0] as Vector3).y, (hips.right[0] as Vector3).y) + 0.3)
		else:
			# A spring pulls the drape towards how fast the body moves (back when running),
			# with a little sway at rest.
			var target := clampf(_speed / 4.0, 0.0, 1.0) * 0.6 + sin(_time * 1.7) * 0.03
			# Small steps keep the spring stable through a long frame (a load, a shader compile).
			var left := _dt
			while left > 0.0:
				var dt := minf(left, 1.0 / 60.0)
				left -= dt
				c.drape_v = float(c.drape_v) + ((target - float(c.drape)) * 40.0 - float(c.drape_v) * 9.0) * dt
				c.drape = clampf(float(c.drape) + float(c.drape_v) * dt, -0.2, 1.0)
			node.set_instance_shader_parameter("anchor", c.anchor)
			node.set_instance_shader_parameter("span", c.span)
			node.set_instance_shader_parameter("drape", c.drape)


## The flash over a cloth piece when it is hit: white, fading with the flash's alpha, bent like the
## cloth (a plain overlay would show the robe rigid through the legs).
static func cloth_flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://game/characters/cloth_flash.gdshader")
	return m


## The cloth shader's deformation on the CPU (the same maths as cloth.gdshaderinc).
static func cloth_deform(v: Vector3, p: Dictionary) -> Vector3:
	var mode := int(p.get("mode", CLOTH_NONE))
	if mode == CLOTH_SKIRT and v.y < float(p.waist_y):
		var k := clampf((float(p.waist_y) - v.y) / maxf(float(p.span), 0.001), 0.0, 1.0)
		var hl: Vector3 = p.hip_l
		var hr: Vector3 = p.hip_r
		var w := hl.x - hr.x
		var t := 0.5 if absf(w) < 0.001 else clampf((v.x - hr.x) / w, 0.0, 1.0)
		var pivot := hr.lerp(hl, t)
		return pivot + _rot_x(v - pivot, lerpf(float(p.ang_r), float(p.ang_l), t) * k)
	if mode == CLOTH_CAPE:
		var an: Vector3 = p.anchor
		if v.y < an.y and v.z < an.z + 0.3:
			var k := clampf((an.y - v.y) / maxf(float(p.span), 0.001), 0.0, 1.0)
			return an + _rot_x(v - an, float(p.drape) * k)
	return v


static func _rot_x(d: Vector3, a: float) -> Vector3:
	return Vector3(d.x, d.y * cos(a) - d.z * sin(a), d.y * sin(a) + d.z * cos(a))
