extends GutTest
## Two real game processes over ENet on this PC. This process hosts with the real main
## scene ("Jugar" + "Abrir grupo"); a second Godot process (tests/helpers/guest_process.gd)
## boots the main scene headless and joins with the group code, like a friend would.
## Needs the game port (data/balance.json) free: close any running copy of the game.

const SETTINGS := "user://test_two_proc_settings.json"
const GUEST_SCRIPT := "res://tests/helpers/guest_process.gd"
const HOST_NAME := "Anfitriona"
const GUEST_NAME := "Invitado"
const HOST_CHAT := "hola desde la anfitriona"
const GUEST_CHAT := "hola desde el invitado"
const REPORT_TIMEOUT_MS := 45000
const LEAVE_TIMEOUT_MS := 8000
const HOST_WALK_MS := 1500
## Max distance between what the guest and the host draw once everyone stands still.
const TOLERANCE := 0.05
const MIN_WALK := 1.0

var _main: Main
var _pid: int = -1
var _report_name: String = ""
var _host_chat: Array = []


func before_each() -> void:
	_report_name = "test_guest_report_%d.json" % Time.get_ticks_usec()
	_host_chat = []


func after_each() -> void:
	Input.action_release("move_up")
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	for path in [SETTINGS, "user://" + _report_name]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_guest_process_joins_walks_chats_and_leaves() -> void:
	await _run_session([], 0.0)


func test_guest_process_with_lag_and_loss() -> void:
	# --lag is one-way and applies in both directions: the guest's ping is ~300 ms.
	await _run_session(["--lag=150", "--loss=5"], 250.0)


## Only when a signaling server is running, e.g. `npm run dev` in tools/signaling and
## THALANDOR_SIGNALING=ws://127.0.0.1:8787, or the deployed wss:// URL (CI has none, so
## it is skipped there).
func test_guest_process_over_webrtc() -> void:
	var url := OS.get_environment("THALANDOR_SIGNALING")
	if url == "":
		pass_test("skipped: set THALANDOR_SIGNALING to a running signaling server")
		return
	await _run_session([], 0.0, url)
	RtcNoise.accept(self)


func _run_session(extra_args: Array, min_ping_ms: float, signaling_url: String = "") -> void:
	_main = load("res://game/main.tscn").instantiate()
	_main.settings_path = SETTINGS
	add_child_autofree(_main)
	await wait_physics_frames(2)
	_main._on_play(HOST_NAME)
	await wait_physics_frames(2)
	var game := _main.game
	game.finish_zone_build() # a player opens the group once the game has loaded
	game.client.chat_received.connect(_on_host_chat)

	var code := ""
	var net_args := ["--net=enet"]
	if signaling_url != "":
		game.net_mode = GameSession.NET_WEBRTC
		game.balance.signaling_url = signaling_url
		net_args = ["--net=webrtc", "--signaling=" + signaling_url]
		game.open_group()
		var wait_start := Time.get_ticks_msec()
		while game.is_opening_group() and Time.get_ticks_msec() - wait_start < 10000:
			await wait_physics_frames(1)
		code = game.group_code()
	else:
		game.net_mode = GameSession.NET_ENET
		code = game.open_group()
		if code == "" and game.last_error == "ERR_NO_NETWORK":
			# PC without LAN/Tailscale address: listen on the same port and join over loopback.
			var t := EnetTransport.host(game.balance.port, game.balance.max_players - 1)
			if t != null:
				game.add_host_transport(t)
				code = GroupCode.encode("127.0.0.1")
		if code != "":
			# The host listens on every interface; join over loopback, because CI runners may
			# not route to their own LAN address (code encoding is covered by unit tests).
			code = GroupCode.encode("127.0.0.1")
	if code == "":
		fail_test("cannot open the group (%s): is the game already running?" % game.last_error)
		return

	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", GUEST_SCRIPT,
		"--", "--code=" + code, "--out=" + _report_name, "--name=" + GUEST_NAME])
	args.append_array(PackedStringArray(net_args))
	args.append_array(PackedStringArray(extra_args))
	_pid = OS.create_process(OS.get_executable_path(), args)
	assert_gt(_pid, 0, "guest process started")
	if _pid <= 0:
		return

	# Host side: once the guest is in, walk up for a moment and say hello; then wait for
	# the guest's report (written after everyone has been standing still for a while).
	var start_ms := Time.get_ticks_msec()
	var walk_start_ms := -1
	var host_start := Vector3.ZERO
	var report_path := "user://" + _report_name
	while not FileAccess.file_exists(report_path):
		if Time.get_ticks_msec() - start_ms > REPORT_TIMEOUT_MS or not OS.is_process_running(_pid):
			break
		if walk_start_ms < 0 and game.host.player_count() == 2:
			walk_start_ms = Time.get_ticks_msec()
			host_start = game.client.render_state(game.client.my_id).position
			Input.action_press("move_up")
			game.client.send_chat(HOST_CHAT)
		elif walk_start_ms >= 0 and Time.get_ticks_msec() - walk_start_ms > HOST_WALK_MS:
			Input.action_release("move_up")
		await wait_physics_frames(1)
	Input.action_release("move_up")

	assert_true(FileAccess.file_exists(report_path), "the guest wrote its report in time")
	if not FileAccess.file_exists(report_path):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	assert_eq(report.get("result"), "ok", "guest result (phase %s, reason %s)" % [report.get("phase", ""), report.get("end_reason", "")])
	assert_eq(report.get("errors", ["missing"]), [], "guest process logged no errors")
	if report.get("result") != "ok":
		return
	gut.p("guest ping: %d ms" % int(report.ping_ms))
	assert_gte(float(report.ping_ms), min_ping_ms, "the guest's simulated lag is applied")

	# Both processes agree on who is in the group.
	var guest_id := int(report.my_id)
	assert_eq(game.host.player_count(), 2)
	assert_eq(game.avatar_count(), 2, "host draws the guest")
	var names: Array = (report.roster as Dictionary).values()
	names.sort()
	assert_eq(names, [HOST_NAME, GUEST_NAME], "guest's roster")
	var guest_entry: Dictionary = game.client.roster.get(guest_id, {})
	assert_eq(guest_entry.get("class_id"), "archer", "the host sees the guest's class")
	assert_eq(guest_entry.get("appearance", {}).get("hair_style"), "hair_ponytail")

	# Both moved, and once standing still they see the same positions.
	var host_id := game.client.my_id
	var host_now: Vector3 = game.client.render_state(host_id).position
	assert_gt(host_now.distance_to(host_start), MIN_WALK, "host walked")
	var guest_start := _vec(report.guest_start)
	var guest_on_host: Vector3 = game.client.render_state(guest_id).get("position", Vector3.INF)
	assert_gt(guest_on_host.distance_to(guest_start), MIN_WALK, "host saw the guest walk")
	var positions: Dictionary = report.positions
	for id_key: String in positions:
		var on_guest := _vec(positions[id_key])
		var on_host: Vector3 = game.client.render_state(int(id_key)).get("position", Vector3.INF)
		assert_lt(on_guest.distance_to(on_host), TOLERANCE,
			"player %s: guest sees %s, host sees %s" % [id_key, on_guest, on_host])
	assert_eq(positions.size(), 2, "guest reports both players")

	# Chat crosses both ways.
	assert_has(report.chat, [HOST_NAME, HOST_CHAT], "guest got the host's chat")
	assert_has(_host_chat, [GUEST_NAME, GUEST_CHAT], "host got the guest's chat")

	# The guest leaves: the host drops it.
	var leave_start := Time.get_ticks_msec()
	while game.host.player_count() > 1 and Time.get_ticks_msec() - leave_start < LEAVE_TIMEOUT_MS:
		await wait_physics_frames(1)
	await wait_physics_frames(2)
	assert_eq(game.host.player_count(), 1, "host noticed the guest left")
	assert_eq(game.avatar_count(), 1, "guest avatar removed")
	_main._leave_game()


func _on_host_chat(author: String, text: String, _is_system: bool) -> void:
	_host_chat.append([author, text])


func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
