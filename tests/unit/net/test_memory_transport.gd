extends GutTest

var net: MemoryNetwork
var host: MemoryTransport
var client: MemoryTransport


func before_each() -> void:
	net = MemoryNetwork.new(42)
	host = net.create_host()
	client = net.connect_client(host)


func _payloads(packets: Array) -> Array:
	var out := []
	for p: Dictionary in packets:
		out.append(p.data)
	return out


func test_connect_announces_both_sides() -> void:
	watch_signals(host)
	watch_signals(client)
	host.poll()
	client.poll()
	assert_signal_emitted_with_parameters(host, "peer_connected", [2])
	assert_signal_emitted_with_parameters(client, "peer_connected", [Transport.HOST_PEER])


func test_zero_latency_delivers_on_next_poll() -> void:
	host.poll()
	client.poll()
	client.send(Transport.HOST_PEER, PackedByteArray([7]), false)
	var got := host.poll()
	assert_eq(got.size(), 1)
	assert_eq(got[0].peer, 2)
	assert_eq(got[0].data, PackedByteArray([7]))


func test_latency_delays_delivery() -> void:
	net.latency_ms = 100
	net.advance(100)
	host.poll()
	client.poll()
	client.send(Transport.HOST_PEER, PackedByteArray([1]), true)
	net.advance(99)
	assert_eq(host.poll().size(), 0)
	net.advance(1)
	assert_eq(host.poll().size(), 1)


func test_connection_waits_for_latency() -> void:
	var n := MemoryNetwork.new(1)
	n.latency_ms = 50
	var h := n.create_host()
	var c := n.connect_client(h)
	watch_signals(c)
	c.poll()
	assert_signal_not_emitted(c, "peer_connected")
	n.advance(50)
	c.poll()
	assert_signal_emitted(c, "peer_connected")


func test_reliable_never_lost_and_ordered() -> void:
	net.loss = 0.5
	net.latency_ms = 30
	net.jitter_ms = 20
	for i in 100:
		client.send(Transport.HOST_PEER, PackedByteArray([i]), true)
		net.advance(1)
	net.advance(200)
	var got := _payloads(host.poll())
	assert_eq(got.size(), 100)
	for i in 100:
		assert_eq(got[i][0], i)


func test_unreliable_loss_rate() -> void:
	net.loss = 0.2
	for i in 1000:
		client.send(Transport.HOST_PEER, PackedByteArray([i % 256]), false)
	var got := host.poll()
	assert_between(1000 - got.size(), 150, 250)


func test_close_notifies_peer() -> void:
	host.poll()
	client.poll()
	watch_signals(host)
	client.close()
	host.poll()
	assert_signal_emitted_with_parameters(host, "peer_disconnected", [2])
	client.send(Transport.HOST_PEER, PackedByteArray([1]), true)
	assert_eq(host.poll().size(), 0)


func test_host_disconnect_peer_notifies_client() -> void:
	host.poll()
	client.poll()
	watch_signals(client)
	host.disconnect_peer(2)
	client.poll()
	assert_signal_emitted_with_parameters(client, "peer_disconnected", [Transport.HOST_PEER])


func test_host_assigns_incrementing_peer_ids() -> void:
	var c2 := net.connect_client(host)
	var c3 := net.connect_client(host)
	watch_signals(host)
	host.poll()
	assert_signal_emit_count(host, "peer_connected", 3)
	c2.send(Transport.HOST_PEER, PackedByteArray([2]), true)
	c3.send(Transport.HOST_PEER, PackedByteArray([3]), true)
	var got := host.poll()
	assert_eq(got[0].peer, 3)
	assert_eq(got[1].peer, 4)


func test_host_sends_to_specific_client() -> void:
	var c2 := net.connect_client(host)
	host.poll()
	client.poll()
	c2.poll()
	host.send(3, PackedByteArray([9]), true)
	assert_eq(client.poll().size(), 0)
	assert_eq(c2.poll().size(), 1)
