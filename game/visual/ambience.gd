class_name Ambience
extends RefCounted
## A lighting ambience read from data/ambiences/<id>.json: sun, sky, ambient light, fog,
## post-processing and ambient particles. Missing sun/sky/ambient/fog/tonemap/color
## sections take defaults; missing glow/ssao/dof/particles sections mean "off".
## Quality levels only strip effects from here (AmbienceBuilder), never add them.

const DEFAULT_ID := "exterior_dia"
const DIR := "res://data/ambiences/"
const PARTICLE_TYPES := ["embers", "dust", "none"]
const TONEMAPS := ["aces", "filmic"]

var id: String = ""

var sun_color := Color("#fff1dc")
var sun_energy: float = 1.1
var sun_elevation: float = 55.0
var sun_azimuth: float = -30.0
var sun_shadows: bool = true

var sky_top := Color("#6f9fd6")
var sky_horizon := Color("#c9dcef")

var ambient_color := Color("#c9d6e6")
var ambient_energy: float = 0.6

var fog_color := Color("#c9dcef")
var fog_density: float = 0.0
var fog_height: float = 0.0
var fog_height_density: float = 0.0
var volumetric_density: float = 0.0
var volumetric_albedo := Color.WHITE

var tonemap: String = "aces"
var exposure: float = 1.0

var glow: bool = false
var glow_intensity: float = 0.8
var glow_threshold: float = 1.0
var glow_bloom: float = 0.0

var ssao: bool = false
var ssao_radius: float = 1.0
var ssao_intensity: float = 2.0

var brightness: float = 1.0
var contrast: float = 1.0
var saturation: float = 1.0

var ssr: bool = false

var dof: bool = false
var dof_distance: float = 30.0
var dof_amount: float = 0.1

var particles: String = "none"
var particle_amount: int = 0
var particle_color := Color.WHITE

## Multiplies the torches' light (low by day, full at night).
var torch_energy: float = 1.0


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".json"):
			out.append(file.get_basename())
	out.sort()
	return out


## The id itself if that ambience exists; otherwise DEFAULT_ID, with a warning when a
## (misspelt) id was given.
static func resolve_id(ambience_id: String) -> String:
	if ambience_id in ids():
		return ambience_id
	if ambience_id != "":
		push_warning("Unknown ambience '%s', using '%s'" % [ambience_id, DEFAULT_ID])
	return DEFAULT_ID


static func load_id(ambience_id: String) -> Ambience:
	var path := DIR + ambience_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("Unknown ambience '%s', using '%s'" % [ambience_id, DEFAULT_ID])
		ambience_id = DEFAULT_ID
		path = DIR + DEFAULT_ID + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(ambience_id, parsed if parsed is Dictionary else {})


static func from_dict(ambience_id: String, d: Dictionary) -> Ambience:
	var a := Ambience.new()
	a.id = ambience_id
	var sun := _section(d, "sun")
	a.sun_color = _color(sun, "color", a.sun_color)
	a.sun_energy = _num(sun, "energy", a.sun_energy)
	a.sun_elevation = _num(sun, "elevation", a.sun_elevation)
	a.sun_azimuth = _num(sun, "azimuth", a.sun_azimuth)
	a.sun_shadows = _bool(sun, "shadows", a.sun_shadows)
	var sky := _section(d, "sky")
	if sky.has("color"):
		a.sky_top = _color(sky, "color", a.sky_top)
		a.sky_horizon = a.sky_top
	a.sky_top = _color(sky, "top", a.sky_top)
	a.sky_horizon = _color(sky, "horizon", a.sky_horizon)
	var amb := _section(d, "ambient")
	a.ambient_color = _color(amb, "color", a.ambient_color)
	a.ambient_energy = _num(amb, "energy", a.ambient_energy)
	var fog := _section(d, "fog")
	a.fog_color = _color(fog, "color", a.fog_color)
	a.fog_density = _num(fog, "density", a.fog_density)
	a.fog_height = _num(fog, "height", a.fog_height)
	a.fog_height_density = _num(fog, "height_density", a.fog_height_density)
	a.volumetric_density = _num(fog, "volumetric_density", a.volumetric_density)
	a.volumetric_albedo = _color(fog, "volumetric_albedo", a.volumetric_albedo)
	var tm := _section(d, "tonemap")
	var mode := str(tm.get("mode", a.tonemap))
	a.tonemap = mode if mode in TONEMAPS else "aces"
	a.exposure = _num(tm, "exposure", a.exposure)
	if d.get("glow") is Dictionary:
		a.glow = true
		a.glow_intensity = _num(d.glow, "intensity", a.glow_intensity)
		a.glow_threshold = _num(d.glow, "threshold", a.glow_threshold)
		a.glow_bloom = _num(d.glow, "bloom", a.glow_bloom)
	if d.get("ssao") is Dictionary:
		a.ssao = true
		a.ssao_radius = _num(d.ssao, "radius", a.ssao_radius)
		a.ssao_intensity = _num(d.ssao, "intensity", a.ssao_intensity)
	var col := _section(d, "color")
	a.brightness = _num(col, "brightness", a.brightness)
	a.contrast = _num(col, "contrast", a.contrast)
	a.saturation = _num(col, "saturation", a.saturation)
	a.ssr = _bool(d, "ssr", false)
	if d.get("dof") is Dictionary:
		a.dof = true
		a.dof_distance = _num(d.dof, "distance", a.dof_distance)
		a.dof_amount = _num(d.dof, "amount", a.dof_amount)
	if d.get("particles") is Dictionary:
		var kind := str(d.particles.get("type", "none"))
		if kind in PARTICLE_TYPES and kind != "none":
			a.particles = kind
			a.particle_amount = maxi(0, int(_num(d.particles, "amount", 0)))
			a.particle_color = _color(d.particles, "color", a.particle_color)
	a.torch_energy = maxf(0.0, _num(_section(d, "torches"), "energy", a.torch_energy))
	return a


static func _section(d: Dictionary, key: String) -> Dictionary:
	return d[key] if d.get(key) is Dictionary else {}


static func _num(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key)
	return float(v) if (v is float or v is int) else fallback


static func _bool(d: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = d.get(key)
	return v if v is bool else fallback


static func _color(d: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = d.get(key)
	return Color.html(v) if (v is String and Color.html_is_valid(v)) else fallback
