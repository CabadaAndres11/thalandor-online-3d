extends GutTest

var catalog: CharacterCatalog


func before_each() -> void:
	catalog = CharacterCatalog.load_default()


func _sample() -> CharacterData:
	var c := CharacterData.new()
	c.id = "0123456789abcdef"
	c.name = "Andrés"
	c.class_id = "mage"
	c.appearance = catalog.sanitize_appearance({"hair_style": "hair_long", "skin": "skin_4"})
	c.progress.level = 20
	c.created_at = 1_800_000_000
	c.inventory = Inventory.starter("mage", ItemDB.load_default())
	c.bar = AbilityDB.load_default().sanitize_bar("mage", ["mage_fireball", "", "mage_frost_nova", "", "", "", "", "", ""], 20)
	return c


func test_round_trip() -> void:
	var c := _sample()
	var d := c.to_dict()
	assert_eq(d.version, CharacterData.VERSION)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(d)), catalog)
	assert_not_null(back)
	assert_eq(back.to_dict(), d)


func test_sanitizes_unknown_class_and_appearance() -> void:
	var d := _sample().to_dict()
	d.class_id = "druid"
	d.appearance = {"skin": "purple", "hair_style": 3}
	var c := CharacterData.from_dict(d, catalog)
	assert_eq(c.class_id, "villager")
	assert_eq(c.appearance, catalog.default_appearance())


func test_rejects_non_dictionary_and_missing_id() -> void:
	assert_null(CharacterData.from_dict(null, catalog))
	assert_null(CharacterData.from_dict([1, 2], catalog))
	var d := _sample().to_dict()
	d.erase("id")
	assert_null(CharacterData.from_dict(d, catalog))


func test_rejects_invalid_name() -> void:
	var d := _sample().to_dict()
	d.name = "x"
	assert_null(CharacterData.from_dict(d, catalog))
	d.name = 42



## A file from before versioning (version 0) used "class" for the class id.
func test_migrates_version_0_example() -> void:
	var old := {"id": "abcdefabcdefabcd", "name": "Lyra", "class": "archer", "appearance": {}, "level": 1}
	var c := CharacterData.from_dict(old, catalog)
	assert_not_null(c)
	assert_eq(c.class_id, "archer")
	assert_eq(c.to_dict().version, CharacterData.VERSION)


func test_newer_version_is_rejected() -> void:
	var d := _sample().to_dict()
	d.version = CharacterData.VERSION + 1
	assert_null(CharacterData.from_dict(d, catalog), "a file from a newer game is left alone")


## Version 1 files had no ability bar: they get the class's default bar.
func test_migrates_v1_to_v2_with_default_bar() -> void:
	var old := {"version": 1, "id": "abcdefabcdefabcd", "name": "Lyra", "class_id": "archer",
		"appearance": {}, "created_at": 5}
	var c := CharacterData.from_dict(old, catalog)
	assert_not_null(c)
	assert_eq(c.bar, AbilityDB.load_default().default_bar("archer"))
	assert_eq(c.to_dict().version, CharacterData.VERSION)
	assert_eq(c.to_dict().bar, c.bar)


func test_bar_sanitized_to_class_abilities() -> void:
	var d := _sample().to_dict()
	d.bar = ["mage_fireball", "warrior_whirlwind", "mage_fireball", 5, "mage_frostbolt"]
	var c := CharacterData.from_dict(d, catalog)
	assert_eq(c.bar, ["mage_fireball", "", "", "", "mage_frostbolt", "", "", "", ""],
		"other classes' abilities, duplicates and non-strings are dropped")
	d.bar = "nope"
	assert_eq(CharacterData.from_dict(d, catalog).bar, AbilityDB.load_default().default_bar("mage", 20))
	d.class_id = "warrior"
	d.bar = ["mage_fireball", "", "", "", "", "", "", "", ""]
	assert_eq(CharacterData.from_dict(d, catalog).bar, ["", "", "", "", "", "", "", "", ""], "the bar follows the class")


func test_new_character_is_villager() -> void:
	assert_eq(CharacterData.new().class_id, "villager")
	var d := {"version": 2, "id": "c1", "name": "Ana", "appearance": {}, "bar": []}
	var c := CharacterData.from_dict(d, CharacterCatalog.load_default())
	assert_eq(c.class_id, "villager", "no class in the file: a villager")


func test_old_save_keeps_class() -> void:
	var d := {"version": 2, "id": "c1", "name": "Ana", "class_id": "mage", "appearance": {}, "bar": []}
	assert_eq(CharacterData.from_dict(d, CharacterCatalog.load_default()).class_id, "mage")


func test_progress_roundtrip() -> void:
	var c := _sample()
	c.progress.level = 33
	c.progress.xp = 1234
	c.progress.attributes["agility"] = 9
	c.progress.talents = ["might_1", "might_2"]
	c.progress.masteries = {"might": 2}
	c.progress.upgrade = "berserker"
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())), catalog)
	assert_eq(back.progress.to_dict(), c.progress.to_dict())
	assert_eq(back.to_dict().progress.level, 33)
	assert_false(back.to_dict().has("level"), "the old level field is gone")


func test_v2_migrates_to_level_1() -> void:
	var old := {"version": 2, "id": "abcdefabcdefabcd", "name": "Lyra", "class_id": "archer",
		"appearance": {}, "level": 1, "created_at": 5, "bar": ["archer_roll", "", "", "", "", "", "", "", ""]}
	var c := CharacterData.from_dict(old, catalog)
	assert_not_null(c)
	assert_eq(c.progress.level, 1)
	assert_eq(c.progress.xp, 0)
	assert_eq(c.to_dict().version, CharacterData.VERSION)
	assert_eq(c.bar.size(), 9)
	assert_eq(c.name, "Lyra", "nothing else is lost")


func test_garbage_progress_loads_defaults() -> void:
	for junk: Variant in ["x", 5, [1, 2], {"level": "x", "attributes": 3, "talents": "a", "upgrade": 9}, null]:
		var d := _sample().to_dict()
		d.progress = junk
		var c := CharacterData.from_dict(d, catalog)
		assert_not_null(c, "the character still loads")
		assert_eq(c.progress.level, 1)
		assert_eq(c.progress.talents, [])
		assert_eq(c.progress.upgrade, "")


func test_bar_uses_the_progress_level() -> void:
	var d := _sample().to_dict()
	d.progress = {"level": 1}
	d.bar = ["mage_fireball", "mage_frost_nova", "", "", "", "", "", "", ""]
	assert_eq(CharacterData.from_dict(d, catalog).bar, ["", "", "", "", "", "", "", "", ""], "locked abilities leave the bar")
	d.progress = {"level": 10}
	assert_eq(CharacterData.from_dict(d, catalog).bar, ["mage_fireball", "mage_frost_nova", "", "", "", "", "", "", ""])


func _worn(c: CharacterData) -> Array:
	var out: Array = c.inventory.equipment.values().map(func(it: Item) -> String: return it.base_id)
	out.sort()
	return out


func test_v3_gets_starter() -> void:
	var d := {"version": 3, "id": "c3", "name": "Ana", "class_id": "warrior", "appearance": {}, "bar": [],
		"progress": {"level": 12, "talents": ["might_1"]}}
	var c := CharacterData.from_dict(d, catalog)
	var kit: Array = ItemDB.load_default().starter("warrior").duplicate()
	kit.sort()
	assert_eq(_worn(c), kit)
	assert_eq(c.progress.level, 12)
	assert_eq(c.progress.talents, ["might_1"])
	assert_eq(c.inventory.gold, 0)
	for it: Item in c.inventory.equipment.values():
		assert_eq([it.level, it.rarity, it.durability], [1, "common", 100])


func test_v3_villager_wood_sword() -> void:
	var d := {"version": 3, "id": "c3", "name": "Ana", "appearance": {}, "bar": []}
	assert_eq(_worn(CharacterData.from_dict(d, catalog)), ["wood_sword"])


func test_v3_assassin_two_daggers() -> void:
	var d := {"version": 3, "id": "c3", "name": "Ana", "class_id": "assassin", "appearance": {}, "bar": []}
	var c := CharacterData.from_dict(d, catalog)
	assert_eq(c.inventory.equipment.main.base_id, "dagger_t1")
	assert_eq(c.inventory.equipment.offhand.base_id, "dagger_t1")


func test_roundtrip_v4() -> void:
	var c := _sample()
	c.inventory.gold = 321
	c.inventory.add(ItemRoll.new_item("wand_t1", 3, "rare"), ItemDB.load_default())
	var d := c.to_dict()
	assert_eq(d.version, 4)
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(d)), catalog)
	assert_eq(back.to_dict(), d)


func test_new_character_is_a_villager_with_a_wood_sword() -> void:
	assert_eq(_worn(CharacterData.new()), ["wood_sword"])


## A 0.9.7 character has no race: it opens as a human with the same looks.
func test_v4_without_race_loads_as_human() -> void:
	var d := _sample().to_dict()
	var app := {"body": "robust", "skin": "skin_4", "eyes": "green", "hair_style": "hair_long", "hair_color": "red", "beard": "short"}
	d.appearance = app
	var c := CharacterData.from_dict(d, catalog)
	assert_eq(c.appearance.race, "human")
	assert_eq(c.appearance.marks, "none")
	for kind: String in app:
		assert_eq(c.appearance[kind], app[kind], kind)


func test_unknown_race_falls_back() -> void:
	var d := _sample().to_dict()
	d.appearance = {"race": "dragon", "hair_style": "hair_long"}
	var c := CharacterData.from_dict(d, catalog)
	assert_eq(c.appearance.race, "human")
	assert_eq(c.appearance.hair_style, "hair_long")
