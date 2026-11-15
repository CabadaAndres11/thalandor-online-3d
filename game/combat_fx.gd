class_name CombatFX
extends Node3D
## Combat visuals driven by the host's events (see SimWorld.events):
##   projectile / projectile_end -> a glowing bolt that flies on its own
##   cast (melee arcs)           -> a short flash of the arc
##   telegraph                   -> a ground warning that fills up until impact
##   telegraph_line              -> a charge's lane that fills toward its end; charge or
##                                  charge_cancel removes it
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
		"telegraph_line":
			_add_line_telegraph(ev)
		"charge", "charge_cancel":
			_remove_telegraph(int(ev[1]))
		"telegraph":
			_add_telegraph(ev)
		"area":
			_area_flash(ev[2], float(ev[3]))
		"status":
			if str(ev[2]) == "shield":
				_add_shield(int(ev[1]), int(ev[3]))
		"hit":
			var at: Variant = _position_of.call(int(ev[1]))
			if at != null:
				_sparks(at, COLOR_CRIT if bool(ev[3]) else Color(1.0, 0.55, 0.3))
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
			(g.fill as Node3D).scale = Vector3(1, 1, k) if g.get("line", false) else Vector3(k, 1, k)
	for f: Dictionary in _flashes.duplicate():
		f.t += dt
		if f.t >= FLASH_TIME:
			(f.node as Node).queue_free()
			_flashes.erase(f)
		elif f.node is MeshInstance3D and f.t >= 0.0:
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


func telegraph_length(id: int) -> float:
	return float(_telegraphs[id].get("length", 0.0)) if _telegraphs.has(id) else 0.0


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
	var color := _color_of(str(ev[3]))
	var node := Node3D.new()
	# A stretched glowing bolt along its flight, with a fading trail behind.
	var bolt := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.55
	bolt.mesh = mesh
	bolt.rotation_degrees.x = 90.0
	bolt.material_override = _material(color.lightened(0.3), 1.0)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(bolt)
	node.add_child(_trail(color))
	var start := from + Vector3(0, 1.1, 0)
	node.position = start
	add_child(node)
	if dir2.length() > 0.001:
		node.rotation.y = atan2(dir2.x, dir2.y)
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
	# Dark blood-red area with a bright glowing rim; the fill grows until impact.
	var area := _disc(radius, Color(0.35, 0.02, 0.02), 0.35)
	holder.add_child(area)
	holder.add_child(_ring(radius, Color(1.0, 0.15, 0.08)))
	var fill := _disc(radius, Color(0.75, 0.05, 0.03), 0.45)
	fill.position.y = 0.01
	fill.scale = Vector3(0.0, 1, 0.0)
	holder.add_child(fill)
	add_child(holder)
	_telegraphs[id] = {"node": holder, "fill": fill, "t": 0.0, "duration": duration}


## A charge lane: dark red strip with glowing edges from `from` to `to`; the fill
## grows from the start toward the end until the charge.
func _add_line_telegraph(ev: Array) -> void:
	var id := int(ev[1])
	var from: Vector3 = ev[2]
	var to: Vector3 = ev[3]
	var width := float(ev[4])
	var duration := maxf(float(int(ev[5]) - int(_tick_now.call())) / float(_tick_rate), 0.05)
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var holder := Node3D.new()
	holder.position = Vector3(from.x, 0.03, from.z)
	if length > 0.01:
		holder.rotation.y = atan2(to.x - from.x, to.z - from.z)
	var lane := _strip(width, length, Color(0.35, 0.02, 0.02), 0.35)
	holder.add_child(lane)
	for side: float in [-1.0, 1.0]:
		var edge := _strip(0.08, length, Color(1.0, 0.15, 0.08), 0.95)
		edge.position.x = side * width / 2.0
		holder.add_child(edge)
	var fill := Node3D.new() # scaled along Z from the start
	var inner := _strip(width, length, Color(0.75, 0.05, 0.03), 0.45)
	inner.position.y = 0.01
	fill.add_child(inner)
	fill.scale = Vector3(1, 1, 0.0)
	holder.add_child(fill)
	add_child(holder)
	_telegraphs[id] = {"node": holder, "fill": fill, "t": 0.0, "duration": duration, "line": true, "length": length}


## A flat strip on the ground from z = 0 to z = length (local), centred on x.
func _strip(width: float, length: float, color: Color, alpha: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.01, maxf(length, 0.01))
	m.mesh = box
	m.position.z = length / 2.0
	m.material_override = _material(color, alpha)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _remove_telegraph(id: int) -> void:
	if _telegraphs.has(id):
		(_telegraphs[id].node as Node).queue_free()
		_telegraphs.erase(id)


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
	label.outline_size = 18
	label.outline_modulate = Color(0.05, 0.02, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.pixel_size = 0.0008
	var jitter := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	label.position = (pos as Vector3) + Vector3(0, HEAD_HEIGHT, 0) + jitter
	add_child(label)
	_numbers.append({"node": label, "t": 0.0, "base_y": label.position.y})


## A thin glowing ring lying on the ground (edge of a warning).
func _ring(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - 0.12, 0.01)
	mesh.outer_radius = radius
	mesh.rings = 48
	mesh.ring_segments = 4
	node.mesh = mesh
	node.scale = Vector3(1, 0.15, 1)
	node.position.y = 0.02
	node.material_override = _material(color, 0.95)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Particles left behind a projectile (in world space, so they trail).
func _trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.25
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := SphereMesh.new()
	quad.radius = 0.05
	quad.height = 0.1
	p.mesh = quad
	p.material_override = _material(color, 0.7)
	p.color_ramp = _fade_ramp(color)
	return p


## A short burst of sparks where something got hit.
func _sparks(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.0, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	p.mesh = mesh
	p.material_override = _material(color, 1.0)
	p.color_ramp = _fade_ramp(color)
	p.position = pos + Vector3(0, 1.0, 0)
	add_child(p)
	_flashes.append({"node": p, "t": -0.3}) # freed with the flashes, a bit later


func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(color, 0.0))
	return g
