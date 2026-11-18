class_name VoxelFx
extends RefCounted
## Voxel models for spell effects, built in code: an arcane prism, a fire orb, ice crystals
## and spikes, burning ground and a pentagram. A model is a Dictionary of cells
## (Vector3i -> Color) in cube units, merged into one mesh with vertex colours. Models face
## +Z (forward) with +Y up.

const CUBE := 0.1
const CORNERS := [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
]
const TRIS := [
	[0, 1, 2], [0, 2, 3], [4, 6, 5], [4, 7, 6], [0, 4, 5], [0, 5, 1],
	[3, 2, 6], [3, 6, 7], [0, 3, 7], [0, 7, 4], [1, 5, 6], [1, 6, 2],
]

const ARCANE := Color("#8f3dff")
const ARCANE_LIGHT := Color("#e2c4ff")
const ICE := Color("#7fd8ff")
const ICE_LIGHT := Color("#f2fcff")


# --- Meshes -------------------------------------------------------------------------

## One mesh with a cube of side `cube` per cell, coloured per cell.
static func mesh_of(cells: Dictionary, cube: float = CUBE) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var h := cube * 0.5
	for c: Vector3i in cells:
		var center := Vector3(c) * cube
		var col: Color = cells[c]
		for tri: Array in TRIS:
			for i: int in tri:
				verts.append(center + (CORNERS[i] as Vector3) * h)
				cols.append(col)
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Unshaded material that shows the cell colours; `glow` adds light to what is behind it.
static func material(glow: bool, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func node(cells: Dictionary, glow: bool = false, alpha: float = 1.0, cube: float = CUBE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh_of(cells, cube)
	n.material_override = material(glow, alpha)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Sets how visible a node made by `node` is (0 to 1).
static func set_alpha(n: MeshInstance3D, alpha: float) -> void:
	(n.material_override as StandardMaterial3D).albedo_color.a = clampf(alpha, 0.0, 1.0)


# --- Shapes -------------------------------------------------------------------------

## The arcane projectile: a purple prism with a bright core, long along +Z.
static func arcane_prism() -> Dictionary:
	var cells := {}
	for z in range(-5, 6):
		var r := int(round(2.0 * (1.0 - absf(float(z)) / 6.0)))
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if absi(x) + absi(y) <= r:
					cells[Vector3i(x, y, z)] = ARCANE_LIGHT if (x == 0 and y == 0) else ARCANE.lerp(ARCANE_LIGHT, 0.15 * float(r - absi(x) - absi(y)))
	return cells


## A ball of flames: yellow in the middle, orange and red outside, with gaps at the edge.
static func fire_orb(seed_value: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				var d := Vector3(x, y, z).length()
				if d > 2.1 or (d > 1.5 and rng.randf() < 0.3):
					continue
				cells[Vector3i(x, y, z)] = Color("#ffe27a") if d < 1.0 else (Color("#ff9a2a") if d < 1.6 else Color("#ff5a14"))
	return cells


## A faceted ice crystal (an octahedron), pale in the middle.
static func ice_crystal() -> Dictionary:
	var cells := {}
	for x in range(-3, 4):
		for y in range(-3, 4):
			for z in range(-3, 4):
				var d := absi(x) + absi(y) + absi(z)
				if d <= 3:
					cells[Vector3i(x, y, z)] = ICE_LIGHT if d <= 1 else ICE.lerp(ICE_LIGHT, 0.2 * float(3 - d))
	return cells


## An ice spike `height` cubes tall: a 3x3 base that tapers to one cube, whiter at the tip.
static func ice_spike(height: int) -> Dictionary:
	var cells := {}
	height = maxi(height, 2)
	for y in height:
		var half := int(floor(float(height - y) * 1.6 / float(height)))
		for x in range(-half, half + 1):
			for z in range(-half, half + 1):
				cells[Vector3i(x, y, z)] = ICE.lerp(ICE_LIGHT, float(y) / float(height))
	return cells


## Flames over the ground: random columns inside a circle, hotter at the top. `cube` is
## bigger than the projectile cubes (these are seen from far away).
static func flame_patch(radius_m: float, cube: float = 0.18, seed_value: int = 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	var columns := clampi(int(radius_m * radius_m * 2.5), 8, 80)
	for i in columns:
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius_m * 0.9
		var cx := roundi(cos(angle) * dist / cube)
		var cz := roundi(sin(angle) * dist / cube)
		var h := rng.randi_range(2, 6)
		for y in h:
			var t := float(y) / float(h)
			cells[Vector3i(cx, y, cz)] = Color("#c4300c").lerp(Color("#ff9a2a"), t * 1.4).lerp(Color("#ffe27a"), maxf(t - 0.6, 0.0))
	return cells


## A flat pentagram inside a ring, lying on the ground.
static func pentagram(radius_m: float, cube: float = 0.12) -> Dictionary:
	var cells := {}
	var r := radius_m * 0.92 / cube
	var steps := maxi(int(TAU * r / 0.8), 12)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		cells[Vector3i(roundi(cos(a) * r), 0, roundi(sin(a) * r))] = ARCANE
	var pts: Array[Vector2] = []
	for k in 5:
		var a := deg_to_rad(90.0 + 72.0 * float(k))
		pts.append(Vector2(cos(a), sin(a)) * r)
	for k in 5:
		var from := pts[k]
		var to := pts[(k + 2) % 5]
		var n := maxi(int(from.distance_to(to) / 0.7), 2)
		for i in n + 1:
			var p := from.lerp(to, float(i) / float(n))
			cells[Vector3i(roundi(p.x), 0, roundi(p.y))] = ARCANE_LIGHT
	return cells


## A ball of cubes of one colour with a pale core (holy, nature, shadow and the rest).
static func orb(color: Color, radius_cubes: float = 2.0, seed_value: int = 5) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	var r := int(ceil(radius_cubes))
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := Vector3(x, y, z).length()
				if d > radius_cubes or (d > radius_cubes * 0.7 and rng.randf() < 0.25):
					continue
				cells[Vector3i(x, y, z)] = color.lerp(Color.WHITE, 0.6) if d < radius_cubes * 0.4 else color
	return cells


## The projectile / charge body of a magic school.
static func body_for(element: String, color: Color) -> Dictionary:
	match element:
		"arcane":
			return arcane_prism()
		"fire":
			return fire_orb()
		"frost":
			return ice_crystal()
	return orb(color)
