class_name CharacterRig
extends Node3D
## A voxel character: Kenney's six-part model with the layered texture shader, body
## proportions and voxel pieces attached to its parts (they follow the animations).
## Built from a resolved "look" (paths, colors, pieces); CharacterCatalog turns a class
## and an appearance into a look.

const BASE_MODEL := "res://assets/characters/base/character-a.glb"
const SHADER := preload("res://assets/characters/character.gdshader")
const MODEL_SCALE := 0.667
const PARTS := ["torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]
## Which body_scale entry applies to each part.
const SCALE_GROUP := {"torso": "torso", "arm-left": "arm", "arm-right": "arm", "leg-left": "leg", "leg-right": "leg"}

static var _blank: ImageTexture

var _parts: Dictionary = {} # name -> MeshInstance3D
var _pieces: Dictionary = {} # piece id -> MeshInstance3D
var _material: ShaderMaterial
var animation_player: AnimationPlayer


## look: skin_color, eyes_color, hair_color, primary, secondary (Color);
## hair_layer, beard_layer, outfit_layer (res:// path or ""); body_scale
## ({"torso"|"arm"|"leg": [x, y, z]}); pieces ([{id, file, part, offset: [x, y, z]}]).
## A character of a class with an appearance (ids; untrusted values are sanitized).
static func create(class_id: String, appearance: Dictionary, catalog: CharacterCatalog = null) -> CharacterRig:
	var cat := catalog if catalog != null else CharacterCatalog.load_default()
	return build(cat.resolve(class_id, appearance))


static func build(look: Dictionary) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.name = "Character"
	rig._setup(look)
	return rig


const WALK_MIN_SPEED := 0.2 # m/s
const BLEND_S := 0.15


## Plays idle or walk for this ground speed; walk runs at speed / move_speed.
func set_moving_speed(speed_mps: float, move_speed: float) -> void:
	if animation_player == null:
		return
	var walking := speed_mps >= WALK_MIN_SPEED
	var anim := "walk" if walking else "idle"
	if animation_player.current_animation != anim:
		animation_player.play(anim, BLEND_S)
	animation_player.speed_scale = clampf(speed_mps / maxf(move_speed, 0.01), 0.2, 2.0) if walking else 1.0


func current_animation() -> String:
	return animation_player.current_animation if animation_player != null else ""


func part(part_name: String) -> MeshInstance3D:
	return _parts.get(part_name)


func piece_node(id: String) -> MeshInstance3D:
	return _pieces.get(id)


func pieces() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_pieces.keys())
	return ids


func _setup(look: Dictionary) -> void:
	scale = Vector3.ONE * MODEL_SCALE
	var model: Node3D = (load(BASE_MODEL) as PackedScene).instantiate()
	add_child(model)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("skin_tex", _texture("res://assets/characters/layers/skin.png"))
	_material.set_shader_parameter("face_tex", _texture("res://assets/characters/layers/face.png"))
	_material.set_shader_parameter("eyes_tex", _texture("res://assets/characters/layers/eyes.png"))
	_material.set_shader_parameter("brows_tex", _texture("res://assets/characters/layers/brows.png"))
	_material.set_shader_parameter("hair_tex", _texture(look.get("hair_layer", "")))
	_material.set_shader_parameter("beard_tex", _texture(look.get("beard_layer", "")))
	_material.set_shader_parameter("outfit_tex", _texture(look.get("outfit_layer", "")))
	_material.set_shader_parameter("skin_color", look.get("skin_color", Color.WHITE))
	_material.set_shader_parameter("eyes_color", look.get("eyes_color", Color.BLACK))
	_material.set_shader_parameter("hair_color", look.get("hair_color", Color.BLACK))
	for part_name: String in PARTS:
		var mesh := model.find_child(part_name, true, false) as MeshInstance3D
		if mesh == null:
			push_error("CharacterRig: part %s missing in %s" % [part_name, BASE_MODEL])
			continue
		_parts[part_name] = mesh
		for s in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(s, _material)
	_apply_body_scale(look.get("body_scale", {}))
	var tints := {
		VoxMesher.TINT_HAIR: look.get("voxel_hair_color", look.get("hair_color", Color.BLACK)),
		VoxMesher.TINT_PRIMARY: look.get("primary", Color.GRAY),
		VoxMesher.TINT_SECONDARY: look.get("secondary", Color.GRAY),
	}
	for p: Dictionary in look.get("pieces", []):
		_attach_piece(p, tints)


func _attach_piece(p: Dictionary, tints: Dictionary) -> void:
	var host := part(str(p.get("part", "")))
	var mesh := VoxMesher.cached(str(p.get("file", "")), tints)
	if host == null or mesh == null:
		push_error("CharacterRig: cannot attach piece %s" % p.get("id", "?"))
		return
	var node := MeshInstance3D.new()
	node.name = str(p.id)
	node.mesh = mesh
	# One voxel is VoxMesher.VOXEL_SIZE model units whatever the scale the part has in
	# the model (the head is scaled by 0.1, the torso by the body type).
	var inv := Vector3.ONE / _scale_in_model(host)
	node.scale = inv
	var o: Array = p.get("offset", [0, 0, 0])
	node.position = Vector3(o[0], o[1], o[2]) * VoxMesher.VOXEL_SIZE * inv
	host.add_child(node)
	_pieces[str(p.id)] = node


## Widens parts by body type. The arms and the head hang from the torso, so they undo
## the torso's factor and keep only their own.
func _apply_body_scale(body_scale: Dictionary) -> void:
	var factors := {}
	for part_name: String in _parts:
		var group: String = SCALE_GROUP.get(part_name, "")
		var f: Array = body_scale.get(group, [1, 1, 1])
		factors[part_name] = Vector3(f[0], f[1], f[2])
	var torso := part("torso")
	var torso_factor: Vector3 = factors.get("torso", Vector3.ONE)
	for part_name: String in _parts:
		var mesh: MeshInstance3D = _parts[part_name]
		var factor: Vector3 = factors[part_name]
		if torso != null and mesh.get_parent() == torso:
			factor /= torso_factor
		mesh.scale *= factor


## Product of the scales from `node` up to (not including) this rig.
func _scale_in_model(node: Node3D) -> Vector3:
	var s := Vector3.ONE
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			s *= (n as Node3D).scale
		n = n.get_parent()
	return s


static func _texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	if _blank == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank = ImageTexture.create_from_image(img)
	return _blank
