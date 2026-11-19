extends GutTest
## ItemDB: who can use what, which bases drop at a level, one and two-handed weapons.

var db: ItemDB


func before_each() -> void:
	db = ItemDB.load_default()


func test_can_use_armor_only_of_own_class() -> void:
	assert_true(db.can_use("warrior", "warrior_chest_t1"))
	assert_false(db.can_use("warrior", "mage_chest_t1"), "a set is only for its class")
	assert_false(db.can_use("mage", "warrior_chest_t1"))
	assert_true(db.can_use("cleric", "cleric_head_t1"))
	assert_false(db.can_use("cleric", "mage_head_t1"), "cloth of another class too")
	assert_true(db.can_use("archer", "archer_legs_t1"))
	assert_false(db.can_use("assassin", "archer_legs_t1"))
	assert_false(db.can_use("villager", "warrior_chest_t1"))


func test_each_set_keeps_its_armor_type() -> void:
	assert_eq(db.base("warrior_chest_t1").kind, "plate")
	assert_eq(db.base("mage_chest_t1").kind, "cloth")
	assert_eq(db.base("archer_chest_t1").kind, "mail")
	assert_eq(db.base("assassin_chest_t1").kind, "leather")


func test_can_use_weapons() -> void:
	assert_true(db.can_use("cleric", "wand_t1"))
	assert_true(db.can_use("cleric", "scepter_t1"))
	assert_true(db.can_use("cleric", "tome_t1"))
	assert_true(db.can_use("mage", "wand_t1"))
	assert_false(db.can_use("mage", "scepter_t1"))
	assert_false(db.can_use("warrior", "staff_t1"))
	assert_true(db.can_use("warrior", "greatsword_t1"))
	assert_true(db.can_use("archer", "crossbow_t1"))
	assert_true(db.can_use("assassin", "dagger_t1"))


func test_jewelry_and_potions_for_everyone() -> void:
	for c: String in ["warrior", "cleric", "mage", "archer", "assassin"]:
		assert_true(db.can_use(c, "ring_t1"), c)
		assert_true(db.can_use(c, "neck_t1"), c)
		assert_true(db.can_use(c, "potion_health"), c)


func test_bases_for_tier() -> void:
	var low := db.bases_for(19)
	assert_true(low.has("warrior_chest_t1"))
	assert_false(low.has("potion_health"), "no consumables")
	assert_false(low.has("wood_sword"), "no villager weapon")
	for id: String in db.bases_for(20):
		assert_ne(int(db.base(id).tier), 1, id)
	for id: String in db.bases_for(500):
		assert_eq(int(db.base(id).tier), 3, id)


func test_bases_for_class_and_slot() -> void:
	for id: String in db.bases_for(5, "mage"):
		assert_true(db.can_use("mage", id), id)
	for id: String in db.bases_for(5, "", "chest"):
		assert_eq(db.base(id).slot, "chest", id)


func test_two_hand() -> void:
	assert_eq(db.hands("greatsword_t1"), 2)
	assert_eq(db.hands("staff_t1"), 2)
	assert_eq(db.hands("bow_t1"), 2)
	assert_eq(db.hands("sword_t1"), 1)
	assert_eq(db.hands("warrior_chest_t1"), 0)


func test_family_of() -> void:
	assert_eq(str(db.family_of("greatsword_t1").get("id")), "heavy")
	assert_eq(str(db.family_of("wand_t1").get("id")), "wand")
	assert_true(db.family_of("warrior_chest_t1").is_empty())


func test_base_resolves_template_stats_and_levels() -> void:
	var b := db.base("warrior_chest_t1")
	assert_eq(int(b.min_level), 1)
	assert_eq(int(b.max_level), 19)
	assert_false((b.stats as Array).is_empty())


func test_unknown_base_is_empty() -> void:
	assert_true(db.base("nope").is_empty())
	assert_false(db.can_use("warrior", "nope"))
