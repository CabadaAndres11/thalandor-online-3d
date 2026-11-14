extends GutTest
## Real WebRTC data channels between two transports in this process (host candidates on
## localhost, no STUN), introduced through the in-memory FakeSignaling hub.

const CODE := "2222-2222"

var hub: FakeSignaling.Hub
var transports: Array = []
var received: Dictionary = {} # transport -> Array of packets


func before_each() -> void:
	hub = FakeSignaling.Hub.new()
	received = {}


func after_each() -> void:
	for t: Transport in transports:
		t.close()
	transports.clear()
	received.clear()
	hub.clear()


func _track(t: Transport) -> Transport:
	transports.append(t)
	received[t] = []
	return t


func _poll_until(cond: Callable, seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0 and not cond.call():
		for t: Transport in transports:
			(received[t] as Array).append_array(t.poll())
		await wait_seconds(0.02)


func test_host_and_guest_connect_and_exchange() -> void:
	var host: WebRtcTransport = _track(WebRtcTransport.host(hub.open_host(CODE), []))
	var codes := []
	host.room_opened.connect(func(c: String) -> void: codes.append(c))
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest(CODE), []))
	var seen := {"host": [], "guest": []}
	host.peer_connected.connect(func(p: int) -> void: seen.host.append(p))
	guest.peer_connected.connect(func(p: int) -> void: seen.guest.append(p))
	await _poll_until(func() -> bool: return not seen.host.is_empty() and not seen.guest.is_empty(), 10.0)
	assert_eq(codes, [CODE], "host learns its room code")
	assert_eq(seen.guest, [Transport.HOST_PEER], "guest sees the host as peer 1")
	assert_eq(seen.host, [2], "host sees the guest with its signaling id")

	guest.send(Transport.HOST_PEER, PackedByteArray([1, 2, 3]), true)
	guest.send(Transport.HOST_PEER, PackedByteArray([4]), false)
	host.send(2, PackedByteArray([9, 9]), true)
	await _poll_until(func() -> bool:
		return (received[host] as Array).size() >= 2 and (received[guest] as Array).size() >= 1, 5.0)
	var at_host: Array = (received[host] as Array).map(func(p: Dictionary) -> PackedByteArray: return p.data)
	assert_has(at_host, PackedByteArray([1, 2, 3]))
	assert_has(at_host, PackedByteArray([4]))
	assert_eq(int((received[host] as Array)[0].peer), 2)
	assert_eq((received[guest] as Array)[0].data, PackedByteArray([9, 9]))
	assert_eq(int((received[guest] as Array)[0].peer), Transport.HOST_PEER)


func test_host_notices_guest_leaving() -> void:
	var host: WebRtcTransport = _track(WebRtcTransport.host(hub.open_host(CODE), []))
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest(CODE), []))
	var gone := []
	host.peer_disconnected.connect(func(p: int) -> void: gone.append(p))
	await _poll_until(func() -> bool: return guest.is_connected_to_host(), 10.0)
	assert_true(guest.is_connected_to_host())
	guest.close()
	transports.erase(guest)
	await _poll_until(func() -> bool: return not gone.is_empty(), 10.0)
	assert_eq(gone, [2])
	_accept_close_warnings()


func test_guest_notices_host_leaving() -> void:
	var host: WebRtcTransport = _track(WebRtcTransport.host(hub.open_host(CODE), []))
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest(CODE), []))
	var gone := []
	guest.peer_disconnected.connect(func(p: int) -> void: gone.append(p))
	await _poll_until(func() -> bool: return guest.is_connected_to_host(), 10.0)
	host.close()
	transports.erase(host)
	await _poll_until(func() -> bool: return not gone.is_empty(), 10.0)
	assert_eq(gone, [Transport.HOST_PEER])
	_accept_close_warnings()


func test_unknown_room_fails() -> void:
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest("3333-3333"), []))
	var failed := [false]
	guest.connection_failed.connect(func() -> void: failed[0] = true)
	await _poll_until(func() -> bool: return failed[0], 2.0)
	assert_true(failed[0])
	assert_eq(guest.last_failure, "no_room")


func test_no_answer_times_out() -> void:
	var host_sig := hub.open_host(CODE) # a room whose host never runs a transport
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest(CODE), []))
	guest.connect_timeout_ms = 300
	var failed := [false]
	guest.connection_failed.connect(func() -> void: failed[0] = true)
	await _poll_until(func() -> bool: return failed[0], 3.0)
	assert_true(failed[0])
	assert_eq(guest.last_failure, "timeout")
	host_sig.close()


func test_host_signaling_failure_reported() -> void:
	hub.open_host(CODE)
	var host: WebRtcTransport = _track(WebRtcTransport.host(hub.open_host(CODE), []))
	var failed := [false]
	host.connection_failed.connect(func() -> void: failed[0] = true)
	await _poll_until(func() -> bool: return failed[0], 2.0)
	assert_true(failed[0])
	assert_eq(host.last_failure, "full")


func test_guest_closes_signaling_once_connected() -> void:
	var host: WebRtcTransport = _track(WebRtcTransport.host(hub.open_host(CODE), []))
	var guest: WebRtcTransport = _track(WebRtcTransport.join(hub.open_guest(CODE), []))
	var gone := []
	host.peer_disconnected.connect(func(p: int) -> void: gone.append(p))
	await _poll_until(func() -> bool: return guest.is_connected_to_host(), 10.0)
	await _poll_until(func() -> bool: return false, 0.5)
	assert_false((hub.rooms[CODE] as Dictionary).has(2), "guest left the signaling room")
	assert_eq(gone, [], "the game connection stays up")


## The library may warn that it could not reset a channel the other side already closed;
## that is expected when a peer leaves.
func _accept_close_warnings() -> void:
	for err: Variant in get_errors():
		if err.contains_text("SctpTransport::sendReset"):
			err.handled = true
