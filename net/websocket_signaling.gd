class_name WebSocketSignaling
extends Signaling
## Signaling over a WebSocket to the relay server (tools/signaling, URL in
## data/balance.json "signaling_url"). Messages are JSON objects.

const CONNECT_TIMEOUT_MS := 8000

var _ws := WebSocketPeer.new()
var _started_ms: int = 0
var _opened: bool = false
var _closed: bool = false
var _start_error: bool = false


static func host(base_url: String) -> WebSocketSignaling:
	return WebSocketSignaling.new(base_url.trim_suffix("/") + "/host")


static func join(base_url: String, code: String) -> WebSocketSignaling:
	return WebSocketSignaling.new(base_url.trim_suffix("/") + "/join/" + code.uri_encode())


func _init(url: String) -> void:
	_started_ms = Time.get_ticks_msec()
	_start_error = not (url.begins_with("ws://") or url.begins_with("wss://")) \
		or _ws.connect_to_url(url) != OK


func send(to: int, msg: Dictionary) -> void:
	if _closed or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var m := msg.duplicate()
	m["to"] = to
	_ws.send_text(JSON.stringify(m))


func poll() -> void:
	if _closed:
		return
	if _start_error:
		_fail("unreachable")
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_opened = true
	while not _closed and _ws.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if parsed is Dictionary:
			_dispatch(parsed)
	if _closed:
		return
	if state == WebSocketPeer.STATE_CLOSED:
		_fail("closed" if _opened else "unreachable")
	elif state == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _started_ms > CONNECT_TIMEOUT_MS:
		_fail("unreachable")


func close() -> void:
	if _closed:
		return
	_closed = true
	_ws.close()


func _fail(reason: String) -> void:
	close()
	failed.emit(reason)
