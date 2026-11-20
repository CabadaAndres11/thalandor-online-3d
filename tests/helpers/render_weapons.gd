extends SceneTree
## Art checkpoint for weapons (needs a window, not --headless): every melee weapon of one
## tier standing point-up in a row on a dark background, like a reference sheet. Saves
## user://render/weapons_sheet_t<tier>.png.
##   Godot --path . -s tests/helpers/render_weapons.gd -- --tier=2

const FAMILIES := ["sword", "short_sword", "dagger", "greatsword", "axe", "great_axe", "mace", "warhammer", "halberd", "scepter"]

var _frames := 0
var _tier := 2


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = int(arg.trim_prefix("--tier="))
	root.size = Vector2i(1800, 700)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#0d0d1c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.62)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var cat := CharacterCatalog.load_default()
	var x := 0.3
	var tallest := 0.0
	for fam: String in FAMILIES:
		var p := cat.piece_v2("w_%s_t%d" % [fam, _tier])
		if p.is_empty():
			continue
		var mesh := VoxMesher.cached(str(p.file), ItemIcons.ICON_TINTS)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var holder := Node3D.new()
		holder.rotation_degrees = Vector3(-90, 0, 0) # the grip's +Z points up
		holder.add_child(mi)
		var box := mesh.get_aabb()
		mi.position = -Vector3(box.get_center().x, box.get_center().y, box.position.z)
		var turn := Node3D.new()
		turn.rotation_degrees.y = 35.0
		turn.position = Vector3(x, 0, 0)
		turn.add_child(holder)
		root.add_child(turn)
		x += maxf(box.size.y, 0.35) + 0.35
		tallest = maxf(tallest, box.size.z)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := 1280.0 / 720.0 # the window the sheet is taken from
	cam.size = maxf(tallest * 1.1, x / aspect * 1.15)
	root.add_child(cam)
	cam.look_at_from_position(Vector3(x / 2.0 - 0.35, tallest / 2.0, 6.0), Vector3(x / 2.0 - 0.35, tallest / 2.0, 0))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/weapons_sheet_t%d.png" % _tier
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false
