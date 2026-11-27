extends GutTest
## Item icons: each base gets one texture (a render of its model, or its painted icon in
## assets/icons/items, as the potions), made once and cached.


func test_icon_cached() -> void:
	var a := ItemIcons.icon("sword_t1")
	assert_not_null(a)
	assert_same(ItemIcons.icon("sword_t1"), a)


func test_potions_use_their_painted_icons() -> void:
	var h := ItemIcons.icon("potion_health")
	var r := ItemIcons.icon("potion_resource")
	assert_eq(h.resource_path, ItemIcons.PAINTED_DIR + "potion_health.png")
	assert_eq(r.resource_path, ItemIcons.PAINTED_DIR + "potion_resource.png")
	var red := h.get_image().get_pixel(64, 80)
	var blue := r.get_image().get_pixel(64, 80)
	assert_gt(red.r, red.b, "a red potion")
	assert_gt(blue.b, blue.r, "a blue potion")


func test_unknown_base_has_a_fallback() -> void:
	assert_not_null(ItemIcons.icon("nope"))


func test_rarity_color() -> void:
	assert_eq(ItemIcons.rarity_color("epic"), Color("#b04fe8"))
	assert_eq(ItemIcons.rarity_color("weird"), Color.WHITE)


func test_icons_use_v2_pieces() -> void:
	var pieces := ItemIcons.icon_pieces("warrior_chest_t3")
	assert_false(pieces.is_empty())
	for p: Dictionary in pieces:
		assert_string_contains(str(p.file), "/vox_v2/")


func test_jewelry_has_a_model_for_icons() -> void:
	for id: String in ["ring_t1", "ring_t2", "ring_t3", "neck_t1", "neck_t2", "neck_t3"]:
		var pieces := ItemIcons.icon_pieces(id)
		assert_eq(pieces.size(), 1, id)
		assert_string_contains(str(pieces[0].file), "jewel_", id)
		assert_true(ResourceLoader.exists(str(pieces[0].file)) or FileAccess.file_exists(str(pieces[0].file)), id)


func test_jewelry_is_never_worn() -> void:
	var inv := Inventory.new()
	inv.equipment["ring_1"] = ItemRoll.new_item("ring_t3", 30)
	inv.equipment["neck"] = ItemRoll.new_item("neck_t3", 30)
	for b: Variant in inv.visible_bases():
		assert_false(str(b).begins_with("ring") or str(b).begins_with("neck"), str(b))
