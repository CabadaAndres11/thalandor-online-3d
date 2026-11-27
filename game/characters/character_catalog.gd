class_name CharacterCatalog
extends RefCounted
## Character options from data/characters/: appearance options, classes and voxel
## pieces. Sanitizes untrusted appearances (saves, imports, the network) and resolves a
## class + appearance into the "look" HumanRig builds.

## The bodies before Plan 8.3e, read as the new ones.
const BODY_ALIASES := {"slim": "female", "robust": "male"}
const KINDS := ["race", "body", "skin", "eyes", "hair_style", "hair_color", "beard", "marks"]
## Races (Plan 7): only looks. Height, proportions, head and pieces of each one.
const RACES_PATH := "res://data/characters/races.json"
## Every character starts as a villager and picks a class in the game (with Brann).
const DEFAULT_CLASS := "villager"
const APPEARANCE_PATH := "res://data/characters/appearance.json"
const CLASSES_PATH := "res://data/characters/classes.json"
const PIECES_PATH := "res://data/characters/pieces.json"
## Equipment models (tools/art/make_gear.mjs); optional until they exist.
const GEAR_PIECES_PATH := "res://data/items/gear_pieces.json"
## v2 versions of the pieces (Plan 6.2), same ids; a piece without one is worn at voxel_scale 2.
const PIECES_V2 := "res://data/characters/pieces_v2.json"
## v2 equipment (Plan 6.3), same ids as GEAR_PIECES_PATH.
const GEAR_PIECES_V2 := "res://data/items/gear_pieces_v2.json"
const BODY := "v2"
## What a character wears on the chest with nothing equipped there.
const BASE_OUTFIT := "outfit_villager"
## Voxel hair is lit from all sides; a touch darker than the painted hair to match it.
const VOXEL_HAIR_DARKEN := 0.15

static var _default: CharacterCatalog

var _options: Dictionary = {} # kind -> Array of option dicts
var _classes: Array = []
var _pieces: Dictionary = {}
var _pieces_v2: Dictionary = {}
var _races: Dictionary = {} # id -> race dict


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


## The options of a kind that a race can wear (an option without "races" fits every race).
func options_for(kind: String, race: String) -> Array:
	if kind == "race":
		return options(kind)
	return options(kind).filter(func(o: Dictionary) -> bool: return not o.has("races") or (o.races as Array).has(race))


func race_def(id: String) -> Dictionary:
	return _races.get(id, {})


func classes() -> Array:
	return _classes


## The classes a villager can choose (not the villager itself).
func selectable_classes() -> Array:
	return _classes.filter(func(c: Dictionary) -> bool: return bool(c.get("selectable", true)))


func is_selectable(id: Variant) -> bool:
	return id is String and not class_def(id).is_empty() and bool(class_def(id).get("selectable", true))


func class_def(id: String) -> Dictionary:
	for c: Dictionary in _classes:
		if c.id == id:
			return c
	return {}


func piece(id: String) -> Dictionary:
	return _pieces.get(id, {})


func piece_v2(id: String) -> Dictionary:
	return _pieces_v2.get(id, {})


## Tag and hides of a piece: its v1 entry, or the v2 one for the pieces made only in v2 (Plan 7).
func meta(id: String) -> Dictionary:
	var p := piece(id)
	return p if not p.is_empty() else piece_v2(id)


func piece_ids() -> Array:
	return _pieces.keys()


func default_appearance() -> Dictionary:
	var app := {}
	var race := str(options("race")[0].id) if not options("race").is_empty() else ""
	for kind: String in KINDS:
		var list := options_for(kind, race)
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
	var r: Variant = (app as Dictionary).get("race")
	var race: String = r if r is String and not option("race", r).is_empty() else out.race
	for kind: String in KINDS:
		var valid := options_for(kind, race)
		var v: Variant = (app as Dictionary).get(kind) if kind != "race" else race
		if kind == "body" and v is String and BODY_ALIASES.has(v):
			v = BODY_ALIASES[v] # the old bodies (Plan 8.3e): slim is a woman, robust a man
		var ids: Array = valid.map(func(o: Dictionary) -> String: return o.id)
		if v is String and ids.has(v):
			out[kind] = v
		else:
			out[kind] = ids[0] if not ids.is_empty() else ""
	return out


func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var app := {}
	var races := options("race")
	var race := str(races[rng.randi_range(0, races.size() - 1)].id)
	for kind: String in KINDS:
		var list := options_for(kind, race)
		app[kind] = list[rng.randi_range(0, list.size() - 1)].id if not list.is_empty() else ""
	app.race = race
	return app


## The look HumanRig.build() expects (see there), from untrusted ids: colors and the
## voxel pieces (headgear, class outfit and gear, weapons, hair unless the headgear
## hides it, beard).
## `upgrade`: the class upgrade of the character; its "look" ({headgear?, weapons?, pieces?})
## changes the headgear and weapons or adds pieces (the Templar helm, the Hunter crossbow).
## `gear`: the base ids of a player's 8 visible slots (Inventory.VISIBLE). When given, the
## equipment decides the clothes, headgear, weapons and grip (the class outfit and the
## upgrade look are not used); an empty chest shows BASE_OUTFIT.
func resolve(class_id: Variant, appearance: Variant, upgrade: String = "", gear: Array = [], items: ItemDB = null) -> Dictionary:
	var c := class_def(sanitize_class(class_id))
	var app := sanitize_appearance(appearance)
	var hair := option("hair_style", app.hair_style)
	var hair_color := Color(str(option("hair_color", app.hair_color).color))
	var pieces: Array = []
	var hidden := {}
	var grip := str(c.get("grip", ""))
	var auras: Array = []
	if gear.is_empty():
		var look: Dictionary = UpgradeDB.load_default().upgrade(upgrade).get("look", {}) if upgrade != "" else {}
		var headgear := str(look.get("headgear", c.get("headgear", "")))
		if headgear != "":
			for tag: String in meta(headgear).get("hides", []):
				hidden[tag] = true
			pieces.append(piece_entry(headgear))
		for id: String in c.get("pieces", []) + look.get("pieces", []):
			pieces.append(piece_entry(id))
		for id: String in look.get("weapons", c.get("weapons", [])):
			pieces.append(piece_entry(id))
	else:
		var db := items if items != null else ItemDB.load_default()
		grip = ""
		for i in mini(gear.size(), Inventory.VISIBLE.size()):
			var base_id := str(gear[i])
			if base_id == "":
				continue
			var b := db.base(base_id)
			if b.has("aura"):
				auras.append(Color(str(b.aura)))
			var ids: Array = b.get("look_offhand", b.get("look", [])) if Inventory.VISIBLE[i] == "offhand" else b.get("look", [])
			for id: String in ids:
				if piece(id).is_empty():
					continue
				for tag: String in meta(id).get("hides", []):
					hidden[tag] = true
				pieces.append(piece_entry(id))
			if Inventory.VISIBLE[i] == "main":
				grip = str(db.family_of(base_id).get("grip", ""))
		var chest := str(gear[4]) if gear.size() > 4 else ""
		if chest != "" and not (db.base(chest).get("look", []) as Array).is_empty():
			hidden["bust"] = true # chest armour covers the body's own chest (Plan 8.3e)
		if chest == "" or (db.base(chest).get("look", []) as Array).is_empty():
			pieces.append(piece_entry(BASE_OUTFIT))
		for id: String in c.get("fixed_pieces", []):
			pieces.append(piece_entry(id))
	for id: String in hair.get("pieces", []):
		if not hidden.has(str(meta(id).get("tag", ""))):
			pieces.append(piece_entry(id))
	var beard := str(option("beard", app.beard).get("piece", ""))
	# A hood or helm that covers the scalp and ears closes over the jaw too: its voxels and the
	# beard's would share cells and flicker, so the beard is not drawn under it (Plan 8.3f).
	if beard != "" and not hidden.has("hair_cap"):
		pieces.append(piece_entry(beard))
	var race := race_def(app.race)
	if hidden.has("hair_cap"):
		hidden["ears"] = true # what covers the scalp covers the elf ears too
	for id: String in race.get("pieces", []) + option("marks", app.marks).get("pieces", []) + option("body", app.body).get("pieces", []):
		if (not piece(id).is_empty() or not piece_v2(id).is_empty()) and not hidden.has(str(meta(id).get("tag", ""))):
			pieces.append(piece_entry(id))
	var swaps: Dictionary = race.get("piece_swap", {}) # pieces drawn again for the race head (Plan 8.1.1)
	for i in pieces.size():
		var swap := str(swaps.get(pieces[i].id, ""))
		if swap != "" and not (piece(swap).is_empty() and piece_v2(swap).is_empty()):
			pieces[i] = piece_entry(swap)
	var fits: Dictionary = race.get("piece_fit", {})
	for e: Dictionary in pieces:
		if fits.has(e.id):
			e["fit"] = fits[e.id] # this piece fitted by hand to the race head
	# A race's own head first (ogre, lizard); otherwise the body's (Plan 8.3e: the woman's).
	var head_id := str(race.get("head", ""))
	if head_id == "":
		head_id = str(option("body", app.body).get("head", ""))
	var head: Dictionary = HumanRig.rig_heads(BODY).get(head_id, {})
	return {
		"skin_color": Color(str(option("skin", app.skin).color)),
		"eyes_color": Color(str(option("eyes", app.eyes).color)),
		"hair_color": hair_color,
		"voxel_hair_color": hair_color.darkened(VOXEL_HAIR_DARKEN),
		"primary": Color(str(c.get("primary", "#808080"))),
		"secondary": Color(str(c.get("secondary", "#808080"))),
		"trousers": Color(str(c.trousers)) if c.has("trousers") else Color(str(c.get("primary", "#808080"))).darkened(HumanRig.TROUSERS_DARKEN),
		"body_scale": option("body", app.body).get("scale", {}),
		"race": str(app.race),
		"race_height": float(race.get("height", 1.0)),
		"race_scale": race.get("scale", {}),
		"head_file": str(head.get("file", "")),
		"head_offset": head.get("offset", []),
		"head_fit": race.get("head_fit", {"scale": 1.0, "offset": [0, 0, 0]}),
		"grip": grip,
		"auras": auras,
		"pieces": pieces,
		"body": BODY,
	}


## The piece as the v2 body wears it: its v2 version, or the v1 one drawn twice as big.
func piece_entry(id: String) -> Dictionary:
	var v2 := piece_v2(id)
	if not v2.is_empty():
		return {"id": id, "file": v2.get("file", ""), "part": v2.get("part", ""), "offset": v2.get("offset", [0, 0, 0])}
	var p := piece(id)
	return {"id": id, "file": p.get("file", ""), "part": p.get("part", ""), "offset": p.get("offset", [0, 0, 0]),
		"voxel_scale": 2.0}


func _load(appearance_path: String, classes_path: String, pieces_path: String) -> void:
	var app: Variant = _read_json(appearance_path)
	if app is Dictionary:
		for kind: String in KINDS:
			_options[kind] = (app as Dictionary).get(kind, [])
	var races: Variant = _read_json(RACES_PATH)
	if races is Array:
		for r: Dictionary in races:
			_races[str(r.id)] = r
	var cls: Variant = _read_json(classes_path)
	if cls is Array:
		_classes = cls
	var pcs: Variant = _read_json(pieces_path)
	if pcs is Dictionary:
		_pieces = pcs
	if FileAccess.file_exists(GEAR_PIECES_PATH):
		var gear: Variant = _read_json(GEAR_PIECES_PATH)
		if gear is Dictionary:
			_pieces.merge(gear)
	if FileAccess.file_exists(PIECES_V2):
		var v2: Variant = _read_json(PIECES_V2)
		if v2 is Dictionary:
			_pieces_v2 = v2
	if FileAccess.file_exists(GEAR_PIECES_V2):
		var gear_v2: Variant = _read_json(GEAR_PIECES_V2)
		if gear_v2 is Dictionary:
			_pieces_v2.merge(gear_v2)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("CharacterCatalog: missing " + path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("CharacterCatalog: bad JSON in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
