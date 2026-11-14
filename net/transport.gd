class_name Transport
extends RefCounted
## Packet transport between the host (peer 1) and its guests.
## Implementations: MemoryTransport (loopback/tests), EnetTransport, LaggyTransport.

signal peer_connected(peer: int)
signal peer_disconnected(peer: int)
signal connection_failed()

const HOST_PEER := 1


func send(_peer: int, _data: PackedByteArray, _reliable: bool) -> void:
	pass


## Returns received packets as [{"peer": int, "data": PackedByteArray}, ...] and emits
## connection signals for events that happened since the last poll.
func poll() -> Array:
	return []


func disconnect_peer(_peer: int) -> void:
	pass


func close() -> void:
	pass
