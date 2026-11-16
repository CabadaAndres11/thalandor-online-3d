class_name GameSession
extends Node3D
## A running game: owns the arena, camera, avatars and the network sessions.
## Playing always means hosting (with the local player on a zero-latency loopback)
## unless joining a friend, in which case there is no local HostSession.

signal session_ended(reason: String)
## WebRTC opens groups asynchronously: the code arrives from the signaling server.
signal group_opened(code: String)
signal group_failed(error_key: String)

const GAME_VERSION_SETTING := "application/config/version"
const NET_WEBRTC := "webrtc"
const NET_ENET := "enet"

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

var arena: Arena
var camera: IsoCamera
var _avatars: Dictionary = {} # id -> PlayerAvatar
var _monster_avatars: Dictionary = {} # id -> MonsterAvatar
var _npc_avatars: Array = [] # NpcAvatar
## Combat visuals (projectiles, warnings, numbers…) driven by host events.
var fx: CombatFX
var _avatar_root: Node3D
## Abilities in slots 1-4 for the next client (the saved character's; empty = class default).
var character_bar: Array = []
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
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	map = arena.build(Arena.load_layout())
	_avatar_root = Node3D.new()
	_avatar_root.name = "Players"
	add_child(_avatar_root)
	for n: Dictionary in NpcDB.placed(map):
		var npc := NpcAvatar.new()
		npc.name = "Npc_" + str(n.id)
		_avatar_root.add_child(npc)
		npc.setup(n.id, n.position, n.facing)
		_npc_avatars.append(npc)
	camera = IsoCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.follow(map.spawn_point())
	fx = CombatFX.new()
	fx.name = "CombatFX"
	add_child(fx)
	fx.setup(_entity_position, _latest_tick, AbilityDB.load_default(), balance.tick_rate)
	_aim = map.spawn_point()


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
		join_with(WebSocketSignaling.join(balance.signaling_url, code), player_name, class_id, appearance, progress)
		return OK
	var t: Transport = EnetTransport.join(ip, balance.port)
	if t == null:
		last_error = "ERR_CONNECT"
		return ERR_CANT_CONNECT
	_start_client(player_name, class_id, appearance, _with_debug_lag(t), progress)
	return OK


## Joins a WebRTC group through the given signaling channel (tests pass a fake one).
func join_with(signaling: Signaling, player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS,
		appearance: Dictionary = {}, progress: Dictionary = {}) -> void:
	var t := WebRtcTransport.join(signaling, WebRtcTransport.ice_from_url(balance.stun_url))
	_start_client(player_name, class_id, appearance, _with_debug_lag(t), progress)


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
	client = ClientSession.new(balance, map, game_version(), player_name, class_id, appearance, progress)
	if not character_bar.is_empty():
		client.bar = character_bar.duplicate()
	client.disconnected.connect(_on_client_disconnected)
	client.combat_event.connect(_on_combat_event)
	client.class_changed.connect(_on_class_changed)
	client.connect_to(t)


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
	if client == null:
		return
	client.update(delta)
	if client == null:
		return # the update ended the session (e.g. timeout) and the game left
	_sync_avatars(delta)
	_sync_monsters(delta)
	var own := client.render_state(client.my_id)
	if not own.is_empty():
		camera.follow(own.position)
		for npc: NpcAvatar in _npc_avatars:
			var d := Vector2(own.position.x - npc.position.x, own.position.z - npc.position.z).length()
			npc.set_prompt_visible(d <= NpcDB.TALK_RANGE)


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
			avatar.setup(entry.name, entry.slot, entry.get("class_id", CharacterCatalog.DEFAULT_CLASS), entry.get("appearance", {}))
			_avatar_root.add_child(avatar)
			_avatars[id] = avatar
		var avatar_node := _avatars[id] as PlayerAvatar
		avatar_node.apply_state(client.render_state(id), delta)
		if client.combat.has(id):
			var c: Dictionary = client.combat[id]
			avatar_node.set_health(float(c.hp), float(c.max_hp), int(c.life) == CombatEntity.ALIVE)
			avatar_node.set_statuses(int(c.status_bits))
			avatar_node.set_level(int(c.get("level", 1)))


func _remove_avatar(id: int) -> void:
	var avatar: Node = _avatars[id]
	_avatars.erase(id)
	avatar.queue_free()


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
			avatar.setup(MonsterDB.load_default().get_type(str(info.type)), bool(info.get("elite", false)), client.balance.elite_scale)
			_monster_avatars[id] = avatar
		(_monster_avatars[id] as MonsterAvatar).apply_state(client.monster_render_state(id), info, delta)


func _on_combat_event(ev: Array) -> void:
	fx.handle(ev)
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
				var ab := AbilityDB.load_default().get_ability(str(ev[2]))
				(_avatars[who] as PlayerAvatar).play_action(str(ab.get("anim", "")))
		"leap":
			var jumper := int(ev[1])
			if _monster_avatars.has(jumper):
				(_monster_avatars[jumper] as MonsterAvatar).land()
		"downed":
			var fallen := int(ev[1])
			if _avatars.has(fallen):
				(_avatars[fallen] as PlayerAvatar).play_action("downed")
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
