extends SceneTree
## Art checkpoint tool (needs a window, not --headless): lines up characters on the
## arena's ground and light and saves user://render/<name>.png.
##   Godot --path . -s tests/helpers/render_characters.gd -- --set=spike
## Each set is a list of looks (see CharacterRig.build) or, from Task 4 on, of
## [class_id, appearance] pairs resolved through CharacterCatalog.

const LAYERS := "res://assets/characters/layers/"
const PIECES := "res://assets/characters/pieces/"
const SPACING := 1.3

var _frames := 0
var _name := "spike"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_name = arg.trim_prefix("--set=")
	root.size = Vector2i(1600, 700)
	var arena := Arena.new()
	root.add_child(arena)
	arena.build(Arena.load_layout())
	var looks := _looks(_name)
	var origin := Vector3(20.5 - (looks.size() - 1) * SPACING / 2.0, 0, 18.5)
	for i in looks.size():
		var rig := CharacterRig.build(looks[i])
		rig.position = origin + Vector3(i * SPACING, 0, 0)
		rig.rotation_degrees.y = float(looks[i].get("rot", 0.0))
		root.add_child(rig)
		if rig.animation_player != null and rig.animation_player.has_animation("idle"):
			rig.animation_player.play("idle")
	var cam := Camera3D.new()
	cam.fov = 30
	root.add_child(cam)
	cam.look_at_from_position(Vector3(20.5, 4.2, 18.5 + 9.5), Vector3(20.5, 0.9, 18.5))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		var path := "user://render/%s.png" % _name
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false


func _looks(set_name: String) -> Array:
	match set_name:
		"spike":
			var mage := {
				"hair_layer": LAYERS + "hair_short.png", "beard_layer": "",
				"outfit_layer": LAYERS + "outfit_mage.png",
				"primary": Color("#5b3f9e"), "secondary": Color("#e8b23a"),
				"pieces": [{"id": "hat_mage", "file": PIECES + "hat_mage.vox", "part": "head", "offset": [-7, 8, -7]}],
			}
			var a := mage.duplicate(true)
			a.merge({"skin_color": Color("#f1c8a4"), "eyes_color": Color("#3d7cc9"), "hair_color": Color("#4a3426")}, true)
			var b := mage.duplicate(true)
			b.merge({"skin_color": Color("#8d5a3b"), "eyes_color": Color("#3b2a1e"), "hair_color": Color("#1d1a19"),
				"beard_layer": LAYERS + "beard_full.png"}, true)
			var c := mage.duplicate(true)
			c.merge({"skin_color": Color("#d9a27a"), "eyes_color": Color("#3f8f4e"), "hair_color": Color("#c9c3b8"),
				"beard_layer": LAYERS + "beard_full.png"}, true)
			var d := mage.duplicate(true)
			d.merge({"skin_color": Color("#f6d9c0"), "eyes_color": Color("#6a4a2a"), "hair_color": Color("#c4542a"),
				"pieces": [{"id": "hair_long", "file": PIECES + "hair_long.vox", "part": "head", "offset": [-5, -3, -6]}]}, true)
			var e := d.duplicate(true)
			e["rot"] = 160.0
			return [a, b, c, d, e]
		"classes":
			return _resolved([
				["warrior", {"skin": "skin_4", "hair_style": "short", "hair_color": "dark_brown", "beard": "full", "body": "robust"}],
				["cleric", {"skin": "skin_2", "hair_style": "bald", "hair_color": "grey", "beard": "short", "eyes": "blue"}],
				["mage", {"skin": "skin_6", "hair_style": "bob", "hair_color": "white", "beard": "goatee", "eyes": "amber"}],
				["archer", {"skin": "skin_3", "hair_style": "swept", "hair_color": "blond", "eyes": "green"}],
				["assassin", {"skin": "skin_7", "hair_style": "short", "hair_color": "black", "eyes": "grey"}],
			])
		"classes_back":
			var looks := _looks("classes")
			for l: Dictionary in looks:
				l["rot"] = 180.0
			return looks
		"warrior":
			return _resolved([
				["warrior", {"skin": "skin_3", "hair_style": "short", "hair_color": "dark_brown", "beard": "full"}],
				["warrior", {"skin": "skin_6", "hair_style": "hair_ponytail", "hair_color": "black", "body": "robust"}, 35.0],
				["warrior", {"skin": "skin_2", "hair_style": "bald", "beard": "mustache", "hair_color": "red"}, 90.0],
				["warrior", {"skin": "skin_4", "hair_style": "hair_long", "hair_color": "blond"}, 180.0],
			])
		"variety":
			return _resolved([
				["warrior", {"hair_style": "hair_long", "hair_color": "red", "skin": "skin_1"}],
				["warrior", {"hair_style": "hair_ponytail", "hair_color": "chestnut", "skin": "skin_5", "body": "robust"}],
				["warrior", {"hair_style": "hair_bun", "hair_color": "platinum", "skin": "skin_8"}],
				["warrior", {"hair_style": "hair_mohawk", "hair_color": "navy", "skin": "skin_3", "beard": "mustache"}],
				["warrior", {"hair_style": "hair_ponytail", "hair_color": "brown", "skin": "skin_2"}, 160.0],
				["warrior", {"hair_style": "hair_bun", "hair_color": "black", "skin": "skin_6"}, 200.0],
			])
	push_error("unknown set " + set_name)
	return []


## [class_id, appearance(, rotation)] -> looks through the catalog.
func _resolved(list: Array) -> Array:
	var catalog := CharacterCatalog.load_default()
	var looks := []
	for entry: Array in list:
		var look := catalog.resolve(entry[0], entry[1])
		if entry.size() > 2:
			look["rot"] = entry[2]
		looks.append(look)
	return looks
