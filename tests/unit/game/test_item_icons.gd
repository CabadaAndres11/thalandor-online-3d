extends GutTest
## Item icons: each base gets one texture (a render of its model, a drawn flask for
## potions), made once and cached.


func test_icon_cached() -> void:
	var a := ItemIcons.icon("sword_t1")
	assert_not_null(a)
	assert_same(ItemIcons.icon("sword_t1"), a)


func test_potions_drawn() -> void:
	var h := ItemIcons.icon("potion_health")
	var r := ItemIcons.icon("potion_resource")
	assert_eq(h.get_width(), ItemIcons.SIZE)
	assert_ne(h, r)
	var img := h.get_image()
	assert_gt(img.get_pixel(ItemIcons.SIZE / 2, ItemIcons.SIZE * 2 / 3).r, 0.5, "a red flask")


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
