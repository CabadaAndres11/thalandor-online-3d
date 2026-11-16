class_name OverheadBar
extends Node3D
## Name and health bar floating above a character or monster. Monsters hide the bar
## while at full health (hide_when_full).

const SHADER := preload("res://assets/monsters/overhead_bar.gdshader")
const WIDTH := 0.9
const HEIGHT := 0.1

var _label: Label3D
var _base_name: String = ""
var _level: int = 0
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _hide_when_full: bool = false
var _fraction: float = 1.0


func setup(display_name: String, hide_when_full: bool, color := Color(0.85, 0.2, 0.2)) -> void:
	_hide_when_full = hide_when_full
	_base_name = display_name
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


# --- Status icons ------------------------------------------------------------------

## Statuses that get an icon, in the order they are shown (stealth and the dodge's
## invulnerability are shown other ways).
const STATUS_ICON_KINDS := ["stun", "freeze", "root", "slow", "poison", "burn", "mark", "taunted",
	"damage_buff", "damage_reduction", "evasion", "hot"]
const MAX_STATUS_ICONS := 4
const STATUS_ICON_DIR := "res://assets/icons/status/%s.png"
const STATUS_ICON_SIZE := 0.22

var _icons: Array[Sprite3D] = []
var _shown_kinds: Array = []
## Height of the icon row over the bar (players raise it above their name).
var icon_height: float = 0.2


## Shows an icon per active status (snapshot bits, StatusEffect.BIT_KINDS), up to
## MAX_STATUS_ICONS, centred in a row above the bar.
func set_statuses(bits: int) -> void:
	var kinds: Array = []
	for k: String in STATUS_ICON_KINDS:
		if StatusEffect.has_bit(bits, k):
			kinds.append(k)
	kinds = kinds.slice(0, MAX_STATUS_ICONS)
	if kinds == _shown_kinds:
		return
	_shown_kinds = kinds
	while _icons.size() < kinds.size():
		var icon := Sprite3D.new()
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.no_depth_test = true
		icon.shaded = false
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		icon.pixel_size = STATUS_ICON_SIZE / 64.0
		icon.render_priority = 1
		add_child(icon)
		_icons.append(icon)
	var start := -(kinds.size() - 1) * STATUS_ICON_SIZE * 0.55
	for i in _icons.size():
		var icon := _icons[i]
		icon.visible = i < kinds.size()
		if icon.visible:
			var path := STATUS_ICON_DIR % kinds[i]
			icon.texture = load(path) if ResourceLoader.exists(path) else null
			icon.position = Vector3(start + i * STATUS_ICON_SIZE * 1.1, icon_height + (0.22 if _label != null else 0.0), 0)


func status_kinds() -> Array:
	return _shown_kinds.duplicate()


func status_icons() -> Array[Sprite3D]:
	return _icons


# --- Level ------------------------------------------------------------------------

## Shows "Nv N name" (a bar without a name has nothing to show it on).
func set_level(level: int) -> void:
	if level == _level or _label == null:
		return
	_level = level
	_label.text = tr("OVERHEAD_LEVEL") % [level, _base_name]


func label_text() -> String:
	return _label.text if _label != null else ""
