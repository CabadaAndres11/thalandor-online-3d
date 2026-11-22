extends SceneTree
## Screenshots of a zone (Plan 8.1), from above and from the game's camera angle:
##   Godot --path . -s tests/helpers/render_zone.gd -- --zone=aldea [--view=top|iso] [--at=x,z]
## Saves user://render/zone_<zone>_<view>.png.

var _zone := "aldea"
var _view := "iso"
var _at := Vector2(-1, -1)
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			_zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--view="):
			_view = arg.trim_prefix("--view=")
		elif arg.begins_with("--at="):
			var p := arg.trim_prefix("--at=").split(",")
			_at = Vector2(float(p[0]), float(p[1]))
	root.size = Vector2i(1600, 900)
	var layout := ZoneLayout.load_id(_zone)
	var view := ZoneView.new()
	root.add_child(view)
	view.build(layout, GraphicsQuality.HIGH)
	var cam := Camera3D.new()
	root.add_child(cam)
	var size := Vector2(layout.size)
	var center := Vector3(size.x / 2.0, 0, size.y / 2.0)
	if _view == "top":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(size.x, size.y) * 1.05
		cam.look_at_from_position(center + Vector3(0, 120, 0.01), center)
	else:
		var focus := Vector3(_at.x, 0, _at.y) if _at.x >= 0 else layout.entry("default")
		cam.fov = 40
		cam.look_at_from_position(focus + Vector3(0, 16, 16), focus)
		view.follow(focus)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/zone_%s_%s.png" % [_zone, _view]
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
