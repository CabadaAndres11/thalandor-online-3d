extends GutTest
## Pressing E: reviving a downed ally beats talking; next to an NPC it talks (Plan 8.3a: the
## class comes from the story, not from Brann); far away nothing happens.

var map: CollisionMap


func before_each() -> void:
	map = CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": [22, 20], "facing": 0}]})


func _decide(pos: Vector3, class_id: String, allies := []) -> Dictionary:
	return NpcInteraction.decide(map, pos, class_id, allies, 2.0)


func test_e_talks_to_brann_even_as_a_villager() -> void:
	var r := _decide(Vector3(20.5, 0, 20.5), "villager")
	assert_eq(r, {"action": NpcInteraction.TALK, "npc": "brann"})


func test_e_with_class_shows_line() -> void:
	var r := _decide(Vector3(20.5, 0, 20.5), "mage")
	assert_eq(r, {"action": NpcInteraction.TALK, "npc": "brann"})


func test_e_far_does_nothing() -> void:
	assert_eq(_decide(Vector3(10.5, 0, 10.5), "villager").action, NpcInteraction.NONE)


func test_e_prefers_revive() -> void:
	var allies := [{"position": Vector3(21.0, 0, 20.5), "life": CombatEntity.DOWNED}]
	assert_eq(_decide(Vector3(20.5, 0, 20.5), "villager", allies).action, NpcInteraction.NONE, "E revives instead")
	var standing := [{"position": Vector3(21.0, 0, 20.5), "life": CombatEntity.ALIVE}]
	assert_eq(_decide(Vector3(20.5, 0, 20.5), "villager", standing).action, NpcInteraction.TALK)


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


func test_e_while_downed_does_nothing() -> void:
	var r := NpcInteraction.decide(map, Vector3(20.5, 0, 20.5), "villager", [], 2.0, false)
	assert_eq(r.action, NpcInteraction.NONE, "on the ground you can't talk to Brann")


func test_revive_still_beats_trainer() -> void:
	var allies := [{"position": Vector3(21.0, 0, 20.5), "life": CombatEntity.DOWNED}]
	assert_eq(_decide(Vector3(20.5, 0, 20.5), "warrior", allies).action, NpcInteraction.NONE)


func test_interact_opens_merchant() -> void:
	var m := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": [10, 10], "facing": 0}, {"id": "merchant", "at": [22, 20], "facing": 0}]})
	var r := NpcInteraction.decide(m, Vector3(20.5, 0, 20.5), "mage", [], 2.0)
	assert_eq(r, {"action": NpcInteraction.TRADE, "npc": "merchant"})
	r = NpcInteraction.decide(m, Vector3(20.5, 0, 20.5), "villager", [], 2.0)
	assert_eq(r.action, NpcInteraction.TRADE, "villagers can trade too")


func test_npc_weapons_follow_the_v2_body() -> void:
	var look := NpcAvatar.look_of({"class": "warrior", "weapons": ["weapon_sword"]})
	var found := false
	for p: Dictionary in look.pieces:
		if str(p.id) == "weapon_sword":
			found = true
			assert_true(str(p.file).contains("/pieces_v2/") or float(p.get("voxel_scale", 1.0)) == 2.0, str(p))
	assert_true(found)


func test_e_talks_to_any_npc() -> void:
	map.npcs.append({"id": "vecina", "at": [10, 10], "facing": 0})
	assert_eq(_decide(Vector3(10.5, 0, 11.5), "mage"), {"action": NpcInteraction.TALK, "npc": "vecina"})


func test_npc_faces_a_point() -> void:
	var a := NpcAvatar.new()
	add_child_autofree(a)
	a.setup("vecina", Vector3(10.5, 0, 10.5), 0.0)
	a.face(Vector3(12.5, 0, 10.5))
	assert_almost_eq(a.rotation.y, PI / 2.0, 0.01)
