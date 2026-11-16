extends GutTest


func test_defaults() -> void:
	var p := PlayerProgress.new()
	assert_eq(p.level, 1)
	assert_eq(p.xp, 0)
	assert_eq(p.upgrade, "")
	assert_eq(p.talents, [])
	for a: String in PlayerProgress.ATTRIBUTES:
		assert_eq(p.attributes[a], 0)


func test_from_dict_garbage() -> void:
	for v: Variant in ["x", {"level": -5}, {"attributes": [1]}, {"talents": "a"}, null, 5]:
		var p := PlayerProgress.from_dict(v)
		assert_not_null(p)
		assert_eq(p.level, 1)
		assert_eq(p.talents, [])
		assert_eq(p.attributes["strength"], 0)


func test_roundtrip() -> void:
	var p := PlayerProgress.new()
	p.level = 12
	p.xp = 345
	p.attributes["strength"] = 7
	p.talents = ["might_1", "might_2"]
	p.masteries = {"might": 3}
	p.upgrade = "berserker"
	var q := PlayerProgress.from_dict(p.to_dict())
	assert_eq(q.to_dict(), p.to_dict())
	assert_eq(q.level, 12)
	assert_eq(q.attributes["strength"], 7)
	assert_eq(q.masteries["might"], 3)
	assert_eq(q.upgrade, "berserker")


func test_roundtrip_through_json() -> void:
	var p := PlayerProgress.new()
	p.level = 9
	p.attributes["spirit"] = 4
	var q := PlayerProgress.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.level, 9)
	assert_eq(q.attributes["spirit"], 4)
