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
	fx.handle(["area", 20, Vector3(5, 0, 5), 3.0, "mage_fireball", 2, 1.0])
	assert_eq(fx.mark_count(), 1, "burning ground")
	fx.handle(["area", 20, Vector3(5, 0, 5), 3.0, "mage_fireball", 1, 1.0])
	assert_eq(fx.mark_count(), 1, "a pulse of the same area refreshes it")
	fx.handle(["area", 21, Vector3(9, 0, 5), 3.0, "mage_frost_nova", 0, 0.0])
	assert_eq(fx.mark_count(), 2, "ice spikes")
	fx.handle(["area", 22, Vector3(9, 0, 9), 3.0, "warrior_whirlwind", 0, 0.0])
	assert_eq(fx.mark_count(), 2, "no mark for physical areas")
	fx.advance(1.0)
	assert_eq(fx.decor_count(), 1, "the instant area's mark is gone, the one with a pulse left stays")
	fx.advance(0.5)
	assert_eq(fx.decor_count(), 0, "it ends with its last pulse")


func test_a_mark_lasts_only_while_the_area_has_pulses_left() -> void:
	fx.handle(["area", 40, Vector3(5, 0, 5), 3.0, "mage_fireball", 5, 1.0])
	fx.advance(4.0)
	assert_eq(fx.mark_count(), 1)
	assert_eq(fx.decor_count(), 1, "5 more seconds of damage: still burning")
	fx.handle(["area", 40, Vector3(5, 0, 5), 3.0, "mage_fireball", 0, 1.0])
	fx.advance(1.2)
	assert_eq(fx.decor_count(), 0, "the last pulse went off")


func test_ice_block_surrounds_the_caster_for_its_duration() -> void:
	fx.handle(["status", 1, "ice_block", latest_tick + 60])
	assert_gt(fx.decor_count(), 1)
	fx.advance(1.0)
	assert_gt(fx.decor_count(), 0)
	fx.advance(2.5)
	assert_eq(fx.decor_count(), 0, "it goes with the status")


func test_arcane_area_leaves_a_pentagram() -> void:
	fx.handle(["area", 30, Vector3(5, 0, 5), 3.0, "mage_arcane_charge", 1, 1.0])
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


func test_meteor_falls_from_the_sky_and_lands_with_an_explosion() -> void:
	fx.handle(["telegraph", 5, Vector3(8, 0, 8), 5.0, latest_tick + 30, "mage_meteor"])
	assert_eq(fx.decor_count(), 1, "the falling rock")
	fx.advance(0.5)
	assert_eq(fx.decor_count(), 1)
	fx.advance(0.6)
	assert_eq(fx.decor_count(), 0, "it arrived")
	fx.handle(["area", 5, Vector3(8, 0, 8), 5.0, "mage_meteor", 0, 0.0, []])
	assert_gt(fx.decor_count(), 3, "explosion, shockwave, shards and the burning crater")


func test_flame_wall_mark_is_turned_along_the_wall() -> void:
	fx.handle(["area", 6, Vector3(8, 0, 8), 3.0, "mage_flame_pillar", 5, 1.0, [10.0, 2.0, 1.0, 0.0]])
	assert_eq(fx.mark_count(), 1)
	var mark: Node3D = fx.get_children().filter(func(n: Node) -> bool: return n is Node3D and n.get_child_count() > 0 and n.get_child(0) is MeshInstance3D and (n.get_child(0) as MeshInstance3D).mesh.get_surface_count() > 0).front()
	assert_not_null(mark)


func test_big_casts_get_an_ember_ring_around_the_caster() -> void:
	fx.handle(["channel", 1, "mage_meteor", 1.2])
	assert_eq(fx.find_children("*", "CPUParticles3D", false, false).size(), 2, "motes and the ring of embers")
	fx.handle(["channel_end", 1])
	await wait_frames(2)
	assert_eq(fx.find_children("*", "CPUParticles3D", false, false).size(), 0)


func test_fire_models_use_the_reference_palette() -> void:
	var sprite := VoxelFx.flame_sprite(14, 1)
	var colors := {}
	for c: Vector3i in sprite:
		colors[(sprite[c] as Color).to_html()] = true
	for want: Color in [VoxelFx.FLAME_RED, VoxelFx.FLAME_ORANGE, VoxelFx.FLAME_YELLOW, VoxelFx.FLAME_CORE]:
		assert_true(colors.has(want.to_html()), want.to_html())
	assert_gt(VoxelFx.flame_wall(10.0).size(), 100)
	assert_lt(VoxelFx.mesh_of(VoxelFx.flame_wall(10.0), 0.18).surface_get_array_len(0), 60000, "hidden faces are not built")


func test_ice_is_not_a_flat_colour() -> void:
	var colors := {}
	for c: Vector3i in VoxelFx.ice_spike(10):
		colors[(VoxelFx.ice_spike(10)[c] as Color).to_html()] = true
	assert_gt(colors.size(), 6)


func test_a_beam_is_one_glowing_tube_that_turns_and_expires() -> void:
	fx.handle(["beam", 1, Vector3(5, 0, 5), Vector3(5, 0, 20), 1.2])
	assert_eq(fx.beam_count(), 1)
	fx.handle(["beam", 1, Vector3(5, 0, 5), Vector3(20, 0, 5), 1.2])
	assert_eq(fx.beam_count(), 1, "the same caster keeps one beam")
	fx.advance(0.2)
	assert_eq(fx.beam_count(), 1)
	fx.advance(0.3)
	assert_eq(fx.beam_count(), 0, "gone when the pulses stop")


func test_the_beam_glides_to_the_new_end_and_channel_end_removes_it() -> void:
	fx.handle(["beam", 1, Vector3(5, 0, 5), Vector3(5, 0, 20), 1.2])
	var b: Dictionary = fx._beams[1]
	fx.handle(["beam", 1, Vector3(5, 0, 5), Vector3(20, 0, 5), 1.2])
	fx.advance(0.05)
	var mid: Vector3 = fx._beams[1].end
	assert_gt(mid.x, 5.0, "moving toward the new end, not jumping")
	assert_lt(mid.x, 21.0)
	assert_eq(b.ends.size(), 2, "a ball at each end")
	fx.handle(["channel_end", 1])
	assert_eq(fx.beam_count(), 0)


func test_a_repeating_slow_snows_once_not_once_per_pulse() -> void:
	var before := fx.get_child_count()
	fx.handle(["status", 7, "slow", 9999])
	var after_first := fx.get_child_count()
	fx.handle(["status", 7, "slow", 9999])
	fx.handle(["status", 7, "slow", 9999])
	assert_eq(fx.get_child_count(), after_first, "later pulses add nothing")
	assert_gte(after_first, before)


func test_the_trap_is_a_bear_trap_with_jaws_teeth_and_a_chain() -> void:
	var cells := VoxelFx.trap()
	var teeth := 0
	var chain := 0
	for c: Vector3i in cells:
		if c.y >= 2:
			teeth += 1
		if c.z < -5:
			chain += 1
	assert_gt(teeth, 8, "teeth point up from both jaws")
	assert_gt(chain, 3, "a chain runs out of the base")


func test_archer_arrows_and_assassin_knives_are_voxel_models() -> void:
	fx.handle(["projectile", 50, 1, "archer_shot", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	var arrow := (fx.get_child(0) as Node3D).get_child(0) as MeshInstance3D
	assert_gt(arrow.mesh.get_surface_count(), 0, "a voxel arrow")
	fx.handle(["projectile", 51, 1, "assassin_throw_knife", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	var knife := (fx.get_child(1) as Node3D).get_child(0) as MeshInstance3D
	var before := knife.rotation.x
	fx.advance(0.1)
	assert_ne(knife.rotation.x, before, "the knife spins in flight")


func test_arrow_rain_pours_arrows_per_pulse_and_they_stick_then_go() -> void:
	fx.handle(["area", 60, Vector3(8, 0, 8), 3.0, "archer_arrow_rain", 2, 0.5, []])
	assert_gt(fx.decor_count(), 10, "a volley")
	fx.advance(0.5)
	assert_gt(fx.decor_count(), 5, "stuck in the ground for a moment")
	fx.advance(1.5)
	assert_eq(fx.decor_count(), 0)
	await wait_frames(2)
	assert_eq(fx.find_children("*", "MeshInstance3D", false, false).size(), 0, "the nodes are freed too")


func test_areas_leave_no_glowing_disc_under_them() -> void:
	fx.handle(["area", 61, Vector3(8, 0, 8), 3.0, "warrior_whirlwind", 0, 0.0, []])
	assert_eq(fx.find_children("*", "MeshInstance3D", false, false).size(), 0)
	fx.handle(["area", 62, Vector3(8, 0, 8), 3.0, "mage_blizzard", 5, 1.0, []])
	var cylinders := fx.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as MeshInstance3D).mesh is CylinderMesh)
	assert_eq(cylinders.size(), 0, "ice stakes instead of a blue disc (Plan 8.3h)")


func test_an_ice_field_does_not_restart_on_every_pulse() -> void:
	fx.handle(["area", 63, Vector3(8, 0, 8), 4.0, "mage_blizzard", 6, 1.0, []])
	var bursts := fx.find_children("*", "CPUParticles3D", false, false).size()
	var decor := fx.decor_count()
	for i in 4:
		fx.advance(1.0)
		fx.handle(["area", 63, Vector3(8, 0, 8), 4.0, "mage_blizzard", 5 - i, 1.0, []])
	assert_eq(fx.find_children("*", "CPUParticles3D", false, false).size(), bursts, "no new bursts")
	assert_eq(fx.decor_count(), decor, "the same field the whole time")
	assert_eq(fx.mark_count(), 1)


func test_the_blizzard_is_a_fixed_field_with_a_spinning_ice_whirlwind() -> void:
	fx.handle(["area", 64, Vector3(8, 0, 8), 5.0, "mage_blizzard", 7, 1.0, []])
	var entry: Dictionary = fx._marks[64]
	assert_eq(entry.grow, 0.0, "it does not grow up from nothing")
	assert_ne(entry.spin, 0.0, "the whirlwind turns")
	assert_eq((entry.node as Node3D).scale, Vector3.ONE)
	var tornado := VoxelFx.ice_tornado(2.5, 4.0, 0.16)
	assert_gt(tornado.size(), 100)
	var low := 0.0
	var high := 0.0
	for c: Vector3i in tornado:
		var r := Vector2(c.x, c.z).length()
		if c.y < 5:
			low = maxf(low, r)
		elif c.y > 20:
			high = maxf(high, r)
	assert_gt(high, low * 2.0, "narrow at the ground, wide at the top")


func test_a_net_falls_over_a_rooted_target_for_the_root() -> void:
	fx.handle(["status", 1000, "root", latest_tick + 90])
	assert_gt(fx.decor_count(), 0)
	fx.advance(2.0)
	assert_gt(fx.decor_count(), 0, "still on while rooted")
	fx.advance(1.5)
	assert_eq(fx.decor_count(), 0)


func test_a_trap_is_visible_on_the_map_until_it_goes_off() -> void:
	fx.handle(["trap", 7, 1, Vector3(9, 0, 9), 1.5, latest_tick + 30])
	assert_eq(fx.trap_count(), 1)
	fx.advance(5.0)
	assert_eq(fx.trap_count(), 1, "it stays")
	fx.handle(["trap_fired", 7, Vector3(9, 0, 9), 1.5])
	assert_eq(fx.trap_count(), 0)
	assert_gt(fx.decor_count(), 1, "an explosion")
	fx.handle(["trap", 8, 1, Vector3(9, 0, 9), 1.5, latest_tick + 30])
	fx.handle(["trap_end", 8])
	assert_eq(fx.trap_count(), 0)


func test_a_teleport_leaves_a_streak_and_flashes() -> void:
	fx.handle(["blink", 1, Vector3(5, 0, 5), Vector3(14, 0, 5), "mage_blink"])
	assert_gt(fx.decor_count(), 8, "motes along the way and two flashes")
	fx.advance(1.5)
	assert_eq(fx.decor_count(), 0)


# --- Cleric: golden crosses, wings and angels ------------------------------------------

func _holy_at(style: String) -> Variant:
	for h: Dictionary in fx.holy_effects():
		if h.style == style:
			return (h.node as Node3D).position
	return null


func test_smite_flies_as_a_spinning_golden_cross() -> void:
	fx.handle(["projectile", 7, 1, "cleric_smite", Vector3(5, 0, 5), Vector2(1, 0), 20.0, 20.0])
	var cross := fx.projectile_node(7).find_child("HolyCross", true, false) as Node3D
	assert_not_null(cross)
	var r := cross.rotation
	fx.advance(0.05)
	assert_ne(cross.rotation, r, "it turns")


func test_heal_raises_a_cross_over_the_healed_ally() -> void:
	fx.handle(["cast", 1, "cleric_heal", Vector3(8, 0, 5), 1.5])
	fx.handle(["heal", 1000, 40.0])
	var at: Variant = _holy_at("cross")
	assert_not_null(at)
	assert_almost_eq((at as Vector3).x, 8.0, 0.01, "over the ally, not the cleric")
	fx.advance(0.3)
	assert_gt((_holy_at("cross") as Vector3).y, (at as Vector3).y, "it rises")


func test_renew_also_raises_a_cross() -> void:
	fx.handle(["cast", 1, "cleric_renew", Vector3(8, 0, 5), 1.5])
	fx.handle(["status", 1000, "hot", latest_tick + 90])
	assert_not_null(_holy_at("cross"))


func test_shield_wraps_the_target_in_wings() -> void:
	fx.handle(["cast", 1, "cleric_shield", Vector3(8, 0, 5), 10.0])
	fx.handle(["status", 1000, "shield", latest_tick + 120])
	assert_almost_eq((_holy_at("wings") as Vector3).x, 8.0, 0.01)


func test_resurrection_sends_down_an_angel() -> void:
	fx.handle(["cast", 1, "cleric_resurrection", Vector3(8, 0, 5), 60.0])
	fx.handle(["revived", 1000, 1])
	var at: Variant = _holy_at("angel")
	assert_not_null(at)
	fx.advance(0.4)
	assert_lt((_holy_at("angel") as Vector3).y, (at as Vector3).y, "it comes down")


func test_holy_nova_throws_out_a_ring_of_crosses() -> void:
	fx.handle(["cast", 1, "cleric_holy_nova", Vector3(5, 0, 5), 8.0])
	assert_almost_eq((_holy_at("nova") as Vector3).x, 5.0, 0.01, "around the cleric")


func test_purify_without_an_event_falls_back_to_the_aim() -> void:
	fx.handle(["cast", 1, "cleric_purify", Vector3(7, 0, 6), 10.0])
	fx.advance(0.2)
	assert_almost_eq((_holy_at("column") as Vector3).x, 7.0, 0.01)


func test_divine_hymn_gives_the_cleric_wings_and_a_halo() -> void:
	fx.handle(["cast", 1, "cleric_divine_hymn", Vector3(5, 0, 5), 60.0])
	assert_not_null(_holy_at("hymn"))


func test_crusader_strike_flashes_a_cross_on_the_blow() -> void:
	fx.handle(["cast", 1, "cleric_crusader_strike", Vector3(8, 0, 5), 4.0])
	assert_not_null(_holy_at("strike"))


func test_holy_areas_draw_a_circle_with_a_cross() -> void:
	fx.handle(["area", 31, Vector3(6, 0, 6), 4.0, "cleric_consecration", 5, 1.0])
	assert_eq(fx.mark_count(), 1)


func test_holy_effects_fade_away() -> void:
	fx.handle(["cast", 1, "cleric_holy_nova", Vector3(5, 0, 5), 8.0])
	fx.advance(5.0)
	assert_eq(fx.holy_effects().size(), 0)


func test_holy_voxel_models_have_cubes() -> void:
	for cells: Dictionary in [VoxelFx.holy_cross(), VoxelFx.angel_wings(), VoxelFx.halo(6), VoxelFx.angel(), VoxelFx.holy_circle(3.0)]:
		assert_gt(cells.size(), 20)


func test_a_purify_is_never_drawn_on_someone_else_healed() -> void:
	positions[2] = Vector3(12, 0, 5)
	fx.handle(["cast", 1, "cleric_purify", Vector3(7, 0, 6), 10.0])
	fx.handle(["heal", 2, 30.0]) # someone else's potion in the same moment
	assert_almost_eq((_holy_at("column") as Vector3).x, 7.0, 0.01, "at the aim")


func test_two_clerics_each_get_their_own_target() -> void:
	positions[2] = Vector3(12, 0, 5)
	positions[3] = Vector3(15, 0, 5)
	fx.handle(["cast", 1, "cleric_shield", Vector3(12, 0, 5), 10.0])
	fx.handle(["cast", 3, "cleric_heal", Vector3(8, 0, 5), 1.5])
	fx.handle(["heal", 1000, 40.0]) # the heal belongs to the last cast
	assert_almost_eq((_holy_at("cross") as Vector3).x, 8.0, 0.01, "the cross on the healed ally")


func test_a_pending_cast_does_not_wait_for_later_frames() -> void:
	fx.handle(["cast", 1, "cleric_heal", Vector3(8, 0, 5), 1.5])
	fx.advance(0.016) # its own heal never came in that batch
	fx.handle(["heal", 1, 5.0]) # a later, unrelated heal
	assert_almost_eq((_holy_at("cross") as Vector3).x, 8.0, 0.01, "shown at the aim, not on the later heal")


func test_hymn_wings_last_the_song_and_go_when_it_is_cut() -> void:
	fx.handle(["cast", 1, "cleric_divine_hymn", Vector3(5, 0, 5), 60.0])
	fx.advance(4.0)
	assert_not_null(_holy_at("hymn"), "still singing")
	assert_gt((_holy_at("hymn") as Vector3).y, 1.5, "above the floating cleric")
	fx.handle(["channel_end", 1])
	fx.advance(0.5)
	assert_null(_holy_at("hymn"), "the song was cut")


func _holy_area_pulse(t_s: float) -> void:
	fx.handle(["area", 31, Vector3(6, 0, 6), 5.0, "cleric_healing_circle", 5, 1.0])
	fx.advance(t_s)


func test_holy_area_does_not_pulse() -> void:
	_holy_area_pulse(0.6)
	var mark: Node3D = fx.mark_node(31)
	assert_almost_eq(mark.scale.x, 1.0, 0.01, "fully grown")
	fx.handle(["area", 31, Vector3(6, 0, 6), 5.0, "cleric_healing_circle", 4, 1.0]) # the next pulse
	fx.advance(0.05)
	assert_almost_eq(mark.scale.x, 1.0, 0.01, "it does not shrink and grow again")


func test_holy_area_has_a_choir_of_angels() -> void:
	_holy_area_pulse(0.3)
	var mark: Node3D = fx.mark_node(31)
	assert_eq(mark.find_children("Angel*", "", true, false).size(), 6)
	assert_not_null(mark.find_child("Motes", true, false))
	assert_not_null(mark.find_child("Beam", true, false))


func test_consecration_adds_golden_flames() -> void:
	fx.handle(["area", 32, Vector3(6, 0, 6), 5.0, "cleric_consecration", 8, 1.0])
	assert_not_null(fx.mark_node(32).find_child("HolyFlames", true, false))
	fx.handle(["area", 33, Vector3(16, 0, 6), 5.0, "cleric_healing_circle", 5, 1.0])
	assert_null(fx.mark_node(33).find_child("HolyFlames", true, false))


func test_frost_areas_raise_ice_stakes_not_a_whirlwind() -> void:
	fx.handle(["area", 70, Vector3(8, 0, 8), 2.5, "mage_glacial_burst", 0, 0.0, []])
	var mark := fx.mark_node(70)
	assert_not_null(mark)
	assert_gt(mark.find_children("*", "MeshInstance3D", true, false).size(), 5, "a field of stakes")
	assert_eq(mark.find_children("*", "CPUParticles3D", true, false).size(), 0, "no blizzard snow")


func test_frost_nova_looks_like_frost() -> void:
	assert_eq(CombatFX.fx_element(AbilityDB.load_default().get_ability("mage_frost_nova")), "frost")


func test_fireball_and_arcane_orb_fly_bigger() -> void:
	fx.handle(["projectile", 80, 1, "mage_fireball", Vector3(2, 0, 2), Vector2(1, 0), 16.0, 22.0])
	fx.handle(["projectile", 81, 1, "mage_arcane_orb", Vector3(2, 0, 2), Vector2(1, 0), 16.0, 22.0])
	fx.handle(["projectile", 82, 1, "mage_missile", Vector3(2, 0, 2), Vector2(1, 0), 16.0, 22.0])
	assert_gt(fx.projectile_node(80).scale.x, 2.0)
	assert_gt(fx.projectile_node(81).scale.x, 2.0)
	assert_eq(fx.projectile_node(82).scale.x, 1.0)


func test_ice_shard_flies_and_arcane_bolt_skims_the_ground() -> void:
	fx.handle(["projectile", 83, 1, "mage_ice_shard", Vector3(2, 0, 2), Vector2(1, 0), 22.0, 22.0])
	fx.handle(["projectile", 84, 1, "mage_arcane_bolt", Vector3(2, 0, 2), Vector2(1, 0), 20.0, 22.0])
	assert_gt(fx.projectile_node(83).get_child_count(), 1, "a flying crystal, not just mist")
	fx.advance(0.3)
	assert_eq(fx.decor_count(), 0, "no spikes along the ice shard's path")
	assert_lt(fx.projectile_node(84).position.y, 0.5, "along the floor")


func test_ice_comet_falls_from_the_sky_onto_the_cursor() -> void:
	fx.handle(["telegraph", 85, Vector3(8, 0, 8), 2.5, 100000, "mage_ice_comet"])
	assert_eq(fx.decor_count(), 1, "the falling comet")
	fx.handle(["area", 85, Vector3(8, 0, 8), 2.5, "mage_ice_comet", 0, 0.0, []])
	assert_gt(fx.decor_count(), 3, "it shatters into stakes")


func test_meteor_is_as_big_as_its_area() -> void:
	fx.handle(["telegraph", 86, Vector3(8, 0, 8), 5.0, 100000, "mage_meteor"])
	var rocks := fx.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as Node3D).scale.x > 5.0)
	assert_eq(rocks.size(), 1)


func test_fire_lance_is_long() -> void:
	fx.handle(["projectile", 87, 1, "mage_fire_lance", Vector3(2, 0, 2), Vector2(1, 0), 34.0, 22.0])
	var n := fx.projectile_node(87)
	assert_gt(n.scale.z, n.scale.x * 2.0)


func test_own_laser_follows_the_cursor_between_pulses() -> void:
	fx.local_id = 1
	var aim := [Vector3(5, 0, 15)] # lambdas capture by value: a box
	fx.local_aim = func() -> Variant: return aim[0]
	fx.handle(["beam", 1, Vector3(5, 0, 5), Vector3(5, 0, 15), 1.2])
	fx.advance(0.05)
	aim[0] = Vector3(15, 0, 5) # the mouse moved to the side, no new pulse yet
	fx.advance(0.05)
	var far := fx.beam_end(1)
	assert_gt(far.x, 12.0, "the beam is already there")
