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
## The minimap and the zone map (M), Plan 8.1.1.
var minimap: Minimap
var map_window: MapWindow
## The windows as icons in the top-right corner (Plan 8.1.1).
var icon_bar: IconBar
const MINIMAP_MARGIN := Vector2(12, 64)
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
var upgrade_window: UpgradeWindow
## At a dungeon's door: choose its level (Plan 8.1).
var dungeon_window: DungeonWindow
var dialogue_window: DialogueWindow
var cutscene_overlay: CutsceneOverlay
var quest_journal: QuestJournal
var quest_tracker: QuestTracker
var quest_notice: QuestNotice
var quest_turn_in: QuestTurnInWindow
## The capital's trainer: resets for gold (Plan 8.3b).
var reset_window: ResetWindow
## After a dialogue or a blocking window closes, attacks wait this long (Plan 8.3c).
const UNBLOCK_GRACE_MS := 250
var _unblock_at_ms: int = 0
var _turn_in_quest: String = ""
## A scene the host said to play while the zone was still loading (Plan 8.2).
var _pending_scene: String = ""
var _playing_scene: String = ""
var _hud_before: Dictionary = {}
## The conversation open now: {npc, quest, kind, dialogue} (Plan 8.2).
var _talk: Dictionary = {}
## The id of an NPC's greeting shown in the dialogue window: this prefix and the NPC's id.
const GREET_DIALOGUE := "greet:"
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
	icon_bar = IconBar.new()
	icon_bar.visible = false
	icon_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	icon_bar.position = Vector2(-icon_bar.get_combined_minimum_size().x - MINIMAP_MARGIN.x, 10)
	icon_bar.pressed_entry.connect(_on_icon)
	_ui.add_child(icon_bar)
	minimap = Minimap.new()
	minimap.visible = false
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-Minimap.SIZE - MINIMAP_MARGIN.x, MINIMAP_MARGIN.y)
	_ui.add_child(minimap)
	quest_tracker = QuestTracker.new()
	quest_tracker.theme = theme
	quest_tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN # flush with the right margin (Plan 8.3c)
	quest_tracker.offset_right = -MINIMAP_MARGIN.x
	quest_tracker.offset_left = quest_tracker.offset_right - quest_tracker.custom_minimum_size.x
	quest_tracker.offset_top = MINIMAP_MARGIN.y + Minimap.SIZE + 34
	_ui.add_child(quest_tracker)
	quest_notice = QuestNotice.new()
	quest_notice.theme = theme
	_ui.add_child(quest_notice)

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

	map_window = MapWindow.new()
	map_window.theme = theme
	_ui.add_child(map_window)

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
	character_window.head_visibility_toggled.connect(func() -> void: _request_item("toggle_head", []))
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


	dialogue_window = DialogueWindow.new()
	dialogue_window.theme = menu_theme
	dialogue_window.finished.connect(_on_dialogue_finished)
	dialogue_window.closed.connect(_on_dialogue_closed)
	dialogue_window.flags_set.connect(_on_dialogue_flags)
	dialogue_window.action.connect(_on_dialogue_action)
	_ui.add_child(dialogue_window)

	quest_journal = QuestJournal.new()
	quest_journal.theme = theme
	quest_journal.track_requested.connect(func(id: String) -> void: game.client.request_quest("track", [id]))
	quest_journal.abandon_requested.connect(func(id: String) -> void: game.client.request_quest("abandon", [id]))
	_ui.add_child(quest_journal)
	quest_turn_in = QuestTurnInWindow.new()
	quest_turn_in.theme = theme
	quest_turn_in.confirmed.connect(func(choice: String) -> void: game.client.request_quest("turn_in", [_turn_in_quest, choice]))
	_ui.add_child(quest_turn_in)
	reset_window = ResetWindow.new()
	reset_window.theme = theme
	reset_window.reset_requested.connect(func(what: String) -> void: game.client.reset_progress(what))
	_ui.add_child(reset_window)

	cutscene_overlay = CutsceneOverlay.new()
	cutscene_overlay.theme = menu_theme
	cutscene_overlay.skip_requested.connect(_on_scene_skip)
	_ui.add_child(cutscene_overlay)

	pause_menu = PauseMenu.new()
	pause_menu.theme = theme
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.leave_requested.connect(_leave_game)
	pause_menu.quit_requested.connect(_ask_quit)
	pause_menu.open_group_requested.connect(_on_open_group)
	pause_menu.join_requested.connect(_on_pause_join)
	pause_menu.options_requested.connect(_show_options)
	pause_menu.leave_group_requested.connect(_on_leave_group)
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
	if game == null or chat.is_typing() or dialog.visible or cutscene_overlay.visible:
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
	elif event.is_action_pressed("window_quests"):
		_toggle_window(quest_journal)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("abilities_window"):
		_toggle_window(abilities_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_character"):
		_toggle_window(character_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_talents"):
		_toggle_window(talents_window)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("window_map"):
		_toggle_window(map_window)
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
	return [abilities_window, character_window, talents_window, map_window, quest_journal]


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
	return class_choice_window.visible or upgrade_window.visible or dungeon_window.visible \
		or dialogue_window.visible or quest_turn_in.visible or reset_window.visible


## Esc: closes whatever window is open and says whether there was one.
func _close_open_window() -> bool:
	for w: Control in [class_choice_window, upgrade_window, reset_window] + _panel_windows() + [merchant_window, inventory_window]:
		if w.visible:
			if (w == upgrade_window and upgrade_window.mandatory) or (w == class_choice_window and class_choice_window.mandatory):
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
			talents_window.show_for(game.client.progress, TalentDB.load_default(), game.client.balance, game.client.class_id)
		quest_journal:
			quest_journal.show_for(game.client.quests, QuestDB.load_default(), ItemDB.load_default(), game.client.inventory)
		map_window:
			var layout := game.zone_view.layout
			map_window.refresh(game.map_texture, ZoneMapImage.markers(layout, game.client), layout.name)
			map_window.visible = true


func _show_character() -> void:
	var c := game.client
	var char_name: String = c.roster[c.my_id].name if c.roster.has(c.my_id) else c.player_name
	character_window.show_for(char_name, c.class_id, c.progress, Progression.preview_stats(c.class_id, c.progress, c.balance, c.inventory),
		c.balance, c.appearance, c.inventory)


## E next to an NPC: a villager by Brann chooses a class; otherwise the NPC's dialogue for
## this player (Plan 8.2), or else its trade, Brann's menu or a greeting.
func _on_interact() -> void:
	if dialogue_window.visible:
		return
	var point := game.quest_point_near()
	if point != "":
		game.client.request_quest("interact", [point])
		return
	var r := game.interaction()
	if str(r.npc) == "":
		var me := game.client.render_state(game.client.my_id)
		var walker := game.walker_near(me.position) if not me.is_empty() else ""
		if walker != "":
			_greet(walker)
			return
	if str(r.npc) != "" and _talk_to(str(r.npc)):
		return
	match str(r.action):
		NpcInteraction.TRADE:
			_request_item("merchant_open", []) # the host answers with the stock
		NpcInteraction.TALK:
			if str(NpcDB.load_default().npc(str(r.npc)).get("role", "")) == "class_trainer":
				_open_resets()
			else:
				_greet(str(r.npc))


## The capital's trainer: the resets window with this player's price (Plan 8.3b).
func _open_resets() -> void:
	reset_window.show_for(game.client.progress, game.client.inventory.gold, game.client.balance)


## An NPC with nothing for this player greets in the dialogue window (2026-11-27: no longer in
## the chat). A greeting is not a story conversation: the host is not told when it ends.
func _greet(npc_id: String) -> void:
	var lines: Dictionary = NpcDB.load_default().npc(npc_id).get("lines", {})
	if not lines.has("greet"):
		return
	var runner := DialogueRunner.from_lines(GREET_DIALOGUE + npc_id, [[npc_id, str(lines.greet)]])
	_open_talk(npc_id, runner, {"npc": npc_id, "quest": "", "kind": "greet", "dialogue": runner.id})


## Opens what an NPC has for this player (NpcTalk): its dialogue, or the turn-in. False when it
## has nothing of its own (then E does what it always did: trade, train, greet).
func _talk_to(npc_id: String) -> bool:
	var c := game.client
	var pick := NpcTalk.pick(npc_id, c.quests, c.progress.level, c.class_id, QuestDB.load_default())
	var dialogue := str(pick.dialogue)
	if dialogue == "":
		if str(pick.kind) == "turn_in":
			_open_turn_in(str(pick.quest))
			return true
		if str(pick.kind) == "offer":
			c.request_quest("accept", [str(pick.quest)])
			return true
		return false
	var runner := DialogueRunner.load_id(dialogue)
	if runner == null:
		push_warning("Main: no dialogue " + dialogue)
		return false
	_open_talk(npc_id, runner, {"npc": npc_id, "quest": str(pick.quest), "kind": str(pick.kind), "dialogue": dialogue})
	return true


## Shows a conversation with an NPC: the panels close and the NPC turns to the player.
func _open_talk(npc_id: String, runner: DialogueRunner, talk: Dictionary) -> void:
	var c := game.client
	runner.start(c.quests)
	_talk = talk
	for w: Control in _panel_windows():
		w.visible = false
	var avatar := game.npc_avatar(npc_id)
	var me := c.render_state(c.my_id)
	if avatar != null and not me.is_empty():
		avatar.face(me.position)
	var npc := NpcDB.load_default().npc(npc_id)
	dialogue_window.show_for(runner, tr(str(npc.get("name", npc_id))), c.player_name, _epithet())


## The player's epithet once the story gives it (the flag "apodo"): Thal An Dor.
func _epithet() -> String:
	return tr("PLAYER_EPITHET") if game != null and game.client.quests.has_flag("apodo") else ""


func _on_dialogue_flags(flags: Array) -> void:
	for f: String in flags:
		game.client.request_quest("choose_flag", [str(_talk.get("dialogue", "")), f])


func _on_dialogue_action(name: String, arg: String) -> void:
	var npc := str(_talk.get("npc", ""))
	match name:
		"accept":
			game.client.request_quest("accept", [str(_talk.get("quest", ""))])
		"turn_in":
			_open_turn_in(str(_talk.get("quest", "")))
		"trade":
			_request_item("merchant_open", [])
		"scene":
			_play_scene(arg)


func _on_dialogue_finished(dialogue_id: String) -> void:
	if game != null and game.client != null and str(_talk.get("kind", "")) != "greet":
		game.client.request_quest("talk_done", [str(_talk.get("npc", "")), dialogue_id])
	_end_talk()


func _on_dialogue_closed() -> void:
	_end_talk()


func _end_talk() -> void:
	_talk = {}
	if game != null and game.camera != null:
		game.camera.focus(false)


## The rewards of a finished quest (Plan 8.2); without choices it is handed in at once.
func _open_turn_in(quest_id: String) -> void:
	var q := QuestDB.load_default().quest(quest_id)
	if q.is_empty():
		return
	if (q.rewards.get("choice", []) as Array).is_empty() and (q.rewards.get("items", []) as Array).is_empty():
		game.client.request_quest("turn_in", [quest_id, ""])
		return
	_turn_in_quest = quest_id
	quest_turn_in.show_for(q, ItemDB.load_default(), game.client.class_id, game.client.progress.level)


## A cutscene asked by a dialogue (Plan 8.2, T11 plays it).
func _play_scene(scene_id: String) -> void:
	if game != null and game.client != null:
		game.client.request_quest("scene_start", [scene_id]) # the host answers scene_go


## The host says the scene may play (out of combat, the player is safe): after loading.
func _start_scene(scene_id: String) -> void:
	if game.client.zone_loading or game.zone_building:
		_pending_scene = scene_id
		return
	var cut := game.play_cutscene(scene_id)
	if cut == null:
		game.client.request_quest("scene_done", [scene_id])
		return
	_playing_scene = scene_id
	dialogue_window.interrupt()
	for w: Control in _panel_windows() + [merchant_window, inventory_window]:
		w.visible = false
	_hud_before = {}
	for n: CanvasItem in [combat_hud, chat, party_frames, icon_bar, minimap]:
		_hud_before[n] = n.visible
		n.visible = false
	cutscene_overlay.open(bool(CutsceneData.load_id(scene_id).get("skippable", true)))
	cut.line.connect(_on_scene_line)
	cut.fade.connect(cutscene_overlay.set_fade)
	if not game.scene_flash.is_connected(cutscene_overlay.flash):
		game.scene_flash.connect(cutscene_overlay.flash)
	game.cutscene_ended.connect(_on_scene_ended, CONNECT_ONE_SHOT)


func _on_scene_line(speaker: String, text_key: String) -> void:
	var who := game.client.player_name if speaker == "player" else tr(str(NpcDB.load_default().npc(speaker).get("name", "")))
	if speaker != "player" and speaker != "" and who == "":
		who = tr(str(MonsterDB.load_default().get_type(speaker).get("name", ""))) # the Heraldo speaks too
	cutscene_overlay.show_line(who, DialogueRunner.format(text_key, game.client.player_name, _epithet()))


func _on_scene_skip() -> void:
	if game != null and game.cutscene != null:
		game.cutscene.skip()


func _on_scene_ended() -> void:
	cutscene_overlay.close()
	for n: CanvasItem in _hud_before:
		n.visible = _hud_before[n]
	_hud_before = {}
	if game != null and game.client != null:
		_open_class_choice_if_asked.call_deferred()
	if game != null and game.client != null and _playing_scene != "":
		game.client.request_quest("scene_done", [_playing_scene])
	_playing_scene = ""


## The upgrade window for the player's class (level 50; final, Plan 8.3a).
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
	if id == game.client.my_id:
		combat_hud.bind(game.client, game.client.bar, abilities) # the slots show the upgrade's variants
	if upgrade != "":
		var who: String = game.client.roster[id].name if game.client.roster.has(id) else "?"
		var name := tr(str(UpgradeDB.load_default().upgrade(upgrade).get("name", upgrade)))
		chat.add_message("", tr("CHAT_UPGRADE_CHOSEN") % [who, name], true)


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
	if id == game.client.my_id:
		quest_notice.show_text("UI_LEVEL_UP", str(level)) # big, in the middle (Plan 8.3d)
	if id == game.client.my_id and level >= ProgressRequests.UPGRADE_LEVEL and game.client.progress.upgrade == "" \
			and CharacterCatalog.load_default().is_selectable(game.client.class_id) \
			and not UpgradeDB.load_default().for_class(game.client.class_id).is_empty():
		chat.add_message("", tr("CHAT_UPGRADE_HINT"), true)
		_require_upgrade()


func _on_class_confirmed(class_id: String) -> void:
	if game == null or game.client == null:
		return
	# Only when the story asks for it (Plan 8.3a): the host checks it again.
	if not _story_asks_class():
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
		talents_window.show_for(c.progress, TalentDB.load_default(), c.balance, c.class_id)
	if abilities_window.visible:
		abilities_window.show_for(c.class_id, c.bar, abilities, c.progress.level, c.progress.upgrade)
	if _playing == null:
		return
	_playing.progress = c.progress.copy()
	_playing.bar = c.bar.duplicate()
	store.queue_save(_playing)


## The host sent this player's inventory: open windows show it and the saved character keeps it.
func _refresh_quest_ui() -> void:
	if game == null or game.client == null:
		return
	_open_class_choice_if_asked()
	var db := QuestDB.load_default()
	quest_tracker.refresh(game.client.quests, db, game.client.inventory)
	if quest_journal.visible:
		quest_journal.show_for(game.client.quests, db, ItemDB.load_default(), game.client.inventory)
	game.refresh_quest_marks()


## The step being done asks to choose a class (Plan 8.3a: the awakening).
func _story_asks_class() -> bool:
	var c := game.client
	if CharacterCatalog.load_default().is_selectable(c.class_id):
		return false
	for id: String in c.quests.active:
		var objs := QuestText.objectives(c.quests, QuestDB.load_default(), id)
		var asks := false
		var scene_first := false # the awakening scene plays before the window opens
		for i in objs.size():
			var o: Dictionary = objs[i]
			asks = asks or str(o.type) == "class"
			if str(o.type) == "scene" and int(c.quests.active[id].counts[i]) < int(o.count):
				scene_first = true
		if asks and not scene_first:
			return true
	return false


## The class window opens by itself when the story asks for it, and cannot be closed.
func _open_class_choice_if_asked() -> void:
	if class_choice_window.visible or cutscene_overlay.visible or not _story_asks_class():
		return
	class_choice_window.mandatory = true
	class_choice_window.show_for(game.client.appearance)


## Quest notices (Plan 8.2), only for this player (the host sends them to their owner).
func _quest_notice(ev: Array) -> void:
	var db := QuestDB.load_default()
	match str(ev[0]):
		"quest_started":
			quest_notice.show_text("UI_QUEST_NEW", tr(str(db.quest(str(ev[2])).get("name", ""))))
		"quest_step":
			quest_notice.show_text("UI_QUEST_STEP", "")
		"quest_done":
			quest_notice.show_text("UI_QUEST_DONE_NOTICE", tr(str(db.quest(str(ev[2])).get("name", ""))))
		"quest_bag_full":
			quest_notice.show_text("UI_QUEST_BAG_FULL", "")


## The host changed this character's quests: saved (a story mark may unlock group play).
func _on_quests_changed() -> void:
	if game == null or game.client == null:
		return
	_refresh_quest_ui()
	if _playing == null:
		return
	_playing.quests = game.client.quests.duplicate()
	if "tutorial_done" in _playing.quests.marks and not _playing.tutorial_done:
		_playing.tutorial_done = true
		pause_menu.set_group_locked(false)
	store.queue_save(_playing)


func _on_inventory_changed() -> void:
	_refresh_quest_ui()
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
	_show_only(select_screen)
	if CharacterStore.should_notice(store.retired, settings):
		settings.old_characters_notice_seen = true
		settings.save_to(settings_path)
		dialog.show_message(tr("UI_OLD_CHARACTERS"))
	elif not store.skipped_files.is_empty():
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


## Joining a friend from the pause menu (Plan 8.1.1): the solo game ends (its character
## saved) and the same character joins the friend's group.
## "Abandonar grupo" (2026-11-27): the group is left (a host closes it) and the same
## character goes on alone, saved where it was.
func _on_leave_group() -> void:
	if _playing == null:
		return
	var id := _playing.id
	_leave_game()
	_on_select_play(id)


func _on_pause_join(code: String) -> void:
	if _playing == null or not _playing.tutorial_done:
		return
	if GroupCode.decode(code) == "":
		dialog.show_message(tr("ERR_BAD_CODE")) # the solo game goes on
		return
	var id := _playing.id
	_leave_game()
	_on_select_join(id, code)


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
	if pending.get("action", "") == "quit" and yes:
		_quit_game()
		return
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
		var typing := chat.is_typing()
		var blocked := pause_menu.visible or options_window.visible or dialog.visible or class_choice_window.visible \
			or upgrade_window.visible or dialogue_window.visible or cutscene_overlay.visible or reset_window.visible or quest_turn_in.visible
		# The click or number that closed it must not attack too (Plan 8.3c): a short grace.
		if blocked:
			_unblock_at_ms = Time.get_ticks_msec() + UNBLOCK_GRACE_MS
		game.input_blocked = typing or blocked or Time.get_ticks_msec() < _unblock_at_ms
		game.attacks_blocked = _panel_open()


func _process(_delta: float) -> void:
	_update_input_block()
	if _pending_scene != "" and game != null and game.client != null and not game.client.zone_loading and not game.zone_building:
		var s := _pending_scene
		_pending_scene = ""
		_start_scene(s)
	_update_minimap()
	_update_icon_bar()
	# Walking away from the merchant closes the trade.
	if merchant_window.visible and game != null and game.client != null 			and str(game.interaction().action) != NpcInteraction.TRADE:
		merchant_window.visible = false


## An icon of the bar: the same as its key.
func _on_icon(id: String) -> void:
	if game == null or game.client == null:
		return
	match id:
		"character":
			_toggle_window(character_window)
		"inventory":
			_toggle_inventory()
		"abilities":
			_toggle_window(abilities_window)
		"talents":
			_toggle_window(talents_window)
		"map":
			_toggle_window(map_window)
		"quests":
			_toggle_window(quest_journal)
		"menu":
			if not _close_open_window():
				pause_menu.visible = not pause_menu.visible


## The icons light up while their windows are open.
func _update_icon_bar() -> void:
	icon_bar.visible = game != null and game.client != null
	if not icon_bar.visible:
		return
	icon_bar.set_open("character", character_window.visible)
	icon_bar.set_open("inventory", inventory_window.visible)
	icon_bar.set_open("abilities", abilities_window.visible)
	icon_bar.set_open("talents", talents_window.visible)
	icon_bar.set_open("map", map_window.visible)
	icon_bar.set_open("menu", pause_menu.visible)


## The minimap follows the player and the camera (Plan 8.1.1); hidden by its setting.
func _update_minimap() -> void:
	var on := game != null and game.client != null and settings.minimap and game.map_texture != null
	minimap.visible = on
	if not on:
		return
	var own := game.client.render_state(game.client.my_id)
	if own.is_empty():
		return
	var pos: Vector3 = own.position
	var layout := game.zone_view.layout
	var marks := ZoneMapImage.markers(layout, game.client)
	minimap.refresh(game.map_texture, marks, Vector2(pos.x, pos.z), game.camera.yaw(), layout.name)
	if map_window.visible: # the arrow walks with you while the map is open (Plan 8.3d)
		map_window.refresh(game.map_texture, marks, layout.name)


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
		game.character_quests = _playing.quests.to_dict()
	pause_menu.join_code_edit.text = "" # never the last code (Plan 8.3d)
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
	client.quests_changed.connect(_on_quests_changed)
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
	if ev.size() >= 2 and str(ev[0]).begins_with("quest_") and game != null and game.client != null and int(ev[1]) == game.client.my_id:
		_quest_notice(ev)
	if ev.size() >= 3 and str(ev[0]) == "scene_go" and game != null and game.client != null and int(ev[1]) == game.client.my_id:
		_start_scene(str(ev[2]))
	if ev.size() >= 2 and str(ev[0]) == "hit" and game != null and game.client != null \
			and int(ev[1]) == game.client.my_id and dialogue_window.visible:
		dialogue_window.interrupt() # a blow ends the conversation
	if ev.size() >= 2 and str(ev[0]) in ["downed", "died"] and game != null and game.client != null \
			and int(ev[1]) == game.client.my_id:
		if not class_choice_window.mandatory:
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
## Cerrar juego (Plan 8.3d): asks first; on yes, saves like leaving and quits.
func _ask_quit() -> void:
	_pending = {"action": "quit"}
	dialog.ask(tr("ASK_QUIT"))


func _quit_game() -> void:
	if game != null:
		_leave_game()
	store.flush()
	get_tree().quit()


func _leave_game() -> void:
	store.flush()
	if game != null:
		game.leave()
		game.queue_free()
		game = null
	debug_overlay.client = null
	_playing = null
	for w: Control in _panel_windows() + [class_choice_window, upgrade_window]:
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
