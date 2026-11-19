extends SceneTree
## Art checkpoint tool (needs a window, not --headless): lines up characters on the
## arena's ground and light and saves user://render/<name>.png.
##   Godot --path . -s tests/helpers/render_characters.gd -- --set=classes
## Equipment: --set=gear --tier=1 [--rot=0|90|180] (the five classes in a full tier kit) and
## --set=weapons --tier=1 --page=0|1|2 (every weapon type in a hand).
## Each set is a list of looks (see HumanRig.build) made from
## [class_id, appearance] pairs resolved through CharacterCatalog.

const PIECES := "res://assets/characters/pieces/"
const SPACING := 1.3

var _frames := 0
var _name := "classes"
var _tier := 1
var _rot := 0.0
var _page := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_name = arg.trim_prefix("--set=")
		elif arg.begins_with("--tier="):
			_tier = int(arg.trim_prefix("--tier="))
		elif arg.begins_with("--rot="):
			_rot = float(arg.trim_prefix("--rot="))
		elif arg.begins_with("--page="):
			_page = int(arg.trim_prefix("--page="))
	root.size = Vector2i(1600, 700)
	var arena := Arena.new()
	root.add_child(arena)
	arena.build(Arena.load_layout())
	if _name == "boss":
		_boss_scene()
		return
	if _name in ["acolyte", "vaelthar", "nhazar", "inquisitor"]:
		_turnaround({"acolyte": "cult_acolyte", "inquisitor": "cult_inquisitor"}.get(_name, _name))
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
		if _name in ["gear", "weapons"]:
			path = "user://render/%s_t%d_%s.png" % [_name, _tier, str(int(_rot)) if _name == "gear" else str(_page)]
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		return true
	return false


func _looks(set_name: String) -> Array:
	match set_name:
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
		"brann":
			var b := NpcAvatar.look_of(NpcDB.load_default().npc("brann").look)
			var v: Dictionary = _resolved([["villager", {"hair_style": "bob", "hair_color": "chestnut", "skin": "skin_2"}]])[0]
			var v2: Dictionary = _resolved([["villager", {"hair_style": "short", "hair_color": "black", "skin": "skin_5", "beard": "short"}]])[0]
			return [v, b, v2]
		"cult":
			var out := []
			for a: Array in [["cultist", 0.0], ["cultist", 90.0], ["cultist", 180.0], ["cult_archer", 25.0]]:
				var l := MonsterAvatar.look_of(MonsterDB.load_default().get_type(a[0]))
				l["rot"] = a[1]
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
		"gear":
			var t := "_t%d" % _tier
			var armor := func(kind: String) -> Array:
				return ["head", "shoulders", "chest", "hands", "legs", "feet"].map(func(sl: String) -> String: return kind + "_" + sl + t)
			var kits := [
				["warrior", ["sword" + t, "shield" + t] + armor.call("warrior"), {"skin": "skin_4", "hair_style": "short", "beard": "full", "body": "robust"}],
				["cleric", ["scepter" + t, "tome" + t] + armor.call("cleric"), {"skin": "skin_2", "hair_style": "bald", "beard": "short"}],
				["mage", ["staff" + t, ""] + armor.call("mage"), {"skin": "skin_6", "hair_style": "bob", "hair_color": "white"}],
				["archer", ["bow" + t, ""] + armor.call("archer"), {"skin": "skin_3", "hair_style": "swept", "hair_color": "blond"}],
				["assassin", ["dagger" + t, "dagger" + t] + armor.call("assassin"), {"skin": "skin_7", "hair_style": "short"}],
			]
			return kits.map(func(k: Array) -> Dictionary: return _geared(k[0], k[2], k[1], _rot))
		"weapons":
			var t := "_t%d" % _tier
			var pages := [
				[["warrior", "greatsword", ""], ["warrior", "great_axe", ""], ["warrior", "warhammer", ""], ["warrior", "halberd", ""], ["warrior", "sword", "shield"], ["warrior", "axe", ""]],
				[["cleric", "mace", "orb"], ["mage", "staff", ""], ["mage", "wand", "tome"], ["cleric", "scepter", "shield"], ["archer", "bow", ""], ["archer", "crossbow", ""]],
				[["archer", "short_sword", ""], ["assassin", "dagger", "dagger"], ["assassin", "short_sword", "dagger"]],
			]
			var out := []
			for w: Array in pages[clampi(_page, 0, pages.size() - 1)]:
				var gear := [str(w[1]) + t, (str(w[2]) + t) if str(w[2]) != "" else "", "", "", "", "", "", ""]
				out.append(_geared(w[0], {"hair_style": "short"}, gear, 35.0))
			return out
	push_error("unknown set " + set_name)
	return []


## A look wearing equipment: gear lists main, offhand, then the six armor slots.
func _geared(class_id: String, appearance: Dictionary, gear: Array, rot: float) -> Dictionary:
	var g := gear.duplicate()
	g.resize(8)
	g = g.map(func(x: Variant) -> String: return str(x) if x != null else "")
	var look := CharacterCatalog.load_default().resolve(class_id, appearance, "", g)
	look["rot"] = rot
	return look


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


## Combat checkpoint: two heroes facing hounds and cultists, a hound mid-lunge, a ground
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
		[1000, "marked_hound", Vector3(20.6, 0, 21.4), -2.6, 0.5],
		[1001, "marked_hound", Vector3(22.2, 0, 20.4), -2.2, 1.0],
		[1002, "marked_hound", Vector3(21.6, 0, 22.8), -2.7, 0.2],
		[1003, "cultist", Vector3(18.0, 0, 23.0), PI, 0.7],
		[1004, "cultist", Vector3(15.6, 0, 22.4), 2.6, 1.0],
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


## Task 12 set: marked boar (warning its charge), cultists (one elite), cult archer and an
## elite marked_hound, around a warrior.
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
		[1000, "marked_boar", Vector3(15.6, 0, 22.6), 2.3, 1.0, false],
		[1001, "cultist", Vector3(20.2, 0, 21.4), -2.7, 0.7, false],
		[1002, "cultist", Vector3(21.7, 0, 20.3), -2.2, 1.0, true],
		[1003, "cult_archer", Vector3(23.6, 0, 23.4), -2.4, 0.9, false],
		[1004, "marked_hound", Vector3(17.6, 0, 24.4), 2.8, 1.0, true],
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
	_fx.handle(["projectile", 8, 1003, "cult_arrow", Vector3(23.6, 0, 23.4), Vector2(-0.75, -0.66).normalized(), 18.0, 60.0])
	_fx.advance(1.2)
	var cam := Camera3D.new()
	cam.fov = 38
	root.add_child(cam)
	cam.look_at_from_position(Vector3(19.5, 9.0, 14.0), Vector3(19.5, 0.6, 21.6))


## A monster seen from the front, its left, the back and its right, with a cultist for scale.
func _turnaround(type_id: String) -> void:
	var db := MonsterDB.load_default()
	var tall := float(db.get_type(type_id).get("bar_height", 1.9)) / 1.9 # a big head needs room and a wider shot
	var spacing := 3.0 * maxf(1.0, tall * 0.95)
	var row := [[type_id, 0.0], [type_id, -PI / 2.0], [type_id, PI], [type_id, PI / 2.0], ["cultist", 0.0]]
	for i in row.size():
		var a := MonsterAvatar.new()
		root.add_child(a)
		var type := db.get_type(row[i][0])
		a.setup(type)
		a.apply_state({"position": Vector3(20.0 + (i - 2) * spacing, 0, 20.0), "facing": row[i][1]}, {"hp": 1.0, "max_hp": 1.0, "status_bits": 0}, 0.016)
		a.bar.visible = false
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(20.0, 3.4 * tall, 34.0 + 10.0 * (tall - 1.0)), Vector3(20.0, 2.0 * tall, 20.0))


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
		[1000, "cult_acolyte", Vector3(20.0, 0, 23.0), PI, 0.55],
		[1001, "cultist", Vector3(16.6, 0, 22.2), 2.6, 1.0],
		[1002, "cultist", Vector3(23.4, 0, 22.0), -2.6, 0.8],
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


## bow, an elite, and one falling apart.
