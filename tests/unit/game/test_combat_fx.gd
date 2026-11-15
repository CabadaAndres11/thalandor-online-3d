extends GutTest

var fx: CombatFX
var positions: Dictionary = {}
var latest_tick := 100


func before_each() -> void:
	positions = {1: Vector3(5, 0, 5), 1000: Vector3(8, 0, 5)}
	fx = CombatFX.new()
	add_child_autofree(fx)
	fx.setup(_position_of, _tick_now, AbilityDB.load_default(), 30)
	fx.set_process(false) # the tests advance time by hand (test frames are long)


func _position_of(id: int) -> Variant:
	return positions.get(id)


func _tick_now() -> int:
	return latest_tick


func test_fx_projectile_removed_on_end() -> void:
	fx.handle(["projectile", 7, 1, "mage_missile", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	assert_eq(fx.projectile_count(), 1)
	fx.advance(0.05)
	assert_gt(fx.projectile_position(7).x, 5.0, "it moves on its own")
	fx.handle(["projectile_end", 7, Vector3(8, 0, 5)])
	assert_eq(fx.projectile_count(), 0)


func test_projectile_visual_expires_after_its_range() -> void:
	fx.handle(["projectile", 8, 1, "mage_missile", Vector3(5, 0, 5), Vector2(1, 0), 40.0, 2.0])
	fx.advance(0.2)
	assert_eq(fx.projectile_count(), 0, "even if the end event is lost")


func test_telegraph_fills_and_frees() -> void:
	fx.handle(["telegraph", 3, Vector3(8, 0, 8), 2.0, latest_tick + 15])
	assert_eq(fx.telegraph_count(), 1)
	fx.advance(0.25)
	assert_between(fx.telegraph_fill(3), 0.2, 0.9, "filling up")
	fx.advance(0.4)
	assert_eq(fx.telegraph_count(), 0, "gone after the impact time")


func test_damage_number_colors() -> void:
	fx.handle(["hit", 1000, 12.4, false, 1])
	fx.handle(["hit", 1000, 30.0, true, 1])
	fx.handle(["heal", 1, 20.0])
	fx.handle(["dodge", 1000])
	var labels := fx.floating_labels()
	assert_eq(labels.size(), 4)
	assert_eq(labels[0].text, "12")
	assert_eq(labels[0].modulate, CombatFX.COLOR_HIT)
	assert_eq(labels[1].modulate, CombatFX.COLOR_CRIT)
	assert_gt(labels[1].font_size, labels[0].font_size, "crits are bigger")
	assert_eq(labels[2].text, "+20")
	assert_eq(labels[2].modulate, CombatFX.COLOR_HEAL)
	assert_eq(labels[3].text, tr("FX_DODGE"))
	assert_eq(labels[3].modulate, CombatFX.COLOR_DODGE)


func test_floating_numbers_rise_and_free() -> void:
	fx.handle(["hit", 1000, 10.0, false, 1])
	var label: Label3D = fx.floating_labels()[0]
	var y := label.position.y
	fx.advance(0.3)
	assert_gt(label.position.y, y)
	fx.advance(0.8)
	assert_eq(fx.floating_labels().size(), 0)


func test_events_for_unknown_entities_are_ignored() -> void:
	fx.handle(["hit", 4242, 10.0, false, 1])
	fx.handle(["status", 4242, "shield", latest_tick + 30])
	fx.handle(["bogus_event", 1])
	fx.handle([])
	assert_eq(fx.floating_labels().size(), 0)


func test_shield_bubble_follows_and_expires() -> void:
	fx.handle(["status", 1, "shield", latest_tick + 9])
	assert_eq(fx.shield_count(), 1)
	fx.advance(0.45)
	assert_eq(fx.shield_count(), 0)


func test_overhead_bar_hidden_when_full_out_of_combat() -> void:
	var bar := OverheadBar.new()
	add_child_autofree(bar)
	bar.setup("Lobo", true)
	bar.set_health(60.0, 60.0)
	assert_false(bar.bar_visible(), "full health, out of combat")
	bar.set_health(30.0, 60.0)
	assert_true(bar.bar_visible())
	assert_almost_eq(bar.fraction(), 0.5, 0.001)
