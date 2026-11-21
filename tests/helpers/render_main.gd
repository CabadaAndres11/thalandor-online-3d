extends SceneTree
## Screenshot of the real menus over the altar scene (Plan 7):
##   Godot --path . -s tests/helpers/render_main.gd -- --screen=title|select|create
## Uses a throwaway characters folder. Saves user://render/main_<screen>.png.

var _screen := "title"
var _frames := 0
var _main: Main


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			_screen = arg.trim_prefix("--screen=")
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
	if _frames == 120:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/main_%s.png" % _screen
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
