class_name ItemIcons
extends Node
## Item icons: a render of each base's own voxel model (a drawn flask for potions), made
## once per session and cached. icon() answers at once with a texture that is redrawn in
## place when the render is ready, so windows never wait. Renders need this node in the
## tree (the game adds one); without it (tests, headless) the placeholder stays.

const SIZE := 64
## Tints of tintable voxels in icons (the wearer's colors are unknown).
const ICON_TINTS := {
	VoxMesher.TINT_PRIMARY: Color("#8d96a1"), VoxMesher.TINT_SECONDARY: Color("#b8933a"),
	VoxMesher.TINT_TROUSERS: Color("#5a4632"), VoxMesher.TINT_SKIN: Color("#e0b090"),
	VoxMesher.TINT_HAIR: Color("#4a3020"), VoxMesher.TINT_EYES: Color("#203040"),
}

static var _cache: Dictionary = {} # base id -> ImageTexture
static var _instance: ItemIcons

var _queue: Array = []
var _viewport: SubViewport
var _holder: Node3D
var _camera: Camera3D
var _waiting: String = ""


static func icon(base_id: String) -> Texture2D:
	if _cache.has(base_id):
		return _cache[base_id]
	var tex := ImageTexture.create_from_image(_placeholder(base_id))
	_cache[base_id] = tex
	if _instance != null and is_instance_valid(_instance) and _instance.is_inside_tree() \
			and not ItemDB.load_default().is_consumable(base_id) and not ItemDB.load_default().base(base_id).is_empty():
		_instance._queue.append(base_id)
	return tex


static func rarity_color(rarity: String) -> Color:
	var colors: Dictionary = ItemDB.load_default().loot().get("rarity_color", {})
	return Color(str(colors[rarity])) if colors.has(rarity) else Color.WHITE


## A flask for potions (red health, blue resource); a dim slot for the rest until rendered.
static func _placeholder(base_id: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var db := ItemDB.load_default()
	var potion := str(db.base(base_id).get("potion", ""))
	if potion != "":
		var liquid := Color("#d8323a") if potion == "health" else Color("#3a6fe0")
		var glass := Color(0.85, 0.9, 0.95, 0.9)
		var c := SIZE / 2
		for y in SIZE:
			for x in SIZE:
				var dx := x - c
				var body := Vector2(dx, y - SIZE * 0.64).length() <= SIZE * 0.27
				var neck := absi(dx) <= SIZE / 12 and y >= SIZE / 6 and y < SIZE * 0.42
				if body:
					img.set_pixel(x, y, liquid.lightened(0.25) if y < SIZE * 0.55 and dx < 0 else liquid)
				elif neck:
					img.set_pixel(x, y, glass)
		for x in range(c - SIZE / 8, c + SIZE / 8):
			for y in range(SIZE / 8, SIZE / 6):
				img.set_pixel(x, y, Color("#7a5230")) # cork
		return img
	for y in range(6, SIZE - 6):
		for x in range(6, SIZE - 6):
			img.set_pixel(x, y, Color(1, 1, 1, 0.08))
	return img


func _enter_tree() -> void:
	_instance = self


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE * 2, SIZE * 2)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_holder = Node3D.new()
	_viewport.add_child(_holder)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	_viewport.add_child(env)


func _process(_delta: float) -> void:
	if _waiting != "":
		var img := _viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			(_cache[_waiting] as ImageTexture).set_image(img)
		_waiting = ""
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _queue.is_empty():
		return
	_waiting = _queue.pop_front()
	_build(_waiting)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The pieces an icon shows: the base's look, each in its v2 version when it has one.
static func icon_pieces(base_id: String) -> Array[Dictionary]:
	var cat := CharacterCatalog.load_default()
	var out: Array[Dictionary] = []
	for id: String in ItemDB.load_default().base(base_id).get("look", []):
		var p := cat.piece_v2(id)
		if p.is_empty():
			p = cat.piece(id)
		if not p.is_empty():
			out.append(p)
	return out


## Lays the base's pieces out as worn around one point, and frames them.
func _build(base_id: String) -> void:
	for c: Node in _holder.get_children():
		c.queue_free()
	var box := AABB()
	var first := true
	for p: Dictionary in icon_pieces(base_id):
		var mesh := VoxMesher.cached(str(p.get("file", "")), ICON_TINTS)
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var o: Array = p.get("offset", [0, 0, 0])
		node.position = Vector3(o[0], o[1], o[2]) * VoxMesher.VOXEL_SIZE
		_holder.add_child(node)
		var b := mesh.get_aabb()
		b.position += node.position
		box = b if first else box.merge(b)
		first = false
	_holder.rotation_degrees = Vector3(0, -35, 0)
	var center := _holder.transform * box.get_center()
	var extent := maxf(box.size.length(), 0.2)
	_camera.size = extent * 1.05
	_camera.look_at_from_position(center + Vector3(0, extent * 0.35, extent * 2.0), center)
