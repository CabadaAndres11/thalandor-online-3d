extends GutTest
## Boots the real main scene, plays, lets an in-memory guest join, moves, chats and leaves.

const SETTINGS := "user://test_boot_settings.json"


func after_each() -> void:
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_boot_play_join_move_chat_leave() -> void:
	var main: Main = load("res://game/main.tscn").instantiate()
	main.settings_path = SETTINGS
	add_child_autofree(main)
	await wait_physics_frames(2)
	main._on_play("Prueba")
	await wait_physics_frames(5)

	var net := MemoryNetwork.new(9)
	var host_side := net.create_host()
	main.game.add_host_transport(host_side)
	var guest := ClientSession.new(main.game.balance, main.game.map, GameSession.game_version(), "Invitada")
	guest.connect_to(net.connect_client(host_side))
	var received := []
	guest.chat_received.connect(func(a: String, t: String, _s: bool) -> void: received.append([a, t]))

	var start := Vector3.ZERO
	for i in 45:
		net.advance(1000.0 / 30.0)
		guest.tick(Vector2(1, 0), Vector3.ZERO)
		guest.update(1.0 / 30.0)
		if i == 5:
			start = guest.render_state(guest.my_id).get("position", Vector3.ZERO)
		await wait_physics_frames(1)

	assert_eq(guest.status, ClientSession.Status.IN_GAME)
	assert_eq(main.game.avatar_count(), 2, "the guest is drawn in the host's scene")
	var host_view: Vector3 = main.game.client.render_state(guest.my_id).position
	assert_gt(host_view.x, start.x + 1.0, "host sees the guest moving")

	main.chat.open_input()
	main.chat.submit("hola desde el host")
	for i in 5:
		net.advance(1000.0 / 30.0)
		guest.tick(Vector2.ZERO, Vector3.ZERO)
		await wait_physics_frames(1)
	assert_has(received, ["Prueba", "hola desde el host"])

	main._leave_game()
	for i in 3:
		net.advance(1000.0 / 30.0)
		guest.tick(Vector2.ZERO, Vector3.ZERO)
	assert_eq(guest.status, ClientSession.Status.CLOSED, "guest notices the host left")
	assert_true(main.select_screen.visible)
	guest.leave()
