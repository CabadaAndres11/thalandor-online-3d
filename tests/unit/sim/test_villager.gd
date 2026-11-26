extends GutTest
## Characters start as villagers (no class yet): modest stats, no class resource, a
## wooden-sword strike and nothing on the bar until Brann trains them.


func test_villager_setup() -> void:
	var p := PlayerState.new()
	ClassRules.setup_player(p, "villager")
	assert_eq(p.class_id, "villager")
	assert_eq(p.stats.max_hp, 120.0)
	assert_eq(p.hp, 120.0)
	assert_eq(p.resource_kind, "none")
	assert_eq(p.stats.max_resource, 0.0)
	assert_eq(p.resource, 0.0)


func test_villager_kit() -> void:
	var db := AbilityDB.load_default()
	assert_eq(db.kind_of("villager", "basic"), "villager_strike")
	assert_eq(db.kind_of("villager", "secondary"), "villager_shove", "a right click for the practice (Plan 8.3a)")
	assert_eq(db.actives("villager"), [])


func test_villager_bar_is_empty_even_from_an_old_bar() -> void:
	var db := AbilityDB.load_default()
	assert_eq(db.sanitize_bar("villager", ["warrior_charge", "warrior_battle_cry", "", "", "", "", "", "", ""]), ["", "", "", "", "", "", "", "", ""])
	assert_eq(db.sanitize_bar("villager", []), ["", "", "", "", "", "", "", "", ""])
