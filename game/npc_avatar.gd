class_name NpcAvatar
extends Node3D
## An NPC standing in the world (data/npcs): a HumanRig dressed from its "look", its
## name above it and a "[E] Hablar" prompt shown while the local player is in reach.

const NAME_HEIGHT := 2.25
const NAME_COLOR := Color("#ffd27a")

var rig: HumanRig
var npc_id: String = ""
var _label: Label3D
var _prompt: Label3D
## The quest sign over the head (Plan 8.2): "!", "!grey", "?" or "".
var _mark: Label3D
var _mark_kind: String = ""
var _name: String = ""


func setup(id: String, at: Vector3, facing: float) -> void:
	npc_id = id
	var data := NpcDB.load_default().npc(id)
	position = at
	rotation.y = facing
	rig = HumanRig.build(look_of(data.get("look", {})))
	add_child(rig)
	if data.has("pose"):
		rig.set_pose_now(str(data.pose)) # the wounded lie (Plan 8.3d)
	_name = tr(str(data.get("name", id)))
	_label = _text(_name, NAME_HEIGHT, 40, NAME_COLOR)
	_prompt = _text(tr("UI_HELP_PROMPT" if str(data.get("pose", "")) == "lie" else "UI_TALK_PROMPT"), NAME_HEIGHT + 0.3, 32, Color.WHITE)
	_prompt.visible = false
	_mark = _text("", NAME_HEIGHT + 0.75, 72, Color("#ffcc33"))
	_mark.outline_size = 14


## A HumanRig look from an NPC's data: a class and appearance resolved by the catalog,
## then its own colors and weapons; with "gear", dressed in those items.
static func look_of(look: Dictionary) -> Dictionary:
	var catalog := CharacterCatalog.load_default()
	# "gear": item bases in Inventory.VISIBLE order, worn like a player's (Plan 8.3e: Mira's cloak).
	var gear: Array = look.get("gear", []) if look.get("gear") is Array else []
	var out := catalog.resolve(str(look.get("class", CharacterCatalog.DEFAULT_CLASS)), look.get("appearance", {}), "", gear)
	for key: String in ["primary", "secondary", "trousers"]:
		if look.has(key):
			out[key] = Color(str(look[key]))
	# "pieces": the character's own outfit (Plan 8.3e: Mira), worn instead of its class's clothes.
	if look.has("pieces"):
		var own: Array = look.pieces
		var class_pieces: Array = catalog.class_def(str(look.get("class", CharacterCatalog.DEFAULT_CLASS))).get("pieces", [])
		var kept: Array = (out.pieces as Array).filter(func(p: Dictionary) -> bool: return not str(p.id) in class_pieces and str(p.id) != "bust_female")
		for id: String in own:
			if not catalog.piece_v2(id).is_empty():
				kept.append(catalog.piece_entry(id))
		out["pieces"] = kept
	if look.has("weapons"):
		var pieces: Array = (out.pieces as Array).filter(
			func(p: Dictionary) -> bool: return str(catalog.piece(p.id).get("tag", "")) != "weapon")
		for id: String in look.weapons:
			if not catalog.piece(id).is_empty():
				pieces.append(catalog.piece_entry(id)) # the v2 version, or the v1 one at double size
		out["pieces"] = pieces
	return out


## The quest sign for the local player: "!" a quest to take, "!grey" one at a higher level,
## "?" something to hand in or say, "" none.
func set_mark(kind: String) -> void:
	_mark_kind = kind
	if _mark == null:
		return
	_mark.text = "!" if kind.begins_with("!") else ("?" if kind == "?" else "")
	_mark.modulate = Color(0.6, 0.6, 0.6) if kind == "!grey" else Color("#ffcc33")


func mark_text() -> String:
	return _mark.text if _mark != null else ""


## Turns to look at a point on the ground (talking to the player, Plan 8.2).
func face(at: Vector3) -> void:
	var d := Vector2(at.x - position.x, at.z - position.z)
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.y)


## The prompt over its head (tests).
func prompt_text() -> String:
	return _prompt.text


func display_name() -> String:
	return _name


func set_prompt_visible(on: bool) -> void:
	if _prompt != null:
		_prompt.visible = on


func prompt_visible() -> bool:
	return _prompt != null and _prompt.visible


## An animal that walks the village (Plan 8.3d: the ranch's cows): a world piece, no rig,
## no name and nothing to say.
func setup_piece(piece_id: String, at: Vector3) -> void:
	npc_id = ""
	position = at
	var pieces: Variant = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.PIECES_PATH))
	var def: Dictionary = (pieces as Dictionary).get(piece_id, {}) if pieces is Dictionary else {}
	var mesh := VoxMesher.cached(str(def.get("vox", "")), {})
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Piece"
	mi.mesh = mesh
	var s := float(def.get("scale", 0.5))
	var off: Array = def.get("offset", [0, 0, 0])
	var size := mesh.get_aabb().size * s
	# Turned so it walks nose first (its length is along x), centred on its spot.
	mi.transform = Transform3D(Basis(Vector3.UP, -PI / 2.0).scaled(Vector3.ONE * s), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, Vector3(float(off[0]), float(off[1]), float(off[2])) * VoxMesher.VOXEL_SIZE - Vector3(size.x / s / 2.0, 0, size.z / s / 2.0))
	add_child(mi)


func _text(text: String, height: float, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = false
	l.no_depth_test = true
	l.pixel_size = 0.010
	l.font_size = font_size
	l.outline_size = 10
	l.position.y = height
	add_child(l)
	return l
