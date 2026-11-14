class_name Arena
extends Node3D
## Builds the test arena (GridMap of 1 m voxel blocks, light and environment) from map
## data and returns the matching CollisionMap.

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


static func load_layout(path: String = LAYOUT_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func build(layout: Dictionary) -> CollisionMap:
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
	_add_lighting()
	return map


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


func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9cc7e6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9d6e6")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)
