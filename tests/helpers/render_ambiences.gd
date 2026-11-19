extends SceneTree
## Lighting checkpoint (needs a window, not --headless): the test arena with the game's
## isometric camera, the five classes, Brann and the merchant, in every ambience and quality
## level. Saves user://render/ambience_<id>_<quality>.png.
##   Godot --path . -s tests/helpers/render_ambiences.gd [-- --ambience=<id>] [-- --quality=0|1|2]

const QUALITY_NAMES := ["baja", "media", "alta"]
const FRAMES_PER_SHOT := 45

var _arena: Arena
var _shots: Array = [] # [ambience id, quality]
var _frames := 0
var _settings := SettingsStore.new()


func _initialize() -> void:
	var only_ambience := ""
	var only_quality := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ambience="):
			only_ambience = arg.trim_prefix("--ambience=")
		elif arg.begins_with("--quality="):
			only_quality = int(arg.trim_prefix("--quality="))
	for id: String in Ambience.ids():
		if only_ambience != "" and id != only_ambience:
			continue
		for q in 3:
			if only_quality == -1 or q == only_quality:
				_shots.append([id, q])
	root.size = Vector2i(1280, 720)
	_arena = Arena.new()
	root.add_child(_arena)
	var layout := Arena.load_layout()
	_arena.build(layout)
	var catalog := CharacterCatalog.load_default()
	var looks := [
		["warrior", {"skin": "skin_4", "hair_style": "short", "hair_color": "dark_brown", "beard": "full", "body": "robust"}],
		["cleric", {"skin": "skin_2", "hair_style": "bald", "hair_color": "grey", "beard": "short"}],
		["mage", {"skin": "skin_6", "hair_style": "bob", "hair_color": "white"}],
		["archer", {"skin": "skin_3", "hair_style": "swept", "hair_color": "blond"}],
		["assassin", {"skin": "skin_7", "hair_style": "short", "hair_color": "black"}],
	]
	var center := Vector3(21.5, 0, 21.0)
	for i in looks.size():
		var rig := HumanRig.build(catalog.resolve(looks[i][0], looks[i][1]))
		rig.position = center + Vector3((i - 2) * 1.3, 0, 0)
		rig.rotation_degrees.y = 200.0
		root.add_child(rig)
	var map := CollisionMap.from_layout(layout)
	for n: Dictionary in NpcDB.placed(map):
		var npc := NpcAvatar.new()
		root.add_child(npc)
		npc.setup(n.id, n.position, n.facing)
	var cam := IsoCamera.new()
	root.add_child(cam)
	cam.follow(center)
	_arena.follow(center)
	_start_shot()


func _start_shot() -> void:
	var shot: Array = _shots[0]
	_settings.quality = shot[1]
	SettingsApplier.apply_viewport(_settings, root)
	SettingsApplier.apply_quality_globals(shot[1])
	_arena.set_ambience(shot[0])
	_arena.set_quality(shot[1])
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < FRAMES_PER_SHOT:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
	var shot: Array = _shots.pop_front()
	var path := "user://render/ambience_%s_%s.png" % [shot[0], QUALITY_NAMES[shot[1]]]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	if _shots.is_empty():
		return true
	_start_shot()
	return false
