extends GutTest
## data/upgrades: every class has its upgrades with texts, and what they name exists.
## Classes whose content is not written yet are listed in PENDING (a task each).

const PENDING := ["archer", "assassin"]
const EXPECTED := {"warrior": 2, "cleric": 2, "mage": 3, "archer": 2, "assassin": 2}

var ups: UpgradeDB
var abilities: AbilityDB


func before_each() -> void:
	ups = UpgradeDB.load_default()
	abilities = AbilityDB.load_default()


func test_every_class_has_its_upgrades() -> void:
	for c: String in EXPECTED:
		assert_eq(ups.for_class(c).size(), EXPECTED[c], c)


func test_mage_has_three() -> void:
	assert_eq(ups.for_class("mage").map(func(u: Dictionary) -> String: return u.id), ["pyromancer", "cryomancer", "arcanist"])


func test_every_upgrade_has_2_actives_2_passives_1_evolution() -> void:
	for c: String in EXPECTED:
		if c in PENDING:
			continue
		var errors := UpgradeDB.from_list(ups.for_class(c)).validate(abilities, true)
		assert_eq(errors, [] as Array[String], c)
	pass_test("classes still pending: %s" % str(PENDING))


func test_all_ids_exist() -> void:
	assert_eq(ups.validate(abilities), [] as Array[String])


func test_texts_exist() -> void:
	for c: String in EXPECTED:
		for u: Dictionary in ups.for_class(c):
			assert_ne(tr(str(u.name)), str(u.name), str(u.id))
			assert_ne(tr(str(u.desc)), str(u.desc), str(u.id))


func test_ids_are_unique_and_the_class_exists() -> void:
	var seen := {}
	for c: String in EXPECTED:
		assert_true(CharacterCatalog.load_default().is_selectable(c))
		for u: Dictionary in ups.for_class(c):
			assert_false(seen.has(u.id), str(u.id))
			seen[u.id] = true
