class_name CharacterCatalog
extends RefCounted
## Character options from data/characters/: appearance options, classes and voxel
## pieces. Sanitizes untrusted appearances (saves, imports, the network) and resolves a
## class + appearance into the "look" CharacterRig builds.

const KINDS := ["body", "skin", "eyes", "hair_style", "hair_color", "beard"]
const DEFAULT_CLASS := "warrior"
const APPEARANCE_PATH := "res://data/characters/appearance.json"
const CLASSES_PATH := "res://data/characters/classes.json"
const PIECES_PATH := "res://data/characters/pieces.json"
## Voxel hair is lit from all sides; a touch darker than the painted hair to match it.
const VOXEL_HAIR_DARKEN := 0.15

static var _default: CharacterCatalog

var _options: Dictionary = {} # kind -> Array of option dicts
var _classes: Array = []
var _pieces: Dictionary = {}


static func load_default() -> CharacterCatalog:
	if _default == null:
		_default = CharacterCatalog.new()
		_default._load(APPEARANCE_PATH, CLASSES_PATH, PIECES_PATH)
	return _default


func options(kind: String) -> Array:
	return _options.get(kind, [])


func option(kind: String, id: String) -> Dictionary:
	for o: Dictionary in options(kind):
		if o.id == id:
			return o
	return {}


func classes() -> Array:
	return _classes


func class_def(id: String) -> Dictionary:
	for c: Dictionary in _classes:
		if c.id == id:
			return c
	return {}


func piece(id: String) -> Dictionary:
	return _pieces.get(id, {})


func piece_ids() -> Array:
	return _pieces.keys()


func default_appearance() -> Dictionary:
	var app := {}
	for kind: String in KINDS:
		var list := options(kind)
		app[kind] = list[0].id if not list.is_empty() else ""
	return app


func sanitize_class(id: Variant) -> String:
	if id is String and not class_def(id).is_empty():
		return id
	return DEFAULT_CLASS


## Exactly the KINDS keys, each a known option id (unknown or missing -> the default).
func sanitize_appearance(app: Variant) -> Dictionary:
	var out := default_appearance()
	if not app is Dictionary:
		return out
	for kind: String in KINDS:
		var v: Variant = (app as Dictionary).get(kind)
		if v is String and not option(kind, v).is_empty():
			out[kind] = v
	return out


func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var app := {}
	for kind: String in KINDS:
		var list := options(kind)
		app[kind] = list[rng.randi_range(0, list.size() - 1)].id
	return app


## The look CharacterRig.build() expects (see there), from untrusted ids.
func resolve(class_id: Variant, appearance: Variant) -> Dictionary:
	var c := class_def(sanitize_class(class_id))
	var app := sanitize_appearance(appearance)
	var hair := option("hair_style", app.hair_style)
	var hair_color := Color(str(option("hair_color", app.hair_color).color))
	var pieces: Array = []
	var hidden := {}
	if str(c.get("headgear", "")) != "":
		var hg := piece(c.headgear)
		for tag: String in hg.get("hides", []):
			hidden[tag] = true
		pieces.append(_piece_entry(c.headgear))
	var hair_piece := str(hair.get("piece", ""))
	if hair_piece != "" and not hidden.has(str(piece(hair_piece).get("tag", ""))):
		pieces.append(_piece_entry(hair_piece))
	return {
		"skin_color": Color(str(option("skin", app.skin).color)),
		"eyes_color": Color(str(option("eyes", app.eyes).color)),
		"hair_color": hair_color,
		"voxel_hair_color": hair_color.darkened(VOXEL_HAIR_DARKEN),
		"hair_layer": str(hair.get("layer", "")),
		"beard_layer": str(option("beard", app.beard).get("layer", "")),
		"outfit_layer": str(c.get("outfit", "")),
		"primary": Color(str(c.get("primary", "#808080"))),
		"secondary": Color(str(c.get("secondary", "#808080"))),
		"body_scale": option("body", app.body).get("scale", {}),
		"pieces": pieces,
	}


func _piece_entry(id: String) -> Dictionary:
	var p := piece(id)
	return {"id": id, "file": p.get("file", ""), "part": p.get("part", ""), "offset": p.get("offset", [0, 0, 0])}


func _load(appearance_path: String, classes_path: String, pieces_path: String) -> void:
	var app: Variant = _read_json(appearance_path)
	if app is Dictionary:
		for kind: String in KINDS:
			_options[kind] = (app as Dictionary).get(kind, [])
	var cls: Variant = _read_json(classes_path)
	if cls is Array:
		_classes = cls
	var pcs: Variant = _read_json(pieces_path)
	if pcs is Dictionary:
		_pieces = pcs


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("CharacterCatalog: missing " + path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("CharacterCatalog: bad JSON in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
