extends GutTest
## Item squares: a red background on what the viewer cannot equip (other class, too high level).


func _slot(base_id: String, item_level: int, class_id: String, level: int) -> ItemSlot:
	var s := ItemSlot.new()
	add_child_autofree(s)
	s.class_id = class_id
	s.level = level
	s.set_item(ItemRoll.new_item(base_id, item_level))
	return s


func test_other_class_armor_is_red() -> void:
	assert_true(_slot("mage_chest_t1", 5, "warrior", 10).unusable())


func test_own_class_armor_is_normal() -> void:
	var s := _slot("mage_chest_t1", 5, "mage", 10)
	assert_false(s.unusable())
	assert_ne((s.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, ItemSlot.UNUSABLE_BG)


func test_too_high_level_is_red() -> void:
	var s := _slot("mage_chest_t1", 12, "mage", 10)
	assert_true(s.unusable())
	assert_eq((s.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, ItemSlot.UNUSABLE_BG)


func test_potions_and_jewelry_never_red() -> void:
	assert_false(_slot("potion_health", 50, "warrior", 1).unusable(), "potions")
	assert_false(_slot("ring_t1", 5, "warrior", 10).unusable(), "rings fit everyone")


func test_no_viewer_class_is_not_red() -> void:
	assert_false(_slot("mage_chest_t1", 5, "", 10).unusable())
