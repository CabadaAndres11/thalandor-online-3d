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
## Pieces and ground are grouped in chunks of CHUNK×CHUNK cells (Plan 8.1.1).
const CHUNK := 16
## Closer than this (from the camera) a piece uses its detailed mesh; beyond, a coarse one.
const LOD_NEAR := 45.0
## Draw distance of a piece without "range" in pieces.json.
const RANGE_DEFAULT := 90.0
## Coarse meshes merge COARSE³ voxels into one.
const COARSE := 2

static var _coarse_cache: Dictionary = {}

var grid: GridMap
var layout: ZoneLayout
var ambience_id: String = Ambience.DEFAULT_ID
var quality: int = GraphicsQuality.MEDIUM
var torches: Array[Torch] = []
var _sun: DirectionalLight3D
var _world_env: WorldEnvironment
var _particles: GPUParticles3D
var _follow := Vector3.ZERO
var _shadow_proxies: Array[GeometryInstance3D] = []
## The house open around the own player (-1: none), Plan 8.1.1.
var open_index: int = -1


## Builds the zone; returns its collision (the same as layout.collision()).
func build(p_layout: ZoneLayout, quality_level: int = GraphicsQuality.MEDIUM) -> CollisionMap:
	for step: Callable in build_steps(p_layout, quality_level):
		step.call()
	return layout.collision()


## The same build cut into steps to run one per frame behind the loading screen (Plan
## 8.1.1): the ground, each kind of piece, the blocks and torches, then the lighting.
func build_steps(p_layout: ZoneLayout, quality_level: int = GraphicsQuality.MEDIUM) -> Array[Callable]:
	layout = p_layout
	quality = GraphicsQuality.clamp_level(quality_level)
	ambience_id = Ambience.resolve_id(layout.ambience)
	var steps: Array[Callable] = [_build_ground]
	var groups := _piece_groups()
	var kinds := {}
	for key: String in groups:
		kinds[key.get_slice("#", 0)] = true
	for kind: String in kinds:
		steps.append(_build_pieces.bind(groups, kind))
	if not layout.houses.is_empty():
		steps.append(_build_houses)
	steps.append(_build_blocks)
	steps.append(func() -> void: _add_torches(layout.torches))
	steps.append(_apply_lighting)
	return steps


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
	# Beyond the map's edge the ground goes on (darker, never walked), so the border shows no void.
	var outer := MeshInstance3D.new()
	outer.name = "GroundBeyond"
	var plane := PlaneMesh.new()
	plane.size = Vector2(layout.size) + Vector2(400, 400)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = (GROUND.get(str(layout.terrain.get("base", "grass")), GROUND.grass) as Color).darkened(0.25)
	outer_mat.roughness = 1.0
	plane.material = outer_mat
	outer.mesh = plane
	outer.position = Vector3(layout.size.x / 2.0, -0.03, layout.size.y / 2.0)
	add_child(outer)
	var by_kind := {} # "kind#cx,cz" -> cells (one mesh per kind and chunk, Plan 8.1.1)
	var cells := ground_cells()
	for c: Vector2i in cells:
		var key := chunk_name(str(cells[c]), c)
		if not by_kind.has(key):
			by_kind[key] = []
		(by_kind[key] as Array).append(c)
	for key: String in by_kind:
		var kind := key.get_slice("#", 0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base: Color = GROUND.get(kind, GROUND.grass)
		var y := -WATER_DEPTH if kind == "water" else 0.0
		for c: Vector2i in by_kind[key]:
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
		mi.name = "Ground_" + key
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)


## Pieces of a kind in a 16×16 chunk share nodes (Plan 8.1.1): Godot culls whole chunks
## off camera. Pieces that cast shadow have the detailed mesh up close (LOD_NEAR), a coarse
## copy beyond and a coarse shadow-only copy (no shadows at LOW); small pieces one mesh.
func _build_pieces(groups: Dictionary, kind: String) -> void:
	var root := get_node_or_null("Pieces")
	if root == null:
		root = Node3D.new()
		root.name = "Pieces"
		add_child(root)
	for key: String in groups:
		if key.get_slice("#", 0) != kind:
			continue
		var list: Array = groups[key]
		var piece_id := str(list[0].id)
		var def := layout.piece_def(piece_id)
		var path := str(def.get("vox", ""))
		var mesh := VoxMesher.cached(path, {})
		if mesh == null:
			continue
		var draw_range := float(def.get("range", RANGE_DEFAULT))
		var shadow := str(def.get("shadow", "medium")) != "never"
		var near := _chunk_node(root, key, mesh, list, Transform3D.IDENTITY)
		near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not shadow or draw_range <= LOD_NEAR:
			near.visibility_range_end = draw_range # small pieces: one detailed mesh, no shadow
			continue
		near.visibility_range_end = LOD_NEAR
		var coarse := _coarse_mesh(path)
		var scale := Transform3D(Basis.from_scale(Vector3.ONE * COARSE), Vector3.ZERO)
		var far := _chunk_node(root, key + "~far", coarse, list, scale)
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far.visibility_range_begin = LOD_NEAR
		far.visibility_range_end = draw_range
		if shadow:
			var proxy := _chunk_node(root, key + "~shadow", coarse, list, scale)
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.visibility_range_end = draw_range
			_shadow_proxies.append(proxy)


## "id#cx,cz" -> the placed pieces of that kind in that chunk (houses are HouseViews).
func _piece_groups() -> Dictionary:
	var groups := {}
	for p: Dictionary in layout.pieces:
		if layout.piece_def(str(p.id)).has("parts"):
			continue
		var key := chunk_name(str(p.id), p.at)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(p)
	return groups


## "id#cx,cz": the node of a piece kind in the chunk holding `at`.
static func chunk_name(piece_id: String, at: Vector2i) -> String:
	return "%s#%d,%d" % [piece_id, floori(at.x / float(CHUNK)), floori(at.y / float(CHUNK))]


func _chunk_node(root: Node, node_name: String, mesh: Mesh, list: Array, local: Transform3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, piece_transform(list[i]) * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	root.add_child(mmi)
	return mmi


## The 2× coarse mesh of a piece (shared by every zone).
static func _coarse_mesh(path: String) -> ArrayMesh:
	if not _coarse_cache.has(path):
		var vox := VoxFile.load_file(path)
		_coarse_cache[path] = VoxMesher.build(VoxMesher.downsample(vox, COARSE), {}) if vox != null else null
	return _coarse_cache[path]


## Where a placed piece is drawn: turned about the centre of its cell (0, 0) like its
## footprint ((1, 0) -> (0, 1)), at its voxel offset and scale.
func piece_transform(p: Dictionary) -> Transform3D:
	var def := layout.piece_def(str(p.id))
	var off: Array = def.get("offset", [0, 0, 0])
	var scale_f := float(def.get("scale", 0.5))
	var local := Transform3D(Basis.from_scale(Vector3.ONE * scale_f),
		Vector3(float(off[0]), float(off[1]), float(off[2])) * VoxMesher.VOXEL_SIZE * scale_f)
	return placement(p) * local


## The cell (0, 0) corner of a placed piece, turned like its footprint.
static func placement(p: Dictionary) -> Transform3D:
	var at: Vector2i = p.at
	var turn := Transform3D(Basis(Vector3.UP, -deg_to_rad(float(p.rot))), Vector3.ZERO)
	return Transform3D.IDENTITY.translated(Vector3(at.x + 0.5, 0, at.y + 0.5)) * turn \
		* Transform3D.IDENTITY.translated(Vector3(-0.5, 0, -0.5))


func _build_houses() -> void:
	var root := Node3D.new()
	root.name = "Houses"
	add_child(root)
	for h: Dictionary in layout.houses:
		var view := HouseView.new()
		view.name = "house_%d" % h.index
		root.add_child(view)
		view.setup(layout.piece_def(str(h.id)), placement(h))


## Opens the house `index` (its roof fades, its walls are cut) and closes the others; -1
## closes them all. Only the own player's house opens (Plan 8.1.1).
func open_house(index: int) -> void:
	open_index = index
	var root := get_node_or_null("Houses")
	if root == null:
		return
	for view: HouseView in root.get_children():
		view.set_open(view.name == "house_%d" % index)


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
	for proxy: GeometryInstance3D in _shadow_proxies:
		proxy.visible = quality >= GraphicsQuality.MEDIUM
