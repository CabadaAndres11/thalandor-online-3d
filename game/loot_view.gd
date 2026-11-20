class_name LootView
extends Node3D
## The own player's loot on the ground: the item's voxel model turning slowly (a sack for
## potions), a beam of light and the item's name in its rarity color, until it is picked up
## or expires; gold won rises as a golden number. Other players' loot never reaches this
## client (the host sends it only to its owner).

const BEAM_HEIGHT := 2.4
const NUMBER_S := 1.4
const GOLD := Color("#f2c84b")
## Largest side of an item model on the ground, in metres, and how fast it turns (rad/s).
const MODEL_SIZE := 0.5
const SPIN := 1.2
const SACK := Color("#9a7448")

var my_id: int = 0
var _drops: Dictionary = {} # drop id -> {node: Node3D, label: Label3D, model: Node3D}
var _numbers: Array = [] # {node: Label3D, t: float, base_y: float}


func handle(ev: Array) -> void:
	if ev.size() < 2 or int(ev[1]) != my_id:
		return
	match str(ev[0]):
		"loot":
			if ev.size() >= 5:
				_spawn(int(ev[2]), ev[3], ev[4])
		"loot_gone":
			_remove(int(ev[2]))
		"gold":
			if ev.size() >= 4:
				_gold(int(ev[2]), ev[3])


func _spawn(drop_id: int, item: Variant, pos: Variant) -> void:
	var it := Item.from_dict(item, ItemDB.load_default())
	if it == null or not pos is Vector3 or _drops.has(drop_id):
		return
	var color := ItemIcons.rarity_color(it.rarity)
	var root := Node3D.new()
	root.position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.14
	cyl.height = BEAM_HEIGHT
	beam.mesh = cyl
	beam.position.y = BEAM_HEIGHT / 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.35)
	mat.emission_enabled = true
	mat.emission = color
	beam.material_override = mat
	root.add_child(beam)
	var label := Label3D.new()
	label.text = tr(str(ItemDB.load_default().base(it.base_id).get("name", it.base_id)))
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.008
	label.font_size = 32
	label.outline_size = 8
	label.position.y = MODEL_SIZE + 0.3
	root.add_child(label)
	var model := _model(it.base_id)
	root.add_child(model)
	add_child(root)
	_drops[drop_id] = {"node": root, "label": label, "model": model}


## The item's pieces (as on its icon) laid out around one point, scaled to MODEL_SIZE and
## resting on the ground; a voxel sack when it has none (potions). The returned node turns.
func _model(base_id: String) -> Node3D:
	var spin := Node3D.new()
	var inner := Node3D.new()
	spin.add_child(inner)
	var box := AABB()
	var first := true
	for p: Dictionary in ItemIcons.icon_pieces(base_id):
		var mesh := VoxMesher.cached(str(p.get("file", "")), ItemIcons.ICON_TINTS)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var o: Array = p.get("offset", [0, 0, 0])
		mi.position = Vector3(o[0], o[1], o[2]) * VoxMesher.VOXEL_SIZE
		inner.add_child(mi)
		var b := mesh.get_aabb()
		b.position += mi.position
		box = b if first else box.merge(b)
		first = false
	if first:
		var sack := VoxelFx.node(_sack_cells())
		var mat := StandardMaterial3D.new() # lit like the world, not glowing
		mat.vertex_color_use_as_albedo = true
		sack.material_override = mat
		inner.add_child(sack)
		box = sack.mesh.get_aabb()
	var k := MODEL_SIZE / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.001))
	inner.scale = Vector3.ONE * k
	var c := box.get_center()
	inner.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)
	return spin


## A small tied sack of cubes.
static func _sack_cells() -> Dictionary:
	var cells := {}
	for x in range(-3, 4):
		for y in range(0, 6):
			for z in range(-3, 4):
				if Vector3(x, (y - 2.5) * 1.1, z).length() <= 3.3:
					cells[Vector3i(x, y, z)] = SACK.darkened(0.15) if (x + y + z) % 3 == 0 else SACK
	for y in range(6, 8):
		cells[Vector3i(0, y, 0)] = SACK.darkened(0.3)
	cells[Vector3i(-1, 7, 0)] = SACK.lightened(0.2)
	cells[Vector3i(1, 7, 0)] = SACK.lightened(0.2)
	return cells


func _remove(drop_id: int) -> void:
	if _drops.has(drop_id):
		(_drops[drop_id].node as Node).queue_free()
		_drops.erase(drop_id)


func _gold(amount: int, pos: Variant) -> void:
	if not pos is Vector3:
		return
	var label := Label3D.new()
	label.text = "+%d %s" % [amount, tr("GOLD_SHORT")]
	label.modulate = GOLD
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 40
	label.outline_size = 14
	label.position = (pos as Vector3) + Vector3(0, 1.6, 0)
	add_child(label)
	_numbers.append({"node": label, "t": 0.0, "base_y": label.position.y})


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for d: Dictionary in _drops.values():
		(d.model as Node3D).rotation.y += SPIN * delta
	for n: Dictionary in _numbers:
		n.t += delta
		var label: Label3D = n.node
		label.position.y = float(n.base_y) + n.t * 0.8
		label.modulate.a = clampf(1.0 - (n.t - NUMBER_S * 0.6) / (NUMBER_S * 0.4), 0.0, 1.0)
	for n: Dictionary in _numbers.filter(func(x: Dictionary) -> bool: return x.t >= NUMBER_S):
		(n.node as Node).queue_free()
	_numbers = _numbers.filter(func(x: Dictionary) -> bool: return x.t < NUMBER_S)


func clear() -> void:
	for id: int in _drops.keys():
		_remove(id)


func drop_count() -> int:
	return _drops.size()


func drop_label(drop_id: int) -> Label3D:
	return _drops[drop_id].label if _drops.has(drop_id) else null


func drop_model(drop_id: int) -> Node3D:
	return _drops[drop_id].model if _drops.has(drop_id) else null


## The model's box in the drop's space, before turning.
func drop_model_aabb(drop_id: int) -> AABB:
	var inner := (_drops[drop_id].model as Node3D).get_child(0) as Node3D
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in inner.find_children("*", "MeshInstance3D", true, false):
		var b := inner.transform * (mi.transform * mi.mesh.get_aabb())
		box = b if first else box.merge(b)
		first = false
	return box


func number_count() -> int:
	return _numbers.size()


func number_label(i: int) -> Label3D:
	return _numbers[i].node
