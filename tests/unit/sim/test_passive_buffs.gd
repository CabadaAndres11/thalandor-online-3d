extends GutTest
## Conditional passive buffs (Concentración and the like) are announced to the clients so the
## interface can show them while they are on.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _mage() -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = 30
	ClassRules.setup_player(p, "mage", null, f.world)
	return p


func test_focus_turns_on_after_some_seconds_without_being_hurt_and_off_when_hit() -> void:
	var p := _mage()
	p.last_hurt_tick = f.world.tick
	f.run(1.0)
	assert_eq(f.events_of("buff").size(), 0, "not yet")
	f.run(4.0)
	var on := f.events_of("buff").filter(func(ev: Array) -> bool: return ev[2] == "focus" and ev[3] == 1)
	assert_eq(on.size(), 1, "announced once, not every tick")
	p.last_hurt_tick = f.world.tick
	f.run(0.2)
	var off := f.events_of("buff").filter(func(ev: Array) -> bool: return ev[2] == "focus" and ev[3] == 0)
	assert_eq(off.size(), 1)


func test_a_class_without_the_passive_announces_nothing() -> void:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	ClassRules.setup_player(p, "warrior", null, f.world)
	f.run(5.0)
	assert_eq(f.events_of("buff").size(), 0)


func test_every_buff_key_has_a_text() -> void:
	for key: String in Passives.CONDITIONAL:
		assert_ne(tr("STATUS_" + key.to_upper()), "STATUS_" + key.to_upper())
