class_name WebRtcTransport
extends Transport
## WebRTC transport (webrtc-native addon): a star of data channels between the host
## (peer 1) and each guest, set up through a Signaling channel. Reliable messages use
## the reliable channel and the rest the unreliable one, like EnetTransport.

## Emitted on the host when the signaling server gives it a room code.
signal room_opened(code: String)

const DEFAULT_CONNECT_TIMEOUT_MS := 15000

## Guests give up if the host is not reachable in this time (e.g. blocked by NAT).
var connect_timeout_ms: int = DEFAULT_CONNECT_TIMEOUT_MS
## Why connection_failed was emitted: a Signaling reason or "timeout".
var last_failure: String = ""

var _signaling: Signaling
var _ice_servers: Array
var _is_server: bool
var _peer := WebRTCMultiplayerPeer.new()
var _peer_ready: bool = false
var _connections: Dictionary = {} # peer id -> WebRTCPeerConnection
var _left_signaling: Dictionary = {} # host: guest id -> msec its signaling left while connecting
var _started_ms: int = 0
var _was_connected: bool = false
var _room_open: bool = false
var _closed: bool = false


## ice_servers: e.g. [{"urls": ["stun:stun.l.google.com:19302"]}]; [] for localhost only.
static func host(signaling: Signaling, ice_servers: Array) -> WebRtcTransport:
	return WebRtcTransport.new(signaling, true, ice_servers)


static func join(signaling: Signaling, ice_servers: Array) -> WebRtcTransport:
	return WebRtcTransport.new(signaling, false, ice_servers)


## ICE server list for one STUN URL ("" = none).
static func ice_from_url(stun_url: String) -> Array:
	return [] if stun_url == "" else [{"urls": [stun_url]}]


func _init(signaling: Signaling, is_server: bool, ice_servers: Array) -> void:
	_signaling = signaling
	_is_server = is_server
	_ice_servers = ice_servers
	_started_ms = Time.get_ticks_msec()
	# Bound methods, not lambdas: a lambda using self would keep this object alive (cycle).
	signaling.room_opened.connect(_on_room_opened)
	signaling.joined.connect(_on_joined)
	signaling.peer_arrived.connect(_on_peer_arrived)
	signaling.peer_left.connect(_on_signaling_peer_left)
	signaling.relayed.connect(_on_relayed)
	signaling.failed.connect(_on_signaling_failed)
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	if is_server:
		_peer_ready = _peer.create_server() == OK


func send(peer: int, data: PackedByteArray, reliable: bool) -> void:
	if _closed or not _peer_ready or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_peer.set_target_peer(peer)
	_peer.transfer_channel = 0 # default channel of each transfer mode
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	_peer.put_packet(data)


func poll() -> Array:
	if _closed:
		return []
	_signaling.poll()
	if _closed or not _peer_ready:
		_check_timeout()
		return []
	_peer.poll()
	if _closed:
		return []
	if _is_server:
		_drop_stalled_guests()
	elif not _was_connected:
		if is_connected_to_host():
			_was_connected = true
			# The game no longer needs the server; frees the room slot.
			_signaling.close()
		else:
			_check_timeout()
	var packets := []
	while not _closed and _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		packets.append({"peer": from, "data": _peer.get_packet()})
	return packets


func is_connected_to_host() -> bool:
	return _peer_ready and not _is_server and _peer.has_peer(Transport.HOST_PEER) \
		and bool(_peer.get_peer(Transport.HOST_PEER).connected)


func disconnect_peer(peer: int) -> void:
	if not _closed and _peer_ready and _peer.has_peer(peer):
		_peer.disconnect_peer(peer)


func close() -> void:
	if _closed:
		return
	_closed = true
	_signaling.close()
	_peer.close() # also closes every peer connection
	_connections.clear()
	_left_signaling.clear()


func _check_timeout() -> void:
	if not _closed and not _is_server and Time.get_ticks_msec() - _started_ms > connect_timeout_ms:
		_fail("timeout")


func _fail(reason: String) -> void:
	last_failure = reason
	close()
	connection_failed.emit()


func _new_connection(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize({"iceServers": _ice_servers})
	c.session_description_created.connect(_on_description_created.bind(id))
	c.ice_candidate_created.connect(_on_candidate_created.bind(id))
	_connections[id] = c
	_peer.add_peer(c, id)
	return c


func _on_room_opened(code: String) -> void:
	_room_open = true
	room_opened.emit(code)


func _on_joined(my_id: int) -> void:
	if not _is_server and not _peer_ready:
		_peer_ready = _peer.create_client(my_id) == OK


func _on_peer_arrived(id: int) -> void:
	if _is_server and _peer_ready and not _connections.has(id):
		_new_connection(id).create_offer()


## Host: a guest whose signaling left while still connecting gets until the connect
## timeout to finish, then is dropped.
func _drop_stalled_guests() -> void:
	var now := Time.get_ticks_msec()
	for id: int in _left_signaling.keys():
		if not _peer.has_peer(id) or bool(_peer.get_peer(id).connected):
			_left_signaling.erase(id)
		elif now - int(_left_signaling[id]) > connect_timeout_ms:
			_left_signaling.erase(id)
			_peer.remove_peer(id)
			_connections.erase(id)


func _on_signaling_peer_left(id: int) -> void:
	# A guest closes its signaling as soon as it sees the connection open, which can be
	# a moment before the host does; don't drop it yet (see _drop_stalled_guests).
	if not _is_server or not _connections.has(id) or not _peer.has_peer(id):
		return
	if not bool(_peer.get_peer(id).connected):
		_left_signaling[id] = Time.get_ticks_msec()


func _on_relayed(from: int, msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"offer":
			if not _is_server and _peer_ready and from == Transport.HOST_PEER:
				var c: WebRTCPeerConnection = _connections.get(from)
				if c == null:
					c = _new_connection(from)
				c.set_remote_description("offer", str(msg.get("sdp", "")))
		"answer":
			if _is_server and _connections.has(from):
				(_connections[from] as WebRTCPeerConnection).set_remote_description("answer", str(msg.get("sdp", "")))
		"candidate":
			if _connections.has(from):
				(_connections[from] as WebRTCPeerConnection).add_ice_candidate(
					str(msg.get("media", "")), int(msg.get("index", 0)), str(msg.get("name", "")))


func _on_description_created(type: String, sdp: String, id: int) -> void:
	var c: WebRTCPeerConnection = _connections.get(id)
	if c == null:
		return
	c.set_local_description(type, sdp)
	_signaling.send(id, {"type": type, "sdp": sdp})


func _on_candidate_created(media: String, index: int, candidate: String, id: int) -> void:
	_signaling.send(id, {"type": "candidate", "media": media, "index": index, "name": candidate})


func _on_signaling_failed(reason: String) -> void:
	if _closed:
		return
	if _is_server:
		# After the room is open the game goes on; only new guests are affected.
		if not _room_open:
			_fail(reason)
	elif not _was_connected:
		_fail(reason)


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_connections.erase(id)
	_left_signaling.erase(id)
	peer_disconnected.emit(id)
