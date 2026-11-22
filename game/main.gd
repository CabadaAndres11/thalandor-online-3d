class_name Main
extends Node
## Application root: title → "Tus personajes" (create, delete, export, import, play,
## join) → a running game; wires the HUD (chat, pause menu, dialogs, debug overlay)
## to the network sessions.

const ERROR_KEYS := {
	"version": "ERR_VERSION",
	"full": "ERR_FULL",
	"name": "ERR_NAME",
	"host_left": "ERR_HOST_LEFT",
	"timeout": "ERR_TIMEOUT",
	"failed": "ERR_CONNECT",
	"tutorial": "ERR_TUTORIAL",
}

var settings: SettingsStore
var settings_path: String = SettingsStore.DEFAULT_PATH
var characters_dir: String = CharacterStore.DEFAULT_DIR
## Network for new games ("" = GameSession's default / command line). Tests use ENet
## so they never reach the Internet.
var net_mode: String = ""
var store: CharacterStore
var game: GameSession
var title: TitleScreen
var select_screen: CharacterSelectScreen
var create_screen: CharacterCreateScreen
## The black sun altar behind the menus (Plan 7); freed while a game runs.
var menu_scene: MenuScene
var credits_window: CreditsWindow
var chat: ChatBox
var combat_hud: CombatHud
var party_frames: PartyFrames
var downed_overlay: DownedOverlay
var pause_menu: PauseMenu
var options_window: OptionsWindow
## The settings last applied, to apply only what an Options change touched.
var _applied: SettingsStore
var abilities_window: AbilitiesWindow
var class_choice_window: ClassChoiceWindow
var character_window: CharacterWindow
var inventory_window: InventoryWindow
var merchant_window: MerchantWindow
var _merchant_stock: Array = []
var talents_window: TalentsWindow
var trainer_menu: TrainerMenu
var upgrade_window: UpgradeWindow
## At a dungeon's door: choose its level (Plan 8.1).
var dungeon_window: DungeonWindow
var _upgrade_sent_at: int = -10000
var abilities: AbilityDB
var dialog: MessageDialog
var debug_overlay: DebugOverlay
var status_label: Label

var _ui: CanvasLayer
var _file_dialog: FileDialog
## What the open dialog / file picker is for: {"action": "delete"|"export"|"import"|
## "import_rename", "id", "path"}; {} when nothing is pending.
var _pending: Dictionary = {}
## The saved character being played (null in games started without one).
var _playing: CharacterData = null


func _ready() -> void:
	add_child(ItemIcons.new()) # renders item icons for every window
	InputSetup.ensure_actions()
	settings = SettingsStore.load_from(settings_path)
	SettingsApplier.ensure_buses()
	SettingsApplier.apply_all(settings, get_viewport())
	_applied = settings.duplicate_store()
	store =CharacterStore.new(characters_dir)
	abilities = AbilityDB.load_default()
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var theme := Theme.new()
	theme.default_font_size = 24 # Teko is condensed: a bit larger than the default font
	HoloTheme.apply(theme)

	# The menus wear the stone and gold of the logo; the game windows stay holographic.
	var menu_theme := Theme.new()
	menu_theme.default_font_size = 24
	StoneTheme.apply(menu_theme)
	_ensure_menu_scene()

	title = TitleScreen.new()
	title.theme = menu_theme
	title.play_requested.connect(_show_select)
	title.quit_requested.connect(_quit)
	title.options_requested.connect(_show_options)
	title.credits_requested.connect(_show_credits)
	_add_screen(title)

	select_screen = CharacterSelectScreen.new()
	select_screen.theme = menu_theme
	select_screen.look_changed.connect(_on_menu_look)
	select_screen.play_requested.connect(_on_select_play)
	select_screen.join_requested.connect(_on_select_join)
	select_screen.create_requested.connect(_show_create)
	select_screen.delete_requested.connect(_on_select_delete)
	select_screen.export_requested.connect(_on_select_export)
	select_screen.import_requested.connect(_on_select_import)
	select_screen.back_requested.connect(_show_title)
	_add_screen(select_screen)

	create_screen = CharacterCreateScreen.new()
	create_screen.theme = menu_theme
	create_screen.look_changed.connect(_on_menu_look)
	create_screen.turn_requested.connect(_on_turn_hero)
	create_screen.create_requested.connect(_on_create_requested)
	create_screen.back_requested.connect(_show_select)
	_add_screen(create_screen)

	credits_window = CreditsWindow.new()
	credits_window.theme = menu_theme
	credits_window.visible = false
	credits_window.close_requested.connect(func() -> void: credits_window.visible = false)
	_ui.add_child(credits_window)

	combat_hud = CombatHud.new()
	combat_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_hud.visible = false
	_ui.add_child(combat_hud)

	party_frames = PartyFrames.new()
	party_frames.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_frames.visible = false
	_ui.add_child(party_frames)

	downed_overlay = DownedOverlay.new()
	downed_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	downed_overlay.visible = false
	_ui.add_child(downed_overlay)

	chat = ChatBox.new()
	chat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat.visible = false
	chat.message_submitted.connect(_on_chat_submitted)
	chat.typing_changed.connect(_on_typing_changed)
	_ui.add_child(chat)

	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.position.y = 24
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.visible = false
	_ui.add_child(status_label)

	debug_overlay = DebugOverlay.new()
	_ui.add_child(debug_overlay)

	abilities_window = AbilitiesWindow.new()
	abilities_window.theme = theme
	abilities_window.bar_changed.connect(_on_bar_changed)
	_ui.add_child(abilities_window)

	class_choice_window = ClassChoiceWindow.new()
	class_choice_window.theme = theme
	class_choice_window.class_confirmed.connect(_on_class_confirmed)
	class_choice_window.visibility_changed.connect(_update_input_block)
	_ui.add_child(class_choice_window)

	character_window = CharacterWindow.new()
	character_window.theme = theme
	character_window.attribute_spent.connect(_on_attribute_spent)
	character_window.unequip_requested.connect(func(slot: String) -> void: _request_item("unequip", [slot]))
	_ui.add_child(character_window)
	inventory_window = InventoryWindow.new()
	inventory_window.theme = theme
	inventory_window.item_action.connect(_request_item)
	inventory_window.visibility_changed.connect(_dock_windows)
	inventory_window.sell_requested.connect(_on_sell_requested)
	_ui.add_child(inventory_window)
	merchant_window = MerchantWindow.new()
	merchant_window.theme = theme
	merchant_window.buy_requested.connect(func(i: int) -> void: _request_item("buy", [i]))
	merchant_window.repair_requested.connect(func() -> void: _request_item("repair", []))
	merchant_window.tab_changed.connect(func(selling: bool) -> void: inventory_window.sell_mode = selling)
	merchant_window.visibility_changed.connect(_on_merchant_visibility)
	_ui.add_child(merchant_window)

	talents_window = TalentsWindow.new()
	talents_window.theme = theme
	talents_window.talent_bought.connect(_on_talent_bought)
	talents_window.mastery_bought.connect(_on_mastery_bought)
	_ui.add_child(talents_window)

	upgrade_window = UpgradeWindow.new()
	upgrade_window.theme = theme
	upgrade_window.confirmed.connect(_on_upgrade_confirmed)
	upgrade_window.visibility_changed.connect(_update_input_block)
	_ui.add_child(upgrade_window)

	dungeon_window = DungeonWindow.new()
	dungeon_window.theme = theme
	dungeon_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dungeon_window.enter_requested.connect(func(zone: String, level: int) -> void:
		if game != null and game.client != null:
			game.client.enter_dungeon(zone, level))
	dungeon_window.visibility_changed.connect(_update_input_block)
	_ui.add_child(dungeon_window)

	trainer_menu = TrainerMenu.new()
	trainer_menu.theme = theme
	trainer_menu.chosen.connect(_on_trainer_choice)
	trainer_menu.arena_level_confirmed.connect(_on_arena_level_confirmed)
	_ui.add_child(trainer_menu)

	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.leave_requested.connect(_leave_game)
	pause_menu.open_group_requested.connect(_on_open_group)
	pause_menu.options_requested.connect(_show_options)
	_ui.add_child(pause_menu)

	options_window = OptionsWindow.new()
	options_window.theme = theme
	options_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_window.settings_changed.connect(_on_settings_changed)
	options_window.closed.connect(_on_options_closed)
	_ui.add_child(options_window)

	dialog = MessageDialog.new()
	dialog.theme = theme
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.answered.connect(_on_dialog_answered)
	dialog.text_answered.connect(_on_dialog_text)
	_ui.add_child(dialog)

	_file_dialog = FileDialog.new()
	_file_dialog.use_native_dialog = true
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json"])
	_file_dialog.file_selected.connect(_on_file_selected)
	_file_dialog.canceled.connect(_on_file_canceled)
	add_child(_file_dialog)
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or chat.is_typing() or dialog.visible:
		return
	if event.is_action_pressed("menu"):
		if not _close_open_window():
			pause_menu.visible = not pause_menu.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not pause_menu.visible and not _modal_open() and not _panel_open() \
			and game.client != null:
		_on_interact() # no set_input_as_handled: holding E also revives
	elif pause_menu.visible or _modal_open() or game.client == null:
		return
	elif event.is_action_pressed("abilities_window"):
		_toggle_window(abilities_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_character"):
		_toggle_window(character_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_talents"):
		_toggle_window(talents_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("potion_health"):
		_request_item("potion", ["health"])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("potion_resource"):
		_request_item("potion", ["resource"])
		get_viewport().set_input_as_handled()


## The windows opened with K, C and T (one at a time): they block mouse attacks, not movement.
func _panel_windows() -> Array:
	return [abilities_window, character_window, talents_window]


func _panel_open() -> bool:
	return _panel_windows().any(func(w: Control) -> bool: return w.visible) or inventory_window.visible


## I: the inventory opens beside whatever K/C/T window is open (it never closes them).
func _toggle_inventory() -> void:
	if inventory_window.visible:
		inventory_window.visible = false
		return
	_show_inventory()


func _show_inventory() -> void:
	var c := game.client
	inventory_window.show_for(c.inventory, c.class_id, c.progress.level)


## The character and merchant windows make room for the inventory docked on the right.
func _dock_windows() -> void:
	var px := inventory_window.reserved_width() if inventory_window.visible else 0.0
	character_window.set_right_margin(px)
	merchant_window.set_right_margin(px)


## The host sent what the merchant sells: the merchant opens with the inventory beside it.
func _on_merchant_stock(items: Array) -> void:
	if game == null or game.client == null:
		return
	_merchant_stock = items
	for w: Control in _panel_windows():
		w.visible = false
	var c := game.client
	merchant_window.show_for(items, c.inventory, c.class_id, c.progress.level)
	_show_inventory()


func _on_merchant_visibility() -> void:
	if not merchant_window.visible:
		inventory_window.sell_mode = false


## Right click in the inventory at the merchant: sell (rare or better asks first).
func _on_sell_requested(index: int) -> void:
	var it: Item = game.client.inventory.bag[index] if index < game.client.inventory.bag.size() else null
	if it == null:
		return
	if not MerchantWindow.needs_confirm(it):
		_request_item("sell", [index])
		return
	_pending = {"action": "sell", "index": index}
	dialog.ask(tr("MERCHANT_SELL_CONFIRM") % [tr(str(ItemDB.load_default().base(it.base_id).get("name", ""))), Merchant.sell_price(it, ItemDB.load_default())])


func _request_item(action: String, args: Array) -> void:
	if game != null and game.client != null:
		game.client.request_item(action, args)


## Class choice and Brann's menu take the whole input while they are open.
func _modal_open() -> bool:
	return class_choice_window.visible or trainer_menu.visible or upgrade_window.visible or dungeon_window.visible


## Esc: closes whatever window is open and says whether there was one.
func _close_open_window() -> bool:
	for w: Control in [class_choice_window, trainer_menu, upgrade_window] + _panel_windows() + [merchant_window, inventory_window]:
		if w.visible:
			if w == upgrade_window and upgrade_window.mandatory:
				return true # the choice cannot be skipped
			w.visible = false
			return true
	return false


## Opens a K/C/T window (closing the other two) or closes it if it is the open one.
func _toggle_window(w: Control) -> void:
	var was_open := w.visible
	for other: Control in _panel_windows():
		other.visible = false
	if was_open:
		return
	match w:
		abilities_window:
			abilities_window.show_for(game.client.class_id, game.client.bar, abilities,
				game.client.progress.level, game.client.progress.upgrade)
		character_window:
			_show_character()
		talents_window:
			talents_window.show_for(game.client.progress, TalentDB.load_default(), game.client.balance)


func _show_character() -> void:
	var c := game.client
	var char_name: String = c.roster[c.my_id].name if c.roster.has(c.my_id) else c.player_name
	character_window.show_for(char_name, c.class_id, c.progress, Progression.preview_stats(c.class_id, c.progress, c.balance, c.inventory),
		c.balance, c.appearance, c.inventory)


## E next to an NPC: a villager by Brann chooses a class; anyone else gets Brann's menu
## (or just hears him when there is nothing to offer).
func _on_interact() -> void:
	var r := game.interaction()
	match str(r.action):
		NpcInteraction.CHOOSE_CLASS:
			class_choice_window.show_for(game.client.appearance)
		NpcInteraction.TRADE:
			_request_item("merchant_open", []) # the host answers with the stock
		NpcInteraction.TALK:
			var c := game.client
			var me: Dictionary = c.combat.get(c.my_id, {})
			var in_combat := false
			if game.host != null and game.host.world.players.has(c.my_id):
				in_combat = (game.host.world.players[c.my_id] as PlayerState).in_combat(game.host.world)
			var options := NpcInteraction.trainer_options(c.class_id, c.progress, game.is_hosting() and c.my_id == 1, in_combat)
			if options.is_empty() or me.is_empty():
				var npc := NpcDB.load_default().npc(str(r.npc))
				var line := str((npc.get("lines", {}) as Dictionary).get("has_class", ""))
				chat.add_message(tr(str(npc.get("name", ""))), tr(line), false)
			else:
				for w: Control in _panel_windows():
					w.visible = false
				trainer_menu.show_for(options)


## An option of Brann's menu. Resets ask first; the host answers with PROGRESS.
func _on_trainer_choice(option: String) -> void:
	if game == null or game.client == null:
		return
	match option:
		"choose_class":
			trainer_menu.visible = false
			class_choice_window.show_for(game.client.appearance)
		"choose_upgrade":
			trainer_menu.visible = false
			_open_upgrade_window()
		"reset_attributes", "reset_talents", "reset_upgrade":
			trainer_menu.visible = false
			_pending = {"action": "reset", "what": option.trim_prefix("reset_")}
			dialog.ask(tr("CONFIRM_" + option.to_upper()))
		"arena_level":
			trainer_menu.show_arena_selector(game.client.arena_level)


## Brann's upgrade window for the player's class.
func _open_upgrade_window() -> void:
	upgrade_window.show_for(game.client.class_id, abilities, UpgradeDB.load_default())


## Level 50 without an upgrade: the choice window opens by itself and cannot be skipped.
func _require_upgrade() -> void:
	var c := game.client
	if upgrade_window.visible or c.progress.level < ProgressRequests.UPGRADE_LEVEL or c.progress.upgrade != "" \
			or not CharacterCatalog.load_default().is_selectable(c.class_id) \
			or UpgradeDB.load_default().for_class(c.class_id).is_empty() \
			or Time.get_ticks_msec() - _upgrade_sent_at < 2000:
		return
	trainer_menu.visible = false
	_open_upgrade_window()
	upgrade_window.mandatory = true


func _on_upgrade_confirmed(id: String) -> void:
	if game != null and game.client != null:
		_upgrade_sent_at = Time.get_ticks_msec()
		game.client.choose_upgrade(id)


## Somebody chose or lost an upgrade: the chat says it, the abilities window follows.
func _on_upgrade_changed(id: int, upgrade: String) -> void:
	if game == null or game.client == null:
		return
	if upgrade != "":
		var who: String = game.client.roster[id].name if game.client.roster.has(id) else "?"
		var name := tr(str(UpgradeDB.load_default().upgrade(upgrade).get("name", upgrade)))
		chat.add_message("", tr("CHAT_UPGRADE_CHOSEN") % [who, name], true)


func _on_arena_level_confirmed(level: int) -> void:
	if game != null and game.client != null:
		game.client.set_arena_level(level)


func _on_arena_level_changed(level: int) -> void:
	chat.add_message("", tr("ARENA_LEVEL_SET") % level, true)


func _on_attribute_spent(attr: String) -> void:
	if game != null and game.client != null:
		game.client.spend_attribute(attr)


func _on_talent_bought(id: String) -> void:
	if game != null and game.client != null:
		game.client.buy_talent(id)


func _on_mastery_bought(dir: String) -> void:
	if game != null and game.client != null:
		game.client.buy_mastery(dir)


## Somebody reached a level: a line in the chat for everyone.
func _on_leveled_up(id: int, level: int) -> void:
	if game == null or game.client == null:
		return
	var who: String = game.client.roster[id].name if game.client.roster.has(id) else "?"
	chat.add_message("", tr("CHAT_LEVEL_UP") % [who, level], true)
	if id == game.client.my_id and level >= ProgressRequests.UPGRADE_LEVEL and game.client.progress.upgrade == "" \
			and CharacterCatalog.load_default().is_selectable(game.client.class_id) \
			and not UpgradeDB.load_default().for_class(game.client.class_id).is_empty():
		chat.add_message("", tr("CHAT_UPGRADE_HINT"), true)
		_require_upgrade()


func _on_class_confirmed(class_id: String) -> void:
	if game == null or game.client == null:
		return
	# Checked again: the player may have been pushed away or knocked down meanwhile,
	# and the host would drop the request without a word.
	if str(game.interaction().action) != NpcInteraction.CHOOSE_CLASS:
		chat.add_message("", tr("CLASS_CHOICE_TOO_FAR"), true)
		return
	game.client.choose_class(class_id)


## The host agreed: this player now has a class. The HUD gets its bar and the saved
## character remembers both.
func _on_class_changed(id: int, class_id: String) -> void:
	if game == null or game.client == null or id != game.client.my_id:
		return
	abilities_window.visible = false
	combat_hud.bind(game.client, game.client.bar, abilities)
	if _playing != null:
		_playing.class_id = class_id
		_playing.bar = game.client.bar.duplicate()
		store.queue_save(_playing)


## The host sent this player's progress (experience, level, points…): the saved character
## keeps it. Saves are coalesced per frame (CharacterStore.queue_save).
func _on_progress_changed() -> void:
	if game == null or game.client == null:
		return
	var c := game.client
	combat_hud.bind(c, c.bar, abilities) # a level-up can add an ability to the bar
	_require_upgrade()
	if character_window.visible:
		_show_character()
	if talents_window.visible:
		talents_window.show_for(c.progress, TalentDB.load_default(), c.balance)
	if abilities_window.visible:
		abilities_window.show_for(c.class_id, c.bar, abilities, c.progress.level, c.progress.upgrade)
	if _playing == null:
		return
	_playing.progress = c.progress.copy()
	_playing.bar = c.bar.duplicate()
	store.queue_save(_playing)


## The host sent this player's inventory: open windows show it and the saved character keeps it.
func _on_inventory_changed() -> void:
	if game == null or game.client == null:
		return
	if inventory_window.visible:
		_show_inventory()
	if merchant_window.visible:
		merchant_window.show_for(_merchant_stock, game.client.inventory, game.client.class_id, game.client.progress.level)
	if character_window.visible:
		_show_character()
	if _playing == null:
		return
	_playing.inventory = Inventory.from_dict(game.client.inventory.to_dict(), game.client.class_id,
		game.client.progress.level, ItemDB.load_default())
	store.queue_save(_playing)


func in_game() -> bool:
	return game != null


# --- Screens -----------------------------------------------------------------------

func _add_screen(screen: Control) -> void:
	_ui.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _show_only(screen: Control) -> void:
	for s: Control in [title, select_screen, create_screen]:
		s.visible = s == screen


func _show_title() -> void:
	_ensure_menu_scene()
	menu_scene.set_shot("title")
	menu_scene.show_character({})
	_show_only(title)


func _show_select() -> void:
	_ensure_menu_scene()
	menu_scene.set_shot("select")
	var list := store.load_all()
	select_screen.set_characters(list, settings.last_character_id)
	select_screen.set_code(settings.last_code)
	_show_only(select_screen)
	if not store.skipped_files.is_empty():
		dialog.show_message(tr("ERR_CHAR_SKIPPED") % store.skipped_files.size())


func _show_create() -> void:
	# The name typed in 0.1.x is suggested for the first character.
	_ensure_menu_scene()
	menu_scene.set_shot("create")
	create_screen.reset(settings.player_name if store.load_all().is_empty() else "")
	_show_only(create_screen)


## The altar scene, built when a menu needs it (at start and back from a game).
func _ensure_menu_scene() -> void:
	if menu_scene != null:
		return
	menu_scene = MenuScene.new()
	menu_scene.name = "MenuScene"
	add_child(menu_scene)
	menu_scene.build()
	menu_scene.set_quality(settings.quality)


func _free_menu_scene() -> void:
	if menu_scene != null:
		remove_child(menu_scene)
		menu_scene.queue_free()
		menu_scene = null


func _on_menu_look(look: Dictionary) -> void:
	_ensure_menu_scene()
	menu_scene.show_character(look)


func _on_turn_hero(deg: float) -> void:
	if menu_scene != null:
		menu_scene.turn_hero(deg)


func _show_credits() -> void:
	credits_window.visible = true


func _on_create_requested(char_name: String, appearance: Dictionary) -> void:
	var c := store.create(char_name, CharacterCatalog.DEFAULT_CLASS, appearance)
	if c == null:
		dialog.show_message(tr(store.last_error))
		return
	_remember_character(c.id)
	_show_select()


func _find(id: String) -> CharacterData:
	for c in store.load_all():
		if c.id == id:
			return c
	return null


func _remember_character(id: String) -> void:
	settings.last_character_id = id
	settings.save_to(settings_path)


func _on_select_play(id: String) -> void:
	var c := _find(id)
	if c != null:
		_remember_character(id)
		_playing = c
		_on_play(c.name, c.class_id, c.appearance, c.progress.to_dict())


func _on_select_join(id: String, code: String) -> void:
	var c := _find(id)
	if c != null:
		_remember_character(id)
		_playing = c
		_on_join(c.name, code, c.class_id, c.appearance, c.progress.to_dict())


func _on_select_delete(id: String) -> void:
	var c := _find(id)
	if c == null:
		return
	_pending = {"action": "delete", "id": id}
	dialog.ask(tr("CONFIRM_DELETE") % c.name)


func _on_select_export(id: String) -> void:
	var c := _find(id)
	if c == null:
		return
	_pending = {"action": "export", "id": id}
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.current_file = "%s.json" % c.name
	_file_dialog.popup_centered_ratio(0.6)


func _on_select_import() -> void:
	_pending = {"action": "import"}
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	var pending := _pending
	_pending = {}
	match pending.get("action", ""):
		"export":
			if store.export_to(pending.id, path) == OK:
				dialog.show_message(tr("EXPORT_DONE"))
			else:
				dialog.show_message(tr("ERR_EXPORT"))
		"import":
			_import(path, "")


func _on_file_canceled() -> void:
	_pending = {}


func _import(path: String, new_name: String) -> void:
	var c := store.import_from(path, new_name)
	if c != null:
		_remember_character(c.id)
		_show_select()
		return
	if store.last_error == "ERR_NAME_TAKEN":
		var original := store.peek(path)
		var shown := new_name if new_name != "" else (original.name if original != null else "")
		_pending = {"action": "import_rename", "path": path}
		dialog.ask_text(tr("IMPORT_NEW_NAME") % shown, shown)
		return
	dialog.show_message(tr(store.last_error))


func _on_dialog_answered(yes: bool) -> void:
	var pending := _pending
	_pending = {}
	if pending.get("action", "") == "sell" and yes:
		_request_item("sell", [int(pending.index)])
	if pending.get("action", "") == "reset" and yes and game != null and game.client != null:
		game.client.reset_progress(str(pending.what))
	if pending.get("action", "") == "delete" and yes:
		var deleted := store.delete(pending.id)
		_show_select()
		if not deleted:
			dialog.show_message(tr("ERR_DELETE"))


func _on_dialog_text(text: String) -> void:
	var pending := _pending
	_pending = {}
	if pending.get("action", "") == "import_rename" and text != "":
		_import(pending.path, text)


func _quit() -> void:
	store.flush()
	get_tree().quit()


## Closing the window (or Alt+F4) also writes the pending progress.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and store != null:
		store.flush()


# --- Game --------------------------------------------------------------------------

func _on_play(player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}, progress: Dictionary = {}) -> void:
	_start_game()
	game.start_host(player_name, class_id, appearance, progress)
	_attach_client()


func _on_join(player_name: String, code: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}, progress: Dictionary = {}) -> void:
	settings.last_code = code
	settings.save_to(settings_path)
	if GroupCode.decode(code) == "":
		dialog.show_message(tr("ERR_BAD_CODE"))
		return
	_start_game()
	if game.join(code, player_name, class_id, appearance, progress) != OK:
		var key := game.last_error
		_leave_game()
		dialog.show_message(tr(key))
		return
	_attach_client()
	status_label.text = tr("CONNECTING")
	status_label.visible = true


func _on_open_group() -> void:
	var code := game.open_group()
	if code != "":
		_on_group_opened(code)
	elif game.last_error == "":
		pause_menu.show_opening() # WebRTC: the code arrives with group_opened
	else:
		_on_group_failed(game.last_error)


func _on_group_opened(code: String) -> void:
	pause_menu.show_code(code)


func _on_group_failed(error_key: String) -> void:
	pause_menu.cancel_opening()
	dialog.show_message(tr(error_key))


func _on_chat_submitted(text: String) -> void:
	if game == null:
		return
	if text.strip_edges() == "/tutorial hecho" and _playing != null:
		# Development (Plan 8.1): marks the village tutorial done until Plan 8.2 does it.
		_playing.tutorial_done = true
		store.save(_playing)
		pause_menu.set_group_locked(false)
		chat.add_message("", tr("CMD_TUTORIAL_DONE"), true)
		return
	var local := AmbienceCommand.handle(text, game.zone_view.ambience_id, Ambience.ids())
	if local.handled:
		if local.switch_to != "":
			game.zone_view.set_ambience(local.switch_to)
		chat.add_message("", local.message, true)
		return
	if game.client != null:
		game.client.send_chat(text)


func _on_typing_changed(_is_typing: bool) -> void:
	_update_input_block()


## No movement or attacks while typing in the chat or with a menu or dialog open
## (a click on a menu button must not attack).
func _update_input_block() -> void:
	if game != null:
		game.input_blocked = chat.is_typing() or pause_menu.visible or options_window.visible or dialog.visible or class_choice_window.visible \
			or trainer_menu.visible or upgrade_window.visible
		game.attacks_blocked = _panel_open()


func _process(_delta: float) -> void:
	_update_input_block()
	# Walking away from the merchant closes the trade.
	if merchant_window.visible and game != null and game.client != null 			and str(game.interaction().action) != NpcInteraction.TRADE:
		merchant_window.visible = false


## Options window (from the title or the pause menu): changes apply live, saved on close.
func _show_options() -> void:
	options_window.open(settings)


## Applies only what changed: a volume slider must not rebuild the lighting or touch the window.
func _on_settings_changed() -> void:
	var old := _applied
	if settings.fullscreen != old.fullscreen or settings.vsync != old.vsync or settings.max_fps != old.max_fps:
		SettingsApplier.apply_window(settings)
	if settings.quality != old.quality or not is_equal_approx(settings.render_scale, old.render_scale):
		SettingsApplier.apply_viewport(settings, get_viewport())
	if settings.quality != old.quality:
		SettingsApplier.apply_quality_globals(settings.quality)
		if game != null:
			game.set_graphics_quality(settings.quality)
		if menu_scene != null:
			menu_scene.set_quality(settings.quality)
	SettingsApplier.apply_audio(settings)
	_applied = settings.duplicate_store()


func _on_options_closed() -> void:
	settings.save_to(settings_path)


func _on_resume() -> void:
	pause_menu.visible = false


func _start_game() -> void:
	_free_menu_scene() # the game builds its own world
	game = GameSession.new()
	game.name = "Game"
	if net_mode != "":
		game.net_mode = net_mode
	add_child(game)
	game.set_graphics_quality(settings.quality)
	game.session_ended.connect(_on_session_ended)
	if _playing != null:
		game.character_bar = _playing.bar.duplicate()
		game.character_inventory = _playing.inventory.to_dict()
		game.character_place = _playing.place.duplicate(true)
		game.character_place["tutorial_done"] = _playing.tutorial_done
	game.group_opened.connect(_on_group_opened)
	game.group_failed.connect(_on_group_failed)
	_show_only(null)
	chat.visible = true
	pause_menu.reset()


## The host says where this character stands: saved at once (and again on leaving).
func _on_place_changed(place: Dictionary) -> void:
	if _playing == null:
		return
	_playing.place = CharacterData.sanitize_place(place)
	if store.save(_playing) != OK:
		dialog.show_message(tr(store.last_error))


func _on_dungeon_offered(zone_id: String, min_level: int, max_level: int, default_level: int) -> void:
	var layout := ZoneLayout.load_id(zone_id)
	dungeon_window.open(zone_id, layout.name if layout != null else zone_id, min_level, max_level, default_level)


func _attach_client() -> void:
	var client := game.client
	client.welcomed.connect(_on_welcomed)
	client.rejected.connect(_on_rejected)
	client.chat_received.connect(chat.add_message)
	client.dungeon_offered.connect(_on_dungeon_offered)
	client.place_changed.connect(_on_place_changed)
	client.combat_event.connect(_on_game_event)
	client.class_changed.connect(_on_class_changed)
	client.progress_changed.connect(_on_progress_changed)
	client.inventory_changed.connect(_on_inventory_changed)
	client.merchant_stock_received.connect(_on_merchant_stock)
	client.leveled_up.connect(_on_leveled_up)
	client.upgrade_changed.connect(_on_upgrade_changed)
	client.arena_level_changed.connect(_on_arena_level_changed)
	debug_overlay.client = client
	debug_overlay.net_label = game.net_label()
	combat_hud.bind(client, client.bar, abilities)
	combat_hud.visible = true
	party_frames.bind(client)
	party_frames.visible = true
	downed_overlay.bind(client)
	downed_overlay.visible = true
	pause_menu.set_can_open_group(game.is_hosting())
	pause_menu.set_group_locked(_playing != null and not _playing.tutorial_done)


## A new bar from the K window: the host, the HUD and the saved character get it.
func _on_bar_changed(bar: Array) -> void:
	if game == null or game.client == null:
		return
	game.client.send_bar(bar)
	combat_hud.bind(game.client, game.client.bar, abilities)
	if _playing != null:
		_playing.bar = game.client.bar.duplicate()
		if store.save(_playing) != OK:
			dialog.show_message(tr(store.last_error))


## Game-wide announcements in the chat (everyone gets the same events).
func _on_game_event(ev: Array) -> void:
	if ev.size() >= 2 and str(ev[0]) in ["downed", "died"] and game != null and game.client != null \
			and int(ev[1]) == game.client.my_id:
		class_choice_window.visible = false # on the ground there is no training
	if ev.size() >= 2 and str(ev[0]) == "boss_down":
		var def := MonsterDB.load_default().get_type(str(ev[1]))
		chat.add_message("", tr("CHAT_BOSS_DOWN") % tr(str(def.get("name", ""))), true)


func _on_welcomed(_id: int) -> void:
	status_label.visible = false


func _on_rejected(reason: String, host_version: String) -> void:
	var text := tr(ERROR_KEYS.get(reason, "ERR_CONNECT"))
	if reason == "version":
		text = text % [host_version, GameSession.game_version()]
	_leave_game()
	dialog.show_message(text)


func _on_session_ended(reason: String) -> void:
	_leave_game()
	dialog.show_message(tr(ERROR_KEYS.get(reason, "ERR_CONNECT")))


## Ends the game (if any) and goes back to the character list.
func _leave_game() -> void:
	store.flush()
	if game != null:
		game.leave()
		game.queue_free()
		game = null
	debug_overlay.client = null
	_playing = null
	for w: Control in _panel_windows() + [class_choice_window, trainer_menu, upgrade_window]:
		w.visible = false
	combat_hud.unbind()
	combat_hud.visible = false
	party_frames.unbind()
	party_frames.visible = false
	downed_overlay.unbind()
	downed_overlay.visible = false
	chat.cancel()
	chat.clear()
	chat.visible = false
	status_label.visible = false
	pause_menu.reset()
	_show_select()
