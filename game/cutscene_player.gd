class_name CutscenePlayer
extends Node3D
## Plays a cutscene (Plan 8.2, CutsceneData): the tracks run side by side, each step in
## order. A step lasts its "time"; a move without time lasts until its actor arrives. The
## clock is advance(dt) (the game calls it every frame; tests drive it). skip() leaves
## everything as the scene would end. Actors are only visual, children of this node.
## ctx: camera (Camera3D), actor_factory (spec -> Node3D), set_ambience (id), fx (name, at),
## origin (Vector3: where the stage stands, for scenes away from the player).

signal line(speaker: String, text: String)
signal fade(to_black: bool, seconds: float)
signal finished()

var _data: Dictionary = {}
var _ctx: Dictionary = {}
var _actors: Dictionary = {} # name -> Node3D
var _tracks: Array = [] # [{steps, index, t, started, from}]
var _finished: bool = true
var _origin: Vector3 = Vector3.ZERO
var _shake: float = 0.0


func play(data: Dictionary, ctx: Dictionary) -> void:
	_data = data
	_ctx = ctx
	_origin = ctx.get("origin", Vector3.ZERO)
	for a: Node in _actors.values():
		a.queue_free()
	_actors.clear()
	var specs: Dictionary = data.get("actors", {})
	for name: String in specs:
		var spec: Dictionary = specs[name]
		var factory: Callable = ctx.get("actor_factory", Callable())
		var node: Node3D = factory.call(spec) if factory.is_valid() else Node3D.new()
		node.name = "Actor_" + name
		add_child(node)
		node.position = _cell(spec.get("at", [0, 0]))
		node.rotation.y = deg_to_rad(float(spec.get("facing", 0.0)))
		node.visible = not bool(spec.get("hidden", false))
		if spec.has("pose") and node.get("rig") is HumanRig:
			(node.get("rig") as HumanRig).set_pose_now(str(spec.pose)) # already in it (Plan 8.3d)
		_actors[name] = node
	_tracks.clear()
	for t: Variant in data.get("tracks", []):
		if t is Array and not (t as Array).is_empty():
			_tracks.append({"steps": t, "index": 0, "t": 0.0, "started": false, "from": {}})
	_finished = _tracks.is_empty()
	advance(0.0)
	if _finished:
		finished.emit()


func actor(name: String) -> Node3D:
	return _actors.get(name)


func is_finished() -> bool:
	return _finished


func _cell(at: Variant) -> Vector3:
	var a: Array = at if at is Array and (at as Array).size() >= 2 else [0, 0]
	var p := _origin + Vector3(float(a[0]) + 0.5, 0, float(a[1]) + 0.5)
	var ground: Callable = _ctx.get("ground", Callable()) # actors stand on the relief (Plan 8.3d)
	if ground.is_valid():
		p.y = float(ground.call(p.x, p.z))
	return p


func _point(v: Variant) -> Vector3:
	var a: Array = v if v is Array and (v as Array).size() >= 3 else [0, 0, 0]
	var p := _origin + Vector3(float(a[0]), float(a[1]), float(a[2]))
	var ground: Callable = _ctx.get("ground", Callable()) # heights count from the ground (Plan 8.3d)
	if ground.is_valid():
		p.y += float(ground.call(p.x, p.z))
	return p


func _process(delta: float) -> void:
	if not _finished:
		advance(delta)


func advance(dt: float) -> void:
	if _finished:
		return
	for tr: Dictionary in _tracks:
		var left := dt
		while tr.index < (tr.steps as Array).size():
			var step: Dictionary = tr.steps[tr.index]
			if not tr.started:
				_start(step, tr)
				tr.started = true
				tr.t = 0.0
			var used := _run(step, tr, left)
			left -= used
			if not _done(step, tr):
				break
			_end(step)
			tr.index += 1
			tr.started = false
		if left < 0.0:
			left = 0.0
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt)
	if _tracks.all(func(t: Dictionary) -> bool: return t.index >= (t.steps as Array).size()):
		_finished = true
		finished.emit()


func _start(step: Dictionary, tr: Dictionary) -> void:
	var cam: Camera3D = _ctx.get("camera")
	match CutsceneData.kind_of(step):
		"camera":
			if cam != null:
				var c: Dictionary = step.camera
				tr.from = {"pos": cam.position, "look": _look_of(cam), "fov": cam.fov}
				if float(step.get("time", 0.0)) <= 0.0:
					_camera_at(c, 1.0, tr.from)
		"line":
			line.emit(str(step.line[0]), str(step.line[1]))
		"fade":
			fade.emit(str(step.fade) == "out", float(step.get("time", 0.5)))
		"ambience":
			var f: Callable = _ctx.get("set_ambience", Callable())
			if f.is_valid():
				f.call(str(step.ambience))
		"show":
			if _actors.has(str(step.show)):
				(_actors[str(step.show)] as Node3D).visible = true
		"hide":
			if _actors.has(str(step.hide)):
				(_actors[str(step.hide)] as Node3D).visible = false
		"pose":
			_pose(str(step.pose[0]), str(step.pose[1]))
		"shake":
			_shake = float(step.get("time", 0.5))
		"fx":
			var fx: Callable = _ctx.get("fx", Callable())
			if fx.is_valid():
				fx.call(str(step.fx), _cell(step.get("at", [0, 0])))
		"move":
			tr.from = {"path": (step.to as Array).duplicate(), "leg": 0}
			var a: Node3D = _actors.get(str(step.move))
			if a != null and a.get("rig") is HumanRig:
				(a.get("rig") as HumanRig).set_moving_speed(float(step.get("speed", 3.0)), 3.0)


## Runs a step for up to `dt` seconds; returns the seconds it used.
func _run(step: Dictionary, tr: Dictionary, dt: float) -> float:
	var time := float(step.get("time", 0.0))
	match CutsceneData.kind_of(step):
		"camera":
			if time > 0.0:
				var used := minf(dt, time - tr.t)
				tr.t += used
				_camera_at(step.camera, _ease(tr.t / time, str(step.get("ease", "in_out"))), tr.from)
				return used
			return 0.0
		"move":
			var a: Node3D = _actors.get(str(step.move))
			if a == null:
				tr.from.leg = (tr.from.path as Array).size()
				return 0.0
			var speed := maxf(0.1, float(step.get("speed", 3.0)))
			var left := dt
			while left > 0.0 and int(tr.from.leg) < (tr.from.path as Array).size():
				var goal := _cell(tr.from.path[tr.from.leg])
				var d := Vector2(goal.x - a.position.x, goal.z - a.position.z)
				var need := d.length() / speed
				if need <= left:
					a.position = Vector3(goal.x, a.position.y, goal.z)
					left -= need
					tr.from.leg = int(tr.from.leg) + 1
				else:
					var stepv := d.normalized() * speed * left
					a.position += Vector3(stepv.x, 0, stepv.y)
					a.rotation.y = atan2(d.x, d.y)
					left = 0.0
			return dt - left
	var used2 := minf(dt, maxf(0.0, time - tr.t))
	tr.t += used2
	return used2


func _done(step: Dictionary, tr: Dictionary) -> bool:
	if CutsceneData.kind_of(step) == "move":
		return int(tr.from.get("leg", 0)) >= (tr.from.get("path", []) as Array).size()
	return tr.t >= float(step.get("time", 0.0)) - 0.00001


func _end(step: Dictionary) -> void:
	if CutsceneData.kind_of(step) == "move":
		var a: Node3D = _actors.get(str(step.move))
		if a != null and a.get("rig") is HumanRig:
			(a.get("rig") as HumanRig).set_moving_speed(0.0, 3.0)


func _pose(name: String, pose: String) -> void:
	var a: Node3D = _actors.get(name)
	if a != null and a.get("rig") is HumanRig:
		(a.get("rig") as HumanRig).play_action(pose)


static func _ease(k: float, kind: String) -> float:
	k = clampf(k, 0.0, 1.0)
	match kind:
		"linear":
			return k
		"in":
			return k * k
		"out":
			return 1.0 - (1.0 - k) * (1.0 - k)
	return k * k * (3.0 - 2.0 * k)


static func _look_of(cam: Camera3D) -> Vector3:
	return cam.global_position - cam.global_transform.basis.z * 10.0 if cam.is_inside_tree() else cam.position + Vector3(0, 0, -10)


func _camera_at(c: Dictionary, k: float, from: Dictionary) -> void:
	var cam: Camera3D = _ctx.get("camera")
	if cam == null:
		return
	var to_pos := _point(c.at) if c.has("at") else (from.get("pos", cam.position) as Vector3)
	var to_look := _point(c.look) if c.has("look") else (from.get("look", to_pos + Vector3(0, 0, -10)) as Vector3)
	var pos: Vector3 = (from.get("pos", to_pos) as Vector3).lerp(to_pos, k)
	var look: Vector3 = (from.get("look", to_look) as Vector3).lerp(to_look, k)
	if _shake > 0.0:
		pos += Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), 0)
	cam.position = pos
	if c.has("fov"):
		cam.fov = lerpf(float(from.get("fov", cam.fov)), float(c.fov), k)
	if pos.distance_to(look) > 0.01 and cam.is_inside_tree():
		cam.look_at(look, Vector3.UP if absf((look - pos).normalized().y) < 0.99 else Vector3.FORWARD)


## Every step to its end, at once: the scene as it would finish.
func skip() -> void:
	if _finished:
		return
	for tr: Dictionary in _tracks:
		while tr.index < (tr.steps as Array).size():
			var step: Dictionary = tr.steps[tr.index]
			if not tr.started:
				if CutsceneData.kind_of(step) in ["line", "fade", "shake", "fx"]:
					tr.index += 1
					continue
				_start(step, tr)
				tr.started = true
				tr.t = 0.0
			match CutsceneData.kind_of(step):
				"camera":
					_camera_at(step.camera, 1.0, tr.from)
				"move":
					var a: Node3D = _actors.get(str(step.move))
					if a != null and not (tr.from.path as Array).is_empty():
						a.position = _cell(tr.from.path[-1])
					_end(step)
			tr.index += 1
			tr.started = false
	_shake = 0.0
	_finished = true
	finished.emit()
