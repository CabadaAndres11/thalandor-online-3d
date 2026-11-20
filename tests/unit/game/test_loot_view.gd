extends GutTest
## Loot on the ground: a light beam and the item's name in its rarity color, only for the
## owner's own drops; gold rises as a golden number.

var view: LootView


func before_each() -> void:
	view = LootView.new()
	add_child_autofree(view)
	view.my_id = 1


func _loot(owner: int, drop_id: int, rarity := "rare") -> Array:
	var it := ItemRoll.new_item("sword_t1", 3, rarity)
	return ["loot", owner, drop_id, it.to_dict(), Vector3(4, 0, 4)]


func test_loot_beam_spawn_and_free() -> void:
	view.handle(_loot(1, 9))
	assert_eq(view.drop_count(), 1)
	var label := view.drop_label(9)
	assert_eq(label.text, tr("ITEM_SWORD_T1"))
	assert_eq(label.modulate, Color("#3f8cff"), "rare = blue")
	view.handle(["loot_gone", 1, 9, true])
	assert_eq(view.drop_count(), 0)


func test_other_players_loot_ignored() -> void:
	view.handle(_loot(2, 9))
	assert_eq(view.drop_count(), 0)


func test_gold_number_rises_and_fades() -> void:
	view.handle(["gold", 1, 42, Vector3(2, 0, 2)])
	assert_eq(view.number_count(), 1)
	assert_string_contains(view.number_label(0).text, "42")
	var y := view.number_label(0).position.y
	view.advance(0.5)
	assert_gt(view.number_label(0).position.y, y)
	view.advance(5.0)
	assert_eq(view.number_count(), 0)


func test_clear() -> void:
	view.handle(_loot(1, 9))
	view.clear()
	assert_eq(view.drop_count(), 0)


func test_drop_shows_the_item_model_on_the_ground() -> void:
	view.handle(_loot(1, 9))
	var model: Node3D = view.drop_model(9)
	assert_not_null(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), ItemIcons.icon_pieces("sword_t1").size(), "one mesh per icon piece")
	var box: AABB = view.drop_model_aabb(9)
	assert_lte(maxf(box.size.x, maxf(box.size.y, box.size.z)), LootView.MODEL_SIZE + 0.001, "fits")
	assert_gte(box.position.y, -0.001, "rests on the ground")


func test_potion_drop_is_a_sack() -> void:
	var it := ItemRoll.new_item("potion_health", 3)
	view.handle(["loot", 1, 4, it.to_dict(), Vector3(1, 0, 1)])
	var model: Node3D = view.drop_model(4)
	assert_not_null(model)
	assert_eq(model.find_children("*", "MeshInstance3D", true, false).size(), 1)


func test_drop_model_spins() -> void:
	view.handle(_loot(1, 9))
	var r: float = view.drop_model(9).rotation.y
	view.advance(0.5)
	assert_ne(view.drop_model(9).rotation.y, r)
