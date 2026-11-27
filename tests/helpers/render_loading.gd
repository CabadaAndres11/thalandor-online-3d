extends SceneTree
## The loading screen pictures (Plan 8.1.2): real shots of each zone at eye height, with
## its ambience and NPCs, saved as assets/ui/loading/<zone>_<n>.jpg (needs a window):
##   Godot --path . -s tests/helpers/render_loading.gd [-- --only=aldea_1]

const OUT := "res://assets/ui/loading/"
const SIZE := Vector2i(1600, 900)
## name -> [zone, camera position, look-at point, fov]
const SHOTS := {
	"aldea_1": ["aldea", Vector3(50.0, 3.4, 49.0), Vector3(66.0, 2.2, 40.0), 58.0],
	"aldea_2": ["aldea", Vector3(26.0, 4.2, 30.0), Vector3(18.0, 2.5, 20.0), 58.0],
	"aldea_3": ["aldea", Vector3(52.0, 3.6, 46.0), Vector3(72.0, 2.4, 55.0), 58.0],
	"bosque_1": ["bosque", Vector3(14.0, 1.8, 63.0), Vector3(36.0, 2.5, 60.5), 60.0],
	"bosque_2": ["bosque", Vector3(99.0, 2.8, 91.0), Vector3(111.0, 0.8, 101.5), 58.0],
	"bosque_3": ["bosque", Vector3(72.0, 3.0, 58.0), Vector3(84.0, 1.5, 76.0), 60.0],
	"camino_1": ["camino", Vector3(10.0, 2.2, 33.0), Vector3(24.0, 1.4, 27.0), 58.0],
	"camino_2": ["camino", Vector3(70.0, 2.4, 36.0), Vector3(82.0, 1.5, 22.0), 58.0],
	"capital_1": ["capital", Vector3(48.5, 2.4, 62.0), Vector3(48.5, 4.0, 8.0), 58.0],
	"capital_2": ["capital", Vector3(40.0, 3.0, 50.0), Vector3(56.0, 1.5, 36.0), 58.0],
	"palacio_1": ["palacio", Vector3(20.0, 3.0, 50.0), Vector3(20.0, 2.4, 4.0), 55.0],
	"cripta_prueba_1": ["cripta_prueba", Vector3(24.5, 1.8, 5.0), Vector3(24.5, 1.6, 30.0), 60.0],
	"cripta_prueba_2": ["cripta_prueba", Vector3(14.0, 2.4, 30.0), Vector3(30.0, 1.0, 46.0), 60.0],
}

var _queue: Array = []
var _frames := 0
var _zone: ZoneView
var _cam: Camera3D
var _npcs: Array = []


func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	_queue = SHOTS.keys().filter(func(k: String) -> bool: return only == "" or k == only)
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_next()


func _next() -> void:
	if _zone != null:
		_zone.free()
		_cam.free()
		for n: Node in _npcs:
			n.free()
		_npcs.clear()
	var shot: Array = SHOTS[_queue[0]]
	var layout := ZoneLayout.load_id(str(shot[0]))
	_zone = ZoneView.new()
	root.add_child(_zone)
	_zone.build(layout, GraphicsQuality.HIGH)
	for n: Dictionary in NpcDB.placed(layout.collision()):
		var npc := NpcAvatar.new()
		root.add_child(npc)
		npc.setup(n.id, n.position, n.facing)
		npc.set_prompt_visible(false)
		for l: Node in npc.find_children("*", "Label3D", true, false):
			(l as Label3D).visible = false # a picture, no name tags
		_npcs.append(npc)
	_cam = Camera3D.new()
	_cam.fov = float(shot[3])
	root.add_child(_cam)
	_cam.look_at_from_position(shot[1], shot[2])
	_zone.follow(shot[2])
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 90:
		return false
	var name: String = _queue.pop_front()
	var path := OUT + name + ".jpg"
	root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.88)
	print("saved ", path)
	if _queue.is_empty():
		return true
	_next()
	return false
