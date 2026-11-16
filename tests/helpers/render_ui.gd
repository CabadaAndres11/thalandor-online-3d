extends SceneTree
## UI checkpoint tool (needs a window): opens the real Main with three sample
## characters in a temporary folder and saves the character list and the create
## screen and a solo game with the combat HUD to user://render/ui_select.png,
## ui_create.png and ui_hud.png.

const DIR := "user://render_ui_chars"

var _main: Main
var _frames := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_clear()
	var store := CharacterStore.new(DIR)
	store.create("Aldric", "warrior", {"beard": "full", "hair_color": "dark_brown", "body": "robust"})
	store.create("Lyra", "archer", {"hair_style": "hair_ponytail", "hair_color": "blond", "skin": "skin_2"})
	store.create("Morwen", "mage", {"hair_style": "bob", "hair_color": "white", "skin": "skin_6"})
	_main = load("res://game/main.tscn").instantiate()
	_main.settings_path = "user://render_ui_settings.json"
	_main.characters_dir = DIR
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_main._show_select()
	elif _frames == 40:
		_save("ui_select")
		_main._show_create()
		_main.create_screen.name_edit.text = "Nombre-Largo-16c"
		_main.create_screen.name_edit.text_changed.emit("Nombre-Largo-16c")
	elif _frames == 80:
		_save("ui_create")
		_main._on_play("Lyra", "archer")
	elif _frames == 200:
		_save("ui_hud")
		# Combat: next to the orc king at 60 % (phase 2), with two allies in the frames
		# (one downed) for the party frames.
		var w := _main.game.host.world
		var me: PlayerState = w.players[_main.game.client.my_id]
		me.position = Vector3(23.5, 0, 10.0)
		me.stats.max_hp = 99999.0
		me.hp = 99999.0
		for m: CombatEntity in w.monsters.values():
			if m.type_id == "guard_beast":
				m.hp = m.stats.max_hp * 0.6
		var c := _main.game.client
		c.roster[90] = {"name": "Bea", "slot": 1, "class_id": "cleric", "appearance": {}}
		c.roster[91] = {"name": "Cris", "slot": 2, "class_id": "mage", "appearance": {}}
	elif _frames > 200 and _frames < 290:
		var c := _main.game.client
		c.combat[90] = {"hp": 120.0, "max_hp": 150.0, "life": CombatEntity.ALIVE, "status_bits": 0, "resource": 0.0, "max_resource": 100.0, "combo": 0, "charge": 0.0}
		c.combat[91] = {"hp": 0.0, "max_hp": 130.0, "life": CombatEntity.DOWNED, "status_bits": 0, "resource": 0.0, "max_resource": 100.0, "combo": 0, "charge": 0.0}
	elif _frames == 290:
		_save("ui_combat")
		var c := _main.game.client
		_main.abilities_window.show_for(c.class_id, c.bar, _main.abilities)
		_main.abilities_window.select_ability("archer_shot")
	elif _frames == 300:
		_save("ui_abilities")
		_main.abilities_window.visible = false
		_main.class_choice_window.show_for({"hair_style": "bob", "beard": "none"})
		_main.class_choice_window.select("cleric")
	elif _frames == 330:
		_save("ui_classes")
		_main.class_choice_window.visible = false
		# A level 35 archer with points spent and a few talents, for the progression windows.
		var w := _main.game.host.world
		var me: PlayerState = w.players[_main.game.client.my_id]
		Xp.set_level(w, me, 35)
		for a: String in ["agility", "agility", "stamina", "strength"]:
			ProgressRequests.spend_attribute(w, me, a)
		for id: String in ["might_1", "might_2", "might_3", "bastion_1", "bastion_2", "arcane_1"]:
			ProgressRequests.buy_talent(w, me, id)
	elif _frames == 345:
		_main._show_character()
	elif _frames == 375:
		_save("ui_character")
		_main.character_window.visible = false
		var c := _main.game.client
		_main.talents_window.show_for(c.progress, TalentDB.load_default(), c.balance)
		_main.talents_window.select("might_4")
	elif _frames == 405:
		_save("ui_talents")
		_main.talents_window.visible = false
		var c := _main.game.client
		_main.trainer_menu.show_for(NpcInteraction.trainer_options(c.class_id, c.progress, true, false))
	elif _frames == 435:
		_save("ui_trainer")
		_main.trainer_menu.visible = false
		_clear()
		return true
	return false


func _save(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
	var path := "user://render/%s.png" % file_name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _clear() -> void:
	var abs := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
	var settings := ProjectSettings.globalize_path("user://render_ui_settings.json")
	if FileAccess.file_exists(settings):
		DirAccess.remove_absolute(settings)
