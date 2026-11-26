extends GutTest
## Cutscenes (Plan 8.2): tracks run side by side, each step in order; a move without time
## lasts until the actor arrives; skipping leaves everything as it would end.

const CUTSCENES := "res://tests/data/cutscenes/"

var cam: Camera3D
var player: CutscenePlayer
var lines: Array
var ambiences: Array


func before_each() -> void:
	CutsceneData.dir = CUTSCENES
	cam = Camera3D.new()
	add_child_autofree(cam)
	player = CutscenePlayer.new()
	add_child_autofree(player)
	lines = []
	ambiences = []
	player.line.connect(func(who: String, text: String) -> void: lines.append([who, text]))


func after_each() -> void:
	CutsceneData.dir = CutsceneData.DIR


func _ctx() -> Dictionary:
	return {"camera": cam, "actor_factory": func(_spec: Dictionary) -> Node3D: return Node3D.new(),
		"set_ambience": func(id: String) -> void: ambiences.append(id)}


func _play() -> void:
	player.play(CutsceneData.load_id("c_test"), _ctx())


func test_tracks_run_in_parallel() -> void:
	_play()
	player.advance(1.9)
	assert_almost_eq(cam.position.x, 3.8, 0.05, "the camera is almost half way after 1.9 of 4 s")
	assert_eq(lines.size(), 2, "the second line is out by then")
	assert_eq(lines[1][0], "player")


func test_actors_placed() -> void:
	_play()
	assert_eq(player.actor("brann").position, Vector3(4.5, 0, 4.5))
	assert_eq(player.actor("lobo").position, Vector3(10.5, 0, 4.5))


func test_move_waits() -> void:
	_play()
	player.advance(1.0)
	assert_almost_eq(player.actor("lobo").position.z, 8.5, 0.05, "4 m/s for 1 s")
	player.advance(1.1)
	assert_almost_eq(player.actor("lobo").position.z, 12.5, 0.05, "arrived after 2 s")
	assert_true(player.actor("lobo").visible)
	player.advance(0.6)
	assert_false(player.actor("lobo").visible, "the pose took 0.5 s, then it hides")


func test_finishes_once() -> void:
	_play()
	watch_signals(player)
	for i in 60:
		player.advance(0.1)
	assert_signal_emit_count(player, "finished", 1)
	assert_eq(ambiences, ["alba"])
	assert_true(player.is_finished())


func test_skip_final_state() -> void:
	_play()
	watch_signals(player)
	player.advance(0.2)
	player.skip()
	assert_signal_emit_count(player, "finished", 1)
	assert_almost_eq(cam.position.x, 8.0, 0.01)
	assert_eq(player.actor("lobo").position, Vector3(10.5, 0, 12.5))
	assert_false(player.actor("lobo").visible)
	assert_eq(ambiences, ["alba"], "the light ends as the scene would")
	player.advance(5.0)
	assert_signal_emit_count(player, "finished", 1)


func test_validate() -> void:
	assert_eq(CutsceneData.validate("c_test"), [] as Array[String])
	var errors := CutsceneData.validate_dict({"id": "x", "actors": {"a": {"npc": "nadie"}},
		"tracks": [[{"pose": ["a", "bailar"]}, {"move": "b", "to": [[1, 1]]}, {"line": ["a", "NO_TEXT"]}, {"ambience": "nada"}]]})
	var all := "\n".join(errors)
	for bit in ["nadie", "bailar", "'b'", "NO_TEXT", "nada"]:
		assert_string_contains(all, bit)


func test_all_cutscenes_valid() -> void:
	CutsceneData.dir = CutsceneData.DIR
	pass_test("no cutscenes is fine")
	for id: String in CutsceneData.ids():
		var errors := CutsceneData.validate(id)
		assert_eq(errors, [] as Array[String], "\n".join(errors))


func test_fx_calls_context() -> void:
	var calls := []
	var ctx := _ctx()
	ctx["fx"] = func(name: String, at: Vector3) -> void: calls.append([name, at])
	player.play({"id": "x", "tracks": [[{"fx": "fire", "at": [3, 4]}]]}, ctx)
	assert_eq(calls, [["fire", Vector3(3.5, 0, 4.5)]])


func test_new_poses_are_valid() -> void:
	for pose in ["kneel", "point", "lie"]:
		assert_true(pose in CutsceneData.POSES, pose)


## Plan 8.3d: an actor may start in a pose, already in it (Brann lies at the gate).
func test_actor_starts_in_pose() -> void:
	var p := CutscenePlayer.new()
	add_child_autofree(p)
	p.play({"actors": {"b": {"look": {"class": "villager"}, "at": [2, 2], "pose": "lie"}}, "tracks": [[{"wait": "", "time": 1.0}]]},
		{"actor_factory": func(spec: Dictionary) -> Node3D:
			var h := CutsceneActor.new()
			h.set_rig(HumanRig.build(NpcAvatar.look_of(spec.look)))
			return h})
	var rig: HumanRig = p.actor("b").get("rig")
	assert_eq(rig.current_action(), "lie")
	assert_almost_eq(rig.action_progress(), 1.0, 0.001, "already lying")


func test_brann_lies_on_his_blood() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cutscenes/prologo_brann.json"))
	assert_eq(str(d.actors.brann.pose), "lie")
	var fx: Array = []
	for tr: Array in d.tracks:
		for st: Dictionary in tr:
			if st.has("fx"):
				fx.append(str(st.fx))
	assert_has(fx, "blood")
	assert_has(CutsceneData.FX, "blood")


func test_wounded_lie() -> void:
	for id: String in ["herido_1", "herida_2"]:
		var a := NpcAvatar.new()
		add_child_autofree(a)
		a.setup(id, Vector3.ZERO, 0.0)
		assert_eq(a.rig.current_action(), "lie", id)
