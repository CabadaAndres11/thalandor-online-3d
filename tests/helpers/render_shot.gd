extends SceneTree
## One picture of a zone from any camera (needs a window):
##   Godot --path . -s tests/helpers/render_shot.gd -- --zone=capital --at=48,6,72 --look=48,1,58 [--fov=48] [--variant=asalto] [--name=x]
## Saves user://render/shot_<name>.png.

var _frames := 0
var _name := "shot"


func _initialize() -> void:
	var zone := "aldea"
	var variant := ""
	var at := Vector3(0, 10, 10)
	var look := Vector3.ZERO
	var fov := 50.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--variant="):
			variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--name="):
			_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--fov="):
			fov = float(arg.trim_prefix("--fov="))
		elif arg.begins_with("--at="):
			var p := arg.trim_prefix("--at=").split(",")
			at = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif arg.begins_with("--look="):
			var p := arg.trim_prefix("--look=").split(",")
			look = Vector3(float(p[0]), float(p[1]), float(p[2]))
	root.size = Vector2i(1280, 720)
	var layout := ZoneLayout.load_variant(zone, variant)
	var view := ZoneView.new()
	root.add_child(view)
	view.build(layout, GraphicsQuality.HIGH)
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.look_at_from_position(at, look)
	view.follow(look)
	view.show_gates(QuestLog.new()) # gates as a new story sees them (closed)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/shot_%s.png" % _name
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
