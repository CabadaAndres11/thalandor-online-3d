class_name CharacterData
extends RefCounted
## One of the player's characters, as saved in user://saves/characters/<id>.json.
## Files are versioned; from_dict() migrates old versions and sanitizes everything
## (a file may be old, hand-edited or imported from elsewhere).

const VERSION := 5

var id: String = ""
var name: String = ""
var class_id: String = CharacterCatalog.DEFAULT_CLASS
var appearance: Dictionary = {}
## Level, experience, attributes, talents and upgrade (see PlayerProgress).
var progress := PlayerProgress.new()
var created_at: int = 0
## Gold, bag and worn equipment (see Inventory). A new character is a villager with a wood sword.
var inventory: Inventory = Inventory.starter(CharacterCatalog.DEFAULT_CLASS, ItemDB.load_default())
## Abilities in slots 1-4 (sanitized to the class's actives).
var bar: Array = []
## Where the character stands (Plan 8.1): {zone, at: [x, z]} (at [] = the zone's entry).
var place: Dictionary = {"zone": START_ZONE, "at": []}
## The village tutorial (the assault) is done: playing in a group is allowed.
var tutorial_done: bool = false

const START_ZONE := "aldea"


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "id": id, "name": name, "class_id": class_id,
		"appearance": appearance.duplicate(), "progress": progress.to_dict(), "created_at": created_at,
		"bar": bar.duplicate(), "inventory": inventory.to_dict(),
		"place": place.duplicate(true), "tutorial_done": tutorial_done,
	}


## null when `d` is not a character of this or an older version (unknown class,
## appearance options and bar abilities are replaced by defaults instead).
static func from_dict(d: Variant, catalog: CharacterCatalog, abilities: AbilityDB = null) -> CharacterData:
	if not d is Dictionary:
		return null
	var version: Variant = (d as Dictionary).get("version", 0)
	if not (version is int or version is float) or int(version) > VERSION:
		return null
	var m := migrate(d as Dictionary)
	var raw_id: Variant = m.get("id")
	var raw_name: Variant = m.get("name")
	if not raw_id is String or (raw_id as String).is_empty() or (raw_id as String).length() > 64:
		return null
	if not raw_name is String or not HostSession.is_valid_name(raw_name):
		return null
	var c := CharacterData.new()
	c.id = raw_id
	c.name = (raw_name as String).strip_edges()
	c.class_id = catalog.sanitize_class(m.get("class_id"))
	c.appearance = catalog.sanitize_appearance(m.get("appearance"))
	c.progress = PlayerProgress.from_dict(m.get("progress"))
	var t: Variant = m.get("created_at", 0)
	c.created_at = int(t) if (t is int or t is float) else 0
	c.inventory = Inventory.from_dict(m.get("inventory"), c.class_id, c.progress.level, ItemDB.load_default())
	c.bar = (abilities if abilities != null else AbilityDB.load_default()).sanitize_bar(c.class_id, m.get("bar"), c.progress.level, c.progress.upgrade)
	c.place = sanitize_place(m.get("place"))
	c.tutorial_done = bool(m.get("tutorial_done", false)) if m.get("tutorial_done") is bool else false
	return c


## {zone: a short id, at: [x, z] or []} from anything (a save may be hand-edited).
static func sanitize_place(v: Variant) -> Dictionary:
	var out := {"zone": START_ZONE, "at": []}
	if not v is Dictionary:
		return out
	var z: Variant = (v as Dictionary).get("zone")
	if z is String and (z as String).length() > 0 and (z as String).length() <= 64 and (z as String).is_valid_filename():
		out.zone = z
	var at: Variant = (v as Dictionary).get("at")
	if at is Array and (at as Array).size() == 2 and (at as Array).all(func(n: Variant) -> bool: return n is int or n is float):
		out.at = [int(at[0]), int(at[1])]
	return out


## Brings an older dictionary to the current layout (step by step per version).
static func migrate(d: Dictionary) -> Dictionary:
	var m := d.duplicate(true)
	var version := int(m.get("version", 0))
	if version < 1:
		# Version 0 (never shipped, kept as the example of a migration): "class".
		if m.has("class") and not m.has("class_id"):
			m["class_id"] = m["class"]
		m.erase("class")
	if version < 2:
		# Version 1 had no ability bar: an empty one becomes the class default.
		if not m.has("bar"):
			m["bar"] = []
	if version < 3:
		# Version 2 had a plain level that was always 1: everyone starts their progress at level 1.
		m["progress"] = {"level": 1}
		m.erase("level")
	if version < 4:
		# Version 3 had no items: everyone gets the starter kit of their class.
		var cls := CharacterCatalog.load_default().sanitize_class(m.get("class_id"))
		m["inventory"] = Inventory.starter(cls, ItemDB.load_default()).to_dict()
	if version < 5:
		# Version 4 had no world: everyone is in the village, and has played the arena.
		m["place"] = {"zone": START_ZONE, "at": []}
		m["tutorial_done"] = true
	m["version"] = VERSION
	return m
