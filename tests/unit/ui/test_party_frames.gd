extends GutTest
## Task 14: allies' frames on the left and the downed / reviving overlay.

const SCREEN := Vector2(1280, 720)


func _client() -> ClientSession:
	var c := ClientSession.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [1, 1], "blocks": []}),
		"0.0.0", "Ana", "warrior")
	c.my_id = 1
	c.roster = {
		1: {"name": "Ana", "slot": 0, "class_id": "warrior", "appearance": {}},
		2: {"name": "Bea", "slot": 1, "class_id": "cleric", "appearance": {}},
		3: {"name": "Cris", "slot": 2, "class_id": "mage", "appearance": {}},
	}
	for id: int in [1, 2, 3]:
		c.combat[id] = {"hp": 100.0, "max_hp": 200.0, "resource": 0.0, "max_resource": 100.0,
			"life": CombatEntity.ALIVE, "status_bits": 0, "combo": 0, "charge": 0.0}
	return c


func _root() -> Control:
	var root := Control.new()
	root.size = SCREEN
	add_child_autofree(root)
	return root


func test_party_frames_show_downed() -> void:
	var c := _client()
	var frames := PartyFrames.new()
	_root().add_child(frames)
	frames.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frames.bind(c)
	frames.advance(0.0)
	assert_eq(frames.frame_ids(), [2, 3], "the allies, not me, in slot order")
	assert_eq(frames.frame_name(2), "Bea")
	assert_almost_eq(frames.frame_fraction(3), 0.5, 0.001)
	assert_eq(frames.frame_status(2), "")
	c.combat[2].life = CombatEntity.DOWNED
	c.combat[2].hp = 0.0
	c.combat[3].life = CombatEntity.DEAD
	frames.advance(0.0)
	assert_eq(frames.frame_status(2), tr("PARTY_DOWNED"))
	assert_eq(frames.frame_status(3), tr("PARTY_DEAD"))
	for id: int in frames.frame_ids():
		assert_true(Rect2(Vector2.ZERO, SCREEN).encloses(frames.frame_rect(id)))
	c.roster.erase(3)
	frames.advance(0.0)
	assert_eq(frames.frame_ids(), [2], "a player who left loses the frame")


func test_solo_has_no_frames() -> void:
	var c := _client()
	c.roster.erase(2)
	c.roster.erase(3)
	var frames := PartyFrames.new()
	_root().add_child(frames)
	frames.bind(c)
	frames.advance(0.0)
	assert_eq(frames.frame_ids(), [])


func test_downed_overlay_countdown_and_revive_bar() -> void:
	var c := _client()
	var overlay := DownedOverlay.new()
	_root().add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.bind(c)
	overlay.advance(0.0)
	assert_false(overlay.downed_visible())
	assert_false(overlay.revive_visible())
	c.combat[1].life = CombatEntity.DOWNED
	c.combat_event.emit(["downed", 1])
	overlay.advance(1.0)
	assert_true(overlay.downed_visible())
	assert_string_contains(overlay.downed_text(), str(int(c.balance.downed_s) - 1))
	c.combat[1].life = CombatEntity.ALIVE
	overlay.advance(0.0)
	assert_false(overlay.downed_visible())
	# Reviving Bea: a progress bar fills over revive_hold_s.
	c.combat_event.emit(["revive_start", 1, 2])
	overlay.advance(c.balance.revive_hold_s / 2.0)
	assert_true(overlay.revive_visible())
	assert_almost_eq(overlay.revive_fraction(), 0.5, 0.05)
	assert_string_contains(overlay.revive_text(), "Bea")
	c.combat_event.emit(["revive_cancel", 1])
	overlay.advance(0.0)
	assert_false(overlay.revive_visible())
	c.combat_event.emit(["revive_start", 1, 2])
	c.combat_event.emit(["revived", 2, 1])
	overlay.advance(0.0)
	assert_false(overlay.revive_visible(), "done")


func test_revive_bar_goes_when_i_go_down() -> void:
	var c := _client()
	var overlay := DownedOverlay.new()
	_root().add_child(overlay)
	overlay.bind(c)
	c.combat_event.emit(["revive_start", 1, 2])
	overlay.advance(0.5)
	assert_true(overlay.revive_visible())
	c.combat[1].life = CombatEntity.DOWNED
	overlay.advance(0.1)
	assert_false(overlay.revive_visible(), "no revive bar while I am down")
	c.combat[1].life = CombatEntity.ALIVE
	overlay.advance(0.1)
	assert_false(overlay.revive_visible(), "and it does not come back")
