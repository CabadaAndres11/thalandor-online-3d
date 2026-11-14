extends SceneTree
## UI checkpoint tool (needs a window): opens the real Main with three sample
## characters in a temporary folder and saves the character list and the create
## screen to user://render/ui_select.png and ui_create.png.

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
		_main.create_screen.select_class("cleric")
	elif _frames == 80:
		_save("ui_create")
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
