extends GutTest
## Two GameSessions in this process over real WebRTC data channels, introduced by the
## in-memory FakeSignaling hub: the host opens a group, the guest joins with the code.

const CODE := "2222-2222"

var hub: FakeSignaling.Hub
var host_game: GameSession
var guest_game: GameSession


func before_each() -> void:
	hub = FakeSignaling.Hub.new()


func after_each() -> void:
	for g: Variant in [guest_game, host_game]:
		if g != null:
			(g as GameSession).leave()
	guest_game = null
	host_game = null
	hub.clear()


func _new_game() -> GameSession:
	var g := GameSession.new()
	g.net_mode = GameSession.NET_WEBRTC
	add_child_autofree(g)
	return g


func _wait_until(cond: Callable, seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0 and not cond.call():
		await wait_physics_frames(1)
	RtcNoise.accept(self)


func test_open_group_is_async_and_guest_joins() -> void:
	host_game = _new_game()
	host_game.start_host("Anfitriona")
	var opened := []
	host_game.group_opened.connect(func(c: String) -> void: opened.append(c))
	host_game.open_group_with(hub.open_host(CODE))
	assert_eq(host_game.group_code(), "", "no code until the server answers")
	await _wait_until(func() -> bool: return not opened.is_empty(), 2.0)
	assert_eq(opened, [CODE])
	assert_eq(host_game.group_code(), CODE)

	guest_game = _new_game()
	guest_game.join_with(hub.open_guest(CODE), "Invitado")
	await _wait_until(func() -> bool:
		return guest_game.client.status == ClientSession.Status.IN_GAME and host_game.avatar_count() == 2, 10.0)
	assert_eq(guest_game.client.status, ClientSession.Status.IN_GAME, "guest is in the game")
	assert_eq(host_game.host.player_count(), 2)
	await _wait_until(func() -> bool: return guest_game.avatar_count() == 2, 2.0)
	assert_eq(guest_game.avatar_count(), 2, "guest draws both players")


## Like Main: when the session ends (here a silent host times out), the game leaves at
## once, in the middle of its own frame update; that must not touch the gone client.
func test_leaving_when_session_times_out_mid_frame() -> void:
	var host_sig := hub.open_host(CODE) # a host that never answers
	guest_game = _new_game()
	guest_game.session_ended.connect(_leave_guest)
	guest_game.join_with(hub.open_guest(CODE), "Invitado")
	guest_game.client.balance.timeout_s = 0.3
	await _wait_until(func() -> bool: return guest_game.client == null, 3.0)
	assert_null(guest_game.client, "the session ended and the game left")
	await wait_physics_frames(2)
	host_sig.close()


func _leave_guest(_reason: String) -> void:
	guest_game.leave()


func test_signaling_failure_reports_error() -> void:
	hub.open_host(CODE) # code already taken: the server answers "full"
	host_game = _new_game()
	host_game.start_host("Anfitriona")
	var failed := []
	host_game.group_failed.connect(func(key: String) -> void: failed.append(key))
	host_game.open_group_with(hub.open_host(CODE))
	await _wait_until(func() -> bool: return not failed.is_empty(), 2.0)
	assert_eq(failed, ["ERR_SIGNALING"])
	assert_eq(host_game.group_code(), "")


func test_open_group_without_server_url_fails_at_once() -> void:
	host_game = _new_game()
	host_game.start_host("Anfitriona")
	host_game.balance.signaling_url = ""
	assert_eq(host_game.open_group(), "")
	assert_eq(host_game.last_error, "ERR_SIGNALING")


func test_open_group_with_server_url_is_pending() -> void:
	host_game = _new_game()
	host_game.start_host("Anfitriona")
	host_game.balance.signaling_url = "ws://127.0.0.1:9"
	assert_eq(host_game.open_group(), "")
	assert_eq(host_game.last_error, "", "pending: the code arrives with group_opened")
	assert_true(host_game.is_opening_group())
