extends GutTest
## The ability a player is seen casting: their upgrade's evolution and their weapon decide
## the animation (the templar's smite is a melee swing).


func test_templar_smite_is_melee() -> void:
	var ab := GameSession.seen_ability("cleric_smite", "templar", "")
	assert_eq(str(ab.anim), "melee")


func test_plain_cleric_smite_is_cast() -> void:
	assert_eq(str(GameSession.seen_ability("cleric_smite", "", "").anim), "cast")


func test_weapon_family_still_applies() -> void:
	var db := ItemDB.load_default()
	var heavy := ""
	for id: String in db.base_ids():
		if str(db.family_of(id).get("melee_anim", "")) == "heavy":
			heavy = id
			break
	assert_ne(heavy, "")
	assert_eq(str(GameSession.seen_ability("cleric_smite", "templar", heavy).anim), "heavy")
