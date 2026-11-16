extends GutTest
## Pressing E: reviving a downed ally beats talking; next to Brann a villager opens
## the class window and anyone else hears a line; far away nothing happens.

var map: CollisionMap


func before_each() -> void:
	map = CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": [22, 20], "facing": 0}]})


func _decide(pos: Vector3, class_id: String, allies := []) -> Dictionary:
	return NpcInteraction.decide(map, pos, class_id, allies, 2.0)


func test_e_opens_for_villager_near_brann() -> void:
	var r := _decide(Vector3(20.5, 0, 20.5), "villager")
	assert_eq(r, {"action": NpcInteraction.CHOOSE_CLASS, "npc": "brann"})


func test_e_with_class_shows_line() -> void:
	var r := _decide(Vector3(20.5, 0, 20.5), "mage")
	assert_eq(r, {"action": NpcInteraction.TALK, "npc": "brann"})


func test_e_far_does_nothing() -> void:
	assert_eq(_decide(Vector3(10.5, 0, 10.5), "villager").action, NpcInteraction.NONE)


func test_e_prefers_revive() -> void:
	var allies := [{"position": Vector3(21.0, 0, 20.5), "life": CombatEntity.DOWNED}]
	assert_eq(_decide(Vector3(20.5, 0, 20.5), "villager", allies).action, NpcInteraction.NONE, "E revives instead")
	var standing := [{"position": Vector3(21.0, 0, 20.5), "life": CombatEntity.ALIVE}]
	assert_eq(_decide(Vector3(20.5, 0, 20.5), "villager", standing).action, NpcInteraction.CHOOSE_CLASS)


func test_brann_avatar_builds_with_name() -> void:
	var a := NpcAvatar.new()
	add_child_autofree(a)
	a.setup("brann", Vector3(1, 0, 2), 0.0)
	assert_true(a.rig is HumanRig)
	assert_has(a.rig.pieces(), "beard_full")
	assert_has(a.rig.pieces(), "weapon_sword")
	assert_eq(a.display_name(), tr("NPC_BRANN"))
	assert_false(a.prompt_visible())
	a.set_prompt_visible(true)
	assert_true(a.prompt_visible())
