class_name ZoneView
extends Node3D
## Draws a zone (Plan 8.1, ZoneLayout): the ground as one mesh per kind of terrain, the
## pieces as one MultiMeshInstance3D per kind (hundreds of trees, one node), the old
## stacked blocks of the test arena, the torches, and the light, fog and particles of its
## data ambience. Changing the ambience or the quality rebuilds the lighting in place.

const ITEM_BLOCK_A := 1
const ITEM_BLOCK_B := 2
const BLOCK_COLORS := {ITEM_BLOCK_A: Color("#9c8b74"), ITEM_BLOCK_B: Color("#7d8794")}
## Colour of each kind of ground (a little noise per cell is added on top).
const GROUND := {
	"grass": Color("#5f8a49"), "dirt": Color("#7a6446"), "road": Color("#8c7a5a"), "stone": Color("#6f6c66"),
	"sand": Color("#c2ad7c"), "water": Color("#3d6f8f"), "crypt": Color("#3d3a36"),
}
const WATER_DEPTH := 0.12
const VOXEL := 0.05 # world pieces are 5 cm voxels (VoxMesher's 0.1 m at scale 0.5)

var grid: GridMap
var layout: ZoneLayout
var ambience_id: String = Ambience.DEFAULT_ID
var quality: int = GraphicsQuality.MEDIUM
var torches: Array[Torch] = []
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _particles: GPUParticles3D
var _follow := Vector3.ZERO


## Builds the zone; returns its collision (the same as layout.collision()).
func build(p_layout: ZoneLayout, quality_level: int = GraphicsQuality.MEDIUM) -> CollisionMap:
	layout = p_layout
	_build_ground()
	_build_pieces()
	_build_blocks()
	_add_torches(layout.torches)
	quality = GraphicsQuality.clamp_level(quality_level)
	ambience_id = Ambience.resolve_id(layout.ambience)
	_apply_lighting()
	return layout.collision()


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
		_particles.position = pos


## The ground kind of every cell: the base, painted areas on top, then paths.
func ground_cells() -> Dictionary:
	var kinds := {}
	var base := str(layout.terrain.get("base", "grass"))
	for a: Dictionary in layout.terrain.get("areas", []):
		var r: Array = a.get("area", [0, 0, 0, 0])
		for x in range(int(r[0]), int(r[0]) + int(r[2])):
			for z in range(int(r[1]), int(r[1]) + int(r[3])):
				kinds[Vector2i(x, z)] = str(a.get("kind", base))
	for p: Dictionary in layout.paths:
		for c: Vector2i in ZoneLayout.path_cells(p):
			kinds[c] = str(p.get("terrain", "road"))
	var out := {}
	for x in layout.size.x:
		for z in layout.size.y:
			var c := Vector2i(x, z)
			out[c] = kinds.get(c, base)
	return out


func _build_ground() -> void:
	var by_kind := {}
	var cells := ground_cells()
	for c: Vector2i in cells:
		if not by_kind.has(cells[c]):
			by_kind[cells[c]] = []
		(by_kind[cells[c]] as Array).append(c)
	for kind: String in by_kind:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base: Color = GROUND.get(kind, GROUND.grass)
		var y := -WATER_DEPTH if kind == "water" else 0.0
		for c: Vector2i in by_kind[kind]:
			var n := (hash(c) % 1000) / 1000.0
			st.set_color(base.darkened(0.08 * n) if n < 0.5 else base.lightened(0.05 * n))
			st.set_normal(Vector3.UP)
			var p0 := Vector3(c.x, y, c.y)
			for v: Vector3 in [p0, p0 + Vector3(1, 0, 0), p0 + Vector3(1, 0, 1), p0, p0 + Vector3(1, 0, 1), p0 + Vector3(0, 0, 1)]:
				st.add_vertex(v)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.2 if kind == "water" else 0.95
		var mi := MeshInstance3D.new()
		mi.name = "Ground_" + kind
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)


func _build_pieces() -> void:
	var by_id := {}
	for p: Dictionary in layout.pieces:
		if not by_id.has(p.id):
			by_id[p.id] = []
		(by_id[p.id] as Array).append(p)
	var root := Node3D.new()
	root.name = "Pieces"
	add_child(root)
	for piece_id: String in by_id:
		var def := layout.piece_def(piece_id)
		var mesh := VoxMesher.cached(str(def.get("vox", "")), {})
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var list: Array = by_id[piece_id]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, piece_transform(list[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = piece_id
		mmi.multimesh = mm
		root.add_child(mmi)


## Where a placed piece is drawn: turned about the centre of its cell (0, 0) like its
## footprint ((1, 0) -> (0, 1)), at its voxel offset and scale.
func piece_transform(p: Dictionary) -> Transform3D:
	var def := layout.piece_def(str(p.id))
	var off: Array = def.get("offset", [0, 0, 0])
	var local := Transform3D(Basis.from_scale(Vector3.ONE * float(def.get("scale", 0.5))),
		Vector3(float(off[0]), float(off[1]), float(off[2])) * VOXEL)
	var at: Vector2i = p.at
	var turn := Transform3D(Basis(Vector3.UP, -deg_to_rad(float(p.rot))), Vector3.ZERO)
	return Transform3D.IDENTITY.translated(Vector3(at.x + 0.5, 0, at.y + 0.5)) * turn \
		* Transform3D.IDENTITY.translated(Vector3(-0.5, 0, -0.5)) * local


func _build_blocks() -> void:
	if layout.blocks.is_empty():
		return
	grid = GridMap.new()
	grid.name = "Blocks"
	grid.cell_size = Vector3.ONE
	grid.mesh_library = _make_library()
	add_child(grid)
	var i := 0
	for block: Array in layout.blocks:
		var item := ITEM_BLOCK_A if i % 2 == 0 else ITEM_BLOCK_B
		for y in int(block[2]):
			grid.set_cell_item(Vector3i(int(block[0]), y, int(block[1])), item)
		i += 1


func _make_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	for id: int in BLOCK_COLORS:
		var mesh := BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BLOCK_COLORS[id]
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
		torch.energy_scale = a.torch_energy
