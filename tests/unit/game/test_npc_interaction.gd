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


func test_e_while_downed_does_nothing() -> void:
	var r := NpcInteraction.decide(map, Vector3(20.5, 0, 20.5), "villager", [], 2.0, false)
	assert_eq(r.action, NpcInteraction.NONE, "on the ground you can't talk to Brann")


# --- Brann as a trainer: what he offers ----------------------------------------------

func _opts(class_id: String, level := 1, upgrade := "", host := false, combat := false) -> Array:
	var pr := PlayerProgress.from_dict({"level": level, "upgrade": upgrade})
	return NpcInteraction.trainer_options(class_id, pr, host, combat)


func test_trainer_options_villager_only_chooses_a_class() -> void:
	assert_eq(_opts("villager"), ["choose_class"])
	assert_eq(_opts("villager", 5, "", true), ["choose_class"], "the host's arena control waits for a class")


func test_trainer_options_class_below_50() -> void:
	assert_eq(_opts("warrior", 10), ["reset_attributes", "reset_talents"])


func test_trainer_options_level_50_without_upgrade() -> void:
	assert_eq(_opts("warrior", 50), ["choose_upgrade", "reset_attributes", "reset_talents"])


func test_trainer_options_with_upgrade() -> void:
	assert_eq(_opts("warrior", 50, "berserker"), ["reset_attributes", "reset_talents", "reset_upgrade"])


func test_trainer_options_host_gets_the_arena_level() -> void:
	assert_eq(_opts("mage", 3, "", true), ["reset_attributes", "reset_talents", "arena_level"])
	assert_eq(_opts("mage", 3, "", false), ["reset_attributes", "reset_talents"])


func test_trainer_options_in_combat_have_no_resets() -> void:
	assert_eq(_opts("warrior", 10, "", false, true), [])
	assert_eq(_opts("warrior", 50, "", false, true), ["choose_upgrade"])
	assert_eq(_opts("warrior", 50, "berserker", true, true), ["arena_level"])


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
