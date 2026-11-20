class_name VoxelFx
extends RefCounted
## Voxel models for spell effects, built in code: an arcane prism, a fire orb, ice crystals
## and spikes, burning ground, a pentagram and the cleric's crosses, wings and angel. A model is a Dictionary of cells
## (Vector3i -> Color) in cube units, merged into one mesh with vertex colours. Models face
## +Z (forward) with +Y up.

const CUBE := 0.1
const CORNERS := [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
]
## Faces: neighbour direction, the 4 corners and a brightness factor.
const FACES := [
	[Vector3i(0, 0, -1), [0, 1, 2, 3], 0.9], [Vector3i(0, 0, 1), [4, 5, 6, 7], 0.9],
	[Vector3i(0, -1, 0), [0, 1, 5, 4], 0.7], [Vector3i(0, 1, 0), [3, 2, 6, 7], 1.0],
	[Vector3i(-1, 0, 0), [0, 3, 7, 4], 0.8], [Vector3i(1, 0, 0), [1, 2, 6, 5], 0.8],
]

const ARCANE := Color("#8f3dff")
const ARCANE_LIGHT := Color("#e2c4ff")
const FLAME_RED := Color("#c4100c")
const FLAME_ORANGE := Color("#e8730a")
const FLAME_YELLOW := Color("#e9c500")
const FLAME_CORE := Color("#e6dc5a")
const ICE := Color("#7fd8ff")
const ICE_LIGHT := Color("#f2fcff")


# --- Meshes -------------------------------------------------------------------------

## One mesh with a cube of side `cube` per cell, coloured per cell. Only the faces that are
## not hidden by a neighbour are made, each a little darker or lighter by direction so the
## cubes read as solid.
static func mesh_of(cells: Dictionary, cube: float = CUBE) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var h := cube * 0.5
	for c: Vector3i in cells:
		var center := Vector3(c) * cube
		var col: Color = cells[c]
		for f: Array in FACES:
			if cells.has(c + (f[0] as Vector3i)):
				continue
			var shade := float(f[2])
			var fc := Color(col.r * shade, col.g * shade, col.b * shade, col.a)
			for i: int in [0, 1, 2, 0, 2, 3]:
				verts.append(center + (CORNERS[(f[1] as Array)[i]] as Vector3) * h)
				cols.append(fc)
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


## The flame of the reference art: a tall teardrop that leans at the tip, red outside, then
## orange, yellow, and a pale core low in the middle, with two small tongues beside it.
## `h` cells tall, 2 deep. Faces +Z.
static func flame_sprite(h: int = 14, seed_value: int = 1, tongues: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	var width := float(h) * 0.34
	var lean := rng.randf_range(-1.0, 1.0)
	for y in h:
		var t := float(y) / float(h)
		var half := width * (1.0 - pow(t, 1.6))
		var cx := int(round(lean * t * t * float(h) * 0.22))
		for x in range(-ceili(half), ceili(half) + 1):
			var edge := half - absf(float(x))
			if edge < 0.0:
				continue
			var col := FLAME_YELLOW
			if edge < 1.2:
				col = FLAME_RED
			elif edge < 2.6:
				col = FLAME_ORANGE
			elif t < 0.45 and absf(float(x)) < half * 0.32:
				col = FLAME_CORE
			for z in 2:
				cells[Vector3i(x + cx, y, z)] = col
	if tongues:
		for side in [-1, 1]:
			var th := maxi(h / 3, 3)
			var ox: int = side * (ceili(width) + 2)
			var oy := int(float(h) * rng.randf_range(0.4, 0.55))
			for y in th:
				var half := 1.0 - float(y) / float(th) * 0.6
				for x in range(-int(half), int(half) + 1):
					for z in 2:
						cells[Vector3i(ox + x, oy + y, z)] = FLAME_RED if y > 0 else FLAME_ORANGE
	return cells


## Several flames merged into one model: each position is in cells (x, z) and is drawn as two
## crossed sprites so it reads from any side. Heights vary.
static func flame_field(spots: Array, base_h: int, seed_value: int = 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	for spot: Vector2i in spots:
		var h := maxi(base_h + rng.randi_range(-2, 3), 4)
		var sprite := flame_sprite(h, rng.randi(), rng.randf() < 0.4)
		for c: Vector3i in sprite:
			cells[Vector3i(spot.x + c.x, c.y, spot.y + c.z)] = sprite[c]
			cells[Vector3i(spot.x + c.z, c.y, spot.y + c.x)] = sprite[c] # the crossed plane
	return cells


## A comet of fire: a ball with a tail of flames trailing along -Z.
static func fire_comet() -> Dictionary:
	var cells := fire_orb()
	for z in range(-3, -11, -1):
		var r := 2.0 * (1.0 - float(-z - 3) / 9.0)
		for x in range(-2, 3):
			for y in range(-2, 3):
				var d := Vector2(x, y).length()
				if d <= r:
					cells[Vector3i(x, y, z)] = FLAME_YELLOW if d < r * 0.4 else (FLAME_ORANGE if d < r * 0.75 else FLAME_RED)
	return cells


## A rock on fire for a meteor: dark core with glowing cracks and a long tail.
static func meteor(seed_value: int = 9) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	for x in range(-4, 5):
		for y in range(-4, 5):
			for z in range(-4, 5):
				var d := Vector3(x, y, z).length() + rng.randf_range(-0.5, 0.5)
				if d > 4.0:
					continue
				cells[Vector3i(x, y, z)] = FLAME_ORANGE if rng.randf() < 0.18 else Color("#3a1d14").lerp(Color("#6a2a14"), rng.randf())
	for z in range(-5, -22, -1):
		var r := 3.5 * (1.0 - float(-z - 4) / 18.0)
		for x in range(-4, 5):
			for y in range(-4, 5):
				var d := Vector2(x, y).length()
				if d <= r and rng.randf() < 0.85:
					cells[Vector3i(x, y, z)] = FLAME_YELLOW if d < r * 0.35 else (FLAME_ORANGE if d < r * 0.7 else FLAME_RED)
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
				cells[Vector3i(x, y, z)] = FLAME_CORE if d < 1.0 else (FLAME_YELLOW if d < 1.5 else (FLAME_ORANGE if d < 1.9 else FLAME_RED))
	return cells


## A faceted ice crystal (an octahedron), pale in the middle.
static func ice_crystal() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cells := {}
	for x in range(-3, 4):
		for y in range(-3, 4):
			for z in range(-3, 4):
				var d := absi(x) + absi(y) + absi(z)
				if d <= 3:
					cells[Vector3i(x, y, z)] = ICE_LIGHT if d <= 1 else ice_color(rng, d == 3)
	return cells


## An ice spike `height` cubes tall: a 3x3 base that tapers to one cube, whiter at the tip.
static func ice_spike(height: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + height
	var cells := {}
	height = maxi(height, 2)
	for y in height:
		var half := int(floor(float(height - y) * 1.6 / float(height)))
		for x in range(-half, half + 1):
			for z in range(-half, half + 1):
				cells[Vector3i(x, y, z)] = ice_color(rng, y >= height - 2).lerp(ICE_LIGHT, float(y) / float(height) * 0.7)
	return cells


## Burning ground in a circle: flames (the reference sprite) scattered inside it. Cubes are
## bigger here (seen from far away); positions are in cells.
static func flame_patch(radius_m: float, cube: float = 0.18, seed_value: int = 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots: Array = []
	for i in clampi(int(radius_m * radius_m * 0.9), 4, 22):
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius_m * 0.85
		spots.append(Vector2i(roundi(cos(angle) * dist / cube), roundi(sin(angle) * dist / cube)))
	return flame_field(spots, 6, seed_value)


## A wall of flames along the X axis (length and width in metres, centred).
static func flame_wall(length_m: float, cube: float = 0.18, seed_value: int = 4) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots: Array = []
	var n := maxi(int(length_m / 0.9), 3)
	for i in n:
		var x := (float(i) / float(n - 1) - 0.5) * length_m
		spots.append(Vector2i(roundi(x / cube), roundi(rng.randf_range(-0.25, 0.25) / cube)))
	return flame_field(spots, 8, seed_value)


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


## A block of ice that fits a standing character: a faceted slab with cut corners, with
## clear and deeper blue cubes mixed in so it is not one flat colour.
static func ice_block(half_x: int = 3, half_y: int = 4, seed_value: int = 11) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	for x in range(-half_x, half_x + 1):
		for y in range(-half_y, half_y + 1):
			for z in range(-half_x, half_x + 1):
				var edges := int(absi(x) == half_x) + int(absi(y) == half_y) + int(absi(z) == half_x)
				if edges >= 3:
					continue # cut corners
				if edges == 0 and rng.randf() < 0.55:
					continue # hollow: you see the character inside
				cells[Vector3i(x, y, z)] = ice_color(rng, edges >= 2)
	return cells


## An ice colour with variation: deep blue, cyan, pale and white, brighter on edges.
static func ice_color(rng: RandomNumberGenerator, edge: bool = false) -> Color:
	var base := Color("#3f9be0").lerp(ICE, rng.randf())
	base = base.lerp(ICE_LIGHT, 0.55 if edge else rng.randf() * 0.35)
	return base


## A whirlwind of ice: a funnel narrow at the ground and wide at the top, built of sparse cubes
## along spiral arms so it reads as turning when it spins. Sizes in cells of `cube` meters.
static func ice_tornado(radius_m: float, height_m: float, cube: float = 0.18, seed_value: int = 11) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := {}
	var levels := maxi(int(height_m / cube), 4)
	for y in levels:
		var k := float(y) / float(levels - 1)
		var ring_m := lerpf(0.25, radius_m, pow(k, 0.8)) # the funnel opens upward
		var ring := ring_m / cube
		var arms := 3
		for arm in arms:
			var a := TAU * float(arm) / float(arms) + float(y) * 0.3 # the arms wind around
			var span := maxi(int(ring * 0.9), 1)
			for s in span:
				var aa := a + float(s) / float(span) * (TAU / float(arms)) * 0.55
				if rng.randf() < 0.3:
					continue
				var jitter := rng.randf_range(-0.6, 0.6)
				var c := Vector3i(roundi(cos(aa) * (ring + jitter)), y, roundi(sin(aa) * (ring + jitter)))
				cells[c] = ice_color(rng, k > 0.7).lerp(Color.WHITE, 0.25 + 0.4 * k)
	return cells


## An arrow along +Z: a wooden shaft, a steel head and red and white fletching.
static func arrow() -> Dictionary:
	var cells := {}
	for z in range(-5, 5):
		cells[Vector3i(0, 0, z)] = Color("#8a5a2b")
	for z in range(5, 8):
		var r := 1 if z == 5 else 0
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if absi(x) + absi(y) <= r:
					cells[Vector3i(x, y, z)] = Color("#d4d9df") if z < 7 else Color("#f4f7fa")
	for z in range(-5, -2):
		var col := Color("#d94a3a") if z != -4 else Color.WHITE
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			cells[Vector3i(off.x, off.y, z)] = col
	return cells


## A throwing knife along +Z: a flat steel blade, a golden guard and a dark handle.
static func knife() -> Dictionary:
	var cells := {}
	for z in range(1, 8):
		var h := 1 if z < 6 else 0
		for y in range(-h, h + 1):
			cells[Vector3i(0, y, z)] = Color("#eef2f6") if y == 0 else Color("#b9c1ca")
	for x in range(-2, 3):
		cells[Vector3i(x, 0, 0)] = Color("#c9a13a")
	for z in range(-4, 0):
		cells[Vector3i(0, 0, z)] = Color("#4a3020")
	cells[Vector3i(0, 0, -5)] = Color("#c9a13a")
	return cells


## A net: a dome of rope strands with knots where they cross, to fall over a target.
static func net(radius_cells: int = 7) -> Dictionary:
	var cells := {}
	var r := float(radius_cells)
	for x in range(-radius_cells, radius_cells + 1):
		for y in range(0, radius_cells + 1):
			for z in range(-radius_cells, radius_cells + 1):
				var d := Vector3(x, y, z).length()
				if absf(d - r) > 0.7:
					continue
				var strand_a := posmod(x + z, 3) == 0
				var strand_b := posmod(x - z, 3) == 0
				if strand_a or strand_b:
					cells[Vector3i(x, y, z)] = Color("#e0c48a") if (strand_a and strand_b) else Color("#b08d52")
	return cells


## A bear trap lying on the ground: a dark plate with a ring of steel teeth.
static func trap(radius_cells: int = 5) -> Dictionary:
	var cells := {}
	var r := float(radius_cells)
	var rim := Color("#8a9099")
	var steel := Color("#c8ced6")
	# Two half-ring jaws lying open on each side of the hinge line (the z axis), each with a row
	# of teeth on its inner edge, over a dark base bar.
	for x in range(-radius_cells, radius_cells + 1):
		for z in range(-radius_cells, radius_cells + 1):
			var d := Vector2(x, z).length()
			if d > r - 0.3 or d < r - 2.1:
				continue
			if x == 0:
				continue # the gap at the hinge
			cells[Vector3i(x, 1, z)] = rim
			if d > r - 1.3 and d <= r - 0.3 and posmod(x + z, 2) == 0:
				continue
			if d <= r - 1.1 and posmod(x + z, 2) == 0:
				cells[Vector3i(x, 2, z)] = steel # teeth, pointing up
				cells[Vector3i(x, 3, z)] = Color("#f0f3f6")
	for x in range(-radius_cells + 1, radius_cells):
		for z in range(-1, 2):
			cells[Vector3i(x, 0, z)] = Color("#3a3f47") # base bar under both jaws
	# The pressure plate in the middle, brass-coloured, with its trigger.
	for x in range(-1, 2):
		for z in range(-1, 2):
			cells[Vector3i(x, 1, z)] = Color("#d6b25a")
	cells[Vector3i(0, 2, 0)] = Color("#8c6a1c")
	# A chain running out of the base, ending in a ring.
	for i in range(1, 5):
		cells[Vector3i(0, 0, -radius_cells - i)] = steel if i % 2 == 1 else Color("#6c727c")
	cells[Vector3i(0, 0, -radius_cells - 5)] = rim
	cells[Vector3i(1, 0, -radius_cells - 5)] = rim
	cells[Vector3i(-1, 0, -radius_cells - 5)] = rim
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
			return fire_comet()
		"frost":
			return ice_crystal()
		"holy":
			return holy_cross(7)
	return orb(color)


# --- Holy (the cleric): gold and white crosses, wings, halos and an angel -------------

const HOLY_GOLD := Color("#e3a623")
const HOLY_LIGHT := Color("#fff4c2")
const HOLY_WHITE := Color("#fbfbf4")


## An upright cross in the XY plane (`h` cubes tall), two cubes deep, a pale core and gold rim.
static func holy_cross(h: int = 9) -> Dictionary:
	var cells := {}
	var arm_y := int(h * 0.62)
	var half := int(h * 0.3)
	for y in h:
		for x in [-1, 0, 1]:
			for z in [0, 1]:
				cells[Vector3i(x, y, z)] = HOLY_LIGHT if x == 0 and z == 0 else HOLY_GOLD
	for x in range(-half - 1, half + 2):
		for y in [arm_y - 1, arm_y, arm_y + 1]:
			for z in [0, 1]:
				cells[Vector3i(x, y, z)] = HOLY_LIGHT if y == arm_y and z == 0 and absi(x) <= half else HOLY_GOLD
	# Centred on its crossing, so it turns about its heart.
	var out := {}
	for c: Vector3i in cells:
		out[c - Vector3i(0, arm_y, 0)] = cells[c]
	return out


## Two spread wings of layered feathers, white with gold tips, behind the body (in XY).
static func angel_wings() -> Dictionary:
	var cells := {}
	for side: int in [-1, 1]:
		for row in 6: # each row a feather, longer toward the top
			var length := 4 + row * 2
			var y0 := 2 + row * 2
			for k in length:
				var x := side * (2 + k)
				var y := y0 - int(k * 0.35) - (row % 2)
				var col := HOLY_GOLD if k >= length - 2 else HOLY_WHITE
				cells[Vector3i(x, y, 0)] = col
				cells[Vector3i(x, y - 1, 0)] = HOLY_WHITE.darkened(0.05)
				if row >= 3:
					cells[Vector3i(x, y + 1, -1)] = HOLY_WHITE
	return cells


## A flat ring of light (radius in cubes) lying in XZ.
static func halo(r: int = 6) -> Dictionary:
	var cells := {}
	var steps := maxi(int(TAU * r), 12)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		cells[Vector3i(roundi(cos(a) * r), 0, roundi(sin(a) * r))] = HOLY_GOLD
		cells[Vector3i(roundi(cos(a) * (r - 1)), 0, roundi(sin(a) * (r - 1)))] = HOLY_LIGHT
	return cells


## A small angel: a flowing robe, head, halo and spread wings, arms open.
static func angel() -> Dictionary:
	var cells := {}
	for y in 16: # the robe widens toward the hem
		var w := 1 + int((15 - y) * 0.28)
		for x in range(-w, w + 1):
			for z in range(-1, 2):
				cells[Vector3i(x, y, z)] = HOLY_WHITE if (x + y) % 5 != 0 else HOLY_LIGHT
	for x in range(-2, 3): # head
		for y in range(16, 20):
			for z in range(-1, 2):
				cells[Vector3i(x, y, z)] = HOLY_LIGHT
	for c: Vector3i in halo(3):
		cells[c + Vector3i(0, 21, 0)] = HOLY_GOLD
	for c: Vector3i in angel_wings():
		cells[c + Vector3i(0, 8, -2)] = angel_wings()[c]
	for side: int in [-1, 1]: # open arms
		for k in 5:
			cells[Vector3i(side * (2 + k), 13 - int(k * 0.4), 1)] = HOLY_WHITE
	return cells


## A circle on the ground with a cross inside (consecrated ground, healing circles).
static func holy_circle(radius_m: float, cube: float = 0.12) -> Dictionary:
	var cells := {}
	var r := radius_m * 0.92 / cube
	var steps := maxi(int(TAU * r / 0.8), 12)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		cells[Vector3i(roundi(cos(a) * r), 0, roundi(sin(a) * r))] = HOLY_GOLD
		cells[Vector3i(roundi(cos(a) * (r - 1.5)), 0, roundi(sin(a) * (r - 1.5)))] = HOLY_LIGHT
	var arm := int(r * 0.7)
	for k in range(-arm, arm + 1):
		for w in [-1, 0, 1]:
			cells[Vector3i(k, 0, w - int(r * 0.15))] = HOLY_LIGHT if w == 0 else HOLY_GOLD
			cells[Vector3i(w, 0, k)] = HOLY_LIGHT if w == 0 else HOLY_GOLD
	return cells


## A column of light cubes, thinning and fading toward the top.
static func light_column(height: int = 30, r: float = 2.5) -> Dictionary:
	var cells := {}
	var ri := int(ceil(r))
	for y in height:
		var rr := r * (1.0 - float(y) / float(height) * 0.5)
		for x in range(-ri, ri + 1):
			for z in range(-ri, ri + 1):
				var d := Vector2(x, z).length()
				if d <= rr and (d >= rr - 1.0 or (x + y + z) % 4 == 0):
					cells[Vector3i(x, y, z)] = HOLY_LIGHT if d < rr - 0.8 else HOLY_GOLD
	return cells


## Golden flames licking up round the edge of a circle (consecrated ground).
static func holy_flame_ring(radius_m: float, cube: float = 0.12) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var cells := {}
	var r := radius_m * 0.95 / cube
	var steps := maxi(int(TAU * r / 2.0), 10)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var cx := roundi(cos(a) * r)
		var cz := roundi(sin(a) * r)
		var h := 3 + rng.randi() % 4
		for y in h:
			var col := HOLY_LIGHT if y >= h - 1 else (HOLY_GOLD if y > 0 else HOLY_GOLD.darkened(0.25))
			cells[Vector3i(cx, y, cz)] = col
			if y < h - 2:
				cells[Vector3i(cx + 1, y, cz)] = HOLY_GOLD
	return cells
