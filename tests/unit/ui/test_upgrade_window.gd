extends GutTest

var win: UpgradeWindow
var abilities: AbilityDB


func before_each() -> void:
	abilities = AbilityDB.load_default()
	win = UpgradeWindow.new()
	var theme := Theme.new()
	theme.default_font_size = 20
	win.theme = theme
	add_child_autofree(win)


func test_lists_the_upgrades_of_the_class() -> void:
	win.show_for("warrior", abilities, UpgradeDB.load_default())
	assert_eq(win.option_ids(), ["protector", "berserker"])
	assert_eq(win.selected(), "protector", "the first one starts selected")
	win.select("berserker")
	assert_eq(win.selected(), "berserker")
	win.select("nonsense")
	assert_eq(win.selected(), "berserker")


func test_confirm_emits_the_selection() -> void:
	win.show_for("mage", abilities, UpgradeDB.load_default())
	win.select("cryomancer")
	watch_signals(win)
	win.confirm_button.pressed.emit()
	assert_signal_emitted_with_parameters(win, "confirmed", ["cryomancer"])
	assert_false(win.visible)


func test_fits_1280x720_with_three_options() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var ups := UpgradeDB.from_list(UpgradeDB.load_default().for_class("mage").map(func(u: Dictionary) -> Dictionary:
		var d := u.duplicate(true)
		d["actives"] = ["mage_fireball", "mage_frostbolt"]
		d["passives"] = ["mage_focus", "mage_ignition"]
		d["evolves"] = {"ability": "mage_fireball", "desc": "UP_ARCANIST_DESC"}
		return d))
	win.show_for("mage", abilities, ups)
	assert_eq(win.option_ids().size(), 3)
	await wait_process_frames(2)
	var r := win.panel_rect()
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "panel %s" % r)
	assert_gt(r.size.x, 800.0, "three columns")


func test_texts_are_translated() -> void:
	for key: String in ["UPGRADE_TITLE", "UPGRADE_WARNING", "UPGRADE_CONFIRM", "UPGRADE_ACTIVES", "UPGRADE_PASSIVES",
			"UPGRADE_EVOLUTION", "UPGRADE_KIT", "CHAT_UPGRADE_HINT", "CHAT_UPGRADE_CHOSEN"]:
		assert_ne(tr(key), key, key)


func test_lists_the_kit_changes() -> void:
	var ups := UpgradeDB.load_default()
	assert_true(UpgradeWindow._kit_names(abilities, ups.upgrade("pyromancer")).contains(tr("AB_MAGE_FIRE_BOLT")))
	assert_eq(UpgradeWindow._kit_names(abilities, ups.upgrade("shadow")), "", "the assassin's kit stays")
