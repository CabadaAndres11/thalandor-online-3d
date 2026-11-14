class_name MemoryTransport
extends Transport
## One endpoint of a MemoryNetwork. Remote endpoints are held weakly to avoid cycles.

var _network: MemoryNetwork
var _is_host: bool
var _next_peer_id: int = 2
## peer id (as seen here) -> {"remote": WeakRef, "my_id": int (our id as seen by the remote), "last_reliable": float}
var _links: Dictionary = {}
var _inbox: Array = []
var _closed: bool = false


func _init(network: MemoryNetwork, is_host: bool) -> void:
	_network = network
	_is_host = is_host


func send(peer: int, data: PackedByteArray, reliable: bool) -> void:
	if _closed or not _links.has(peer):
		return
	var link: Dictionary = _links[peer]
	var remote: MemoryTransport = link.remote.get_ref()
	if remote == null or remote._closed:
		return
	if not reliable and _network._lost():
		return
	var at := _network.now_ms + _network._delay()
	if reliable:
		at = maxf(at, link.last_reliable)
		link.last_reliable = at
	remote._enqueue({"at": at, "kind": "packet", "peer": link.my_id, "data": data})


func poll() -> Array:
	var packets := []
	var remaining := []
	var due := []
	for ev: Dictionary in _inbox:
		if ev.at <= _network.now_ms:
			due.append(ev)
		else:
			remaining.append(ev)
	_inbox = remaining
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.at < b.at or (a.at == b.at and a.order < b.order))
	for ev: Dictionary in due:
		match ev.kind:
			"packet":
				if _links.has(ev.peer):
					packets.append({"peer": ev.peer, "data": ev.data})
			"connect":
				if _links.has(ev.peer):
					peer_connected.emit(ev.peer)
			"disconnect":
				if _links.has(ev.peer):
					_links.erase(ev.peer)
					peer_disconnected.emit(ev.peer)
	return packets


func disconnect_peer(peer: int) -> void:
	if not _links.has(peer):
		return
	var link: Dictionary = _links[peer]
	var remote: MemoryTransport = link.remote.get_ref()
	if remote != null:
		remote._enqueue({"at": _network.now_ms + _network.latency_ms, "kind": "disconnect", "peer": link.my_id})
	_links.erase(peer)


func close() -> void:
	for peer: int in _links.keys():
		disconnect_peer(peer)
	_closed = true


func _link(peer: int, remote: MemoryTransport, my_id: int) -> void:
	_links[peer] = {"remote": weakref(remote), "my_id": my_id, "last_reliable": 0.0}


func _enqueue(ev: Dictionary) -> void:
	ev["order"] = _network._next_order()
	_inbox.append(ev)
