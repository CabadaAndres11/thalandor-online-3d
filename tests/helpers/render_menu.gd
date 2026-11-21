extends SceneTree
## Screenshot of the menu scene (Plan 7) at one of its shots, for reviewing the art:
##   Godot --path . -s tests/helpers/render_menu.gd -- --shot=title|select|create
## Saves user://render/menu_<shot>.png.

var _shot := "title"
var _frames := 0
var _scene: MenuScene


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	root.size = Vector2i(1280, 720)
	_scene = MenuScene.new()
	root.add_child(_scene)
	_scene.build()
	_scene.set_quality(GraphicsQuality.HIGH)
	if _shot != "title":
		_scene.show_character(CharacterCatalog.load_default().resolve("villager", {"race": "dwarf", "hair_style": "hair_warrior_braid", "beard": "dwarf_braided", "hair_color": "auburn"}))
	_scene.set_shot(_shot, true)
	_scene._time = 8.0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/menu_%s.png" % _shot
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
