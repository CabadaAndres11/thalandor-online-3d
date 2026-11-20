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
var _name: String = ""


func setup(id: String, at: Vector3, facing: float) -> void:
	npc_id = id
	var data := NpcDB.load_default().npc(id)
	position = at
	rotation.y = facing
	rig = HumanRig.build(look_of(data.get("look", {})))
	add_child(rig)
	_name = tr(str(data.get("name", id)))
	_label = _text(_name, NAME_HEIGHT, 40, NAME_COLOR)
	_prompt = _text(tr("CLASS_CHOICE_TALK"), NAME_HEIGHT + 0.3, 32, Color.WHITE)
	_prompt.visible = false


## A HumanRig look from an NPC's data: a class and appearance resolved by the catalog,
## then its own colors and weapons.
static func look_of(look: Dictionary) -> Dictionary:
	var catalog := CharacterCatalog.load_default()
	var out := catalog.resolve(str(look.get("class", CharacterCatalog.DEFAULT_CLASS)), look.get("appearance", {}))
	for key: String in ["primary", "secondary", "trousers"]:
		if look.has(key):
			out[key] = Color(str(look[key]))
	if look.has("weapons"):
		var pieces: Array = (out.pieces as Array).filter(
			func(p: Dictionary) -> bool: return str(catalog.piece(p.id).get("tag", "")) != "weapon")
		for id: String in look.weapons:
			if not catalog.piece(id).is_empty():
				pieces.append(catalog.piece_entry(id)) # the v2 version, or the v1 one at double size
		out["pieces"] = pieces
	return out


func display_name() -> String:
	return _name


func set_prompt_visible(on: bool) -> void:
	_prompt.visible = on


func prompt_visible() -> bool:
	return _prompt.visible


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
