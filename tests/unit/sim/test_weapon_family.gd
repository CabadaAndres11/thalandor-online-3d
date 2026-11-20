extends GutTest
## Weapon families change the basic attack (reach, arc, speed, damage, animation); the
## other abilities stay the same.

var db: ItemDB
var abilities: AbilityDB


func before_each() -> void:
	db = ItemDB.load_default()
	abilities = AbilityDB.load_default()


func _fam(id: String) -> Dictionary:
	var f: Dictionary = (db.weapons().families as Dictionary)[id].duplicate()
	f["id"] = id
	return f


func test_heavy_basic() -> void:
	var slash := abilities.get_ability("warrior_slash")
	var a := WeaponFamily.adjust(slash, _fam("heavy"))
	assert_almost_eq(float(a.cooldown_s), 0.45 * 1.25, 0.0001)
	assert_almost_eq(float(a.range), 3.0, 0.0001)
	assert_eq(a.anim, "heavy")
	var arc: Dictionary = a.effects[0]
	assert_almost_eq(float(arc.range), 3.0, 0.0001)
	assert_eq(int(arc.angle_deg), 150)
	assert_almost_eq(float(arc.damage.base), 7.5 * 1.34, 0.0001)
	assert_almost_eq(float(arc.damage.coef), 0.45 * 1.34, 0.0001)


func test_polearm_thrust() -> void:
	var a := WeaponFamily.adjust(abilities.get_ability("warrior_slash"), _fam("polearm"))
	assert_eq(a.anim, "thrust")
	assert_almost_eq(float(a.range), 4.0, 0.0001)
	assert_eq(int(a.effects[0].angle_deg), 50)


func test_wand_projectile() -> void:
	var a := WeaponFamily.adjust(abilities.get_ability("mage_missile"), _fam("wand"))
	var pr: Dictionary = a.effects[0]
	assert_eq(int(pr.speed), 30)
	assert_eq(int(pr.range), 14)
	assert_almost_eq(float(a.range), 14.0, 0.0001)
	assert_almost_eq(float(a.cooldown_s), 0.7 * 0.75, 0.0001)


func test_crossbow_auto_charge() -> void:
	var a := WeaponFamily.adjust(abilities.get_ability("archer_shot"), _fam("crossbow"))
	assert_true(bool(a.get("auto_charge", false)))
	assert_almost_eq(float(a.cooldown_s), 0.6 * 2.0, 0.0001)
	assert_true(a.has("charge"), "it still fires the charged shot")


func test_other_abilities_untouched() -> void:
	var brutal := abilities.get_ability("warrior_brutal")
	assert_eq(WeaponFamily.adjust(brutal, _fam("heavy")), brutal)


func test_original_not_mutated() -> void:
	var slash := abilities.get_ability("warrior_slash")
	var before := slash.duplicate(true)
	WeaponFamily.adjust(slash, _fam("heavy"))
	assert_eq(slash, before)


func test_empty_family_is_identity() -> void:
	var slash := abilities.get_ability("warrior_slash")
	assert_eq(WeaponFamily.adjust(slash, {}), slash)


func test_cast_uses_the_family() -> void:
	var f := CombatFixture.new()
	f.world.abilities = abilities
	var p := f.world.add_player(1, Vector3(5, 0, 5))
	ClassRules.setup_player(p, "warrior", null, f.world)
	p.inventory.equipment["main"] = ItemRoll.new_item("greatsword_t1", 1)
	assert_true(Combat.try_cast(f.world, p, "warrior_slash", Vector3(6, 0, 5)))
	assert_eq(int(p.cooldowns.warrior_slash), f.world.tick + f.world.ticks(0.45 * 1.25))
