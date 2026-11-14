class_name CharacterData
extends RefCounted
## One of the player's characters, as saved in user://saves/characters/<id>.json.
## Files are versioned; from_dict() migrates old versions and sanitizes everything
## (a file may be old, hand-edited or imported from elsewhere).

const VERSION := 1

var id: String = ""
var name: String = ""
var class_id: String = CharacterCatalog.DEFAULT_CLASS
var appearance: Dictionary = {}
var level: int = 1
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "id": id, "name": name, "class_id": class_id,
		"appearance": appearance.duplicate(), "level": level, "created_at": created_at,
	}


## null when `d` is not a character of this or an older version (unknown class or
## appearance options are replaced by defaults instead).
static func from_dict(d: Variant, catalog: CharacterCatalog) -> CharacterData:
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
	var lv: Variant = m.get("level", 1)
	c.level = maxi(1, int(lv)) if (lv is int or lv is float) else 1
	var t: Variant = m.get("created_at", 0)
	c.created_at = int(t) if (t is int or t is float) else 0
	return c


## Brings an older dictionary to the current layout (step by step per version).
static func migrate(d: Dictionary) -> Dictionary:
	var m := d.duplicate(true)
	var version := int(m.get("version", 0))
	if version < 1:
		# Version 0 (never shipped, kept as the example of a migration): "class".
		if m.has("class") and not m.has("class_id"):
			m["class_id"] = m["class"]
		m.erase("class")
	m["version"] = VERSION
	return m
