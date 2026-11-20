extends SceneTree
## Art checkpoint for the cleric's holy effects (needs a window, not --headless): the
## smite cross, a heal cross, shield wings, the nova, a column, the hymn, the angel and a
## consecrated circle, side by side on the arena, frozen mid-effect. Saves
## user://render/holy.png.
##   Godot --path . -s tests/helpers/render_holy.gd

var _frames := 0
var _fx: CombatFX
var _spots: Dictionary = {}


func _initialize() -> void:
	root.size = Vector2i(1600, 700)
	var arena := Arena.new()
	root.add_child(arena)
	arena.build(Arena.load_layout())
	_fx = CombatFX.new()
	root.add_child(_fx)
	_fx.setup(func(id: int) -> Variant: return _spots.get(id), func() -> int: return 0, AbilityDB.load_default(), 30)
	_fx.set_process(false)
	var x := 14.9
	for i in 8:
		_spots[100 + i] = Vector3(x + i * 1.6, 0, 18.5)
	_fx.handle(["projectile", 1, 100, "cleric_smite", _spots[100], Vector2(0, 1), 0.0, 20.0])
	for pair: Array in [[101, "cleric_heal", "heal"], [102, "cleric_shield", "shield"], [107, "cleric_resurrection", "revived"]]:
		_fx.handle(["cast", pair[0], pair[1], _spots[pair[0]], 1.0])
		match str(pair[2]):
			"heal": _fx.handle(["heal", pair[0], 40.0])
			"shield": _fx.handle(["status", pair[0], "shield", 300])
			"revived": _fx.handle(["revived", pair[0], 1])
	_fx.handle(["cast", 103, "cleric_holy_nova", _spots[103], 1.0])
	_fx.handle(["cast", 104, "cleric_purify", _spots[104], 1.0])
	_fx.handle(["cast", 105, "cleric_divine_hymn", _spots[105], 1.0])
	_fx.handle(["area", 9, _spots[106], 1.5, "cleric_consecration", 5, 1.0])
	for i in 8:
		var rig := HumanRig.build(CharacterCatalog.load_default().resolve("cleric", {"hair_style": "short"}))
		rig.position = _spots[100 + i]
		root.add_child(rig)
	_fx.advance(0.3)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(20.5, 5.0, 18.5 + 10.5), Vector3(20.5, 1.2, 18.5))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://render"))
		root.get_texture().get_image().save_png("user://render/holy.png")
		print("saved ", ProjectSettings.globalize_path("user://render/holy.png"))
		return true
	return false
