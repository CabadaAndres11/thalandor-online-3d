extends GutTest

const NAMES := ["Ana", "Bea", "Cris", "Dani"]
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0.7, -0.7)]


func _join_all(h: NetHarness) -> void:
	for n: String in NAMES:
		h.add_client(n)
	h.run_ticks(30)


func test_four_players_converge_with_lag_and_loss() -> void:
	var h := NetHarness.new(150, 20, 0.05, 11)
	_join_all(h)
	var moves := {}
	for i in NAMES.size():
		moves[NAMES[i]] = DIRS[i]
	var max_correction := 0.0
	for t in 90:
		h.run_ticks(1, moves)
		for n: String in NAMES:
			max_correction = maxf(max_correction, (h.clients[n] as ClientSession).last_correction)
	h.run_ticks(60)
	for viewer: String in NAMES:
		var c: ClientSession = h.clients[viewer]
		assert_eq(c.status, ClientSession.Status.IN_GAME, viewer)
		for target: String in NAMES:
			var id := h.id_of(target)
			var seen: Vector3 = c.render_state(id).position
			var truth: Vector3 = h.host.world.players[id].position
			assert_almost_eq(seen.distance_to(truth), 0.0, 0.05, "%s sees %s" % [viewer, target])
	assert_lt(max_correction, 0.5, "own-player corrections stay small")


func test_fifth_client_rejected() -> void:
	var h := NetHarness.new(80, 0, 0, 2)
	_join_all(h)
	var e := h.add_client("Eva")
	watch_signals(e)
	h.run_ticks(15)
	assert_signal_emitted_with_parameters(e, "rejected", ["full", NetHarness.VERSION])


func test_version_mismatch_rejected() -> void:
	var h := NetHarness.new(80, 0, 0, 3)
	h.add_client("Ana")
	var b := h.add_client("Bea", "0.0.1")
	watch_signals(b)
	h.run_ticks(15)
	assert_signal_emitted_with_parameters(b, "rejected", ["version", NetHarness.VERSION])


func test_rejoin_reuses_free_slot() -> void:
	var h := NetHarness.new(80, 10, 0.05, 4)
	_join_all(h)
	var freed_slot: int = (h.clients["Ana"] as ClientSession).roster[h.id_of("Bea")].slot
	h.remove_client("Bea")
	h.run_ticks(15)
	var e := h.add_client("Eva")
	h.run_ticks(15)
	assert_eq(e.roster[e.my_id].slot, freed_slot)
	var reference: Dictionary = (h.clients["Ana"] as ClientSession).roster
	for n: String in h.clients:
		assert_eq((h.clients[n] as ClientSession).roster, reference, n)


func test_chat_reaches_everyone_in_order() -> void:
	var h := NetHarness.new(120, 30, 0.05, 5)
	_join_all(h)
	for n: String in NAMES:
		h.chats[n].clear()
	(h.clients["Bea"] as ClientSession).send_chat("uno")
	h.run_ticks(1)
	(h.clients["Ana"] as ClientSession).send_chat("dos")
	h.run_ticks(1)
	(h.clients["Dani"] as ClientSession).send_chat("tres")
	h.run_ticks(30)
	# The host's arrival order is authoritative (Ana plays on the host, so "dos" may come
	# first); what matters is that every player sees the same complete sequence.
	var reference: Array = h.chats["Ana"]
	assert_eq(reference.size(), 3)
	for msg: Array in [["Bea", "uno", false], ["Ana", "dos", false], ["Dani", "tres", false]]:
		assert_has(reference, msg)
	for n: String in NAMES:
		assert_eq(h.chats[n], reference, n)


func test_host_stall_recovers() -> void:
	var h := NetHarness.new(100, 10, 0.02, 6)
	_join_all(h)
	var moves := {"Bea": Vector2(1, 0)}
	h.run_ticks(15, moves)
	h.host_paused = true
	h.run_ticks(30, moves)
	h.host_paused = false
	h.run_ticks(30, moves)
	h.run_ticks(60)
	var bal := h.balance
	for n: String in NAMES:
		var c: ClientSession = h.clients[n]
		assert_eq(c.status, ClientSession.Status.IN_GAME, n)
		var id := h.id_of("Bea")
		assert_almost_eq(c.render_state(id).position.distance_to(h.host.world.players[id].position), 0.0, 0.05, n)
		assert_lte(h.host.pending_inputs(h.id_of(n)), bal.max_pending_inputs)
