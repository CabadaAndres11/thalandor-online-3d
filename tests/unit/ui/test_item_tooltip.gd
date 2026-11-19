extends GutTest
## Item tooltips: name in rarity color, slot, level, stats, durability, value, and the
## comparison with what is worn in that slot.

var db: ItemDB


func before_each() -> void:
	db = ItemDB.load_default()


func _texts(lines: Array) -> Array:
	return lines.map(func(l: Array) -> String: return l[0])


func _item(base_id: String, level: int, rarity := "common", affixes: Array = []) -> Item:
	var it := ItemRoll.new_item(base_id, level, rarity)
	it.affixes = affixes
	return it


func test_name_in_rarity_color() -> void:
	var lines := ItemTooltip.lines(_item("sword_t1", 3, "epic"), "warrior", 10, null, db)
	assert_eq(lines[0][0], tr("ITEM_SWORD_T1"))
	assert_eq(lines[0][1], Color("#b04fe8"))


func test_stats_and_affixes_listed() -> void:
	var it := _item("warrior_chest_t1", 10, "uncommon", [{"id": "strength", "value": 12.0}])
	var t := _texts(ItemTooltip.lines(it, "warrior", 10, null, db))
	assert_has(t, tr("STAT_ARMOR_ADD") % "+13")
	assert_has(t, tr("STAT_STRENGTH") % "+17", "5 fixed + 12 from the property")


func test_tooltip_compare() -> void:
	# Two chests of the same base: level 10 gives 13 armor, level 12 gives 15.4 → +2.
	var worn := _item("warrior_chest_t1", 10)
	var new := _item("warrior_chest_t1", 12)
	var lines := ItemTooltip.lines(new, "warrior", 20, worn, db)
	var t := _texts(lines)
	var i := t.find(tr("STAT_ARMOR_ADD") % "+2")
	assert_gt(i, t.find(tr("ITEM_COMPARE")), "after the comparison header")
	assert_eq(lines[i][1], ItemTooltip.BETTER)


func test_worse_is_red() -> void:
	var lines := ItemTooltip.lines(_item("warrior_chest_t1", 5), "warrior", 20, _item("warrior_chest_t1", 10), db)
	var red := lines.filter(func(l: Array) -> bool: return l[1] == ItemTooltip.WORSE)
	assert_false(red.is_empty())


func test_cannot_use_and_too_high() -> void:
	var t := _texts(ItemTooltip.lines(_item("warrior_chest_t1", 30), "mage", 10, null, db))
	assert_has(t, tr("ITEM_CLASS_CANNOT"))
	var lines := ItemTooltip.lines(_item("mage_chest_t1", 30), "mage", 10, null, db)
	var lvl: Array = lines.filter(func(l: Array) -> bool: return l[0] == tr("ITEM_LEVEL") % 30)[0]
	assert_eq(lvl[1], ItemTooltip.WORSE, "level above the character's in red")


func test_broken_and_value() -> void:
	var it := _item("sword_t1", 10, "rare")
	it.durability = 0
	var lines := ItemTooltip.lines(it, "warrior", 10, null, db)
	var dur: Array = lines.filter(func(l: Array) -> bool: return l[0] == tr("ITEM_DURABILITY") % 0)[0]
	assert_eq(dur[1], ItemTooltip.WORSE)
	assert_has(_texts(lines), tr("ITEM_SELL") % Merchant.sell_price(it, db))


func test_potion() -> void:
	var it := _item("potion_health", 1)
	it.count = 7
	var t := _texts(ItemTooltip.lines(it, "mage", 1, null, db))
	assert_has(t, tr("ITEM_POTION_HEALTH_DESC"))


func test_build_is_a_control() -> void:
	var c := ItemTooltip.build(_item("sword_t1", 1), "warrior", 1, null, db)
	assert_true(c is Control)
	c.free()
