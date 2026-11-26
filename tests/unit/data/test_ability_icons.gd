extends GutTest
## Every player ability points at an icon that exists, and every class-kit icon
## (passives included) is from the painted 128 px set, not an old placeholder.

const ABILITY_DIR := "res://data/abilities/"
const ICON_PATH := "res://assets/icons/%s.png"
const KIT_FILES := ["warrior", "mage", "archer", "assassin", "cleric"]
const MIN_SIDE := 128


func _abilities(file: String) -> Array:
	var f := FileAccess.open(ABILITY_DIR + file + ".json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Array else []


func test_every_player_ability_icon_exists() -> void:
	# Monster abilities are left out on purpose: they are never shown in the HUD
	# and still point at placeholder names (e.g. "bite") until their icon phase.
	for file in ["warrior", "mage", "archer", "assassin", "cleric", "villager"]:
		for a in _abilities(file):
			var icon := str(a.get("icon", ""))
			assert_true(ResourceLoader.exists(ICON_PATH % icon), "%s -> %s" % [a.get("id"), icon])


func test_kit_icons_are_painted_set() -> void:
	for file in KIT_FILES:
		for a in _abilities(file):
			var tex := load(ICON_PATH % str(a.get("icon", ""))) as Texture2D
			assert_not_null(tex, str(a.get("id")))
			if tex != null:
				assert_gte(tex.get_width(), MIN_SIDE, "%s icon too small" % a.get("id"))
