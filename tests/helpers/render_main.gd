extends SceneTree
## Screenshot of the real menus over the altar scene (Plan 7):
##   Godot --path . -s tests/helpers/render_main.gd -- --screen=title|select|create|game|map|loading
## Uses a throwaway characters folder. Saves user://render/main_<screen>.png.

var _screen := "title"
var _frames := 0
var _main: Main
## --hover: light the buttons up as if the mouse were over them (MenuFx).
var _hover := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			_screen = arg.trim_prefix("--screen=")
		elif arg == "--hover":
			_hover = true
	root.size = Vector2i(1280, 720)
	_main = Main.new()
	_main.settings_path = "user://render_main_settings.json"
	_main.characters_dir = "user://render_main_chars"
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		match _screen:
			"select":
				if _main.store.load_all().is_empty():
					_main.store.create("Brunhild", CharacterCatalog.DEFAULT_CLASS, {"race": "dwarf", "hair_style": "hair_warrior_braid", "beard": "dwarf_braided", "hair_color": "auburn"})
					_main.store.create("Sslith", CharacterCatalog.DEFAULT_CLASS, {"race": "lizard", "skin": "lizard_jade"})
				_main._show_select()
			"create":
				_main._show_create()
			"game", "map", "loading":
				_main._on_play("Prueba") # Plan 8.1.1: the HUD, minimap, icon bar (and map)
	if _frames == 90 and _screen == "map":
		_main._toggle_window(_main.map_window)
	if _frames == 100 and _hover:
		for b: Node in _main.find_children("*", "BaseButton", true, false):
			if (b as Control).is_visible_in_tree() and (b as Node).name != "Play":
				MenuFx.set_hover(b as Control, true, true)
	if _screen == "loading" and _frames == 12:
		_main.game.loading.set_progress(0.4) # mid-load (the shot is taken while it loads)
	if _frames == (300 if _screen in ["game", "map"] else (14 if _screen == "loading" else 120)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/main_%s%s.png" % [_screen, "_hover" if _hover else ""]
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
