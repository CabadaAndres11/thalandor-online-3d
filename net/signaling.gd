class_name Signaling
extends RefCounted
## Signaling channel for WebRTC: the relay server (tools/signaling) introduces the host
## (id 1) and its guests and forwards their offers, answers and ICE candidates.
## Implementations: WebSocketSignaling (the real server) and FakeSignaling (tests).

signal room_opened(code: String)
signal joined(my_id: int)
signal peer_arrived(id: int)
signal peer_left(id: int)
signal relayed(from: int, msg: Dictionary)
## reason: "no_room", "full", "bad_code", "host_left", "unreachable" or "closed".
signal failed(reason: String)


func send(_to: int, _msg: Dictionary) -> void:
	pass


## Reads pending server messages and emits the signals above.
func poll() -> void:
	pass


func close() -> void:
	pass


func _dispatch(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"room":
			room_opened.emit(str(msg.get("code", "")))
		"joined":
			joined.emit(int(msg.get("id", 0)))
		"peer":
			peer_arrived.emit(int(msg.get("id", 0)))
		"peer_left":
			peer_left.emit(int(msg.get("id", 0)))
		"host_left":
			failed.emit("host_left")
		"error":
			failed.emit(str(msg.get("reason", "closed")))
		"offer", "answer", "candidate":
			relayed.emit(int(msg.get("from", 0)), msg)
