extends GutTest

const PORT := 24690

var transports: Array = []


func after_each() -> void:
	for t: Transport in transports:
		t.close()
	transports.clear()


func _poll_until(cond: Callable, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not cond.call():
		for t: Transport in transports:
			_received[t] = (_received.get(t, []) as Array) + t.poll()
		await wait_seconds(0.02)
		elapsed += 0.02


var _received: Dictionary = {}


func test_localhost_connect_and_exchange() -> void:
	_received.clear()
	var server := EnetTransport.host(PORT, 3)
	assert_not_null(server)
	var client := EnetTransport.join("127.0.0.1", PORT)
	transports.append_array([server, client])
	var events := {"server": 0, "client": 0}
	server.peer_connected.connect(func(_p: int) -> void: events.server += 1)
	client.peer_connected.connect(func(p: int) -> void:
		if p == Transport.HOST_PEER:
			events.client += 1)
	await _poll_until(func() -> bool: return events.server > 0 and events.client > 0, 2.0)
	assert_eq(events.client, 1, "client sees the host")
	assert_eq(events.server, 1, "server sees the client")
	client.send(Transport.HOST_PEER, PackedByteArray([1, 2, 3]), true)
	client.send(Transport.HOST_PEER, PackedByteArray([4]), false)
	await _poll_until(func() -> bool: return (_received.get(server, []) as Array).size() >= 2, 2.0)
	var got: Array = _received.get(server, [])
	assert_eq(got.size(), 2)
	var datas := got.map(func(p: Dictionary) -> PackedByteArray: return p.data)
	assert_has(datas, PackedByteArray([1, 2, 3]))
	assert_has(datas, PackedByteArray([4]))
	assert_gt(int(got[0].peer), 1)


func test_port_in_use_returns_null() -> void:
	var first := EnetTransport.host(PORT + 1, 3)
	transports.append(first)
	var second := EnetTransport.host(PORT + 1, 3)
	assert_null(second)
	assert_ne(EnetTransport.last_error, OK)
	assert_engine_error("Couldn't create an ENet host")


func test_join_unreachable_fails() -> void:
	_received.clear()
	var client := EnetTransport.join("127.0.0.1", PORT + 2)
	transports.append(client)
	var failed := [false]
	client.connection_failed.connect(func() -> void: failed[0] = true)
	await _poll_until(func() -> bool: return failed[0], 8.0)
	assert_true(failed[0], "connection_failed emitted")
