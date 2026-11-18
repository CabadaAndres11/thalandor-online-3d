extends GutTest
## The assassin's new kit: a thrown knife, Desgarro (bleed) and Aluvión (4 quick hits);
## Evasión is gone.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))
	f.world.abilities = AbilityDB.load_default()


func _db() -> AbilityDB:
	return AbilityDB.load_default()


func _hero() -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	ClassRules.setup_player(p, "assassin", null, f.world)
	p.level = 50 # may cast everything; stats stay those of level 1
	p.stats.crit_chance = 0.0
	p.resource = 100.0
	p.resource_def["regen_per_s"] = 0.0
	return p


func _dummy(pos: Vector3) -> CombatEntity:
	var d := f.dummy(2000, pos, 5000.0)
	d.stats.dodge_chance = 0.0
	return d


func test_kit_has_nine_usable_and_levels() -> void:
	var all := _db().class_abilities("assassin").filter(func(a: Dictionary) -> bool: return not a.has("upgrade"))
	var usable := all.filter(func(a: Dictionary) -> bool: return a.get("kind") != "passive")
	assert_eq(usable.size(), 9)
	assert_eq(_db().actives("assassin").map(func(id: String) -> int: return int(_db().get_ability(id).level)),
		[1, 3, 6, 10, 15, 20, 30])
	assert_eq(_db().actives("assassin"), ["assassin_shadowstep", "assassin_throw_knife", "assassin_stealth",
		"assassin_blade_fan", "assassin_poison", "assassin_rend", "assassin_flurry"])
	assert_eq(all.filter(func(a: Dictionary) -> bool: return a.get("kind") == "passive").size(), 4)


func test_throw_knife_slows_and_gives_combo() -> void:
	var p := _hero()
	var start := f.world.tick
	var t := _dummy(Vector3(10, 0, 15))
	assert_true(Combat.try_cast(f.world, p, "assassin_throw_knife", t.position))
	f.run(1.0)
	assert_almost_eq(5000.0 - t.hp, 10.0 + 0.8 * 20.0, 0.01)
	assert_almost_eq(t.status_magnitude("slow"), 0.4, 0.001)
	assert_eq(p.combo, 1)
	assert_eq(p.resource, 80.0)
	assert_eq(p.cooldowns["assassin_throw_knife"], start + f.world.ticks(6.0), "6 s of cooldown")


func test_throw_knife_reaches_12_m_and_no_further() -> void:
	var p := _hero()
	var far := _dummy(Vector3(10, 0, 26))
	assert_true(Combat.try_cast(f.world, p, "assassin_throw_knife", far.position))
	f.run(1.5)
	assert_eq(far.hp, 5000.0)


func test_rend_bleeds() -> void:
	var p := _hero()
	var t := _dummy(Vector3(10, 0, 11.2))
	assert_true(Combat.try_cast(f.world, p, "assassin_rend", t.position))
	assert_almost_eq(5000.0 - t.hp, 14.0 + 1.2 * 20.0, 0.01)
	assert_true(t.has_status("bleed"))
	assert_almost_eq(t.status_magnitude("bleed"), 0.3 * 20.0, 0.001)
	f.run(6.5)
	assert_almost_eq(5000.0 - t.hp, 14.0 + 1.2 * 20.0 + 5.0 * 6.0, 0.5, "five ticks of 6 (the sixth coincides with the end)")
	assert_false(t.has_status("bleed"))
	assert_eq(p.combo, 2)
	assert_eq(p.resource, 70.0)


func test_bleed_is_negative_and_visible() -> void:
	assert_has(StatusEffect.NEGATIVE, "bleed")
	assert_has(StatusEffect.BIT_KINDS, "bleed")
	assert_lte(StatusEffect.BIT_KINDS.size(), 32)


func test_flurry_hits_four_times_two_combo() -> void:
	var p := _hero()
	var t := _dummy(Vector3(10, 0, 11.2))
	assert_true(Combat.try_cast(f.world, p, "assassin_flurry", t.position))
	f.run(1.0)
	assert_almost_eq(5000.0 - t.hp, 4.0 * (6.0 + 0.5 * 20.0), 0.01)
	assert_eq(p.combo, 2, "two in all, not two per hit")
	assert_eq(p.resource, 60.0)


func test_saved_bar_with_evasion_sanitized() -> void:
	assert_eq(_db().sanitize_bar("assassin", ["assassin_evasion", "assassin_shadowstep", "", "", "", "", "", "", ""], 50),
		["", "assassin_shadowstep", "", "", "", "", "", "", ""])
	assert_false(_db().has("assassin_evasion"))


func test_no_text_keys_left_for_evasion() -> void:
	var csv := FileAccess.get_file_as_string("res://data/texts/textos.csv")
	assert_false(csv.contains("AB_ASSASSIN_EVASION,"))
	assert_false(csv.contains("AB_ASSASSIN_EVASION_DESC,"))
	assert_false(FileAccess.file_exists("res://assets/icons/evasion.png"))
	for id: String in ["assassin_throw_knife", "assassin_rend", "assassin_flurry"]:
		var a := _db().get_ability(id)
		assert_ne(tr(str(a.name)), str(a.name), id + " name")
		assert_ne(tr(str(a.desc)), str(a.desc), id + " desc")
		assert_true(ResourceLoader.exists(CombatHud.ICON_DIR % a.icon), id + " icon")
