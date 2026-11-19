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
