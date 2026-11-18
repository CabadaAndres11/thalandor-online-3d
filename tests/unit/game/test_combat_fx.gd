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


func test_line_telegraph_fills_along_the_line_and_goes_with_the_charge() -> void:
	fx.handle(["telegraph_line", 4, Vector3(5, 0, 5), Vector3(5, 0, 13), 1.4, latest_tick + 24])
	assert_eq(fx.telegraph_count(), 1)
	assert_almost_eq(fx.telegraph_length(4), 8.0, 0.01)
	fx.advance(0.4)
	assert_between(fx.telegraph_fill(4), 0.3, 0.9, "filling along the line")
	fx.handle(["charge", 4, 1000, Vector3(5, 0, 5), Vector3(5, 0, 13)])
	assert_eq(fx.telegraph_count(), 0, "the charge replaces the warning")
	fx.handle(["telegraph_line", 5, Vector3(5, 0, 5), Vector3(13, 0, 5), 1.4, latest_tick + 24])
	fx.handle(["charge_cancel", 5])
	assert_eq(fx.telegraph_count(), 0, "a cancelled charge clears its warning")


func test_level_up_shows_a_number_and_a_flash() -> void:
	var numbers := fx.floating_labels().size()
	fx.handle(["level_up", 1, 6])
	assert_eq(fx.floating_labels().size(), numbers + 1)
	assert_eq((fx.floating_labels()[numbers] as Label3D).text, tr("FX_LEVEL_UP") % 6)
	fx.advance(2.0)
	assert_eq(fx.floating_labels().size(), numbers, "it fades away")


func test_magic_colours_follow_the_element() -> void:
	assert_eq(CombatFX.element_of(AbilityDB.load_default().get_ability("mage_fireball").effects), "fire")
	assert_eq(CombatFX.element_of(AbilityDB.load_default().get_ability("mage_frostbolt").effects), "frost")
	assert_eq(CombatFX.element_of([]), "")


func test_magic_projectile_glows_with_a_light() -> void:
	fx.handle(["projectile", 8, 1, "mage_fireball", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	var node := fx.get_child(0) as Node3D
	assert_not_null(node.find_children("*", "OmniLight3D", true, false).front() if not node.find_children("*", "OmniLight3D", true, false).is_empty() else null)


func test_cast_time_shows_a_charge_until_it_ends() -> void:
	fx.handle(["channel", 1, "mage_fireball", 1.2])
	assert_eq(fx.charge_count(), 1)
	fx.advance(0.5)
	assert_eq(fx.charge_count(), 1)
	fx.handle(["channel_end", 1])
	assert_eq(fx.charge_count(), 0)
	fx.handle(["channel", 1, "mage_fireball", 0.3])
	fx.advance(0.4)
	assert_eq(fx.charge_count(), 0, "it ends by itself")


func test_magic_area_bursts_with_motes() -> void:
	fx.handle(["area", 3, Vector3(5, 0, 5), 3.0, "mage_fireball"])
	var parts := fx.find_children("*", "CPUParticles3D", true, false)
	assert_eq(parts.size(), 1)


func test_arcane_projectile_is_a_voxel_prism_with_a_light() -> void:
	fx.handle(["projectile", 9, 1, "mage_missile", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	var node := fx.get_child(0) as Node3D
	var body := node.get_child(0) as MeshInstance3D
	assert_gt(body.mesh.get_surface_count(), 0, "voxel mesh")
	assert_eq(CombatFX.fx_element(AbilityDB.load_default().get_ability("mage_missile")), "arcane")
	assert_false(node.find_children("*", "OmniLight3D", true, false).is_empty())


func test_magic_projectile_explodes_when_it_ends() -> void:
	fx.handle(["projectile", 10, 1, "mage_fireball", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	fx.handle(["projectile_end", 10, Vector3(9, 0, 5)])
	assert_eq(fx.projectile_count(), 0)
	assert_gt(fx.decor_count(), 1, "flash and shards")
	fx.advance(1.5)
	assert_eq(fx.decor_count(), 0, "they clean up after themselves")


func test_frost_leaves_spikes_that_grow_along_its_line_and_end_in_a_finale() -> void:
	fx.handle(["projectile", 11, 1, "mage_frostbolt", Vector3(5, 0, 5), Vector2(1, 0), 10.0, 10.0])
	fx.advance(0.5) # 5 m flown
	var early := fx.decor_count()
	assert_gt(early, 4, "spikes come out of the ground along the line")
	fx.advance(0.4)
	assert_gt(fx.decor_count(), early)
	var before := fx.decor_count()
	fx.handle(["projectile_end", 11, Vector3(14, 0, 5)])
	assert_gt(fx.decor_count(), before + 8, "the big finale")
	fx.advance(3.0)
	assert_eq(fx.decor_count(), 0)


func test_frozen_target_gets_snow_and_an_ice_shell() -> void:
	fx.handle(["status", 1000, "freeze", latest_tick + 60])
	assert_gt(fx.decor_count(), 1, "snow and the shell")
	fx.advance(3.0)
	assert_eq(fx.decor_count(), 0, "the shell lasts as long as the freeze")


func test_ground_marks_by_element() -> void:
	fx.handle(["area", 20, Vector3(5, 0, 5), 3.0, "mage_fireball"])
	assert_eq(fx.mark_count(), 1, "burning ground")
	fx.handle(["area", 20, Vector3(5, 0, 5), 3.0, "mage_fireball"])
	assert_eq(fx.mark_count(), 1, "a pulse of the same area refreshes it")
	fx.handle(["area", 21, Vector3(9, 0, 5), 3.0, "mage_frost_nova"])
	assert_eq(fx.mark_count(), 2, "ice spikes")
	fx.handle(["area", 22, Vector3(9, 0, 9), 3.0, "warrior_whirlwind"])
	assert_eq(fx.mark_count(), 2, "no mark for physical areas")
	fx.advance(CombatFX.MARK_LIFE + 0.5)
	assert_eq(fx.mark_count(), 2)
	assert_eq(fx.decor_count(), 0, "all gone")


func test_arcane_area_leaves_a_pentagram() -> void:
	fx.handle(["area", 30, Vector3(5, 0, 5), 3.0, "mage_arcane_charge"])
	assert_eq(fx.mark_count(), 1)


func test_cast_orb_forms_and_gets_brighter() -> void:
	fx.handle(["cast", 1, "mage_fireball", Vector3(9, 0, 5), 8.0])
	fx.handle(["channel", 1, "mage_fireball", 1.0])
	var small := fx.charge_orb_scale(1)
	fx.advance(0.8)
	assert_gt(fx.charge_orb_scale(1), small, "it grows while the cast goes on")
	fx.handle(["channel_end", 1])
	assert_eq(fx.charge_orb_scale(1), 0.0)


func test_voxel_models_have_cubes() -> void:
	for cells: Dictionary in [VoxelFx.arcane_prism(), VoxelFx.fire_orb(), VoxelFx.ice_crystal(), VoxelFx.ice_spike(8),
			VoxelFx.flame_patch(3.0), VoxelFx.pentagram(3.0), VoxelFx.orb(Color.GREEN)]:
		assert_gt(cells.size(), 5)
		assert_gt(VoxelFx.mesh_of(cells).get_surface_count(), 0)
	assert_lt(VoxelFx.pentagram(3.0).size(), 1500, "a ground mark stays light")
