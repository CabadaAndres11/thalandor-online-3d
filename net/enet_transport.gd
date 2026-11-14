class_name EnetTransport
extends Transport
## ENet (UDP) transport. Uses ENetMultiplayerPeer directly as a packet peer;
## channel 0 carries reliable messages and channel 1 unreliable ones.

const CHANNEL_RELIABLE := 0
const CHANNEL_UNRELIABLE := 1
const CONNECT_TIMEOUT_MS := 5000

## Error of the last failed host()/join() call.
static var last_error: Error = OK

var _peer: ENetMultiplayerPeer
var _is_server: bool = false
var _was_connected: bool = false
var _closed: bool = false


static func host(port: int, max_clients: int) -> EnetTransport:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, max_clients, 2)
	if err != OK:
		last_error = err
		return null
	last_error = OK
	return EnetTransport.new(p, true)


static func join(ip: String, port: int) -> EnetTransport:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port, 2)
	if err != OK:
		last_error = err
		return null
	last_error = OK
	var host_peer := p.get_peer(Transport.HOST_PEER)
	if host_peer != null:
		host_peer.set_timeout(0, CONNECT_TIMEOUT_MS, CONNECT_TIMEOUT_MS)
	return EnetTransport.new(p, false)


func _init(peer: ENetMultiplayerPeer, is_server: bool) -> void:
	_peer = peer
	_is_server = is_server
	# Bound methods, not lambdas: a lambda using self would keep this object alive (cycle).
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func send(peer: int, data: PackedByteArray, reliable: bool) -> void:
	if _closed or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_peer.set_target_peer(peer)
	if reliable:
		_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
		_peer.transfer_channel = CHANNEL_RELIABLE
	else:
		_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		_peer.transfer_channel = CHANNEL_UNRELIABLE
	_peer.put_packet(data)


func poll() -> Array:
	if _closed:
		return []
	_peer.poll()
	var status := _peer.get_connection_status()
	if not _is_server:
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			_was_connected = true
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED and not _was_connected:
			_closed = true
			connection_failed.emit()
			return []
	var packets := []
	while _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		var data := _peer.get_packet()
		packets.append({"peer": from, "data": data})
	return packets


func disconnect_peer(peer: int) -> void:
	if not _closed:
		_peer.disconnect_peer(peer)


func close() -> void:
	if _closed:
		return
	_closed = true
	_peer.close()


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)
