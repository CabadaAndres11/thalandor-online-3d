class_name PlayerAvatar
extends Node3D
## Placeholder player: a colored capsule with its name above and an aim arrow on the ground.

const SLOT_COLORS := [Color("#E5533D"), Color("#3D8BE5"), Color("#4CC26A"), Color("#E5C33D")]
const HEIGHT := 1.8
const RADIUS := 0.4

var _label: Label3D
var _body: MeshInstance3D


func setup(player_name: String, slot: int) -> void:
	var color: Color = SLOT_COLORS[clampi(slot, 0, SLOT_COLORS.size() - 1)]
	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = HEIGHT
	capsule.radius = RADIUS
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	capsule.material = mat
	_body.mesh = capsule
	_body.position.y = HEIGHT / 2.0
	add_child(_body)

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
	arrow.position = Vector3(0, 0.03, RADIUS + 0.45)
	add_child(arrow)

	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.pixel_size = 0.0008
	_label.font_size = 40
	_label.outline_size = 10
	_label.position.y = HEIGHT + 0.45
	add_child(_label)


func apply_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	position = state.position
	rotation.y = state.facing
	# The name stays upright regardless of facing (billboard), nothing else to do.
