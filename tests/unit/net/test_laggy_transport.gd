extends GutTest

var net: MemoryNetwork
var host: MemoryTransport
var laggy: LaggyTransport


func before_each() -> void:
	net = MemoryNetwork.new(5)
	host = net.create_host()
	laggy = LaggyTransport.new(net.connect_client(host), 100, 0.0, 1)
	laggy.now_func = func() -> float: return net.now_ms
	host.poll()
	laggy.poll()


func test_outgoing_is_delayed() -> void:
	laggy.send(Transport.HOST_PEER, PackedByteArray([1]), true)
	laggy.poll()
	assert_eq(host.poll().size(), 0)
	net.advance(100)
	laggy.poll()
	assert_eq(host.poll().size(), 1)


func test_incoming_is_delayed() -> void:
	host.send(2, PackedByteArray([2]), true)
	assert_eq(laggy.poll().size(), 0)
	net.advance(100)
	assert_eq(laggy.poll().size(), 1)


func test_drops_unreliable_but_not_reliable() -> void:
	laggy.loss = 0.5
	for i in 200:
		laggy.send(Transport.HOST_PEER, PackedByteArray([0]), false)
		laggy.send(Transport.HOST_PEER, PackedByteArray([1]), true)
	net.advance(100)
	laggy.poll()
	var reliable := 0
	var unreliable := 0
	for p: Dictionary in host.poll():
		if p.data[0] == 1:
			reliable += 1
		else:
			unreliable += 1
	assert_eq(reliable, 200)
	assert_between(unreliable, 60, 140)


func test_forwards_disconnect_signal() -> void:
	watch_signals(laggy)
	host.close()
	laggy.poll()
	assert_signal_emitted_with_parameters(laggy, "peer_disconnected", [Transport.HOST_PEER])
