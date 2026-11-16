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
	if _name == "skeleton" or _name == "skeleton_face":
		_skeleton_scene()
		return
	if _name == "boss":
		_boss_scene()
		return
	if _name == "monsters_b":
		_monsters_b()
		return
	if _name == "monsters_a":
		_combat_scene()
		return
	var looks := _looks(_name)
	var origin := Vector3(20.5 - (looks.size() - 1) * SPACING / 2.0, 0, 18.5)
	for i in looks.size():
		var rig := HumanRig.build(looks[i])
		rig.position = origin + Vector3(i * SPACING, 0, 0)
		rig.rotation_degrees.y = float(looks[i].get("rot", 0.0))
		root.add_child(rig)
		if looks[i].has("action") or looks[i].has("dx"):
			rig.position.x += (i - 3) * float(looks[i].get("dx", 0.35)) # spread the poses out
		var action := str(looks[i].get("action", ""))
		if action != "":
			rig.auto_update = false
			rig.update(rig.play_action(action) * float(looks[i].get("at", 0.4)))
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
		"actions":
			var out := []
			for a: Array in [["warrior", "melee", 0.25], ["warrior", "melee", 0.45], ["archer", "shoot", 0.5], ["mage", "cast", 0.3], ["assassin", "dash", 0.5], ["cleric", "downed", 1.0], ["warrior", "die", 1.0]]:
				var l: Dictionary = _resolved([[a[0], {"hair_style": "short", "beard": "short"}, 35.0]])[0]
				l["action"] = a[1]
				l["at"] = a[2]
				out.append(l)
			return out
		"grip":
			var out := []
			for a: Array in [["archer", "", 0.0, 50.0], ["archer", "shoot", 0.5, 70.0], ["mage", "", 0.0, 50.0], ["mage", "cast", 0.5, 70.0]]:
				var l: Dictionary = _resolved([[a[0], {"hair_style": "short"}, a[3]]])[0]
				l["dx"] = 0.6
				if a[1] != "":
					l["action"] = a[1]
					l["at"] = a[2]
				out.append(l)
			return out
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
		"red":
			return _resolved([
				["mage", {"hair_style": "bob", "hair_color": "crimson", "eyes": "red", "skin": "skin_1"}],
				["assassin", {"hair_style": "hair_mohawk", "hair_color": "crimson", "eyes": "red", "skin": "skin_7"}],
				["warrior", {"hair_style": "hair_long", "hair_color": "crimson", "eyes": "red", "skin": "skin_3"}],
				["archer", {"hair_style": "swept", "hair_color": "red", "eyes": "red", "skin": "skin_2"}],
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


## Combat checkpoint: two heroes facing wolves and slimes, a wolf mid-lunge, a ground
## warning, a projectile, a shield, damage numbers and health bars.
var _fx: CombatFX
var _spots: Dictionary = {}


func _spot(id: int) -> Variant:
	return _spots.get(id)


func _combat_scene() -> void:
	var catalog := CharacterCatalog.load_default()
	var heroes := [
		[1, "warrior", {"beard": "full", "hair_color": "dark_brown", "skin": "skin_3"}, Vector3(18.5, 0, 19.5), 0.35],
		[2, "mage", {"hair_style": "bob", "hair_color": "white", "skin": "skin_6"}, Vector3(16.8, 0, 18.3), 0.6],
	]
	for h: Array in heroes:
		var p := PlayerAvatar.new()
		root.add_child(p)
		p.setup("Aldric" if h[0] == 1 else "Morwen", h[0] - 1, h[1], h[2])
		p.position = h[3]
		p.rotation.y = h[4]
		p.set_health(140.0 if h[0] == 1 else 90.0, 200.0 if h[0] == 1 else 130.0)
		_spots[h[0]] = h[3]
	var db := MonsterDB.load_default()
	var monsters := [
		[1000, "wolf", Vector3(20.6, 0, 21.4), -2.6, 0.5],
		[1001, "wolf", Vector3(22.2, 0, 20.4), -2.2, 1.0],
		[1002, "wolf", Vector3(21.6, 0, 22.8), -2.7, 0.2],
		[1003, "slime", Vector3(18.0, 0, 23.0), PI, 0.7],
		[1004, "slime", Vector3(15.6, 0, 22.4), 2.6, 1.0],
	]
	var lunging: MonsterAvatar
	for m: Array in monsters:
		var a := MonsterAvatar.new()
		root.add_child(a)
		var type := db.get_type(m[1])
		a.setup(type)
		var max_hp := float((type.get("stats", {}) as Dictionary).get("max_hp", 60.0))
		a.apply_state({"position": m[2], "facing": m[3]}, {"hp": max_hp * float(m[4]), "max_hp": max_hp, "status_bits": 0}, 0.016)
		_spots[m[0]] = m[2]
		if m[0] == 1000:
			lunging = a
	var t := lunging.play_attack()
	t.pause()
	t.custom_step(0.1)
	_fx = CombatFX.new()
	root.add_child(_fx)
	_fx.setup(_spot, func() -> int: return 0, AbilityDB.load_default(), 30)
	_fx.set_process(false)
	_fx.handle(["telegraph", 1, Vector3(17.0, 0, 22.6), 2.5, 30])
	_fx.handle(["projectile", 2, 2, "mage_missile", Vector3(16.8, 0, 18.3), Vector2(0.3, 0.95).normalized(), 22.0, 22.0])
	_fx.handle(["status", 1, "shield", 300])
	_fx.handle(["hit", 1001, 23.0, false, 1])
	_fx.handle(["hit", 1002, 41.0, true, 1])
	_fx.handle(["heal", 2, 35.0])
	_fx.advance(0.12)
	var cam := Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	cam.look_at_from_position(Vector3(19.0, 9.0, 13.5), Vector3(19.0, 0.6, 20.8))


## Task 12 set: boar (warning its charge), goblins (one elite), skeleton archer and an
## elite wolf, around a warrior.
func _monsters_b() -> void:
	var hero := PlayerAvatar.new()
	root.add_child(hero)
	hero.setup("Aldric", 0, "warrior", {"beard": "full", "hair_color": "dark_brown", "skin": "skin_3"})
	hero.position = Vector3(19.0, 0, 19.6)
	hero.rotation.y = 0.5
	hero.set_health(150.0, 200.0)
	_spots[1] = hero.position
	var db := MonsterDB.load_default()
	var monsters := [
		[1000, "boar", Vector3(15.6, 0, 22.6), 2.3, 1.0, false],
		[1001, "goblin", Vector3(20.2, 0, 21.4), -2.7, 0.7, false],
		[1002, "goblin", Vector3(21.7, 0, 20.3), -2.2, 1.0, true],
		[1003, "skeleton_archer", Vector3(23.6, 0, 23.4), -2.4, 0.9, false],
		[1004, "wolf", Vector3(17.6, 0, 24.4), 2.8, 1.0, true],
	]
	for m: Array in monsters:
		var a := MonsterAvatar.new()
		root.add_child(a)
		var type := db.get_type(m[1])
		a.setup(type, m[5], 1.3)
		var max_hp := float((type.get("stats", {}) as Dictionary).get("max_hp", 60.0)) * (2.5 if m[5] else 1.0)
		a.apply_state({"position": m[2], "facing": m[3]}, {"hp": max_hp * float(m[4]), "max_hp": max_hp, "status_bits": 0}, 0.016)
		_spots[m[0]] = m[2]
		if m[0] == 1001:
			a.play_attack("melee")
		elif m[0] == 1003:
			a.play_attack("shoot")
	_fx = CombatFX.new()
	root.add_child(_fx)
	_fx.setup(_spot, func() -> int: return 0, AbilityDB.load_default(), 30)
	_fx.set_process(false)
	_fx.handle(["telegraph_line", 7, Vector3(15.6, 0, 22.6), Vector3(15.6, 0, 22.6) + Vector3(sin(2.3), 0, cos(2.3)) * 8.0, 1.4, 90])
	_fx.handle(["projectile", 8, 1003, "skeleton_arrow", Vector3(23.6, 0, 23.4), Vector2(-0.75, -0.66).normalized(), 18.0, 60.0])
	_fx.advance(1.2)
	var cam := Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	cam.look_at_from_position(Vector3(19.5, 9.0, 14.0), Vector3(19.5, 0.6, 21.6))


## Task 13 set: the orc king facing two heroes, warning its jump on one of them,
## with two of its goblins.
func _boss_scene() -> void:
	var heroes := [
		[1, "warrior", {"beard": "full", "hair_color": "dark_brown", "skin": "skin_3"}, Vector3(18.4, 0, 19.0), 0.4, "Aldric"],
		[2, "cleric", {"hair_style": "bob", "hair_color": "white", "skin": "skin_6"}, Vector3(21.6, 0, 18.4), -0.3, "Elora"],
	]
	for h: Array in heroes:
		var p := PlayerAvatar.new()
		root.add_child(p)
		p.setup(h[5], h[0] - 1, h[1], h[2])
		p.position = h[3]
		p.rotation.y = h[4]
		p.set_health(150.0, 200.0)
		_spots[h[0]] = h[3]
	var db := MonsterDB.load_default()
	var monsters := [
		[1000, "orc_king", Vector3(20.0, 0, 23.0), PI, 0.55],
		[1001, "goblin", Vector3(16.6, 0, 22.2), 2.6, 1.0],
		[1002, "goblin", Vector3(23.4, 0, 22.0), -2.6, 0.8],
	]
	for m: Array in monsters:
		var a := MonsterAvatar.new()
		root.add_child(a)
		var type := db.get_type(m[1])
		a.setup(type)
		var max_hp := float((type.get("stats", {}) as Dictionary).get("max_hp", 60.0))
		a.apply_state({"position": m[2], "facing": m[3]}, {"hp": max_hp * float(m[4]), "max_hp": max_hp, "status_bits": 0}, 0.016)
		_spots[m[0]] = m[2]
		if m[0] == 1000:
			a.play_attack("melee")
	_fx = CombatFX.new()
	root.add_child(_fx)
	_fx.setup(_spot, func() -> int: return 0, AbilityDB.load_default(), 30)
	_fx.handle(["telegraph", 9, Vector3(18.4, 0, 19.0), 4.0, 90])
	_fx.advance(1.2)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(20.0, 10.5, 12.5), Vector3(20.0, 1.0, 21.0))


## Plan 3.1 set: the skeleton archer's own rig — facing us, mid-stride, drawing the
## bow, an elite, and one falling apart.
func _skeleton_scene() -> void:
	var type := MonsterDB.load_default().get_type("skeleton_archer")
	var spots := [
		[Vector3(17.6, 0, 21.0), PI * 0.9, "idle", false],
		[Vector3(19.0, 0, 21.4), PI * 0.75, "walk", false],
		[Vector3(20.6, 0, 21.2), PI * 1.15, "shoot", false],
		[Vector3(22.4, 0, 21.8), PI * 1.05, "idle", true],
		[Vector3(24.0, 0, 20.6), PI * 0.8, "die", false],
	]
	for s: Array in spots:
		var a := MonsterAvatar.new()
		root.add_child(a)
		a.setup(type, s[3], 1.3)
		var info := {"hp": 50.0, "max_hp": 50.0, "status_bits": 0}
		var pos: Vector3 = s[0]
		if s[2] == "walk":
			for i in 9:
				pos += Vector3(0.06, 0, 0)
				a.apply_state({"position": pos, "facing": s[1]}, info, 1.0 / 60.0)
		else:
			a.apply_state({"position": pos, "facing": s[1]}, info, 0.3)
		if s[2] == "shoot":
			var t := a.play_attack("shoot")
			t.pause()
			t.custom_step(0.3)
		elif s[2] == "die":
			var t := a.play_death()
			t.pause()
			t.custom_step(0.35)
	var cam := Camera3D.new()
	cam.fov = 30
	root.add_child(cam)
	if _name == "skeleton_face": # close-up of the idle one's skull
		cam.look_at_from_position(Vector3(18.15, 2.05, 19.35), Vector3(17.6, 1.85, 21.0))
	else:
		cam.look_at_from_position(Vector3(20.8, 4.2, 12.2), Vector3(20.8, 1.0, 21.2))
