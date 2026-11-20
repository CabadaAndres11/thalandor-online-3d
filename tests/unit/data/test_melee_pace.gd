extends GutTest
## Basic melee attacks come faster (Plan 6.3.2) with the same damage per second as before.

## [ability, cooldown s, damage base/s, damage coef/s] (the old base and coef over the old cooldown).
const PACE := [
	["warrior_slash", 0.45, 10.0 / 0.6, 0.6 / 0.6],
	["assassin_stab", 0.4, 9.0 / 0.5, 0.5 / 0.5],
	["villager_strike", 0.55, 7.0 / 0.7, 0.42 / 0.7],
]


func _dmg(ab: Dictionary) -> Dictionary:
	for e: Dictionary in ab.effects:
		if e.has("damage"):
			return e.damage
	return {}


func test_faster_basics_same_dps() -> void:
	var db := AbilityDB.load_default()
	for row: Array in PACE:
		var ab := db.get_ability(row[0])
		assert_almost_eq(float(ab.cooldown_s), float(row[1]), 0.001, row[0])
		var d := _dmg(ab)
		assert_almost_eq(float(d.base) / float(ab.cooldown_s), float(row[2]), 0.05, row[0] + " base dps")
		assert_almost_eq(float(d.coef) / float(ab.cooldown_s), float(row[3]), 0.01, row[0] + " coef dps")


func test_templar_smite_faster_same_dps() -> void:
	var ab := AbilityDB.load_default().resolved("cleric_smite", "templar")
	assert_almost_eq(float(ab.cooldown_s), 0.6, 0.001)
	var d := _dmg(ab)
	assert_almost_eq(float(d.base) / 0.6, 10.35 / 0.8, 0.05)
	assert_almost_eq(float(d.coef) / 0.6, 0.69 / 0.8, 0.01)


func test_two_handed_and_polearm_pace() -> void:
	var fams: Dictionary = ItemDB.load_default().weapons().families
	assert_eq(float(fams.heavy.cooldown_mult), 1.25)
	assert_almost_eq(float(fams.heavy.damage_mult) / 1.25, 1.5 / 1.4, 0.01, "same dps with a two-hander")
	assert_eq(float(fams.polearm.cooldown_mult), 1.1)
	assert_almost_eq(float(fams.polearm.damage_mult) / 1.1, 1.25 / 1.2, 0.01)


func test_swings_fit_in_the_new_cooldowns() -> void:
	assert_lte(float(HumanRig.ACTIONS.melee), 0.45)
	assert_lte(float(HumanRig.ACTIONS.heavy), 0.45 * 1.25)
	assert_lte(float(HumanRig.ACTIONS.thrust), 0.45 * 1.1)
	assert_lte(float(HumanRig.ACTIONS.stab), 0.4)
