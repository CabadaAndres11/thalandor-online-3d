extends GutTest

const SCREEN := Vector2(1280, 720)


func _client(class_id: String) -> ClientSession:
	var c := ClientSession.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [1, 1], "blocks": []}),
		"0.0.0", "Ana", class_id)
	c.my_id = 1
	c.combat[1] = {"hp": 120.0, "max_hp": 200.0, "resource": 30.0, "max_resource": 100.0,
		"life": CombatEntity.ALIVE, "status_bits": 0, "combo": 0, "charge": 0.0}
	return c


func _hud(c: ClientSession) -> CombatHud:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	var hud := CombatHud.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.bind(c, c.bar, AbilityDB.load_default())
	return hud


func test_hud_shows_hp_resource() -> void:
	var hud := _hud(_client("warrior"))
	hud.advance(0.0)
	assert_eq(hud.hp_text(), "120 / 200")
	assert_eq(hud.resource_text(), "30 / 100")
	assert_almost_eq(hud.hp_fraction(), 0.6, 0.001)


func test_slots_follow_class_and_bar() -> void:
	var c := _client("mage")
	var hud := _hud(c)
	var db := AbilityDB.load_default()
	assert_eq(hud.slot_count(), 12, "CI, CD, 1-9 and Espacio")
	assert_eq(hud.slot_ability(0), db.kind_of("mage", "basic"))
	assert_eq(hud.slot_ability(1), db.kind_of("mage", "secondary"))
	assert_eq(hud.slot_ability(2), c.bar[0])
	assert_eq(hud.slot_key(11), tr("HUD_KEY_SPACE"))


func test_slot_dims_without_resource() -> void:
	var c := _client("mage") # the secondary (mage_blast) costs 25 mana
	c.combat[1].resource = 5.0
	var hud := _hud(c)
	hud.advance(0.0)
	var blast := 1
	assert_eq(hud.slot_ability(blast), "mage_blast")
	assert_true(hud.slot_dimmed(blast), "not enough mana")
	assert_false(hud.slot_dimmed(0), "the basic attack is free")
	c.combat[1].resource = 100.0
	hud.advance(0.0)
	assert_false(hud.slot_dimmed(blast))


func test_cooldown_sweep_from_cast_event() -> void:
	var c := _client("mage")
	var hud := _hud(c)
	var db := AbilityDB.load_default()
	var secondary := db.kind_of("mage", "secondary")
	var cd := float(db.get_ability(secondary).cooldown_s)
	c.combat_event.emit(["cast", 1, secondary, Vector3.ZERO])
	hud.advance(0.0)
	assert_almost_eq(hud.slot_cooldown(1), 1.0, 0.01, "full sweep just after casting")
	hud.advance(cd / 2.0)
	assert_almost_eq(hud.slot_cooldown(1), 0.5, 0.02)
	hud.advance(cd)
	assert_eq(hud.slot_cooldown(1), 0.0)


func test_gcd_sweeps_other_gcd_slots_only() -> void:
	var c := _client("mage")
	var db := AbilityDB.from_list([
		{"id": "b", "class": "mage", "kind": "basic", "cost": 0, "cooldown_s": 0.5, "gcd": false},
		{"id": "s", "class": "mage", "kind": "secondary", "cost": 0, "cooldown_s": 4, "gcd": false},
		{"id": "a1", "class": "mage", "kind": "active", "cost": 0, "cooldown_s": 10, "gcd": true},
		{"id": "a2", "class": "mage", "kind": "active", "cost": 0, "cooldown_s": 10, "gcd": true},
	])
	var hud := _hud(c)
	hud.bind(c, ["a1", "a2", "", ""], db)
	c.combat_event.emit(["cast", 1, "a1", Vector3.ZERO])
	hud.advance(0.0)
	assert_almost_eq(hud.slot_cooldown(2), 1.0, 0.01, "a1's own cooldown")
	assert_almost_eq(hud.slot_cooldown(3), 1.0, 0.01, "a2 waits for the global cooldown")
	assert_eq(hud.slot_cooldown(0), 0.0, "the basic attack ignores the global cooldown")
	assert_eq(hud.slot_cooldown(1), 0.0, "the secondary ignores the global cooldown")
	assert_eq(hud.slot_cooldown(4), 0.0, "an empty slot")
	hud.advance(c.balance.gcd_s + 0.01)
	assert_eq(hud.slot_cooldown(3), 0.0, "the global cooldown is over")
	assert_gt(hud.slot_cooldown(2), 0.9)


func test_other_players_casts_do_not_sweep() -> void:
	var c := _client("mage")
	var hud := _hud(c)
	c.combat_event.emit(["cast", 2, AbilityDB.load_default().kind_of("mage", "secondary"), Vector3.ZERO])
	hud.advance(0.0)
	assert_eq(hud.slot_cooldown(1), 0.0)


func test_combo_pips_only_for_assassin() -> void:
	var c := _client("assassin")
	c.combat[1].combo = 3
	var hud := _hud(c)
	hud.advance(0.0)
	assert_true(hud.combo_visible())
	assert_eq(hud.combo_lit(), 3)
	var w := _hud(_client("warrior"))
	w.advance(0.0)
	assert_false(w.combo_visible())


func test_archer_charge_bar() -> void:
	var c := _client("archer")
	var hud := _hud(c)
	hud.advance(0.0)
	assert_false(hud.charge_visible())
	c.combat[1].charge = 0.5
	hud.advance(0.0)
	assert_true(hud.charge_visible())
	assert_almost_eq(hud.charge_fraction(), 0.5, 0.001)


func test_death_countdown() -> void:
	var c := _client("warrior")
	var hud := _hud(c)
	c.combat_event.emit(["died", 1])
	c.combat[1].life = CombatEntity.DEAD
	hud.advance(0.0)
	assert_true(hud.death_visible())
	assert_string_contains(hud.death_text(), "3")
	hud.advance(1.2)
	assert_string_contains(hud.death_text(), "2")
	c.combat_event.emit(["respawned", 1, Vector3.ZERO])
	c.combat[1].life = CombatEntity.ALIVE
	hud.advance(0.0)
	assert_false(hud.death_visible())


func test_hud_fits_and_avoids_chat() -> void:
	var c := _client("assassin")
	c.combat[1].combo = 5
	c.combat[1].charge = 1.0
	var hud := _hud(c)
	c.combat_event.emit(["died", 1])
	c.combat[1].life = CombatEntity.DEAD
	hud.advance(0.0)
	var chat := ChatBox.new()
	hud.get_parent().add_child(chat)
	chat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 8:
		chat.add_message("Nombre-Largo-16c", "x".repeat(120), false)
	chat.open_input()
	await wait_frames(3)
	var screen := Rect2(Vector2.ZERO, SCREEN).grow(0.5)
	var bar := hud.bar_rect()
	assert_true(screen.encloses(bar), "HUD %s inside 1280x720" % bar)
	assert_true(screen.encloses(hud.death_rect()))
	assert_false(bar.intersects(chat.column_rect()), "chat %s over the HUD %s" % [chat.column_rect(), bar])


func test_boss_bar_shows_name_and_phase() -> void:
	var c := _client("warrior")
	var hud := _hud(c)
	hud.advance(0.0)
	assert_false(hud.boss_bar_visible(), "no boss around")
	c.monsters[1000] = {"type": "guard_beast", "hp": 1200.0, "max_hp": 1200.0, "status_bits": 0, "target": 0, "elite": false}
	hud.advance(0.0)
	assert_false(hud.boss_bar_visible(), "a boss that is not fighting has no bar")
	c.monsters[1000].target = 1
	c.monsters[1000].hp = 700.0
	hud.advance(0.0)
	assert_true(hud.boss_bar_visible())
	assert_string_contains(hud.boss_bar_text(), tr("MON_GUARD_BEAST"))
	assert_string_contains(hud.boss_bar_text(), tr("HUD_BOSS_PHASE") % 2)
	assert_almost_eq(hud.boss_fraction(), 700.0 / 1200.0, 0.001)
	assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(hud.boss_bar_rect()), "on screen")
	c.monsters.erase(1000)
	hud.advance(0.0)
	assert_false(hud.boss_bar_visible())


func test_cooldown_from_the_cast_event_wins() -> void:
	# Sigilo cast in combat: 45 s, not the 8 s of the data.
	var c := _client("assassin")
	c.bar = ["assassin_stealth", "", "", ""]
	var hud := _hud(c)
	c.combat_event.emit(["cast", 1, "assassin_stealth", Vector3.ZERO, 45.0])
	hud.advance(10.0)
	assert_gt(hud.slot_cooldown(2), 0.7, "still cooling after 10 s of 45")
	hud.advance(36.0)
	assert_eq(hud.slot_cooldown(2), 0.0)


func test_cast_bar_fills_and_hides() -> void:
	var c := _client("mage")
	var hud := _hud(c)
	hud.advance(0.0)
	assert_false(hud.cast_visible())
	c.combat_event.emit(["channel", 1, "mage_fireball", 1.2])
	assert_true(hud.cast_visible())
	assert_eq(hud.cast_text(), tr("AB_MAGE_FIREBALL"))
	hud.advance(0.6)
	assert_almost_eq(hud.cast_fraction(), 0.5, 0.01)
	hud.advance(0.7)
	assert_false(hud.cast_visible(), "the time is up")
	c.combat_event.emit(["channel", 1, "mage_fireball", 1.2])
	c.combat_event.emit(["channel_end", 1])
	assert_false(hud.cast_visible(), "interrupted")
	c.combat_event.emit(["channel", 2, "mage_fireball", 1.2])
	assert_false(hud.cast_visible(), "somebody else's cast")


func test_status_tiles_show_effects_and_blink_when_ending() -> void:
	var c := _client("warrior")
	c.combat[1].status_bits = (1 << StatusEffect.BIT_KINDS.find("poison")) | (1 << StatusEffect.BIT_KINDS.find("haste"))
	var hud := _hud(c)
	c._latest_tick = 100
	c.combat_event.emit(["status", 1, "poison", 100 + 30 * 10]) # 10 s left
	c.combat_event.emit(["status", 1, "haste", 100 + 30 * 2]) # 2 s left: about to end
	hud.advance(0.1)
	assert_eq(hud.status_tiles.kinds().size(), 2)
	assert_true(hud.status_tiles.visible)
	assert_false(hud.status_tiles.is_blinking("poison"))
	assert_true(hud.status_tiles.is_blinking("haste"), "it will vanish soon")
	assert_true(StatusTiles.is_debuff("poison"))
	assert_ne(hud.status_tiles.edge_color("poison"), hud.status_tiles.edge_color("haste"), "red for harm, green for help")


func test_a_status_leaves_with_its_time_or_when_the_snapshot_drops_it() -> void:
	var c := _client("warrior")
	c.combat[1].status_bits = 1 << StatusEffect.BIT_KINDS.find("slow")
	var hud := _hud(c)
	c._latest_tick = 100
	c.combat_event.emit(["status", 1, "slow", 130])
	hud.advance(0.1)
	assert_eq(hud.status_tiles.kinds(), ["slow"])
	c.combat[1].status_bits = 0 # cleansed
	hud.advance(0.1)
	assert_eq(hud.status_tiles.kinds(), [])
	assert_false(hud.status_tiles.visible)
	c.combat[1].status_bits = 1 << StatusEffect.BIT_KINDS.find("slow")
	c.combat_event.emit(["status", 1, "slow", 130])
	c._latest_tick = 131
	hud.advance(0.1)
	assert_eq(hud.status_tiles.kinds(), [], "time is up")


func test_slots_show_the_icon_of_their_bound_key_and_numbers_only_numbers() -> void:
	var hud := _hud(_client("mage"))
	assert_eq(hud.slot_key_icon(0), "mouse_left")
	assert_eq(hud.slot_key_icon(1), "mouse_right")
	assert_eq(hud.slot_key_icon(hud.slot_count() - 1), "space")
	assert_eq(hud.slot_key_icon(2), "", "a slot shows its number")
	assert_eq(hud.slot_key(2), "1")


func test_key_icons_follow_the_binding() -> void:
	InputSetup.ensure_actions()
	assert_eq(KeyIcon.describe("dodge").kind, "space")
	assert_eq(KeyIcon.describe("attack_basic").kind, "mouse_left")
	assert_eq(KeyIcon.describe("interact"), {"kind": "key", "text": "E"})
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_Q
	InputMap.action_erase_events("dodge")
	InputMap.action_add_event("dodge", ev)
	assert_eq(KeyIcon.describe("dodge"), {"kind": "key", "text": "Q"}, "rebound")
	InputMap.action_erase_events("dodge") # put the default back
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	InputMap.action_add_event("dodge", space)
