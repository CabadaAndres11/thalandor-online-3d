class_name GameSession
extends Node3D
## A running game: owns the zone view, camera, avatars and the network sessions.
## Playing always means hosting (with the local player on a zero-latency loopback)
## unless joining a friend, in which case there is no local HostSession.

## A cutscene ended (played to its end or skipped), Plan 8.2.
signal cutscene_ended()
signal session_ended(reason: String)
## WebRTC opens groups asynchronously: the code arrives from the signaling server.
signal group_opened(code: String)
signal group_failed(error_key: String)
## The zone finished building (all its steps ran, Plan 8.1.1).
signal zone_built()

const GAME_VERSION_SETTING := "application/config/version"
const NET_WEBRTC := "webrtc"
const NET_ENET := "enet"
## Where a game starts until characters remember their place (Plan 8.1, Task 9).
const START_ZONE := "aldea"

var balance: Balance
var map: CollisionMap
var client: ClientSession
var host: HostSession
## When true (chat open) movement input is ignored.
var input_blocked: bool = false
## When true (the K, C or T window is open) mouse attacks are ignored; moving still works.
var attacks_blocked: bool = false
## Text key of the last open_group()/join() error.
var last_error: String = ""
## Network used for groups: NET_WEBRTC (default) or NET_ENET; user argument --net=.
var net_mode: String = NET_WEBRTC

var zone_view: ZoneView
## The cutscene playing now (Plan 8.2), or null; while it plays the camera is its own.
var cutscene: CutscenePlayer
var _stage_view: ZoneView
## Glows on the quest points the local player has an objective for (Plan 8.2).
var _point_marks: Dictionary = {} # point id -> Node3D
var _cut_fov: float = 40.0
## The zone's picture for the map and the minimap (Plan 8.1.1), made with each zone.
var map_texture: ImageTexture
## True while the zone is still being built, one step per frame (Plan 8.1.1).
var zone_building: bool = false
var _build_steps: Array[Callable] = []
## Monster models built ahead (after the zone), kept across zone changes (review fix).
var _prewarm: Array[Callable] = []
var _build_total := 0 # steps of this load, for the loading bar (Plan 8.1.2)
var _build_done := 0
## The signaling of a WebRTC join, opened once the zone is loaded (review fix).
var join_signaling: Signaling
var _drawn_loading := false # the loading screen gets one frame on screen before any step
var camera: IsoCamera
var _avatars: Dictionary = {} # id -> PlayerAvatar
var _monster_avatars: Dictionary = {} # id -> MonsterAvatar
var _npc_avatars: Array = [] # NpcAvatar
## Villagers walking their routes (Plan 8.3a): [{avatar: NpcAvatar, route, speed, pause_s, loop}].
var _walkers: Array = []
## The loading screen between zones (Plan 8.1).
var loading: LoadingOverlay
var _quality: int = GraphicsQuality.MEDIUM
## Combat visuals (projectiles, warnings, numbers…) driven by host events.
var fx: CombatFX
## The own player's loot on the ground and the gold they win.
var loot_view: LootView
var _avatar_root: Node3D
## Abilities in slots 1-4 for the next client (the saved character's; empty = class default).
var character_bar: Array = []
## The saved inventory of the character playing (Inventory.to_dict), sent in HELLO.
var character_inventory: Dictionary = {}
## The saved place of the character playing (Plan 8.1), sent in HELLO.
var character_place: Dictionary = {}
## The character's quest log (Plan 8.2), sent in HELLO.
var character_quests: Dictionary = {}
var _loopback: MemoryNetwork
var _group_code: String = ""
var _opening: bool = false
var _aim: Vector3 = Vector3.ZERO


func _init() -> void:
	InputSetup.ensure_actions()
	balance = Balance.load_from()
	net_mode = NET_ENET if _user_arg("net") == NET_ENET else NET_WEBRTC
	var signaling_override := _user_arg("signaling")
	if signaling_override != "":
		balance.signaling_url = signaling_override
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "Loading"
	overlay_layer.layer = 50
	add_child(overlay_layer)
	loading = LoadingOverlay.new()
	overlay_layer.add_child(loading)
	build_zone(ZoneLayout.load_id(START_ZONE), ["build"])
	_prewarm = MonsterAvatar.prewarm_steps() # while the game loads, not when a boss appears
	_avatar_root = Node3D.new()
	_avatar_root.name = "Players"
	add_child(_avatar_root)
	_place_npcs()
	camera = IsoCamera.new()
	camera.name = "Camera"
	camera.bounds = Rect2(Vector2.ZERO, Vector2(map.size))
	camera.inset = float(zone_view.layout.band) if zone_view.layout.band > 0 else IsoCamera.BOUNDS_INSET
	add_child(camera)
	camera.follow(map.spawn_point())
	fx = CombatFX.new()
	fx.name = "CombatFX"
	add_child(fx)
	fx.setup(_entity_position, _latest_tick, AbilityDB.load_default(), balance.tick_rate)
	fx.slash_owners = func(id: int) -> bool: return _avatars.has(id)
	loot_view = LootView.new()
	loot_view.name = "Loot"
	add_child(loot_view)
	_aim = map.spawn_point()


## Rebuilds the zone lighting for a video quality level (GraphicsQuality).
func set_graphics_quality(q: int) -> void:
	_quality = q
	zone_view.set_quality(q)


static func game_version() -> String:
	return str(ProjectSettings.get_setting(GAME_VERSION_SETTING, "0.0.0"))


## Starts a game hosted on this PC (solo until open_group() is called).
func start_host(player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS, appearance: Dictionary = {},
		progress: Dictionary = {}) -> void:
	host = HostSession.new(balance, map, game_version())
	_loopback = MemoryNetwork.new()
	var host_t := _loopback.create_host()
	host.add_transport(host_t)
	_start_client(player_name, class_id, appearance, _loopback.connect_client(host_t), progress)


## Opens the game to friends. Returns the group code, or "" with last_error set, or ""
## with last_error == "" while a WebRTC group is opening (then group_opened/group_failed).
func open_group() -> String:
	if _group_code != "":
		return _group_code
	if host == null:
		last_error = "ERR_PORT"
		return ""
	if net_mode == NET_WEBRTC:
		if _opening:
			last_error = ""
			return ""
		if balance.signaling_url == "":
			last_error = "ERR_SIGNALING"
			return ""
		open_group_with(WebSocketSignaling.host(balance.signaling_url))
		return ""
	var ip := GroupCode.pick_host_ip(IP.get_local_addresses())
	if ip == "":
		last_error = "ERR_NO_NETWORK"
		return ""
	var t := EnetTransport.host(balance.port, balance.max_players - 1)
	if t == null:
		last_error = "ERR_PORT"
		return ""
	host.add_transport(t)
	_group_code = GroupCode.encode(ip)
	return _group_code


## Opens a WebRTC group through the given signaling channel (tests pass a fake one).
func open_group_with(signaling: Signaling) -> void:
	var t := WebRtcTransport.host(signaling, WebRtcTransport.ice_from_url(balance.stun_url))
	t.room_opened.connect(_on_room_opened)
	t.connection_failed.connect(_on_group_failed)
	_opening = true
	last_error = ""
	host.add_transport(t)


func group_code() -> String:
	return _group_code


func is_opening_group() -> bool:
	return _opening


## "WebRTC" or "ENet", for the debug overlay.
func net_label() -> String:
	return "WebRTC" if net_mode == NET_WEBRTC else "ENet"


## Joins a friend's game by code.
func join(code: String, player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS, appearance: Dictionary = {},
		progress: Dictionary = {}) -> Error:
	var ip := GroupCode.decode(code)
	if ip == "":
		last_error = "ERR_BAD_CODE"
		return ERR_INVALID_PARAMETER
	if net_mode == NET_WEBRTC:
		if balance.signaling_url == "":
			last_error = "ERR_SIGNALING"
			return ERR_UNCONFIGURED
		var url := balance.signaling_url
		_start_client(player_name, class_id, appearance, null, progress)
		_when_loaded(func() -> void:
			if client == null:
				return
			join_signaling = WebSocketSignaling.join(url, code)
			client.connect_to(_with_debug_lag(WebRtcTransport.join(join_signaling, WebRtcTransport.ice_from_url(balance.stun_url)))))
		return OK
	_start_client(player_name, class_id, appearance, null, progress)
	_when_loaded(func() -> void:
		if client == null:
			return
		var t: Transport = EnetTransport.join(ip, balance.port)
		if t == null:
			_on_client_disconnected("failed")
		else:
			client.connect_to(_with_debug_lag(t)))
	return OK


## Joins a WebRTC group through the given signaling channel (tests pass a fake one).
func join_with(signaling: Signaling, player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}, progress: Dictionary = {}) -> void:
	_start_client(player_name, class_id, appearance, null, progress)
	_when_loaded(func() -> void:
		if client != null:
			join_signaling = signaling
			client.connect_to(_with_debug_lag(WebRtcTransport.join(signaling, WebRtcTransport.ice_from_url(balance.stun_url)))))


## A guest connects only once its zone is loaded (Plan 8.1.1): loading stalls frames
## (a big model takes seconds to build) and a connection must not wait on them.
func _when_loaded(connect_now: Callable) -> void:
	if zone_building:
		zone_built.connect(connect_now, CONNECT_ONE_SHOT)
	else:
		connect_now.call()


func _with_debug_lag(t: Transport) -> Transport:
	var lag := _debug_lag()
	if lag.x > 0.0 or lag.y > 0.0:
		return LaggyTransport.new(t, lag.x, lag.y / 100.0, randi())
	return t


func _on_room_opened(code: String) -> void:
	_opening = false
	_group_code = code
	group_opened.emit(code)


func _on_group_failed() -> void:
	_opening = false
	last_error = "ERR_SIGNALING"
	group_failed.emit(last_error)


## Attaches an extra transport to the host (used by tests to add in-memory guests).
func add_host_transport(t: Transport) -> void:
	if host != null:
		host.add_transport(t)


func leave() -> void:
	if client != null:
		client.leave()
	if host != null:
		host.close()
	client = null
	host = null
	_group_code = ""
	_opening = false
	for id: int in _monster_avatars.keys():
		(_monster_avatars[id] as Node).queue_free()
	_monster_avatars.clear()
	for id: int in _avatars.keys():
		_remove_avatar(id)


func is_hosting() -> bool:
	return host != null


func _start_client(player_name: String, class_id: String, appearance: Dictionary, t: Transport, progress: Dictionary = {}) -> void:
	client = ClientSession.new(balance, map, game_version(), player_name, class_id, appearance, progress, character_inventory)
	if not character_bar.is_empty():
		client.bar = character_bar.duplicate()
	client.disconnected.connect(_on_client_disconnected)
	client.combat_event.connect(_on_combat_event)
	client.class_changed.connect(_on_class_changed)
	client.upgrade_changed.connect(_on_upgrade_changed)
	client.gear_changed.connect(_on_gear_changed)
	client.place = character_place.duplicate(true)
	client.quests = QuestLog.from_dict(character_quests, QuestDB.load_default())
	client.zone_changed.connect(_on_zone_changed)
	client.zone_ready.connect(loading.done.bind("ready"))
	if t != null:
		client.connect_to(t)


## The host moved this player to another zone: draw it, with its NPCs, behind a short
## loading screen; nothing of the old zone stays (monsters and loot go too).
func _on_zone_changed(zone_id: String, _key: String, _level: int) -> void:
	var layout := ZoneLayout.load_variant(zone_id, client.zone_variant)
	if layout == null:
		return
	build_zone(layout, ["build", "ready"])
	for npc: Node in _npc_avatars:
		npc.queue_free()
	_npc_avatars.clear()
	_place_npcs()
	place_walkers(layout)
	for id: String in _point_marks.keys():
		(_point_marks[id] as Node).queue_free()
	_point_marks.clear()
	refresh_quest_marks()
	for id: int in _monster_avatars.keys():
		(_monster_avatars[id] as Node).queue_free()
	_monster_avatars.clear()
	loot_view.clear()


## Starts drawing a zone behind the loading screen: its collision at once, its view one
## step per frame (Plan 8.1.1). A zone still building is dropped for the new one.
func build_zone(layout: ZoneLayout, waits: Array = ["build", "ready"]) -> void:
	loading.show_zone(layout.name, waits, layout.id)
	if zone_view != null:
		remove_child(zone_view)
		zone_view.free()
	zone_view = ZoneView.new()
	zone_view.name = "Zone"
	add_child(zone_view)
	move_child(zone_view, 0)
	map = layout.collision()
	if camera != null:
		camera.bounds = Rect2(Vector2.ZERO, Vector2(layout.size))
		camera.inset = float(layout.band) if layout.band > 0 else IsoCamera.BOUNDS_INSET
	_build_steps = zone_view.build_steps(layout, _quality)
	_build_steps.insert(1, func() -> void: map_texture = ImageTexture.create_from_image(ZoneMapImage.make(layout)))
	zone_building = true
	_build_total = _build_steps.size() + _prewarm.size()
	_build_done = 0
	_drawn_loading = false


## Runs the next build step (the zone's, then the monster prewarm); false when none is left.
func run_build_step() -> bool:
	if _build_steps.is_empty() and _prewarm.is_empty():
		return false
	var step: Callable = _build_steps.pop_front() if not _build_steps.is_empty() else _prewarm.pop_front()
	step.call()
	_build_done += 1
	loading.set_progress(float(_build_done) / maxf(1.0, float(_build_total)))
	if _build_steps.is_empty() and _prewarm.is_empty() and zone_building:
		zone_building = false
		loading.done("build")
		zone_built.emit()
	return true


## Monster models still to build ahead.
func prewarm_left() -> int:
	return _prewarm.size()


## Runs every step left (tests, and nothing else waits for frames).
func finish_zone_build() -> void:
	while run_build_step():
		pass


func _place_npcs() -> void:
	for n: Dictionary in NpcDB.placed(map):
		var npc := NpcAvatar.new()
		npc.name = "Npc_" + str(n.id)
		_avatar_root.add_child(npc)
		npc.setup(n.id, n.position, n.facing)
		_npc_avatars.append(npc)


func _on_client_disconnected(reason: String) -> void:
	session_ended.emit(reason)


func _physics_process(delta: float) -> void:
	if client == null:
		return
	var move := Vector2.ZERO
	if not input_blocked:
		move = InputReader.camera_relative_move(InputReader.read_raw(), camera.yaw())
	_update_aim()
	if _loopback != null:
		_loopback.advance(delta * 1000.0)
	var buttons := 0 if input_blocked else InputReader.read_buttons()
	if attacks_blocked:
		buttons &= ~(PlayerInput.BTN_BASIC | PlayerInput.BTN_BASIC_HELD | PlayerInput.BTN_SECONDARY)
	client.tick(move, _aim, buttons)
	if host != null:
		host.tick()


func _process(delta: float) -> void:
	if _drawn_loading:
		run_build_step()
	_drawn_loading = true
	if client == null:
		return
	client.update(delta)
	if client == null:
		return # the update ended the session (e.g. timeout) and the game left
	_sync_avatars(delta)
	_sync_monsters(delta)
	move_walkers(client.target_render_tick() / float(balance.tick_rate))
	var own := client.render_state(client.my_id)
	if not own.is_empty():
		if cutscene == null:
			camera.follow(own.position)
		zone_view.follow(own.position)
		update_house(own.position)
		for npc: NpcAvatar in _npc_avatars:
			var d := Vector2(own.position.x - npc.position.x, own.position.z - npc.position.z).length()
			npc.set_prompt_visible(d <= NpcDB.TALK_RANGE)


## Opens the house the own player stands in (and only that one), Plan 8.1.1.
func update_house(pos: Vector3) -> void:
	if zone_view.layout == null:
		return
	var index := zone_view.layout.house_at(Vector2i(floori(pos.x), floori(pos.z)))
	if index != zone_view.open_index:
		zone_view.open_house(index)


func _update_aim() -> void:
	var vp := get_viewport()
	if vp == null or not camera.is_inside_tree():
		return
	var mouse := vp.get_mouse_position()
	var hit: Variant = InputReader.ground_point(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit != null:
		_aim = hit


func _sync_avatars(delta: float) -> void:
	for id: int in _avatars.keys():
		if not client.roster.has(id):
			_remove_avatar(id)
	for id: int in client.roster:
		if not _avatars.has(id):
			var entry: Dictionary = client.roster[id]
			var avatar := PlayerAvatar.new()
			avatar.name = "Player%d" % id
			avatar.move_speed = balance.move_speed
			avatar.setup(entry.name, entry.slot, entry.get("class_id", CharacterCatalog.DEFAULT_CLASS), entry.get("appearance", {}),
				str(entry.get("upgrade", "")), entry.get("gear", []))
			_avatar_root.add_child(avatar)
			_avatars[id] = avatar
		var avatar_node := _avatars[id] as PlayerAvatar
		var state := client.render_state(id)
		avatar_node.visible = not state.is_empty() # a partner in another zone is not drawn here
		avatar_node.apply_state(state, delta)
		if client.combat.has(id):
			var c: Dictionary = client.combat[id]
			avatar_node.set_health(float(c.hp), float(c.max_hp), int(c.life) == CombatEntity.ALIVE)
			avatar_node.set_statuses(int(c.status_bits))
			avatar_node.set_level(int(c.get("level", 1)))
			avatar_node.set_charging(float(c.get("charge", 0.0)) > 0.0)


func _remove_avatar(id: int) -> void:
	var avatar: Node = _avatars[id]
	_avatars.erase(id)
	avatar.queue_free()


## Plays a cutscene (Plan 8.2): its actors are built here, its camera is the game's own and
## its light changes the zone's. A scene away from the player ({zone, variant}) is built
## as its own stage while the zone waits aside. Returns the player (null if it does not exist).
func play_cutscene(scene_id: String) -> CutscenePlayer:
	var data := CutsceneData.load_id(scene_id)
	if data.is_empty() or cutscene != null:
		return null
	var stage: Variant = data.get("stage", "here")
	var view := zone_view
	if stage is Dictionary:
		var layout := ZoneLayout.load_variant(str(stage.get("zone", "")), str(stage.get("variant", "")))
		if layout != null and zone_view != null:
			remove_child(zone_view)
			_stage_view = ZoneView.new()
			_stage_view.name = "Stage"
			add_child(_stage_view)
			move_child(_stage_view, 0)
			for step: Callable in _stage_view.build_steps(layout, _quality):
				step.call()
			view = _stage_view
			_avatar_root.visible = false
	_cut_fov = camera.fov
	var own := player_avatar(client.my_id)
	if own != null:
		own.visible = false
	cutscene = CutscenePlayer.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	cutscene.finished.connect(_end_cutscene, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	cutscene.play(data, {"camera": camera, "actor_factory": _cutscene_actor,
		"set_ambience": func(id: String) -> void:
			if view != null:
				view.set_ambience(id)})
	return cutscene


func _cutscene_actor(spec: Dictionary) -> Node3D:
	if spec.has("npc"):
		var npc := NpcAvatar.new()
		npc.setup(str(spec.npc), Vector3.ZERO, 0.0)
		return npc
	if spec.has("monster"):
		var m := MonsterAvatar.new()
		m.setup(MonsterDB.load_default().get_type(str(spec.monster)))
		return m
	var holder := CutsceneActor.new()
	if spec.has("player") or str(spec.get("look", "")) == "player":
		holder.set_rig(HumanRig.create(client.class_id, client.appearance, null, client.progress.upgrade, client.gear_of(client.my_id)))
	elif spec.get("look") is Dictionary:
		holder.set_rig(HumanRig.build(NpcAvatar.look_of(spec.look)))
	return holder


func _end_cutscene() -> void:
	if cutscene == null:
		return
	cutscene.queue_free()
	cutscene = null
	if _stage_view != null:
		_stage_view.queue_free()
		remove_child(_stage_view)
		_stage_view = null
		if zone_view != null and zone_view.get_parent() == null:
			add_child(zone_view)
			move_child(zone_view, 0)
		_avatar_root.visible = true
	camera.fov = _cut_fov
	var own := player_avatar(client.my_id) if client != null else null
	if own != null:
		own.visible = true
	cutscene_ended.emit()


## The quest signs over the NPCs and the glows on quest points, for the local player's log.
func refresh_quest_marks() -> void:
	if client == null:
		return
	var db := QuestDB.load_default()
	for npc: NpcAvatar in _npc_avatars:
		npc.set_mark(NpcTalk.mark(npc.npc_id, client.quests, client.progress.level, client.class_id, db))
	var want := QuestText.visible_points(map.quest_points, client.quests, db, map.zone_id)
	for id: String in _point_marks.keys():
		if not id in want:
			(_point_marks[id] as Node).queue_free()
			_point_marks.erase(id)
	for id: String in want:
		if _point_marks.has(id) or str(map.quest_points[id].get("look", "")) == "":
			continue
		var at: Vector2i = map.quest_points[id].at
		var glow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		glow.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.3, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.3)
		glow.material_override = mat
		glow.position = Vector3(at.x + 0.5, 1.2, at.y + 0.5)
		glow.name = "QuestPoint_" + id
		_avatar_root.add_child(glow)
		_point_marks[id] = glow


## The interact quest point the local player can examine here ("" if none).
func quest_point_near() -> String:
	var own := client.render_state(client.my_id)
	if own.is_empty():
		return ""
	return QuestText.interact_point_near(map.quest_points, client.quests, QuestDB.load_default(), map.zone_id, own.position)


func quest_point_count() -> int:
	return _point_marks.size()


## The villagers that walk this zone's routes (they are not on the map: nothing collides).
func place_walkers(layout: ZoneLayout) -> void:
	for w: Dictionary in _walkers:
		(w.avatar as Node).queue_free()
	_walkers.clear()
	for spec: Variant in layout.walkers:
		if not spec is Dictionary:
			continue
		var route: Array = (spec.get("route", []) as Array).map(func(p: Array) -> Vector2: return Vector2(float(p[0]), float(p[1])))
		if route.is_empty():
			continue
		var npc := NpcAvatar.new()
		npc.name = "Walker_%d" % _walkers.size()
		_avatar_root.add_child(npc)
		npc.setup(str(spec.get("npc", "")), Vector3(route[0].x + 0.5, 0, route[0].y + 0.5), 0.0)
		_walkers.append({"avatar": npc, "route": route, "speed": float(spec.get("speed", 1.2)),
			"pause_s": float(spec.get("pause_s", 3.0)), "loop": bool(spec.get("loop", true)), "id": str(spec.get("npc", ""))})


## Moves every walker to where the host's clock (seconds) puts it.
func move_walkers(t: float) -> void:
	for w: Dictionary in _walkers:
		var s := WalkerPath.at(w.route, w.speed, w.pause_s, w.loop, t)
		var a: NpcAvatar = w.avatar
		a.position = s.position
		a.rotation.y = s.facing
		if a.rig != null:
			a.rig.set_moving_speed(w.speed if s.moving else 0.0, 3.0)


func walker_count() -> int:
	return _walkers.size()


func walker_avatar(i: int) -> NpcAvatar:
	return _walkers[i].avatar


## The walker in talking reach of a point, or "" (it greets in the chat, Plan 8.3a).
func walker_near(pos: Vector3) -> String:
	for w: Dictionary in _walkers:
		var a: NpcAvatar = w.avatar
		if Vector2(pos.x - a.position.x, pos.z - a.position.z).length() <= NpcDB.TALK_RANGE:
			return str(w.id)
	return ""


func npc_avatar(id: String) -> NpcAvatar:
	for npc: NpcAvatar in _npc_avatars:
		if npc.npc_id == id:
			return npc
	return null


func npc_count() -> int:
	return _npc_avatars.size()


func player_avatar(id: int) -> PlayerAvatar:
	return _avatars.get(id)


## What E does here and now (see NpcInteraction): {action, npc}.
func interaction() -> Dictionary:
	var own := client.render_state(client.my_id)
	if own.is_empty():
		return {"action": NpcInteraction.NONE, "npc": ""}
	var allies := []
	for id: int in client.roster:
		if id != client.my_id and client.combat.has(id):
			var st := client.render_state(id)
			if not st.is_empty():
				allies.append({"position": st.position, "life": int(client.combat[id].life)})
	var alive := not client.combat.has(client.my_id) or int(client.combat[client.my_id].life) == CombatEntity.ALIVE
	return NpcInteraction.decide(map, own.position, client.class_id, allies, balance.revive_range, alive)


## A player learned a class: their avatar is rebuilt in the new class's clothes.
func _on_class_changed(id: int, _class_id: String) -> void:
	if _avatars.has(id):
		_remove_avatar(id)


## A player chose or lost an upgrade: the avatar is rebuilt with its look (helm, crossbow).
func _on_upgrade_changed(id: int, _upgrade: String) -> void:
	if _avatars.has(id):
		_remove_avatar(id)


## A player's visible equipment changed: the avatar is rebuilt wearing it.
func _on_gear_changed(id: int) -> void:
	if _avatars.has(id):
		_remove_avatar(id)


func avatar_count() -> int:
	return _avatars.size()


## (latency_ms, loss_percent) from user arguments --lag=<ms> --loss=<pct>.
static func _debug_lag() -> Vector2:
	return Vector2(float(_user_arg("lag", "0")), float(_user_arg("loss", "0")))


## Value of the user argument --<key>=<value> (after "--" on the command line).
static func _user_arg(key: String, default: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + key + "="):
			return arg.trim_prefix("--" + key + "=")
	return default


func monster_avatar_count() -> int:
	return _monster_avatars.size()


func _sync_monsters(delta: float) -> void:
	for id: int in _monster_avatars.keys():
		if not client.monsters.has(id):
			(_monster_avatars[id] as Node).queue_free()
			_monster_avatars.erase(id)
	for id: int in client.monsters:
		var info: Dictionary = client.monsters[id]
		if not _monster_avatars.has(id):
			var avatar := MonsterAvatar.new()
			avatar.name = "Monster%d" % id
			_avatar_root.add_child(avatar)
			avatar.setup(MonsterDB.load_default().get_type(str(info.type)), bool(info.get("elite", false)), client.balance.elite_scale, bool(info.get("ally", false)))
			_monster_avatars[id] = avatar
		(_monster_avatars[id] as MonsterAvatar).apply_state(client.monster_render_state(id), info, delta)


## The ability as others see a player cast it: evolved by their upgrade (the templar's smite
## is a melee swing), then changed by the family of the weapon in hand (WeaponFamily).
static func seen_ability(ability_id: String, upgrade: String, main_base: String) -> Dictionary:
	var ab := AbilityDB.load_default().resolved(ability_id, upgrade)
	if main_base != "":
		ab = WeaponFamily.adjust(ab, ItemDB.load_default().family_of(main_base))
	return ab


func _on_combat_event(ev: Array) -> void:
	fx.handle(ev)
	loot_view.my_id = client.my_id
	loot_view.handle(ev)
	if str(ev[0]) == "bag_full" and ev.size() > 1 and int(ev[1]) == client.my_id:
		client.chat_received.emit("", tr("ITEM_BAG_FULL"), true)
	if str(ev[0]) == "trade_refused" and ev.size() > 2 and int(ev[1]) == client.my_id:
		client.chat_received.emit("", tr("TRADE_REFUSED_" + str(ev[2]).to_upper()), true)
	match str(ev[0]):
		"cast":
			var who := int(ev[1])
			if _monster_avatars.has(who):
				var mab := AbilityDB.load_default().get_ability(str(ev[2]))
				var avatar := _monster_avatars[who] as MonsterAvatar
				var rise := _leap_delay(mab)
				if rise > 0.0:
					avatar.play_leap(rise)
				else:
					avatar.play_attack(str(mab.get("anim", "melee")))
			elif _avatars.has(who):
				var pa := _avatars[who] as PlayerAvatar
				var gear := client.gear_of(who)
				var upgrade := str((client.roster.get(who, {}) as Dictionary).get("upgrade", ""))
				var ab := seen_ability(str(ev[2]), upgrade, str(gear[0]) if not gear.is_empty() else "")
				var anim := str(ab.get("anim", ""))
				var basic := str(ab.get("kind", "")) == "basic"
				pa.play_action(anim, basic) # basic melee attacks chain three swings
				if HumanRig.SWINGS.has(anim) and pa.rig != null:
					for hand: String in pa.rig.combo_hands():
						if pa.rig.weapon_points(hand).is_empty():
							continue
						var slash := SlashFx.new()
						_avatar_root.add_child(slash)
						slash.setup(pa.rig, (CombatFX.CLASS_COLORS.get(str(ab.get("class", "")), Color.WHITE) as Color).lightened(0.3), hand)
		"channel":
			if _avatars.has(int(ev[1])):
				var sung := AbilityDB.load_default().get_ability(str(ev[2]))
				(_avatars[int(ev[1])] as PlayerAvatar).play_long_cast(float(ev[3]), bool(sung.get("levitate", false)))
		"channel_end":
			if _avatars.has(int(ev[1])):
				(_avatars[int(ev[1])] as PlayerAvatar).stop_long_cast()
		"hit":
			if _monster_avatars.has(int(ev[1])):
				(_monster_avatars[int(ev[1])] as MonsterAvatar).react_to_hit(_entity_position(int(ev[4])) if ev.size() > 4 else null)
		"leap":
			var jumper := int(ev[1])
			if _monster_avatars.has(jumper):
				(_monster_avatars[jumper] as MonsterAvatar).land()
		"downed":
			var fallen := int(ev[1])
			if _avatars.has(fallen):
				(_avatars[fallen] as PlayerAvatar).play_action("downed")
		"fled":
			# A boss ran away (Plan 8.3a): it leaves the scene, no binary dissolve.
			var gone := int(ev[1])
			if _monster_avatars.has(gone):
				(_monster_avatars[gone] as MonsterAvatar).visible = false
		"died":
			var who := int(ev[1])
			if _monster_avatars.has(who):
				(_monster_avatars[who] as MonsterAvatar).play_death()
			elif _avatars.has(who):
				(_avatars[who] as PlayerAvatar).play_action("die")


## Drawn position of a player or monster (for effects), or null.
func _entity_position(id: int) -> Variant:
	if _avatars.has(id):
		return (_avatars[id] as Node3D).position
	if _monster_avatars.has(id):
		return (_monster_avatars[id] as Node3D).position
	return null


func _latest_tick() -> int:
	return client.latest_tick() if client != null else 0


## Warning time of a leaping ability (0 when it does not leap).
static func _leap_delay(ability: Dictionary) -> float:
	for eff: Dictionary in ability.get("effects", []):
		if bool(eff.get("leap", false)):
			return float(eff.get("delay_s", 0.0))
	return 0.0
