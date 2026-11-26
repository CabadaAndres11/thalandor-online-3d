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
	"forest": Color("#3f5530"), # the floor under the edge band (Plan 8.1.2)
}
const WATER_DEPTH := 0.12
## Pixels per cell of the ground texture (Plan 8.1.3).
const GROUND_PX := 4
## Pieces and ground are grouped in chunks of CHUNK×CHUNK cells (Plan 8.1.1).
const CHUNK := 16
## Closer than this (from the camera) a piece uses its detailed mesh; beyond, a coarse one.
const LOD_NEAR := 45.0
## Draw distance of a piece without "range" in pieces.json.
const RANGE_DEFAULT := 90.0
## A signpost's zone name shows within this distance of the camera.
const SIGN_READ_RANGE := 40.0
## Suffix of the nodes of the edge band and the outer forest: they cast no shadow (their
## square shadows on the paths looked bad, Plan 8.1.2).
const EDGE := "e"
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
## The ground picture (Plan 8.1.3) and the details sown on it: {id, at, rot, off}.
var ground_image: Image
var decor: Array = []
## The house open around the own player (-1: none), Plan 8.1.1.
var _house_cover: Dictionary = {} # cell -> house index (walls and inside)
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
	_sow_decor()
	var groups := _piece_groups()
	var kinds := {}
	for key: String in groups:
		kinds[key.get_slice("#", 0)] = true
	# Each model is meshed in a step of its own (the slow part, once per game) so no frame
	# stalls long: the network keeps answering while a zone loads.
	for kind: String in kinds:
		var def := layout.piece_def(kind)
		var path := str(def.get("vox", ""))
		steps.append(func() -> void: VoxMesher.cached(path, {}))
		if str(def.get("shadow", "medium")) != "never" and float(def.get("range", RANGE_DEFAULT)) > LOD_NEAR:
			steps.append(func() -> void: _coarse_mesh(path))
		steps.append(_build_pieces.bind(groups, kind))
	var house_kinds := {}
	for h: Dictionary in layout.houses:
		house_kinds[str(h.id)] = true
	for kind: String in house_kinds:
		for part: Dictionary in (layout.piece_def(kind).get("parts", {}) as Dictionary).values():
			var part_path := str(part.get("vox", ""))
			steps.append(func() -> void: VoxMesher.cached(part_path, {}))
	if not layout.houses.is_empty():
		steps.append(_build_houses)
	steps.append(_build_blocks)
	steps.append(_build_exit_marks)
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
	return ground_cells_of(layout)


static func ground_cells_of(layout: ZoneLayout) -> Dictionary:
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
	if layout.band > 0:
		for x in layout.size.x:
			for z in layout.size.y:
				if layout.in_band(Vector2i(x, z)):
					kinds[Vector2i(x, z)] = "forest"
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
	# Under the outer margin: forest floor (or the dungeon's rock), so gaps between trees
	# read as undergrowth, not as void (Plan 8.1.2).
	var beyond: Color = GROUND.crypt if layout.instanced else GROUND.forest
	outer_mat.albedo_color = beyond.darkened(0.15)
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
	# One pixel texture for the whole zone (Plan 8.1.3): GROUND_PX × GROUND_PX pixels per
	# cell in patches of three tones, borders between kinds dithered.
	ground_image = make_ground_image(cells)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_texture = ImageTexture.create_from_image(ground_image)
	ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_mat.roughness = 0.95
	var inv := Vector2(1.0 / layout.size.x, 1.0 / layout.size.y)
	for key: String in by_kind:
		var kind := key.get_slice("#", 0)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var base: Color = GROUND.get(kind, GROUND.grass)
		var y := -WATER_DEPTH if kind == "water" else 0.0
		for c: Vector2i in by_kind[key]:
			var n := (hash(c) % 1000) / 1000.0
			st.set_color(base.darkened(0.08 * n) if n < 0.5 else base.lightened(0.05 * n))
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var corner := c + k
				# The relief lifts the ground at each corner (Plan 8.3d); water lies in its hollow.
				var v := Vector3(corner.x, y + layout.corner_height(corner), corner.y)
				st.set_uv(Vector2(v.x, v.z) * inv)
				st.add_vertex(v)
		st.generate_normals()
		var mat := ground_mat
		if kind == "water":
			mat = StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.2
		var mi := MeshInstance3D.new()
		mi.name = "Ground_" + key
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)


## Pieces of a kind in a 16×16 chunk share nodes (Plan 8.1.1): Godot culls whole chunks
## off camera. Pieces that cast shadow have the detailed mesh up close (LOD_NEAR), a coarse
## copy beyond and a coarse shadow-only copy (no shadows at LOW); small pieces one mesh.
## The ground picture: per cell GROUND_PX² pixels of three tones of its kind in patches
## of 2×2, and on a border with another kind a few pixels of the neighbour's colour.
func make_ground_image(cells: Dictionary) -> Image:
	var px := GROUND_PX
	var w := layout.size.x * px
	var h := layout.size.y * px
	var tones := {}
	for kind: String in GROUND:
		var c: Color = GROUND[kind]
		tones[kind] = [c, c.darkened(0.12), c.lightened(0.08)]
	var data := PackedByteArray()
	data.resize(w * h * 3)
	var i := 0
	for y in h:
		var cz := y / px
		var sy := y % px
		for x in w:
			var cx := x / px
			var sx := x % px
			var kind: String = cells.get(Vector2i(cx, cz), "grass")
			var r := _hash3(x, y, 7)
			# A border pixel may take the colour of the neighbour on that side.
			var side := Vector2i.ZERO
			if sx == 0:
				side = Vector2i(-1, 0)
			elif sx == px - 1:
				side = Vector2i(1, 0)
			elif sy == 0:
				side = Vector2i(0, -1)
			elif sy == px - 1:
				side = Vector2i(0, 1)
			if side != Vector2i.ZERO and r < 0.4:
				var other: Variant = cells.get(Vector2i(cx, cz) + side)
				if other != null and other != kind and other != "water" and kind != "water":
					kind = other
			var patch := _hash3(x / 2, y / 2, 11)
			var col: Color = (tones.get(kind, tones.grass) as Array)[0 if patch < 0.55 else (1 if patch < 0.8 else 2)]
			data[i] = col.r8
			data[i + 1] = col.g8
			data[i + 2] = col.b8
			i += 3
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)


static func _hash3(a: int, b: int, c: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 1023) / 1024.0


## Grass tufts and flowers on grass, pebbles on dirt and roads (Plan 8.1.3): sown by cell
## (the same every time), never on pieces, in houses, on water or in the edge band; fewer
## at LOW quality. Drawn like the small pieces (by chunk, no shadow, close only).
func _sow_decor() -> void:
	decor.clear()
	var taken := {}
	for p: Dictionary in layout.pieces:
		for c: Vector2i in layout.footprint(str(p.id), p.at, p.rot):
			taken[c] = true
	for h: Dictionary in layout.houses:
		for c: Vector2i in h.cells + h.door:
			taken[c] = true
	var scale_d := 0.4 if quality <= GraphicsQuality.LOW else 1.0
	var cells := ground_cells()
	for c: Vector2i in cells:
		if taken.has(c) or layout.in_band(c):
			continue
		var kind: String = cells[c]
		var r := _hash3(c.x, c.y, 31)
		var id := ""
		if kind == "grass":
			if r < 0.035 * scale_d:
				id = ["flower_blue", "flower_white", "flower_yellow"][int(_hash3(c.x, c.y, 37) * 3.0)]
			elif r < 0.3 * scale_d:
				id = "grass_tuft"
		elif kind in ["dirt", "road", "forest"] and r < 0.06 * scale_d:
			id = "pebbles" if kind != "forest" else "grass_tuft"
		if id == "" or layout.piece_def(id).is_empty():
			continue
		decor.append({"id": id, "at": c, "rot": int(_hash3(c.x, c.y, 41) * 4.0) * 90,
			"off": Vector3(_hash3(c.x, c.y, 43) - 0.5, 0.0, _hash3(c.x, c.y, 47) - 0.5) * 0.6})


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
		var small := str(def.get("shadow", "medium")) == "never"
		var shadow := not small and not key.ends_with(EDGE)
		var near := _chunk_node(root, key, mesh, list, Transform3D.IDENTITY)
		near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if small or draw_range <= LOD_NEAR:
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
	for p: Dictionary in decor:
		var dkey := chunk_name(str(p.id), p.at)
		if not groups.has(dkey):
			groups[dkey] = []
		(groups[dkey] as Array).append(p)
	for edge: bool in [false, true]:
		for p: Dictionary in (layout.margin_pieces if edge else layout.pieces):
			if layout.piece_def(str(p.id)).has("parts"):
				continue
			var key := chunk_name(str(p.id), p.at) + (EDGE if edge else "") # the edge: its own nodes, no shadow
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
	var lift := Transform3D.IDENTITY.translated(Vector3(0, ground_at(p), 0)) # on the relief (Plan 8.3d)
	if p.has("off"): # ground details sit anywhere in their cell
		return lift * Transform3D.IDENTITY.translated(p.off) * placement(p) * local
	return lift * placement(p) * local


## The ground's height under a placed piece (its cell's centre, or its detail's spot).
func ground_at(p: Dictionary) -> float:
	if layout == null or layout.relief.is_empty():
		return 0.0
	var at: Vector2i = p.at
	var off: Vector3 = p.get("off", Vector3.ZERO)
	return layout.height_at(at.x + 0.5 + off.x, at.y + 0.5 + off.z)


## The cell (0, 0) corner of a placed piece, turned like its footprint.
static func placement(p: Dictionary) -> Transform3D:
	var at: Vector2i = p.at
	var turn := Transform3D(Basis(Vector3.UP, -deg_to_rad(float(p.rot))), Vector3.ZERO)
	return Transform3D.IDENTITY.translated(Vector3(at.x + 0.5, 0, at.y + 0.5)) * turn \
		* Transform3D.IDENTITY.translated(Vector3(-0.5, 0, -0.5))


## The gates of the exits the story opens (Plan 8.3b): the closed or the open piece, for this
## player's own story. Only drawn: the exit itself refuses (or lets through) on the host.
func show_gates(log: QuestLog) -> void:
	for i in layout.exits.size():
		var e: Dictionary = layout.exits[i]
		var gate: Dictionary = e.get("gate", {})
		if gate.is_empty():
			continue
		var want := str(gate.get("open" if ZoneLayout.exit_open(e, log) else "closed", ""))
		var node_name := "Gate_%d" % i
		var old := get_node_or_null(node_name)
		if old != null and old.get_meta("piece", "") == want:
			continue
		if old != null:
			remove_child(old)
			old.queue_free()
		var mesh := VoxMesher.cached(str(layout.piece_def(want).get("vox", "")), {})
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh
		mi.set_meta("piece", want)
		mi.transform = piece_transform({"id": want, "at": ZoneLayout._v2i(gate.get("at", [0, 0])), "rot": int(gate.get("rot", 0))})
		add_child(mi)


## Pieces that stay until the player is done with their quest point (Plan 8.3d): drawn only.
func show_story_pieces(log: QuestLog, quests: QuestDB) -> void:
	for i in layout.story_pieces.size():
		var sp: Dictionary = layout.story_pieces[i]
		var node_name := "Story_%d" % i
		var want := not QuestText.point_done(log, quests, str(sp.point))
		var old := get_node_or_null(node_name)
		if want and old == null:
			var mesh := VoxMesher.cached(str(layout.piece_def(str(sp.id)).get("vox", "")), {})
			if mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = node_name
			mi.mesh = mesh
			mi.transform = piece_transform(sp)
			add_child(mi)
		elif not want and old != null:
			remove_child(old)
			old.queue_free()


func story_piece_shown(index: int) -> bool:
	return get_node_or_null("Story_%d" % index) != null


## The piece a gate shows now ("" if none).
func gate_piece(index: int) -> String:
	var n := get_node_or_null("Gate_%d" % index)
	return str(n.get_meta("piece", "")) if n != null else ""


## The name of the zone each way out leads to on its signpost, and a soft glow on the
## ground of each exit (Plan 8.1.1).
func _build_exit_marks() -> void:
	var root := Node3D.new()
	root.name = "Exits"
	add_child(root)
	for m: Dictionary in layout.exit_markers:
		var label := Label3D.new()
		label.text = tr("ZONE_" + str(m.to).to_upper())
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.outline_size = 12
		label.modulate = Color("#ffe2a8")
		label.visibility_range_end = SIGN_READ_RANGE
		var at: Vector2i = m.at
		label.position = Vector3(at.x + 0.5, 2.8 + layout.height_at(at.x + 0.5, at.y + 0.5), at.y + 0.5)
		root.add_child(label)
	for i in layout.exits.size():
		var r: Rect2i = layout.exits[i].area
		var glow := MeshInstance3D.new()
		glow.name = "ExitGlow_%d" % i
		var plane := PlaneMesh.new()
		plane.size = Vector2(r.size)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.8, 0.45, 0.28)
		plane.material = mat
		glow.mesh = plane
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(r.position.x + r.size.x / 2.0, 0.03, r.position.y + r.size.y / 2.0)
		root.add_child(glow)
		# The way goes on through the margin (a dirt track into the trees).
		var inward := layout.exit_inward(r)
		if inward == Vector2i.ZERO:
			continue
		var track := MeshInstance3D.new()
		track.name = "ExitTrack_%d" % i
		var strip := PlaneMesh.new()
		var len := float(ZoneLayout.MARGIN)
		strip.size = Vector2(len, r.size.y) if inward.x != 0 else Vector2(r.size.x, len)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = GROUND.road
		tmat.roughness = 1.0
		strip.material = tmat
		track.mesh = strip
		var c := Vector2(r.position) + Vector2(r.size) / 2.0 - Vector2(inward) * (len / 2.0 + (r.size.x if inward.x != 0 else r.size.y) / 2.0)
		track.position = Vector3(c.x, -0.01, c.y)
		root.add_child(track)


func _build_houses() -> void:
	var root := Node3D.new()
	root.name = "Houses"
	add_child(root)
	for h: Dictionary in layout.houses:
		var view := HouseView.new()
		view.name = "house_%d" % h.index
		root.add_child(view)
		view.setup(layout.piece_def(str(h.id)), Transform3D.IDENTITY.translated(Vector3(0, ground_at(h), 0)) * placement(h))
		view.set_quality(quality)
	if open_index >= 0:
		open_house(open_index) # the player was already inside when the zone loaded


## Opens the house `index` (its roof fades, its walls are cut) and closes the others; -1
## closes them all. Only the own player's house opens (Plan 8.1.1).
## The houses whose walls stand between the camera and `target` (up to 8 m from it).
func occluders(cam_pos: Vector3, target: Vector3) -> Array:
	if layout == null or layout.houses.is_empty():
		return []
	if _house_cover.is_empty():
		for h: Dictionary in layout.houses:
			for c: Vector2i in layout.footprint(h.id, h.at, h.rot) + (h.cells as Array):
				_house_cover[c] = int(h.index)
	var out: Array = []
	var from := Vector2(target.x, target.z)
	var dir := Vector2(cam_pos.x, cam_pos.z) - from
	if dir.length() < 0.01:
		return out
	dir = dir.normalized()
	for i in range(1, 17):
		var p := from + dir * (i * 0.5)
		var c := Vector2i(floori(p.x), floori(p.y))
		if _house_cover.has(c) and not int(_house_cover[c]) in out:
			out.append(int(_house_cover[c]))
	return out


## Opens several houses at once (the one you are in, or those hiding you); closes the rest.
func open_houses(indices: Array) -> void:
	open_index = int(indices[0]) if not indices.is_empty() else -1
	var root := get_node_or_null("Houses")
	if root == null:
		return
	for view: HouseView in root.get_children():
		view.set_open(indices.any(func(i: int) -> bool: return view.name == "house_%d" % i))


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
		torch.position = Vector3(float(cell[0]) + 0.5, layout.height_at(float(cell[0]) + 0.5, float(cell[1]) + 0.5), float(cell[1]) + 0.5)
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
	var houses := get_node_or_null("Houses")
	if houses != null:
		for view: HouseView in houses.get_children():
			view.set_quality(quality)
