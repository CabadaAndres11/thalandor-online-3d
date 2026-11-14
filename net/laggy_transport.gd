class_name LaggyTransport
extends Transport
## Debug wrapper adding one-way latency (both directions) and unreliable-packet loss to
## another transport. Enabled with the user arguments --lag=<ms> --loss=<percent>.

var latency_ms: float
var loss: float
## Clock in milliseconds; replaceable in tests.
var now_func: Callable = func() -> float: return float(Time.get_ticks_msec())

var _inner: Transport
var _rng := RandomNumberGenerator.new()
var _outgoing: Array = [] # {"at", "peer", "data", "reliable"}
var _incoming: Array = [] # {"at", "peer", "data"}


func _init(inner: Transport, p_latency_ms: float, p_loss: float, seed_value: int = 1) -> void:
	_inner = inner
	latency_ms = p_latency_ms
	loss = p_loss
	_rng.seed = seed_value
	# Bound methods, not lambdas: a lambda using self would keep this object alive (cycle).
	inner.peer_connected.connect(_forward_connected)
	inner.peer_disconnected.connect(_forward_disconnected)
	inner.connection_failed.connect(_forward_failed)


func send(peer: int, data: PackedByteArray, reliable: bool) -> void:
	if not reliable and _rng.randf() < loss:
		return
	_outgoing.append({"at": now_func.call() + latency_ms, "peer": peer, "data": data, "reliable": reliable})


func poll() -> Array:
	var now: float = now_func.call()
	while not _outgoing.is_empty() and float(_outgoing[0].at) <= now:
		var o: Dictionary = _outgoing.pop_front()
		_inner.send(o.peer, o.data, o.reliable)
	for p: Dictionary in _inner.poll():
		_incoming.append({"at": now + latency_ms, "peer": p.peer, "data": p.data})
	var out := []
	while not _incoming.is_empty() and float(_incoming[0].at) <= now:
		var i: Dictionary = _incoming.pop_front()
		out.append({"peer": i.peer, "data": i.data})
	return out


func disconnect_peer(peer: int) -> void:
	_inner.disconnect_peer(peer)


func close() -> void:
	_inner.close()


func _forward_connected(p: int) -> void:
	peer_connected.emit(p)


func _forward_disconnected(p: int) -> void:
	peer_disconnected.emit(p)


func _forward_failed() -> void:
	connection_failed.emit()
