class_name NpcDB
extends RefCounted
## Non-player characters (data/npcs/<id>.json): who they are and how they look. They
## stand where the map puts them ("npcs": [{id, at: [x, z], facing}]); they are not
## combat entities. A "class_trainer" (Brann) lets a villager choose a class.

const DIR := "res://data/npcs"
## How close a player must be to talk to an NPC (meters, on the ground).
const TALK_RANGE := 2.5

static var _default: NpcDB
var _by_id: Dictionary = {}


static func load_default() -> NpcDB:
	if _default == null:
		_default = NpcDB.new()
		for f: String in DirAccess.get_files_at(DIR):
			if f.ends_with(".json"):
				var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
				if d is Dictionary and (d as Dictionary).has("id"):
					_default._by_id[str(d.id)] = d
	return _default


func npc(id: String) -> Dictionary:
	return _by_id.get(id, {})


## The NPCs placed on a map: [{id, position: Vector3, facing: float (radians)}].
static func placed(map: CollisionMap) -> Array:
	var out := []
	for n: Dictionary in map.npcs:
		var at: Array = n.get("at", [0, 0])
		out.append({"id": str(n.get("id", "")), "position": Vector3(float(at[0]) + 0.5, 0.0, float(at[1]) + 0.5),
			"facing": deg_to_rad(float(n.get("facing", 0.0)))})
	return out


## The id of an NPC with this role within TALK_RANGE of `pos`, or "".
func near_with_role(map: CollisionMap, pos: Vector3, role: String) -> String:
	for n: Dictionary in placed(map):
		if str(npc(n.id).get("role", "")) != role:
			continue
		var d := Vector2(pos.x - n.position.x, pos.z - n.position.z).length()
		if d <= TALK_RANGE:
			return n.id
	return ""
