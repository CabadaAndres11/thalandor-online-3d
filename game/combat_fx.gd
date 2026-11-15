class_name CombatFX
extends Node3D
## Combat visuals driven by the host's events (see SimWorld.events):
##   projectile / projectile_end -> a glowing bolt that flies on its own
##   cast (melee arcs)           -> a short flash of the arc
##   telegraph                   -> a ground warning that fills up until impact
##   area                        -> a flash where an area went off
##   status "shield"             -> a bubble around the entity until it fades
##   hit / heal / dodge          -> floating numbers
## Time advances in advance(dt) (called from _process; tests call it by hand).

const COLOR_HIT := Color(1, 1, 1)
const COLOR_CRIT := Color(1.0, 0.85, 0.2)
const COLOR_HEAL := Color(0.4, 1.0, 0.45)
const COLOR_DODGE := Color(0.7, 0.7, 0.72)
const CLASS_COLORS := {
	"warrior": Color("#d8dde3"), "cleric": Color("#ffe38a"), "mage": Color("#b98cff"),
	"archer": Color("#e8d2a0"), "assassin": Color("#ff5f6d"),
}
const MONSTER_COLOR := Color("#ff8a3d")
const NUMBER_TIME := 0.9
const NUMBER_RISE := 1.2
const FLASH_TIME := 0.2
const HEAD_HEIGHT := 2.0

var _position_of: Callable # id -> Vector3 or null
var _tick_now: Callable # -> int (latest snapshot tick)
var _abilities: AbilityDB
var _tick_rate: int = 30

var _projectiles: Dictionary = {} # pid -> {node, from, dir, speed, range, t}
var _telegraphs: Dictionary = {} # id -> {node, fill, t, duration}
var _flashes: Array = [] # {node, t}
var _numbers: Array = [] # {node, t, base_y}
var _shields: Dictionary = {} # entity id -> {node, t, duration}


func setup(position_of: Callable, tick_now: Callable, abilities: AbilityDB, tick_rate: int) -> void:
	_position_of = position_of
	_tick_now = tick_now
	_abilities = abilities
	_tick_rate = tick_rate


func _process(delta: float) -> void:
	advance(delta)


func handle(ev: Array) -> void:
	if ev.is_empty():
		return
	match str(ev[0]):
		"projectile":
			_add_projectile(ev)
		"projectile_end":
			_remove_projectile(int(ev[1]))
		"cast":
			_cast_flash(ev)
		"telegraph":
			_add_telegraph(ev)
		"area":
			_area_flash(ev[2], float(ev[3]))
		"status":
			if str(ev[2]) == "shield":
				_add_shield(int(ev[1]), int(ev[3]))
		"hit":
			if bool(ev[3]):
				_number(int(ev[1]), "%d" % roundi(float(ev[2])), COLOR_CRIT, 64)
			else:
				_number(int(ev[1]), "%d" % roundi(float(ev[2])), COLOR_HIT, 44)
		"heal":
			if float(ev[2]) >= 0.5:
				_number(int(ev[1]), "+%d" % roundi(float(ev[2])), COLOR_HEAL, 44)
		"dodge":
			_number(int(ev[1]), tr("FX_DODGE"), COLOR_DODGE, 36)


func advance(dt: float) -> void:
	for pid: int in _projectiles.keys():
		var p: Dictionary = _projectiles[pid]
		p.t += dt
		var travelled: float = p.speed * p.t
		if travelled >= p.range:
			_remove_projectile(pid)
		else:
			(p.node as Node3D).position = p.from + p.dir * travelled
	for id: int in _telegraphs.keys():
		var g: Dictionary = _telegraphs[id]
		g.t += dt
		if g.t >= g.duration:
			(g.node as Node).queue_free()
			_telegraphs.erase(id)
		else:
			var k: float = g.t / g.duration
			(g.fill as Node3D).scale = Vector3(k, 1, k)
	for f: Dictionary in _flashes.duplicate():
		f.t += dt
		if f.t >= FLASH_TIME:
			(f.node as Node).queue_free()
			_flashes.erase(f)
		else:
			((f.node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - f.t / FLASH_TIME)
	for n: Dictionary in _numbers.duplicate():
		n.t += dt
		var label: Label3D = n.node
		if n.t >= NUMBER_TIME:
			label.queue_free()
			_numbers.erase(n)
		else:
			label.position.y = n.base_y + NUMBER_RISE * (n.t / NUMBER_TIME)
			label.modulate.a = 1.0 - maxf(0.0, (n.t / NUMBER_TIME - 0.6) / 0.4)
	for id: int in _shields.keys():
		var s: Dictionary = _shields[id]
		s.t += dt
		var pos: Variant = _position_of.call(id)
		if s.t >= s.duration or pos == null:
			(s.node as Node).queue_free()
			_shields.erase(id)
		else:
			(s.node as Node3D).position = pos + Vector3(0, 0.9, 0)


# --- Accessors (tests and HUD) ------------------------------------------------------

func projectile_count() -> int:
	return _projectiles.size()


func projectile_position(pid: int) -> Vector3:
	return (_projectiles[pid].node as Node3D).position if _projectiles.has(pid) else Vector3.INF


func telegraph_count() -> int:
	return _telegraphs.size()


func telegraph_fill(id: int) -> float:
	return float(_telegraphs[id].t) / float(_telegraphs[id].duration) if _telegraphs.has(id) else 0.0


func floating_labels() -> Array:
	return _numbers.map(func(n: Dictionary) -> Label3D: return n.node)


func shield_count() -> int:
	return _shields.size()


# --- Builders -----------------------------------------------------------------------

func _color_of(ability_id: String) -> Color:
	var ab := _abilities.get_ability(ability_id)
	if ab.has("fx_color"):
		return Color(str(ab.fx_color))
	return CLASS_COLORS.get(str(ab.get("class", "")), MONSTER_COLOR)


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_projectile(ev: Array) -> void:
	var pid := int(ev[1])
	var from: Vector3 = ev[4]
	var dir2: Vector2 = ev[5]
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	node.mesh = mesh
	node.material_override = _material(_color_of(str(ev[3])), 1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var start := from + Vector3(0, 1.1, 0)
	node.position = start
	add_child(node)
	_projectiles[pid] = {"node": node, "from": start, "dir": Vector3(dir2.x, 0, dir2.y),
		"speed": float(ev[6]), "range": float(ev[7]), "t": 0.0}


func _remove_projectile(pid: int) -> void:
	if _projectiles.has(pid):
		(_projectiles[pid].node as Node).queue_free()
		_projectiles.erase(pid)


func _disc(radius: float, color: Color, alpha: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 32
	node.mesh = mesh
	node.material_override = _material(color, alpha)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _add_telegraph(ev: Array) -> void:
	var id := int(ev[1])
	var radius := float(ev[3])
	var duration := maxf(float(int(ev[4]) - int(_tick_now.call())) / float(_tick_rate), 0.05)
	var holder := Node3D.new()
	holder.position = (ev[2] as Vector3) + Vector3(0, 0.03, 0)
	var ring := _disc(radius, Color(1.0, 0.25, 0.15), 0.28)
	holder.add_child(ring)
	var fill := _disc(radius, Color(1.0, 0.35, 0.1), 0.45)
	fill.position.y = 0.01
	fill.scale = Vector3(0.0, 1, 0.0)
	holder.add_child(fill)
	add_child(holder)
	_telegraphs[id] = {"node": holder, "fill": fill, "t": 0.0, "duration": duration}


func _area_flash(pos: Vector3, radius: float) -> void:
	var d := _disc(radius, Color(1, 0.9, 0.6), 0.6)
	d.position = pos + Vector3(0, 0.05, 0)
	add_child(d)
	_flashes.append({"node": d, "t": 0.0})


## Melee arcs flash in front of the caster, toward the aim point.
func _cast_flash(ev: Array) -> void:
	var ab := _abilities.get_ability(str(ev[2]))
	var arc: Dictionary = {}
	for e: Dictionary in ab.get("effects", []):
		if e.get("type") == "melee_arc":
			arc = e
	var pos: Variant = _position_of.call(int(ev[1]))
	if arc.is_empty() or pos == null:
		return
	var aim: Vector3 = ev[3]
	var node := MeshInstance3D.new()
	node.mesh = _sector(deg_to_rad(float(arc.get("angle_deg", 90.0))), float(arc.get("range", 2.0)))
	node.material_override = _material(_color_of(str(ev[2])), 0.6)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = (pos as Vector3) + Vector3(0, 0.6, 0)
	var to := Vector2(aim.x - pos.x, aim.z - pos.z)
	node.rotation.y = atan2(to.x, to.y) if to.length() > 0.01 else 0.0
	add_child(node)
	_flashes.append({"node": node, "t": 0.0})


## A flat circular sector facing +Z (angle in radians, radius in meters).
static func _sector(angle: float, radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 12
	for i in steps:
		var a0 := -angle / 2.0 + angle * i / steps
		var a1 := -angle / 2.0 + angle * (i + 1) / steps
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a1), 0, cos(a1)) * radius)
		verts.append(Vector3(sin(a0), 0, cos(a0)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_shield(id: int, end_tick: int) -> void:
	var pos: Variant = _position_of.call(id)
	if pos == null:
		return
	if _shields.has(id):
		(_shields[id].node as Node).queue_free()
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.85
	mesh.height = 1.9
	node.mesh = mesh
	node.material_override = _material(Color(0.55, 0.8, 1.0), 0.22)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = (pos as Vector3) + Vector3(0, 0.9, 0)
	add_child(node)
	var duration := maxf(float(end_tick - int(_tick_now.call())) / float(_tick_rate), 0.05)
	_shields[id] = {"node": node, "t": 0.0, "duration": duration}


func _number(id: int, text: String, color: Color, size: int) -> void:
	var pos: Variant = _position_of.call(id)
	if pos == null:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = size
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.pixel_size = 0.0008
	var jitter := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	label.position = (pos as Vector3) + Vector3(0, HEAD_HEIGHT, 0) + jitter
	add_child(label)
	_numbers.append({"node": label, "t": 0.0, "base_y": label.position.y})
