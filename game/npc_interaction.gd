class_name NpcInteraction
extends RefCounted
## What pressing E does near NPCs. Holding E next to a downed ally revives it (the
## simulation handles that), so a downed ally in reach wins over talking. Next to a
## class trainer a villager chooses a class; anyone else just hears a line.

const NONE := ""
const CHOOSE_CLASS := "choose_class"
const TALK := "talk"


## allies: [{position: Vector3, life: int}] (other players); own_alive: false while this
## player is downed or dead (then E does nothing here). Returns {action, npc}.
static func decide(map: CollisionMap, pos: Vector3, class_id: String, allies: Array, revive_range: float,
		own_alive: bool = true) -> Dictionary:
	if not own_alive:
		return {"action": NONE, "npc": ""}
	for a: Dictionary in allies:
		if int(a.life) == CombatEntity.DOWNED and Vector2(pos.x - a.position.x, pos.z - a.position.z).length() <= revive_range:
			return {"action": NONE, "npc": ""}
	var npc := NpcDB.load_default().near_with_role(map, pos, "class_trainer")
	if npc == "":
		return {"action": NONE, "npc": ""}
	var villager := not CharacterCatalog.load_default().is_selectable(class_id)
	return {"action": CHOOSE_CLASS if villager else TALK, "npc": npc}


## What Brann offers a player (ids for TrainerMenu), in order. A villager only learns a
## class (then the menu is skipped and the class window opens). In combat there are no
## resets; the arena level is the host player's.
static func trainer_options(class_id: String, progress: PlayerProgress, is_host: bool, in_combat: bool) -> Array:
	if not CharacterCatalog.load_default().is_selectable(class_id):
		return ["choose_class"]
	var out: Array = []
	if progress.level >= ProgressRequests.UPGRADE_LEVEL and progress.upgrade == "":
		out.append("choose_upgrade")
	if not in_combat:
		out.append("reset_attributes")
		out.append("reset_talents")
		if progress.upgrade != "":
			out.append("reset_upgrade")
	if is_host:
		out.append("arena_level")
	return out
