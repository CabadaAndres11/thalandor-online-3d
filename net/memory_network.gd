class_name MemoryNetwork
extends RefCounted
## In-memory network with a manual clock, latency, jitter and loss of unreliable packets.
## Used for the host's own player (zero latency) and for network tests.

var latency_ms: float = 0.0
var jitter_ms: float = 0.0
var loss: float = 0.0
var now_ms: float = 0.0

var _rng := RandomNumberGenerator.new()
var _order: int = 0


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func create_host() -> MemoryTransport:
	return MemoryTransport.new(self, true)


func connect_client(host: MemoryTransport) -> MemoryTransport:
	var client := MemoryTransport.new(self, false)
	var id := host._next_peer_id
	host._next_peer_id += 1
	host._link(id, client, Transport.HOST_PEER)
	client._link(Transport.HOST_PEER, host, id)
	var at := now_ms + latency_ms
	host._enqueue({"at": at, "kind": "connect", "peer": id})
	client._enqueue({"at": at, "kind": "connect", "peer": Transport.HOST_PEER})
	return client


func advance(ms: float) -> void:
	now_ms += ms


func _delay() -> float:
	var j := _rng.randf_range(-jitter_ms, jitter_ms) if jitter_ms > 0.0 else 0.0
	return maxf(0.0, latency_ms + j)


func _lost() -> bool:
	return loss > 0.0 and _rng.randf() < loss


func _next_order() -> int:
	_order += 1
	return _order
