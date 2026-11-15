class_name OverheadBar
extends Node3D
## Name and health bar floating above a character or monster. Monsters hide the bar
## while at full health (hide_when_full).

const SHADER := preload("res://assets/monsters/overhead_bar.gdshader")
const WIDTH := 0.9
const HEIGHT := 0.1

var _label: Label3D
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _hide_when_full: bool = false
var _fraction: float = 1.0


func setup(display_name: String, hide_when_full: bool, color := Color(0.85, 0.2, 0.2)) -> void:
	_hide_when_full = hide_when_full
	if display_name != "":
		_label = Label3D.new()
		_label.text = display_name
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.fixed_size = true
		_label.no_depth_test = true
		_label.pixel_size = 0.0008
		_label.font_size = 32
		_label.outline_size = 8
		_label.position.y = 0.18
		add_child(_label)
	_quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(WIDTH, HEIGHT)
	_quad.mesh = mesh
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fill_color", color)
	_quad.material_override = _material
	add_child(_quad)
	set_health(1.0, 1.0)


func set_health(hp: float, max_hp: float) -> void:
	_fraction = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_material.set_shader_parameter("fill", _fraction)
	_quad.visible = not (_hide_when_full and _fraction >= 0.999)


func fraction() -> float:
	return _fraction


func bar_visible() -> bool:
	return _quad.visible
