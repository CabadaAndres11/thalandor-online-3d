class_name CombatFX
extends Node3D
## Combat visuals driven by the host's events (see SimWorld.events):
##   projectile / projectile_end -> a voxel bolt that flies on its own (arcane prism, fire orb);
##                                  frost leaves a line of ice spikes that grow toward the end;
##                                  magic ends in an explosion (frost: a big burst of spikes)
##   channel / channel_end       -> motes and a voxel orb that forms and brightens in front of the caster
##   cast (melee arcs)           -> a short flash of the arc
##   telegraph                   -> a ground warning that fills up until impact
##   telegraph_line              -> a charge's lane that fills toward its end; charge or
##                                  charge_cancel removes it
##   area                        -> a flash where an area went off; arcane leaves a pentagram,
##                                  fire burning ground and frost ice spikes for a few seconds
##   status slow / freeze        -> snow on the target (freeze also an ice shell)
##   status "shield"             -> a bubble around the entity until it fades
##   hit / heal / dodge          -> floating numbers
##   level_up                    -> "¡Nivel N!" over the player and a flash
## Time advances in advance(dt) (called from _process; tests call it by hand).

const COLOR_HIT := Color(1, 1, 1)
const COLOR_CRIT := Color(1.0, 0.85, 0.2)
const COLOR_HEAL := Color(0.4, 1.0, 0.45)
const COLOR_DODGE := Color(0.7, 0.7, 0.72)
const COLOR_LEVEL := Color(1.0, 0.82, 0.3)
const CLASS_COLORS := {
	"warrior": Color("#d8dde3"), "cleric": Color("#ffe38a"), "mage": Color("#b98cff"),
	"archer": Color("#e8d2a0"), "assassin": Color("#ff5f6d"),
}
const MONSTER_COLOR := Color("#ff8a3d")
const NUMBER_TIME := 0.9
const NUMBER_RISE := 1.2
const FLASH_TIME := 0.2
const HEAD_HEIGHT := 2.0
const SPIKE_SPACING := 0.8
## How high a falling comet (fx_flight "sky") starts above its path.
const SKY_HEIGHT := 9.0
const SNOW_COOLDOWN_MS := 1800 # snow over an entity at most this often
const BEAM_HOLD_S := 0.35 # a beam stays until the next pulse of the channel (or this long)
const MARK_LINGER := 0.3 # how long a mark outlasts its last pulse
const MARK_MIN_LIFE := 0.7
## Colours of the magic schools (damage element of the ability).
const ELEMENT_COLORS := {
	"fire": Color("#ff7a2a"), "frost": Color("#7fd8ff"), "arcane": Color("#c07bff"), "nature": Color("#7be07b"),
	"holy": Color("#ffe48a"), "shadow": Color("#9a6bd8"), "poison": Color("#8ee05a"),
}

var _position_of: Callable # id -> Vector3 or null
var _tick_now: Callable # -> int (latest snapshot tick)
var _abilities: AbilityDB
var _tick_rate: int = 30

var _projectiles: Dictionary = {} # pid -> {node, from, dir, speed, range, t}
var _telegraphs: Dictionary = {} # id -> {node, fill, t, duration}
var _flashes: Array = [] # {node, t}
var _numbers: Array = [] # {node, t, base_y}
var _shields: Dictionary = {} # entity id -> {node, t, duration}
var _charges: Dictionary = {} # caster id -> {node, orb, t, duration, element} (cast times and channels)
var _cast_aim: Dictionary = {} # caster id -> where its last cast was aimed
var _decor: Array = [] # {node, t, life, grow, target, fade, base, flicker, spin}: voxel effects that grow and fade
var _marks: Dictionary = {} # area id -> decor entry of its ground mark
var _mesh_cache: Dictionary = {}
## id -> bool: casters whose swing is drawn by a SlashFx (set by the game session).
var slash_owners: Callable
var _beams: Dictionary = {} # caster id -> {node, t}
var _snow_last: Dictionary = {} # entity key -> msec of its last snow burst
var _shell_last: Dictionary = {} # entity id -> msec of its last ice shell
var _trap_nodes: Dictionary = {} # trap id -> {node, light, armed_tick}
## The cleric's holy effects: {style, node, t, life, follow?, from?, to?, rise?}.
var _holy: Array = []
## A cleric's targeted cast waiting for the heal/status/revive event that follows it in the
## same batch (the host applies a cast's effects right after announcing it): caster id ->
## {style, aim}. Whatever is still waiting at the next frame shows at its aim.
var _holy_pending: Dictionary = {}
## Holy styles drawn on whoever the cast touched (the rest are drawn on the cleric at once,
## the column at the aim: a cleanse says nothing about whom it touched).
const HOLY_TARGETED := ["cross", "wings", "angel"]


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
		"beam":
			_beam(ev)
		"blink":
			_blink_fx(ev[2], ev[3], str(ev[4]) if ev.size() > 4 else "")
		"trap":
			_trap_placed(int(ev[1]), ev[3], int(ev[5]))
		"trap_fired":
			_trap_fired(int(ev[1]), ev[2], float(ev[3]))
		"trap_end":
			_trap_remove(int(ev[1]))
		"projectile_end":
			_end_projectile(int(ev[1]), ev[2] if ev.size() > 2 else null)
		"cast":
			if ev.size() > 3 and ev[3] is Vector3:
				_cast_aim[int(ev[1])] = ev[3]
			_cast_flash(ev)
			_holy_cast(ev)
		"channel":
			_start_charge(int(ev[1]), str(ev[2]), float(ev[3]))
		"channel_end":
			_end_charge(int(ev[1]))
			for h: Dictionary in _holy: # the hymn's wings fade with the song
				if h.style == "hymn" and int(h.get("follow", -1)) == int(ev[1]):
					h.life = minf(float(h.life), float(h.t) + 0.35)
			if _beams.has(int(ev[1])):
				_free_beam(_beams[int(ev[1])])
				_beams.erase(int(ev[1]))
		"telegraph_line":
			_add_line_telegraph(ev)
		"charge", "charge_cancel":
			_remove_telegraph(int(ev[1]))
		"telegraph":
			_add_telegraph(ev)
			if ev.size() > 5 and _fx_style(str(ev[5])) in ["meteor", "ice_comet"]:
				_meteor_fall(ev[2], maxf(float(int(ev[4]) - int(_tick_now.call())) / float(_tick_rate), 0.1), float(ev[3]),
					_fx_style(str(ev[5])) == "ice_comet")
		"level_up":
			level_up(int(ev[1]), int(ev[2]))
		"area":
			_area_flash(ev[2], float(ev[3]), str(ev[4]) if ev.size() > 4 else "", int(ev[1]),
				(int(ev[5]) * float(ev[6])) if ev.size() > 6 else 0.0, ev[7] if ev.size() > 7 else [])
		"status":
			if str(ev[2]) in ["shield", "hot"]: # what a cleric's shield or renew puts on
				_holy_touched(int(ev[1]))
			if str(ev[2]) == "shield":
				_add_shield(int(ev[1]), int(ev[3]))
			elif str(ev[2]) == "root":
				_net(int(ev[1]), int(ev[3]))
			elif str(ev[2]) == "ice_block":
				_ice_block(int(ev[1]), int(ev[3]))
			elif str(ev[2]) in ["slow", "freeze"]:
				_snow(int(ev[1]), str(ev[2]) == "freeze", int(ev[3]) if ev.size() > 3 else 0)
		"hit":
			var at: Variant = _position_of.call(int(ev[1]))
			if at != null:
				_sparks(at, COLOR_CRIT if bool(ev[3]) else Color(1.0, 0.55, 0.3))
			if bool(ev[3]):
				_number(int(ev[1]), "%d" % roundi(float(ev[2])), COLOR_CRIT, 64)
			else:
				_number(int(ev[1]), "%d" % roundi(float(ev[2])), COLOR_HIT, 44)
		"revived":
			_holy_touched(int(ev[1]))
		"heal":
			_holy_touched(int(ev[1]))
			if float(ev[2]) >= 0.5:
				_number(int(ev[1]), "+%d" % roundi(float(ev[2])), COLOR_HEAL, 44)
		"dodge":
			_number(int(ev[1]), tr("FX_DODGE"), COLOR_DODGE, 36)


## A player reached a level: a golden number over them and a flash on the ground.
func level_up(id: int, level: int) -> void:
	_number(id, tr("FX_LEVEL_UP") % level, COLOR_LEVEL, 60)
	var at: Variant = _position_of.call(id)
	if at != null:
		_area_flash(at, 1.6)
		_level_glow(at)


## A column of blue light and rising sparks around who levels up (Plan 8.3d), for 1.2 s.
func _level_glow(at: Vector3) -> void:
	var col := MeshInstance3D.new()
	col.name = "LevelGlow"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.8
	cyl.height = 4.0
	col.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.65, 1.0, 0.55)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	col.material_override = mat
	col.position = at + Vector3(0, 2.0, 0)
	add_child(col)
	var sparks := CPUParticles3D.new()
	sparks.amount = 40
	sparks.lifetime = 1.0
	sparks.one_shot = true
	sparks.explosiveness = 0.6
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.0
	sparks.gravity = Vector3.ZERO
	sparks.color = Color(0.55, 0.8, 1.0)
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	sparks.mesh = dot
	sparks.emitting = true
	col.add_child(sparks)
	var tw := col.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(col.queue_free)


func advance(dt: float) -> void:
	_advance_holy(dt)
	for pid: int in _projectiles.keys():
		var p: Dictionary = _projectiles[pid]
		p.t += dt
		var travelled: float = p.speed * p.t
		if travelled >= p.range:
			_remove_projectile(pid)
		else:
			(p.node as Node3D).position = p.from + p.dir * travelled
			if p.get("flight") == "sky": # a comet: it drops out of the sky onto its path
				(p.node as Node3D).position.y += SKY_HEIGHT * exp(-travelled / 2.5)
			if p.spin != null:
				(p.spin as Node3D).rotation.x += dt * 22.0
			if p.get("spin_z") != null:
				(p.spin_z as Node3D).rotation.z += dt * 9.0
			if p.element == "frost" and p.get("flight", "") == "":
				while travelled >= p.next_spike and p.next_spike < p.range:
					_ice_spikes_at(p, p.next_spike)
					p.next_spike += SPIKE_SPACING
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
	for id: int in _beams.keys():
		var bm: Dictionary = _beams[id]
		bm.t += dt
		bm.age += dt
		if bm.t >= BEAM_HOLD_S:
			_free_beam(bm)
			_beams.erase(id)
		else:
			_place_beam(bm, id, dt)
	for id: int in _charges.keys():
		var c: Dictionary = _charges[id]
		c.t += dt
		var at: Variant = _position_of.call(id)
		if c.t >= c.duration or at == null:
			_end_charge(id)
		else:
			(c.node as Node3D).position = (at as Vector3) + Vector3(0, 0.9, 0)
			if c.extra != null:
				(c.extra as Node3D).position = (at as Vector3) + Vector3(0, 0.1, 0)
			_grow_charge_orb(c, id, at as Vector3)
	_advance_decor(dt)
	for tid: int in _trap_nodes.keys():
		var tn: Dictionary = _trap_nodes[tid]
		var armed := int(_tick_now.call()) >= int(tn.armed_tick)
		(tn.light as Node3D).visible = (sin(Time.get_ticks_msec() / 1000.0 * 8.0) > 0.0) if armed else true # it blinks once armed
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


func projectile_node(pid: int) -> Node3D:
	return _projectiles[pid].node if _projectiles.has(pid) else null


func holy_effects() -> Array:
	return _holy


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


## Live voxel effects (ice spikes, ground marks, explosions, shells).
func decor_count() -> int:
	return _decor.size()


func mark_node(area_id: int) -> Node3D:
	return _marks[area_id].node if _marks.has(area_id) else null


func mark_count() -> int:
	return _marks.size()


func charge_orb_scale(id: int) -> float:
	return ((_charges[id].orb as Node3D).scale.x) if _charges.has(id) and _charges[id].orb != null else 0.0


# --- Builders -----------------------------------------------------------------------

## The damage element of an ability ("" when it has none), looking inside nested effects.
static func element_of(node: Variant) -> String:
	if node is Dictionary:
		var d := node as Dictionary
		if d.has("element") and d.element is String:
			return d.element
		for k: Variant in d:
			var found := element_of(d[k])
			if found != "":
				return found
	elif node is Array:
		for v: Variant in node:
			var found := element_of(v)
			if found != "":
				return found
	return ""


## The visual school of an ability: its own "fx_element", the element of its damage or the
## school of its class (mages are arcane, clerics holy). "" = not magic.
static func fx_element(ab: Dictionary) -> String:
	if ab.has("fx_element"):
		return str(ab.fx_element)
	var e := element_of(ab.get("effects", []))
	if e != "":
		return e
	return {"mage": "arcane", "cleric": "holy"}.get(str(ab.get("class", "")), "")


func _fx_style(ability_id: String) -> String:
	return str(_abilities.get_ability(ability_id).get("fx_style", "")) if _abilities != null and _abilities.has(ability_id) else ""


func _element_of_ability(ability_id: String) -> String:
	return fx_element(_abilities.get_ability(ability_id)) if _abilities != null and _abilities.has(ability_id) else ""


func _is_magic(ability_id: String) -> bool:
	return _element_of_ability(ability_id) != ""


func _color_of(ability_id: String) -> Color:
	var ab := _abilities.get_ability(ability_id)
	if ab.has("fx_color"):
		return Color(str(ab.fx_color))
	var element := fx_element(ab)
	if ELEMENT_COLORS.has(element):
		return ELEMENT_COLORS[element]
	return CLASS_COLORS.get(str(ab.get("class", "")), MONSTER_COLOR)


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Additive, unshaded material: it glows over whatever is behind it.
func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := _material(color, alpha)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## The voxel model of a physical projectile ("" = the plain bolt): archers shoot arrows, assassins
## throw knives; an ability can name its own with "fx_model".
func _projectile_model(ability_id: String) -> String:
	if _abilities == null or not _abilities.has(ability_id):
		return ""
	var ab := _abilities.get_ability(ability_id)
	if ab.has("fx_model"):
		return str(ab.fx_model)
	return {"archer": "arrow", "assassin": "knife"}.get(str(ab.get("class", "")), "")


func _add_projectile(ev: Array) -> void:
	var pid := int(ev[1])
	var from: Vector3 = ev[4]
	var dir2: Vector2 = ev[5]
	var color := _color_of(str(ev[3]))
	var element := _element_of_ability(str(ev[3]))
	var node := Node3D.new()
	var model := _projectile_model(str(ev[3]))
	var ab: Dictionary = _abilities.get_ability(str(ev[3])) if _abilities != null and _abilities.has(str(ev[3])) else {}
	# fx_flight: "air" (frost flies like other bolts), "ground" (skims the floor), "sky" (falls from above)
	var flight := str(ab.get("fx_flight", ""))
	var spin: Node3D = null
	if element == "" and model != "":
		var shape := _voxel("proj_" + model, func() -> Dictionary: return VoxelFx.arrow() if model == "arrow" else VoxelFx.knife(), false, 1.0, 0.07)
		node.add_child(shape)
		if model == "knife":
			spin = shape # a thrown knife turns end over end
		node.add_child(_trail(Color(0.85, 0.88, 0.92)))
	elif element == "":
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
	elif element == "frost" and flight == "":
		node.add_child(_trail(color, true)) # no bolt: a mist, and the spikes come out of the ground
	else:
		var body := _voxel("body_" + element, func() -> Dictionary: return VoxelFx.body_for(element, color), true, 1.0)
		node.add_child(body)
		if element == "holy":
			body.name = "HolyCross" # a golden cross turning as it flies
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.4
		light.omni_range = 4.0
		node.add_child(light)
		node.add_child(_trail(color, true))
	var start := from + Vector3(0, 0.3 if flight == "ground" else 1.1, 0)
	node.position = start
	var size := float(ab.get("fx_scale", 2.6 if flight == "sky" else 1.0))
	if not is_equal_approx(size, 1.0):
		node.scale = Vector3.ONE * size
	if ab.has("fx_stretch"): # a long lance along its flight (its forward is +Z)
		node.scale.z *= float(ab.fx_stretch)
	add_child(node)
	if dir2.length() > 0.001:
		node.rotation.y = atan2(dir2.x, dir2.y)
	_projectiles[pid] = {"node": node, "from": start, "dir": Vector3(dir2.x, 0, dir2.y),
		"speed": float(ev[6]), "range": float(ev[7]), "t": 0.0, "element": element, "color": color, "next_spike": 0.6, "spin": spin, "flight": flight,
		"spin_z": node.find_child("HolyCross", false, false)}


func _remove_projectile(pid: int) -> void:
	if _projectiles.has(pid):
		(_projectiles[pid].node as Node).queue_free()
		_projectiles.erase(pid)


## The flight ended (it hit something or ran out of range): magic explodes where it stopped.
func _end_projectile(pid: int, at: Variant) -> void:
	if _projectiles.has(pid) and at is Vector3:
		var p: Dictionary = _projectiles[pid]
		if p.element == "frost":
			_ice_finale(at as Vector3)
		elif p.element != "":
			_explosion(at as Vector3, p.color, p.element)
	_remove_projectile(pid)


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


func _area_flash(pos: Vector3, radius: float, ability_id: String = "", area_id: int = 0, still_going_s: float = 0.0, wall: Array = []) -> void:
	var magic := ability_id != "" and _is_magic(ability_id)
	var color := _color_of(ability_id).lightened(0.35) if magic else Color(1, 0.9, 0.6)
	if ability_id == "": # a level-up flash; areas of abilities do not glow under their targets
		var d := _disc(radius, color, 0.6)
		d.position = pos + Vector3(0, 0.05, 0)
		add_child(d)
		_flashes.append({"node": d, "t": 0.0})
	var again: bool = _marks.has(area_id) and is_instance_valid(_marks[area_id].node) and _marks[area_id] in _decor
	if _fx_style(ability_id) == "arrow_rain":
		_arrow_volley(pos, radius)
	if magic:
		if not again: # the effect stays in the field: only its first pulse bursts
			_burst(pos, radius, color, wall)
		_ground_mark(area_id, pos, radius, _element_of_ability(ability_id), still_going_s, wall, ability_id)
		if _fx_style(ability_id) == "meteor":
			_explosion(pos, color, "fire", radius / 2.0)
			_shockwave(pos, radius)
		elif _fx_style(ability_id) == "ice_comet":
			_ice_finale(pos)


## A burst of glowing motes rising from an area that went off.
func _burst(pos: Vector3, radius: float, color: Color, wall: Array = []) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = clampi(int(radius * 14.0), 16, 90)
	p.lifetime = 0.7
	p.explosiveness = 0.9
	if wall.is_empty():
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = maxf(radius * 0.8, 0.2)
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX # a line of embers, not a circle
		p.emission_box_extents = Vector3(float(wall[0]) / 2.0, 0.1, float(wall[1]) / 2.0)
		p.rotation.y = atan2(-float(wall[3]), float(wall[2]))
		p.amount = clampi(int(float(wall[0]) * 6.0), 24, 90)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, 1.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	p.mesh = mesh
	p.material_override = _glow(color, 0.9)
	p.color_ramp = _fade_ramp(color)
	p.position = pos + Vector3(0, 0.2, 0)
	add_child(p)
	_flashes.append({"node": p, "t": -0.5}) # freed with the flashes, once the motes are gone


## Motes spiralling into the caster while a cast time or a channel lasts.
func _start_charge(id: int, ability_id: String, total: float) -> void:
	_end_charge(id)
	var at: Variant = _position_of.call(id)
	if at == null or total <= 0.0:
		return
	var color := _color_of(ability_id).lightened(0.3)
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.1
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.2
	p.radial_accel_min = -5.0
	p.radial_accel_max = -3.0
	p.tangential_accel_min = 2.0
	p.tangential_accel_max = 4.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	p.mesh = mesh
	p.material_override = _glow(color, 0.9)
	p.color_ramp = _fade_ramp(color)
	p.position = (at as Vector3) + Vector3(0, 0.9, 0)
	add_child(p)
	var element := _element_of_ability(ability_id)
	var orb: MeshInstance3D = null
	var is_beam := false
	for e: Dictionary in _abilities.get_ability(ability_id).get("effects", []):
		is_beam = is_beam or e.get("type") == "beam"
	if is_beam:
		element = "" # the beam itself is the visual; no growing orb
	if element != "":
		orb = _voxel("body_" + element, func() -> Dictionary: return VoxelFx.body_for(element, color), true, 0.35)
		orb.scale = Vector3.ONE * 0.15
		add_child(orb)
	var extra: CPUParticles3D = null
	if _fx_style(ability_id) == "meteor":
		extra = _embers_ring(color)
		add_child(extra)
	_charges[id] = {"node": p, "orb": orb, "extra": extra, "t": 0.0, "duration": total, "element": element}
	if orb != null:
		_grow_charge_orb(_charges[id], id, at as Vector3)


## A ring of embers rising around the caster during a big cast.
func _embers_ring(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 50
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 1.4
	p.emission_ring_inner_radius = 1.0
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3.ZERO
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 6
	drop.rings = 3
	p.mesh = drop
	p.material_override = _glow(color, 0.9)
	p.color_ramp = _fade_ramp(color)
	return p


func _end_charge(id: int) -> void:
	if _charges.has(id):
		(_charges[id].node as Node).queue_free()
		if _charges[id].orb != null:
			(_charges[id].orb as Node).queue_free()
		if _charges[id].extra != null:
			(_charges[id].extra as Node).queue_free()
		_charges.erase(id)


func charge_count() -> int:
	return _charges.size()


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
	if slash_owners.is_valid() and bool(slash_owners.call(int(ev[1]))):
		return # the weapon's own cut is drawn instead of a flat sector
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
func _trail(color: Color, magic: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 48 if magic else 24
	p.lifetime = 0.45 if magic else 0.25
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	if magic:
		var mote := SphereMesh.new()
		mote.radius = 0.05
		mote.height = 0.1
		mote.radial_segments = 6
		mote.rings = 3
		p.mesh = mote
	else:
		var quad := SphereMesh.new()
		quad.radius = 0.05
		quad.height = 0.1
		p.mesh = quad
	p.material_override = _glow(color, 0.8) if magic else _material(color, 0.7)
	p.color_ramp = _fade_ramp(color)
	return p


## A voxel model node from a cache of meshes (each node has its own material).
func _voxel(key: String, build: Callable, glow: bool, alpha: float, cube: float = VoxelFx.CUBE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var ck := "%s|%s" % [key, cube]
	if not _mesh_cache.has(ck):
		_mesh_cache[ck] = VoxelFx.mesh_of(build.call(), cube)
	n.mesh = _mesh_cache[ck]
	n.material_override = VoxelFx.material(glow, alpha)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Adds a voxel effect: it grows to `target` in `grow` s, lives `life` s and fades during the
## last `fade` s. `flicker` (flames) and `spin` (pentagram) are optional.
func _add_decor(node: Node3D, life: float, grow: float = 0.0, target: Vector3 = Vector3.ONE, fade: float = 0.4,
		base_alpha: float = 1.0, flicker: bool = false, spin: float = 0.0) -> Dictionary:
	add_child(node)
	var d := {"node": node, "t": 0.0, "life": life, "grow": grow, "target": target, "fade": fade, "base": base_alpha,
		"flicker": flicker, "spin": spin, "phase": randf() * TAU}
	if grow > 0.0:
		node.scale = target * 0.05
	_decor.append(d)
	return d


func _advance_decor(dt: float) -> void:
	for d: Dictionary in _decor.duplicate():
		d.t += dt
		var node: Node3D = d.node
		if not is_instance_valid(node):
			_decor.erase(d)
			continue
		var lt: float = d.t - float(d.get("delay", 0.0)) # time since it started (it can wait first)
		if lt < 0.0:
			node.visible = false
			continue
		node.visible = true
		if lt >= d.life:
			node.queue_free()
			_decor.erase(d)
			continue
		if d.has("fall"):
			var fk := clampf(lt / maxf(float(d.fall.get("dur", d.life)), 0.01), 0.0, 1.0)
			node.position = (d.fall.from as Vector3).lerp(d.fall.to as Vector3, fk * fk) # it speeds up as it falls
		if d.has("follow"):
			var fp: Variant = _position_of.call(int(d.follow))
			if fp != null:
				node.position = (fp as Vector3) + Vector3(0, 0.95, 0)
		if d.grow > 0.0:
			var k := clampf(lt / d.grow, 0.0, 1.0)
			node.scale = (d.target as Vector3) * (1.0 - pow(1.0 - k, 3.0)) # eases out
		if d.flicker:
			var f := 0.85 + 0.25 * sin(lt * 11.0 + d.phase)
			node.scale = Vector3((d.target as Vector3).x, (d.target as Vector3).y * f, (d.target as Vector3).z)
		if d.spin != 0.0:
			node.rotation.y += float(d.spin) * dt
		var remaining: float = d.life - lt
		if d.fade > 0.0 and remaining < d.fade:
			_set_decor_alpha(node, float(d.base) * remaining / float(d.fade))


func _set_decor_alpha(node: Node, a: float) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).material_override is StandardMaterial3D:
		((node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = clampf(a, 0.0, 1.0)
	for c in node.get_children():
		_set_decor_alpha(c, a)


## Orb in front of the caster that forms and brightens while a cast time or a channel lasts.
func _grow_charge_orb(c: Dictionary, id: int, at: Vector3) -> void:
	var orb: MeshInstance3D = c.orb
	if orb == null:
		return
	var k := clampf(c.t / maxf(c.duration, 0.01), 0.0, 1.0)
	var dir := Vector3(0, 0, 1)
	if _cast_aim.has(id):
		var to: Vector3 = (_cast_aim[id] as Vector3) - at
		to.y = 0.0
		if to.length() > 0.01:
			dir = to.normalized()
	orb.position = at + dir * 0.9 + Vector3(0, 1.1, 0)
	orb.rotation.y = atan2(dir.x, dir.z)
	orb.scale = Vector3.ONE * lerpf(0.15, 1.0, k)
	VoxelFx.set_alpha(orb, lerpf(0.35, 1.0, k)) # it gets brighter as it forms


## Ice spikes coming out of the ground along a frost bolt's line, bigger toward its end.
func _ice_spikes_at(p: Dictionary, dist: float) -> void:
	var k := clampf(dist / maxf(float(p.range), 0.1), 0.0, 1.0)
	var ground_y := (p.from as Vector3).y - 1.1
	var side := Vector3(-(p.dir as Vector3).z, 0, (p.dir as Vector3).x)
	for s: float in [-1.0, 1.0]:
		var h := int(round(lerpf(4.0, 12.0, k))) + (0 if s > 0.0 else -1)
		var spike := _voxel("spike_%d" % h, func() -> Dictionary: return VoxelFx.ice_spike(h), false, 0.95)
		var at := (p.from as Vector3) + (p.dir as Vector3) * dist + side * (0.22 * s) * (1.0 + 2.0 * k)
		at.y = ground_y
		spike.position = at
		spike.rotation.y = randf() * TAU
		spike.rotation.z = randf_range(-0.2, 0.2)
		_add_decor(spike, 1.4, 0.18, Vector3.ONE, 0.5)


## The big end of a frost bolt: a ring of large spikes erupts, with shards and snow.
func _ice_finale(pos: Vector3) -> void:
	var centre := _voxel("spike_16", func() -> Dictionary: return VoxelFx.ice_spike(16), false, 0.95, 0.13)
	centre.position = pos
	_add_decor(centre, 1.8, 0.2, Vector3.ONE, 0.6)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var h := 9 + (i % 3) * 2
		var spike := _voxel("spike_%d" % h, func() -> Dictionary: return VoxelFx.ice_spike(h), false, 0.95, 0.12)
		spike.position = pos + Vector3(cos(a), 0, sin(a)) * (0.9 + 0.25 * float(i % 2))
		spike.rotation.y = a
		spike.rotation.z = 0.0
		_add_decor(spike, 1.7, 0.22, Vector3.ONE, 0.6)
	_shards(pos + Vector3(0, 0.6, 0), VoxelFx.ICE, 44)
	_flash_orb(pos + Vector3(0, 0.8, 0), VoxelFx.ICE_LIGHT, 1.6)
	_snow_burst(pos + Vector3(0, 1.8, 0))


## Fire and arcane impact: a flash that swells and cubes that fly out.
func _explosion(pos: Vector3, color: Color, element: String, scale_k: float = 1.0) -> void:
	var at := pos + Vector3(0, 0.9, 0)
	_flash_orb(at, color.lightened(0.4), 2.2 * scale_k)
	_shards(at, color, int(40.0 * scale_k))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 6.0 * scale_k
	light.position = at
	_add_decor(light, 0.25, 0.0, Vector3.ONE, 0.0)


## A meteor that falls out of the sky onto `pos` and arrives when the area goes off.
func _meteor_fall(pos: Vector3, seconds: float, radius: float = 0.0, ice: bool = false) -> void:
	var rock := _voxel("ice_comet", func() -> Dictionary: return VoxelFx.ice_crystal(), false, 1.0, 0.16) if ice 		else _voxel("meteor", func() -> Dictionary: return VoxelFx.meteor(), false, 1.0, 0.16)
	var from := pos + Vector3(7, 22, 7) * maxf(1.0, radius / 3.0)
	rock.position = from
	rock.basis = Basis.looking_at(-(pos - from).normalized(), Vector3.UP) # its tail trails behind
	if radius > 0.0: # as big as the area it lands on (its head is 4 cubes of 0.16 m)
		rock.scale = Vector3.ONE * maxf(1.0, radius / 0.64)
	var d := _add_decor(rock, seconds, 0.0, Vector3.ONE, 0.0)
	d.fall = {"from": from, "to": pos + Vector3(0, 0.5, 0)}
	var light := OmniLight3D.new()
	light.light_color = ELEMENT_COLORS.frost if ice else Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = 8.0
	rock.add_child(light)
	if ice:
		rock.add_child(_trail(ELEMENT_COLORS.frost, true))


## A ring that expands across the ground from an impact.
func _shockwave(pos: Vector3, radius: float) -> void:
	var ring := _ring(radius * 0.4, Color(1.0, 0.65, 0.25))
	ring.position = Vector3(pos.x, 0.08, pos.z)
	_add_decor(ring, 0.5, 0.5, Vector3(2.5, 1.0, 2.5), 0.5, 0.95)


## A glowing voxel ball that swells and fades (the flash of an impact).
func _flash_orb(at: Vector3, color: Color, size: float) -> void:
	var orb := _voxel("flash_%s" % color.to_html(), func() -> Dictionary: return VoxelFx.orb(color, 2.5), true, 0.9)
	orb.position = at
	_add_decor(orb, 0.4, 0.3, Vector3.ONE * size, 0.3, 0.9)


## Cubes flying out of a point (one burst).
func _shards(at: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -8.0, 0)
	var shard := PrismMesh.new() # shards and sparks are little triangles
	shard.size = Vector3(0.12, 0.16, 0.04)
	p.mesh = shard
	p.material_override = _glow(color, 1.0)
	p.color_ramp = _fade_ramp(color)
	p.position = at
	_add_decor(p, 1.0, 0.0, Vector3.ONE, 0.0)


## Snowflakes falling over a point.
func _snow_burst(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 36
	p.lifetime = 1.2
	p.explosiveness = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.1, 0.9)
	p.direction = Vector3.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -2.0, 0)
	var flake := SphereMesh.new()
	flake.radius = 0.035
	flake.height = 0.07
	flake.radial_segments = 6
	flake.rings = 3
	p.mesh = flake
	p.material_override = _material(Color(0.92, 0.97, 1.0), 0.95)
	p.position = at
	_add_decor(p, 1.5, 0.0, Vector3.ONE, 0.0)


## Snow over a slowed or frozen entity (frozen: also an ice shell for as long as it lasts).
func _snow(id: int, frozen: bool, end_tick: int) -> void:
	var at: Variant = _position_of.call(id)
	if at == null:
		return
	# A field of ice refreshes the slow on every pulse: snow falls once, not once per pulse.
	var now := Time.get_ticks_msec()
	var key := id * 2 + (1 if frozen else 0)
	if now - int(_snow_last.get(key, -100000)) >= SNOW_COOLDOWN_MS:
		_snow_last[key] = now
		_snow_burst((at as Vector3) + Vector3(0, 2.0, 0))
	if frozen:
		if now - int(_shell_last.get(id, -100000)) < SNOW_COOLDOWN_MS:
			return
		_shell_last[id] = now
		var seconds := clampf(float(end_tick - int(_tick_now.call())) / float(_tick_rate), 0.3, 6.0)
		var shell := _voxel("shell", func() -> Dictionary: return VoxelFx.ice_crystal(), false, 0.4, 0.2)
		shell.position = (at as Vector3) + Vector3(0, 0.9, 0)
		shell.scale = Vector3(1.0, 1.4, 1.0)
		_add_decor(shell, seconds, 0.0, Vector3(1.0, 1.4, 1.0), 0.4, 0.4)


## A block of ice around the caster for as long as the status lasts.
func _ice_block(id: int, end_tick: int) -> void:
	var at: Variant = _position_of.call(id)
	if at == null:
		return
	var seconds := clampf(float(end_tick - int(_tick_now.call())) / float(_tick_rate), 0.3, 10.0)
	var block := _voxel("iceblock", func() -> Dictionary: return VoxelFx.ice_block(), false, 0.5, 0.22)
	block.position = (at as Vector3) + Vector3(0, 0.95, 0)
	var d := _add_decor(block, seconds, 0.25, Vector3.ONE, 0.5, 0.5)
	d.follow = id
	_snow_burst((at as Vector3) + Vector3(0, 2.2, 0))


## What an area leaves on the ground: arcane a pentagram, fire burning ground, frost ice spikes.
func _ground_mark(area_id: int, pos: Vector3, radius: float, element: String, still_going_s: float = 0.0, wall: Array = [],
		ability_id: String = "") -> void:
	if not element in ["arcane", "fire", "frost", "holy"]:
		return
	var life_left := maxf(still_going_s + MARK_LINGER, MARK_MIN_LIFE) # only while the area still does something
	if _marks.has(area_id) and is_instance_valid(_marks[area_id].node) and _marks[area_id] in _decor:
		# A new pulse only keeps it alive longer: it does not grow again from nothing.
		_marks[area_id].life = float(_marks[area_id].t) + life_left
		return
	var r := snappedf(radius, 0.5)
	var holder := Node3D.new()
	holder.position = Vector3(pos.x, 0.04, pos.z)
	var life := life_left
	var entry: Dictionary
	match element:
		"arcane":
			var star := _voxel("penta_%s" % r, func() -> Dictionary: return VoxelFx.pentagram(r), true, 0.85, 0.12)
			holder.add_child(star)
			entry = _add_decor(holder, life, 0.25, Vector3.ONE, 0.7, 0.85, false, 0.5)
		"holy":
			var circle := _voxel("holy_circle_%s" % r, func() -> Dictionary: return VoxelFx.holy_circle(r), true, 0.85, 0.12)
			holder.add_child(circle)
			_holy_choir(holder, radius, ability_id)
			entry = _add_decor(holder, life, 0.25, Vector3.ONE, 0.7, 0.85, false, 0.4)
		"fire":
			var flames: MeshInstance3D
			if wall.is_empty():
				flames = _voxel("flame_%s" % r, func() -> Dictionary: return VoxelFx.flame_patch(r), false, 0.95, 0.18)
			else:
				var len_m := float(wall[0])
				flames = _voxel("wall_%s" % len_m, func() -> Dictionary: return VoxelFx.flame_wall(len_m), false, 0.95, 0.18)
				holder.rotation.y = atan2(-float(wall[3]), float(wall[2]))
			holder.add_child(flames)
			entry = _add_decor(holder, life, 0.2, Vector3.ONE, 0.7, 0.9, true)
		_:
			# Ice stakes out of the ground over the area (they stay still); the blizzard adds an
			# icy whirlwind turning in the middle and snow swirling around it.
			if _fx_style(ability_id) != "blizzard":
				holder.add_child(_stake_field(radius))
				entry = _add_decor(holder, life, 0.18, Vector3.ONE, 0.6, 1.0, false, 0.0)
				_marks[area_id] = entry
				return
			var stakes := Node3D.new() # apart from the whirlwind, which turns: the stakes stay still
			stakes.position = holder.position
			stakes.add_child(_stake_field(radius))
			_add_decor(stakes, life, 0.0, Vector3.ONE, 0.7, 1.0, false, 0.0)
			var funnel_r := clampf(radius * 0.55, 0.8, 3.2)
			var funnel := _voxel("tornado_%s" % r, func() -> Dictionary: return VoxelFx.ice_tornado(funnel_r, 4.2, 0.16), false, 0.8, 0.16)
			holder.add_child(funnel)
			holder.add_child(_storm_snow(radius))
			entry = _add_decor(holder, life, 0.0, Vector3.ONE, 0.7, 1.0, false, 1.8)
	_marks[area_id] = entry


## Ice stakes standing out of the ground, scattered over a circle (they do not move).
func _stake_field(radius: float) -> Node3D:
	var field := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 100.0)
	var count := clampi(int(radius * radius * 2.2), 6, 60)
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var h := 6 + rng.randi() % 9
		var spike := _voxel("spike_%d" % h, func() -> Dictionary: return VoxelFx.ice_spike(h), false, 0.95, 0.12)
		spike.position = Vector3(cos(a) * d, 0, sin(a) * d)
		spike.rotation.y = rng.randf() * TAU
		spike.rotation.z = rng.randf_range(-0.25, 0.25)
		field.add_child(spike)
	return field


## Flakes whipped around and upward over a whole area: the blizzard's air.
func _storm_snow(radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = clampi(int(radius * 14.0), 30, 90)
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.9
	p.emission_ring_inner_radius = radius * 0.2
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3.ZERO
	p.tangential_accel_min = 2.0
	p.tangential_accel_max = 4.0
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	flake.radial_segments = 6
	flake.rings = 3
	p.mesh = flake
	p.material_override = _material(Color(0.92, 0.97, 1.0), 0.9)
	return p


## A beam (the arcane laser, any line attack): a glowing tube from the caster to where it ends,
## kept alive while pulses keep coming and turning with each one.
func _beam(ev: Array) -> void:
	var id := int(ev[1])
	var from: Vector3 = (ev[2] as Vector3) + Vector3(0, 1.2, 0)
	var end: Vector3 = (ev[3] as Vector3) + Vector3(0, 1.2, 0)
	var width := float(ev[4])
	var length := from.distance_to(end)
	if length < 0.1:
		return
	if not _beams.has(id):
		var holder := Node3D.new()
		var glow := _beam_tube(ELEMENT_COLORS["arcane"], 0.45, 14)
		holder.add_child(glow)
		var core := _beam_tube(Color("#f2e0ff"), 0.95, 8)
		holder.add_child(core)
		var light := OmniLight3D.new()
		light.light_color = ELEMENT_COLORS["arcane"]
		light.light_energy = 1.4
		light.omni_range = 6.0
		holder.add_child(light)
		add_child(holder)
		# A bright ball at each end: where the beam leaves the caster and where it lands.
		var ends: Array = []
		for i in 2:
			var ball := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			sphere.radial_segments = 12
			sphere.rings = 6
			ball.mesh = sphere
			ball.material_override = _glow(Color("#f2e0ff") if i == 0 else ELEMENT_COLORS["arcane"], 0.85)
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ball)
			ends.append(ball)
		_beams[id] = {"node": holder, "glow": glow, "core": core, "light": light, "ends": ends, "t": 0.0, "age": 0.0,
			"from": from, "end": end, "end_target": end, "width": width}
	var b: Dictionary = _beams[id]
	b.t = 0.0
	b.end_target = end
	b.width = width
	if b.age == 0.0:
		b.end = end
		_place_beam(b, id, 0.0)


func _beam_tube(color: Color, alpha: float, segments: int) -> MeshInstance3D:
	var tube := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = segments
	tube.mesh = mesh
	tube.material_override = _glow(color, alpha)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tube


## One continuous beam: it leaves the caster every frame and its far end glides toward the point
## the latest pulse reached, so it turns smoothly with the cursor instead of in steps.
func _place_beam(b: Dictionary, id: int, dt: float) -> void:
	var at: Variant = _position_of.call(id)
	if at != null:
		b.from = (at as Vector3) + Vector3(0, 1.2, 0)
	b.end = (b.end as Vector3).lerp(b.end_target, clampf(dt * 14.0, 0.0, 1.0))
	var from: Vector3 = b.from
	var end: Vector3 = b.end
	var length := maxf(from.distance_to(end), 0.05)
	var dir := (end - from).normalized()
	var holder: Node3D = b.node
	holder.position = (from + end) / 2.0
	holder.basis = Basis(Quaternion(Vector3.UP, dir)) # the tubes' axis (Y) along the beam
	var width: float = b.width
	var pulse := 1.0 + 0.1 * sin(b.age * 40.0 + float(id))
	var ramp := clampf(b.age / 0.15, 0.0, 1.0) # it opens up in a moment
	(b.glow as Node3D).scale = Vector3(width * 0.45 * pulse * ramp, length, width * 0.45 * pulse * ramp)
	(b.core as Node3D).scale = Vector3(width * 0.16 * ramp, length, width * 0.16 * ramp)
	(b.ends[0] as Node3D).position = from + dir * 0.4
	(b.ends[0] as Node3D).scale = Vector3.ONE * width * 0.5 * pulse * ramp
	(b.ends[1] as Node3D).position = end
	(b.ends[1] as Node3D).scale = Vector3.ONE * width * 0.62 * pulse * ramp


func _free_beam(bm: Dictionary) -> void:
	(bm.node as Node).queue_free()
	for ball: Node in bm.ends:
		ball.queue_free()


func beam_count() -> int:
	return _beams.size()


## Arrows falling out of the sky over an area, one volley per pulse; they stick in the ground
## for a moment.
func _arrow_volley(pos: Vector3, radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31.0 + pos.z * 17.0) + Engine.get_physics_frames()
	for i in clampi(int(radius * 6.0), 8, 28):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var target := pos + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var arrow := _voxel("proj_arrow", func() -> Dictionary: return VoxelFx.arrow(), false, 1.0, 0.07)
		arrow.rotation = Vector3(PI / 2.0 + rng.randf_range(-0.15, 0.15), rng.randf() * TAU, 0) # pointing down
		var from := target + Vector3(rng.randf_range(-1.0, 1.0), 13.0, rng.randf_range(-1.0, 1.0))
		arrow.position = from
		var dec := _add_decor(arrow, 0.9, 0.0, Vector3.ONE, 0.35)
		dec.fall = {"from": from, "to": target + Vector3(0, 0.25, 0), "dur": 0.22}
		dec.delay = rng.randf_range(0.0, 0.3)


## A net that falls over a rooted target and stays while the root lasts.
func _net(id: int, end_tick: int) -> void:
	var at: Variant = _position_of.call(id)
	if at == null:
		return
	var seconds := clampf(float(end_tick - int(_tick_now.call())) / float(_tick_rate), 0.3, 8.0)
	var mesh := _voxel("net", func() -> Dictionary: return VoxelFx.net(), false, 0.95, 0.13)
	var to := (at as Vector3) + Vector3(0, 0.1, 0)
	var from := to + Vector3(0, 2.8, 0)
	mesh.position = from
	var dec := _add_decor(mesh, seconds, 0.0, Vector3.ONE, 0.4)
	dec.fall = {"from": from, "to": to, "dur": 0.25}


## A trap lying on the ground from the moment it is set until it goes off or runs out.
func _trap_placed(id: int, pos: Vector3, armed_tick: int) -> void:
	_trap_remove(id)
	var holder := Node3D.new()
	holder.position = Vector3(pos.x, 0.03, pos.z)
	var body := _voxel("trap", func() -> Dictionary: return VoxelFx.trap(), false, 1.0, 0.1)
	holder.add_child(body)
	var light := _voxel("trap_light", func() -> Dictionary: return VoxelFx.orb(Color("#ff3b2f"), 1.3), true, 1.0, 0.1)
	light.position = Vector3(0, 0.4, 0)
	holder.add_child(light)
	add_child(holder)
	_trap_nodes[id] = {"node": holder, "light": light, "armed_tick": armed_tick}


func _trap_fired(id: int, pos: Vector3, radius: float) -> void:
	_trap_remove(id)
	_explosion(pos, Color("#ff9a2a"), "fire", maxf(radius / 1.5, 0.8))


func _trap_remove(id: int) -> void:
	if _trap_nodes.has(id):
		(_trap_nodes[id].node as Node).queue_free()
		_trap_nodes.erase(id)


func trap_count() -> int:
	return _trap_nodes.size()


## A teleport: a flash where it started, a streak of glowing motes along the way that fades from
## the start to the end, and a brighter flash where it arrives.
func _blink_fx(from: Vector3, to: Vector3, ability_id: String) -> void:
	var color := _color_of(ability_id).lightened(0.2) if ability_id != "" else Color("#c07bff")
	var dist := from.distance_to(to)
	var n := clampi(int(dist / 0.6), 4, 24)
	for i in n:
		var t := float(i) / float(n - 1)
		var mote := _voxel("blink_mote_%s" % color.to_html(), func() -> Dictionary: return VoxelFx.orb(color, 1.6), true, 0.85, 0.1)
		mote.position = from.lerp(to, t) + Vector3(0, 1.0, 0)
		var dec := _add_decor(mote, 0.45, 0.12, Vector3.ONE * lerpf(1.2, 0.6, t), 0.35, 0.85)
		dec.delay = t * 0.12
	_flash_orb(from + Vector3(0, 1.0, 0), color, 1.2)
	_flash_orb(to + Vector3(0, 1.0, 0), color.lightened(0.3), 1.7)
	_shards(to + Vector3(0, 1.0, 0), color, 18)


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
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
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


# --- Holy (cleric) ------------------------------------------------------------------

## A cleric's cast with "fx_holy": targeted styles wait for the event that says whom it
## touched; the others show on the cleric now (the nova, the hymn, the crusader's blow).
func _holy_cast(ev: Array) -> void:
	if _abilities == null or not _abilities.has(str(ev[2])):
		return
	var style := str(_abilities.get_ability(str(ev[2])).get("fx_holy", ""))
	if style == "":
		return
	var caster := int(ev[1])
	var aim: Variant = ev[3] if ev.size() > 3 and ev[3] is Vector3 else _position_of.call(caster)
	if style in HOLY_TARGETED:
		_holy_pending.erase(caster) # re-added last: the newest cast takes the next event
		_holy_pending[caster] = {"style": style, "aim": aim}
		return
	if style == "column":
		if aim != null:
			_holy_spawn(style, aim, -1, aim)
		return
	var at: Variant = _position_of.call(caster)
	if at != null:
		_holy_spawn(style, at, caster, aim)


## The heal, status or revive right after a targeted holy cast shows it on that entity
## (the newest cast first).
func _holy_touched(id: int) -> void:
	if _holy_pending.is_empty():
		return
	var caster: int = _holy_pending.keys()[-1]
	var pend: Dictionary = _holy_pending[caster]
	_holy_pending.erase(caster)
	var at: Variant = _position_of.call(id)
	if at == null:
		at = pend.aim
	if at != null:
		_holy_spawn(str(pend.style), at, id, pend.aim)


func _holy_spawn(style: String, at: Vector3, who: int, aim: Variant) -> void:
	var node := Node3D.new()
	var h := {"style": style, "node": node, "t": 0.0, "life": 1.2, "follow": who, "lift": 1.0}
	match style:
		"cross": # rises over the healed one, turning
			node.add_child(_voxel("holy_cross", func() -> Dictionary: return VoxelFx.holy_cross(), false, 1.0, 0.09))
			h.lift = 2.2 # above the head
			h.rise = 0.8
			h.spin = 2.0
		"wings": # wrap the shielded one for a moment
			node.add_child(_voxel("angel_wings", func() -> Dictionary: return VoxelFx.angel_wings(), false, 0.85, 0.06))
			h.life = 1.4
			h.lift = 0.9
			h.grow = 0.25
		"angel": # comes down onto the fallen, in a column of light
			node.add_child(_voxel("angel", func() -> Dictionary: return VoxelFx.angel(), false, 0.95, 0.07))
			h.life = 1.8
			h.from = 4.0
			h.to = 1.0
			h.erase("follow")
			var column := Node3D.new()
			column.add_child(_voxel("light_column", func() -> Dictionary: return VoxelFx.light_column(), true, 0.35, 0.12))
			column.position = at
			add_child(column)
			_holy.append({"style": "angel_light", "node": column, "t": 0.0, "life": 1.8, "lift": 0.0})
		"column":
			node.add_child(_voxel("light_column", func() -> Dictionary: return VoxelFx.light_column(), true, 0.6, 0.12))
			h.life = 1.0
			h.lift = 0.0
			h.grow = 0.2
			h.erase("follow")
		"nova": # a ring of crosses flying out from the cleric
			for i in 8:
				var c := _voxel("holy_cross_s", func() -> Dictionary: return VoxelFx.holy_cross(7), false, 1.0, 0.08)
				c.rotation.y = TAU * float(i) / 8.0
				node.add_child(c)
			h.life = 0.9
			h.lift = 1.2
			h.ring = 4.0
			h.erase("follow")
		"hymn": # wings and a halo over the singing cleric
			var wings := _voxel("angel_wings", func() -> Dictionary: return VoxelFx.angel_wings(), false, 0.8, 0.07)
			wings.position = Vector3(0, 0.2, -0.25)
			node.add_child(wings)
			var halo := _voxel("halo", func() -> Dictionary: return VoxelFx.halo(6), true, 0.95, 0.05)
			halo.position.y = 0.95
			node.add_child(halo)
			h.life = 6.2 # the whole song; a cut channel ends it sooner
			h.lift = 1.0 + PlayerAvatar.HOVER_M
			h.grow = 0.3
		"strike": # a cross flashing on the blow, in front of the templar
			node.add_child(_voxel("holy_cross", func() -> Dictionary: return VoxelFx.holy_cross(), false, 1.0, 0.09))
			h.life = 0.5
			h.grow = 0.12
			h.erase("follow")
			if aim is Vector3:
				var to := Vector3((aim as Vector3).x - at.x, 0, (aim as Vector3).z - at.z)
				if to.length() > 0.01:
					node.rotation.y = atan2(to.x, to.z)
					at += to.normalized() * 1.2
	node.position = at + Vector3(0, float(h.get("from", h.lift)), 0)
	h.base = node.position
	if h.has("grow"):
		node.scale = Vector3.ONE * 0.05
	add_child(node)
	_holy.append(h)


func _advance_holy(dt: float) -> void:
	for caster: int in _holy_pending.keys(): # nothing said whom it touched: show it at the aim
		var pend: Dictionary = _holy_pending[caster]
		_holy_pending.erase(caster)
		if pend.aim != null:
			_holy_spawn(str(pend.style), pend.aim, -1, pend.aim) # stays where it was aimed
	for h: Dictionary in _holy.duplicate():
		h.t += dt
		var node: Node3D = h.node
		if h.t >= h.life or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_holy.erase(h)
			continue
		var k: float = h.t / h.life
		if h.has("base"):
			node.position = h.base
		if h.has("follow"):
			var fp: Variant = _position_of.call(int(h.follow))
			if fp != null:
				node.position = (fp as Vector3) + Vector3(0, h.lift, 0)
		if h.has("rise"):
			node.position.y += float(h.rise) * k
		if h.has("from"):
			var e := 1.0 - pow(1.0 - minf(k * 1.6, 1.0), 2.0)
			node.position.y = (h.base as Vector3).y - float(h.from) + lerpf(float(h.from), float(h.to), e)
		if h.has("spin"):
			node.rotation.y += float(h.spin) * dt
		if h.has("grow"):
			node.scale = Vector3.ONE * clampf(h.t / float(h.grow), 0.05, 1.0)
		if h.has("ring"):
			for c: Node3D in node.get_children():
				c.position = Vector3(sin(c.rotation.y), 0.0, cos(c.rotation.y)) * float(h.ring) * k
		var remaining: float = h.life - h.t
		if remaining < 0.35:
			_set_decor_alpha(node, remaining / 0.35)


## A holy area as an ultimate: six angels floating round the edge (they turn with the
## circle), motes of light rising from the whole area and a beam in the middle; consecrated
## ground ("fx_flames") burns with golden flames round its edge too.
func _holy_choir(holder: Node3D, radius: float, ability_id: String) -> void:
	for i in 6:
		var a := TAU * float(i) / 6.0
		var angel := _voxel("angel", func() -> Dictionary: return VoxelFx.angel(), false, 0.95, 0.06)
		angel.name = "Angel%d" % i
		angel.position = Vector3(sin(a), 0.0, cos(a)) * radius * 0.95 + Vector3(0, 1.3, 0)
		angel.rotation.y = a + PI # facing the middle
		holder.add_child(angel)
	var beam := _voxel("light_column", func() -> Dictionary: return VoxelFx.light_column(), true, 0.45, 0.12)
	beam.name = "Beam"
	holder.add_child(beam)
	var motes := _storm_snow(radius)
	motes.name = "Motes"
	motes.tangential_accel_min = 0.0
	motes.tangential_accel_max = 0.6
	motes.initial_velocity_min = 0.8
	motes.initial_velocity_max = 1.8
	motes.material_override = _glow(VoxelFx.HOLY_LIGHT, 0.9)
	holder.add_child(motes)
	var ab := _abilities.get_ability(ability_id) if _abilities != null and _abilities.has(ability_id) else {}
	if bool(ab.get("fx_flames", false)):
		var r := snappedf(radius, 0.5)
		var flames := _voxel("holy_flames_%s" % r, func() -> Dictionary: return VoxelFx.holy_flame_ring(r), true, 0.9, 0.12)
		flames.name = "HolyFlames"
		holder.add_child(flames)
