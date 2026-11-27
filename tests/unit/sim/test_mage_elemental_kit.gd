extends GutTest
## Plan 8.3h: with an upgrade, the mage's base kit is cast in its element (variants as data).

var f: CombatFixture
var db: AbilityDB


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	db = AbilityDB.load_default()
	f.world.abilities = db
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String) -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "mage", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	return p


func _foe(id: int, pos: Vector3) -> CombatEntity:
	var d := f.dummy(id, pos, 50000.0)
	d.stats.dodge_chance = 0.0
	return d


func _element(ab: Dictionary) -> String:
	return CombatFX.element_of(ab.get("effects", []))


func test_each_upgrade_resolves_its_variants() -> void:
	var expect := {
		"pyromancer": {"mage_missile": "mage_fire_bolt", "mage_blast": "mage_eruption", "mage_blink": "mage_flame_step",
			"mage_frost_nova": "mage_fire_nova", "mage_mana_barrier": "mage_flame_shield", "mage_fireball": "mage_fireball",
			"mage_frostbolt": "mage_fire_lance"},
		"cryomancer": {"mage_missile": "mage_ice_shard", "mage_blast": "mage_glacial_burst", "mage_blink": "mage_frost_step",
			"mage_frost_nova": "mage_frost_nova", "mage_mana_barrier": "mage_ice_armor", "mage_fireball": "mage_ice_comet",
			"mage_frostbolt": "mage_frostbolt"},
		"arcanist": {"mage_missile": "mage_missile", "mage_blast": "mage_blast", "mage_blink": "mage_blink",
			"mage_frost_nova": "mage_arcane_nova", "mage_mana_barrier": "mage_mana_barrier", "mage_fireball": "mage_arcane_orb",
			"mage_frostbolt": "mage_arcane_bolt"},
	}
	for up: String in expect:
		for base: String in expect[up]:
			assert_eq(str(db.resolved(base, up).id), expect[up][base], "%s %s" % [up, base])
	assert_eq(str(db.resolved("mage_missile", "").id), "mage_missile", "no upgrade: the base")


func test_variants_keep_the_base_numbers_and_change_the_element() -> void:
	for pair: Array in [["mage_missile", "pyromancer", "fire"], ["mage_missile", "cryomancer", "frost"],
			["mage_blast", "pyromancer", "fire"], ["mage_frostbolt", "pyromancer", "fire"], ["mage_fireball", "cryomancer", "frost"]]:
		var base := db.get_ability(pair[0])
		var v := db.variant_for(pair[0], pair[1])
		assert_eq([v.cost, v.cooldown_s, v.level, v.kind], [base.cost, base.cooldown_s, base.level, base.kind], v.id)
		assert_eq(_element(v), pair[2], v.id)


func test_variants_are_not_listed_on_their_own() -> void:
	var ids := db.actives("mage", "pyromancer")
	assert_false("mage_fire_nova" in ids)
	assert_true("mage_frost_nova" in ids, "the bar keeps the base id")
	assert_eq(db.kind_of("mage", "basic"), "mage_missile")
	var bar := db.default_bar("mage", 50, "pyromancer")
	assert_true("mage_frost_nova" in bar, "the base id stays in its slot")
	assert_false("mage_fire_nova" in bar)


func test_the_bar_casts_the_variant_and_keeps_the_base_cooldown() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(10, 0, 20))
	assert_true(Combat.try_cast(f.world, p, "mage_missile", foe.position))
	assert_eq(f.world.projectiles.size(), 1)
	assert_eq(f.world.projectiles[0].ability_id, "mage_fire_bolt", "the fire bolt flies (its look follows it)")
	assert_true(p.cooldowns.has("mage_missile"))


func test_fire_nova_stuns_and_arcane_nova_roots() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(12, 0, 10))
	assert_true(Combat.try_cast(f.world, p, "mage_frost_nova", p.position))
	assert_true(foe.has_status("stun"))
	assert_false(foe.has_status("freeze"))
	f.world.players.clear()
	var q := _hero("arcanist")
	var foe2 := _foe(2001, Vector3(12, 0, 10))
	assert_true(Combat.try_cast(f.world, q, "mage_frost_nova", q.position))
	assert_true(foe2.has_status("root"))
	assert_false(foe2.has_status("freeze"))


func test_fire_lance_burns_instead_of_slowing() -> void:
	var v := db.variant_for("mage_frostbolt", "pyromancer")
	var kinds: Array = (v.effects[0].statuses as Array).map(func(s: Dictionary) -> String: return s.kind)
	assert_eq(kinds, ["burn"])


func test_flame_shield_burns_melee_attackers() -> void:
	var p := _hero("pyromancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	assert_true(Combat.try_cast(f.world, p, "mage_mana_barrier", p.position))
	assert_gt(p.shield, 0.0)
	Combat.deal(f.world, foe, p, {"type": "melee_arc", "damage": {"base": 5, "coef": 0, "kind": "physical", "can_crit": false}}, {})
	assert_true(foe.has_status("burn"), "hit in melee: it burns")
	var archer := _foe(2001, Vector3(20, 0, 10))
	Combat.deal(f.world, archer, p, {"type": "projectile", "damage": {"base": 5, "coef": 0, "kind": "physical", "can_crit": false}}, {})
	assert_false(archer.has_status("burn"), "only melee hits")


func test_ice_armor_slows_melee_attackers() -> void:
	var p := _hero("cryomancer")
	var foe := _foe(2000, Vector3(11, 0, 10))
	assert_true(Combat.try_cast(f.world, p, "mage_mana_barrier", p.position))
	Combat.deal(f.world, foe, p, {"type": "melee_arc", "damage": {"base": 5, "coef": 0, "kind": "physical", "can_crit": false}}, {})
	assert_true(foe.has_status("slow"))


func test_ice_comet_slows_on_explosion() -> void:
	var v := db.variant_for("mage_fireball", "cryomancer")
	assert_eq(str(v.effects[0].explode.statuses[0].kind), "slow")


func test_piercing_cold_counts_the_upgrades_control() -> void:
	var expect := {"pyromancer": ["burn"], "cryomancer": ["freeze", "slow"], "arcanist": ["root"]}
	for up: String in expect:
		f.world.players.clear()
		var p := _hero(up)
		var found: Array = []
		for h: Dictionary in Passives.hooks(p, "bonus_vs_status"):
			if is_equal_approx(float(h.pct), 0.2): # Frío penetrante (Combustión is +10 %)
				found.append_array(h.statuses)
		assert_eq(found, expect[up], up)


func test_ignition_burns_with_the_fire_bolt() -> void:
	var p := _hero("pyromancer")
	p.stats.crit_chance = 1.0
	var foe := _foe(2000, Vector3(10, 0, 12))
	assert_true(Combat.try_cast(f.world, p, "mage_missile", foe.position))
	f.run(1.0)
	assert_true(foe.has_status("burn"), "a fire crit leaves a burn (Ignición)")


func test_variants_validate() -> void:
	assert_eq(db.validate(), [] as Array[String])
	var bad := AbilityDB.from_list([
		{"id": "a", "class": "mage", "kind": "basic", "name": "x", "desc": "x", "effects": [{"type": "beam"}]},
		{"id": "b", "class": "mage", "upgrade": "w", "replaces": "a", "kind": "active", "name": "x", "desc": "x", "effects": [{"type": "beam"}]},
		{"id": "c", "class": "mage", "upgrade": "u", "replaces": "a", "kind": "basic", "name": "x", "desc": "x", "effects": [{"type": "beam"}]},
		{"id": "d", "class": "mage", "upgrade": "u", "replaces": "a", "kind": "basic", "name": "x", "desc": "x", "effects": [{"type": "beam"}]},
	])
	var errors := bad.validate(false)
	assert_eq(errors.size(), 2, str(errors))
