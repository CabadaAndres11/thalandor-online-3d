class_name NpcInteraction
extends RefCounted
## What pressing E does near NPCs. Holding E next to a downed ally revives it (the
## simulation handles that), so a downed ally in reach wins over talking. Next to the
## merchant E trades; next to anyone else it talks (the class comes from the story, Plan 8.3a).

const NONE := ""
const TALK := "talk"
const TRADE := "trade"


## allies: [{position: Vector3, life: int}] (other players); own_alive: false while this
## player is downed or dead (then E does nothing here). Returns {action, npc}.
static func decide(map: CollisionMap, pos: Vector3, class_id: String, allies: Array, revive_range: float,
		own_alive: bool = true) -> Dictionary:
	if not own_alive:
		return {"action": NONE, "npc": ""}
	for a: Dictionary in allies:
		if int(a.life) == CombatEntity.DOWNED and Vector2(pos.x - a.position.x, pos.z - a.position.z).length() <= revive_range:
			return {"action": NONE, "npc": ""}
	var merchant := NpcDB.load_default().near_with_role(map, pos, "merchant")
	if merchant != "":
		return {"action": TRADE, "npc": merchant}
	var other := NpcDB.load_default().near_any(map, pos)
	return {"action": TALK, "npc": other} if other != "" else {"action": NONE, "npc": ""}
