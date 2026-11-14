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
	c.level = 1
	c.created_at = 1_800_000_000
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
	assert_eq(c.class_id, "warrior")
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
	assert_null(CharacterData.from_dict(d, catalog))


func test_level_is_at_least_one() -> void:
	var d := _sample().to_dict()
	d.level = -5
	assert_eq(CharacterData.from_dict(d, catalog).level, 1)
	d.level = "lots"
	assert_eq(CharacterData.from_dict(d, catalog).level, 1)


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
