class_name PlayerAvatar
extends Node3D
## A player in the world: their voxel character (CharacterRig), their name above it in
## their slot color and an aim arrow on the ground. Plays idle or walk from how fast
## its drawn position moves.

const SLOT_COLORS := [Color("#E5533D"), Color("#3D8BE5"), Color("#4CC26A"), Color("#E5C33D")]
const NAME_HEIGHT := 2.25
const ARROW_DISTANCE := 0.75
## Speed smoothing time constant: drawn positions of the own player only change on
## physics ticks, so raw per-frame speed alternates between 0 and double.
const SPEED_SMOOTHING_S := 0.1
## A jump longer than this in one frame (spawn, big correction) is not walking.
const TELEPORT_DISTANCE := 2.0

var rig: CharacterRig
## Walk animation plays at real speed / move_speed (set from balance by the game).
var move_speed: float = 5.0

var _label: Label3D
var _last_position: Variant = null
var _speed: float = 0.0


func setup(player_name: String, slot: int, class_id: String, appearance: Dictionary) -> void:
	var color: Color = SLOT_COLORS[clampi(slot, 0, SLOT_COLORS.size() - 1)]
	rig = CharacterRig.create(class_id, appearance)
	add_child(rig)
	rig.set_moving_speed(0.0, move_speed)

	var arrow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.7, 0.05)
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = color.lightened(0.4)
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prism.material = arrow_mat
	arrow.mesh = prism
	# Lay the prism flat on the ground with its tip pointing to local +Z, in front of the body.
	arrow.rotation_degrees = Vector3(90, 0, 0)
	arrow.position = Vector3(0, 0.03, ARROW_DISTANCE)
	add_child(arrow)

	_label = Label3D.new()
	_label.text = player_name
	_label.modulate = color.lightened(0.5)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.pixel_size = 0.0008
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = NAME_HEIGHT
	add_child(_label)


## state: {"position", "aim", "facing"} from the client ({} = unknown yet).
func apply_state(state: Dictionary, delta: float) -> void:
	var measured := 0.0
	if not state.is_empty():
		var pos: Vector3 = state.position
		if _last_position != null and delta > 0.0:
			var step := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length()
			if step > TELEPORT_DISTANCE:
				_speed = 0.0 # a jump, not movement
			else:
				measured = step / delta
		_last_position = pos
		position = pos
		rotation.y = state.facing
	if delta > 0.0:
		_speed = lerpf(_speed, measured, 1.0 - exp(-delta / SPEED_SMOOTHING_S))
	if rig != null:
		rig.set_moving_speed(_speed, move_speed)
