class_name HouseView
extends Node3D
## A walkable house (Plan 8.1.1): its floor and furniture, its walls, the same walls cut
## at 1 m, and its roof. When the own player steps inside, the roof fades out and the
## walls are cut, so the camera (which can turn) sees in from any side.

const FADE_S := 0.25
const LIGHT_COLOR := Color("#ffb066")

var open: bool = false
var _roof: MeshInstance3D
var _roof_material: StandardMaterial3D
var _fade := 1.0 # roof opacity


## Builds the parts of a pieces.json house entry; `place` is where the house stands.
func setup(def: Dictionary, place: Transform3D) -> void:
	transform = place
	var scale_f := float(def.get("scale", 1.0))
	var parts: Dictionary = def.get("parts", {})
	for pair: Array in [["floor", "Floor"], ["walls", "Walls"], ["walls_cut", "WallsCut"], ["roof", "Roof"]]:
		var part: Dictionary = parts.get(pair[0], {})
		var mi := MeshInstance3D.new()
		mi.name = pair[1]
		mi.mesh = VoxMesher.cached(str(part.get("vox", "")), {})
		var off: Array = part.get("offset", [0, 0, 0])
		mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * scale_f),
			Vector3(float(off[0]), float(off[1]), float(off[2])) * VoxMesher.VOXEL_SIZE * scale_f)
		add_child(mi)
	_roof = get_node("Roof")
	_roof_material = VoxMesher.material().duplicate()
	_roof_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	get_node("WallsCut").visible = false
	for cell: Array in def.get("lights", []):
		var light := OmniLight3D.new()
		light.light_color = LIGHT_COLOR
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = Vector3(float(cell[0]) + 0.5, 1.2, float(cell[1]) + 0.5)
		add_child(light)


## Houses cast shadow at MEDIUM and HIGH, none at LOW (like the other pieces).
func set_quality(q: int) -> void:
	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q >= GraphicsQuality.MEDIUM else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part: String in ["Floor", "Walls", "WallsCut", "Roof"]:
		(get_node(part) as GeometryInstance3D).cast_shadow = cast


func set_open(value: bool) -> void:
	if value == open:
		return
	open = value
	get_node("Walls").visible = not open
	get_node("WallsCut").visible = open
	_roof.visible = true
	_roof.material_override = _roof_material


func _process(delta: float) -> void:
	if _roof == null or _roof.material_override == null:
		return
	_fade = move_toward(_fade, 0.0 if open else 1.0, delta / FADE_S)
	_roof_material.albedo_color.a = _fade
	if _fade <= 0.0:
		_roof.visible = false
		_roof.material_override = null
	elif _fade >= 1.0:
		_roof.material_override = null # opaque again: the shared material
