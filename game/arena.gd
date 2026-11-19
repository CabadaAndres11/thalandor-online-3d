class_name Arena
extends Node3D
## Builds the test arena (GridMap of 1 m voxel blocks, torches, and the light and
## environment of its data ambience) from map data and returns the matching CollisionMap.
## Changing the ambience or the quality level rebuilds the lighting in place.

const LAYOUT_PATH := "res://data/maps/test_arena.json"
const ITEM_FLOOR := 0
const ITEM_BLOCK_A := 1
const ITEM_BLOCK_B := 2
const COLORS := {
	ITEM_FLOOR: Color("#6f9a5a"),
	ITEM_BLOCK_A: Color("#9c8b74"),
	ITEM_BLOCK_B: Color("#7d8794"),
}

var grid: GridMap
var ambience_id: String = Ambience.DEFAULT_ID
var quality: int = GraphicsQuality.MEDIUM
var torches: Array[Torch] = []
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _particles: GPUParticles3D
var _follow := Vector3.ZERO


static func load_layout(path: String = LAYOUT_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func build(layout: Dictionary, quality_level: int = GraphicsQuality.MEDIUM) -> CollisionMap:
	var map := CollisionMap.from_layout(layout)
	grid = GridMap.new()
	grid.name = "Blocks"
	grid.cell_size = Vector3.ONE
	grid.mesh_library = _make_library()
	add_child(grid)
	for x in map.size.x:
		for z in map.size.y:
			grid.set_cell_item(Vector3i(x, -1, z), ITEM_FLOOR)
	var i := 0
	for block: Array in layout.get("blocks", []):
		var item := ITEM_BLOCK_A if i % 2 == 0 else ITEM_BLOCK_B
		for y in int(block[2]):
			grid.set_cell_item(Vector3i(int(block[0]), y, int(block[1])), item)
		i += 1
	_add_torches(layout.get("torches", []))
	quality = GraphicsQuality.clamp_level(quality_level)
	var wanted := str(layout.get("ambience", Ambience.DEFAULT_ID))
	ambience_id = wanted if wanted in Ambience.ids() else Ambience.DEFAULT_ID
	_apply_lighting()
	return map


## Switches to another data ambience; false (and no change) if it does not exist.
func set_ambience(id: String) -> bool:
	if not id in Ambience.ids():
		return false
	ambience_id = id
	_apply_lighting()
	return true


func set_quality(q: int) -> void:
	quality = GraphicsQuality.clamp_level(q)
	_apply_lighting()


## Keeps the ambient particles around the camera target.
func follow(pos: Vector3) -> void:
	_follow = pos
	if _particles != null:
		_particles.position = pos # the arena sits at the world origin


func _make_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	for id: int in COLORS:
		var mesh := BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[id]
		mat.roughness = 0.9
		mesh.material = mat
		lib.create_item(id)
		lib.set_item_mesh(id, mesh)
	return lib


func _add_torches(cells: Array) -> void:
	var root := Node3D.new()
	root.name = "Torches"
	add_child(root)
	for cell: Variant in cells:
		if not (cell is Array and cell.size() >= 2):
			continue
		var torch := Torch.new()
		torch.position = Vector3(float(cell[0]) + 0.5, 0.0, float(cell[1]) + 0.5)
		root.add_child(torch)
		torches.append(torch)


func _apply_lighting() -> void:
	var a := Ambience.load_id(ambience_id)
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		add_child(_sun)
	AmbienceBuilder.configure_sun(_sun, a, quality)
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "Environment"
		add_child(_world_env)
	_world_env.environment = AmbienceBuilder.make_environment(a, quality)
	_world_env.camera_attributes = AmbienceBuilder.camera_attributes(a, quality)
	if _particles != null:
		remove_child(_particles)
		_particles.free()
	_particles = AmbienceBuilder.make_particles(a, quality)
	if _particles != null:
		_particles.position = _follow
		add_child(_particles)
	for torch: Torch in torches:
		torch.set_quality(quality)
