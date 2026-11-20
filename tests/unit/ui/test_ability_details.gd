extends GutTest
## Plan 3.1: the computed details under each ability's description.

const CLASSES := ["warrior", "cleric", "mage", "archer", "assassin"]
const RESOURCES := {"warrior": "rage", "cleric": "mana", "mage": "mana", "archer": "focus", "assassin": "energy"}

var db: AbilityDB


func before_each() -> void:
	db = AbilityDB.load_default()


func _stats(attack := 20.0, spell := 20.0) -> CombatStats:
	return CombatStats.from_dict({"max_hp": 150, "attack_power": attack, "spell_power": spell, "crit_chance": 0.05})


func _text(id: String, stats: CombatStats = null, class_id := "") -> String:
	var a := db.get_ability(id)
	var c := class_id if class_id != "" else str(a.get("class", ""))
	return "\n".join(AbilityDetails.lines(a, stats if stats != null else _stats(), RESOURCES.get(c, "mana")))


func test_damage_formula_and_result() -> void:
	var t := _text("warrior_whirlwind")
	assert_string_contains(t, "18 + 80 % de tu poder de ataque (20) = 34 físico")
	assert_string_contains(t, "3 m")


func test_magic_uses_spell_power() -> void:
	var t := _text("mage_missile", _stats(5, 30))
	assert_string_contains(t, "10 + 70 % de tu poder mágico (30) = 31 mágico")


func test_heal_over_time() -> void:
	var t := _text("cleric_renew")
	assert_string_contains(t, "30 + 120 % de tu poder mágico (20) = 54")
	assert_string_contains(t, "6 s")


func test_status_lines() -> void:
	var mark := _text("archer_mark")
	assert_string_contains(mark, "15 %")
	assert_string_contains(mark, "10 s")
	var bolt := _text("mage_frostbolt")
	assert_string_contains(bolt, "50 %")
	assert_string_contains(bolt, "4 s")
	assert_string_contains(_text("mage_frost_nova"), "2 s")


func test_cost_cooldown_and_combat_cooldown() -> void:
	var t := _text("assassin_stealth")
	assert_string_contains(t, "20 de energía")
	assert_string_contains(t, "8 s")
	assert_string_contains(t, "45 s en combate")
	assert_string_contains(_text("warrior_slash"), tr("DETAIL_NO_COST"))


func test_crit_line_only_with_damage() -> void:
	assert_string_contains(_text("warrior_slash"), "5 %")
	assert_false(_text("warrior_taunt").contains(tr("DETAIL_CRIT").get_slice("%", 0)), "no crit line without damage")


func test_finisher_charge_and_combo() -> void:
	assert_string_contains(_text("assassin_eviscerate"), tr("DETAIL_FINISHER"))
	var shot := _text("archer_shot")
	assert_string_contains(shot, "×2,2")
	assert_false(shot.contains("concentración"), "the charge is free (Plan 6.4.4)")
	assert_string_contains(_text("assassin_stab"), tr("DETAIL_COMBO_GAIN") % 1)


func test_secondary_effects_are_described() -> void:
	assert_string_contains(_text("mage_fireball"), "2,5 m", "the explosion")
	assert_string_contains(_text("warrior_charge"), "1,8 m", "the landing blow")
	assert_string_contains(_text("archer_arrow_rain"), "3")
	assert_string_contains(_text("assassin_poison"), "5")


func test_passive_shows_level_and_stat() -> void:
	var t := _text("archer_reflexes")
	assert_string_contains(t, tr("DETAIL_PASSIVE_LEVEL") % 5)
	assert_string_contains(t, "+5 %")


func test_every_class_ability_has_clean_details() -> void:
	for c: String in CLASSES:
		for a: Dictionary in db.class_abilities(c):
			var lines := AbilityDetails.lines(a, _stats(), RESOURCES[c])
			assert_gt(lines.size(), 0, a.id)
			var t := "\n".join(lines)
			for bad: String in ["%s", "%d", "DETAIL_", "  ", "nan", "inf"]:
				assert_false(t.contains(bad), "%s: '%s' in\n%s" % [a.id, bad, t])
			assert_lte(lines.size(), 7, "%s fits the K window box" % a.id)


func test_lines_start_with_a_capital_and_cleanse_is_whole() -> void:
	assert_true(_text("mage_frost_nova").contains("\nCongela 2 s"))
	assert_string_contains(_text("cleric_purify"), "quemadura y marca)")
