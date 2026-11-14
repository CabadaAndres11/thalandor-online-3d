class_name FakeSignaling
extends Signaling
## In-memory stand-in for the signaling server (tools/signaling): one hub holds the rooms;
## each FakeSignaling is one player's connection. Messages arrive on the next poll().
##   var hub := FakeSignaling.Hub.new()
##   var host_sig := hub.open_host("2222-2222"); var guest_sig := hub.open_guest("2222-2222")


class Hub:
	extends RefCounted
	var rooms: Dictionary = {} # code -> {id: FakeSignaling}
	var next_ids: Dictionary = {} # code -> next guest id

	func open_host(code: String) -> FakeSignaling:
		var s := FakeSignaling.new(self, code, 1)
		if rooms.has(code):
			s.inbox.append({"type": "error", "reason": "full"})
			return s
		rooms[code] = {1: s}
		s.inbox.append({"type": "room", "code": code, "id": 1})
		return s

	func open_guest(code: String) -> FakeSignaling:
		var s := FakeSignaling.new(self, code, 0)
		var room: Dictionary = rooms.get(code, {})
		if not room.has(1):
			s.inbox.append({"type": "error", "reason": "no_room"})
			return s
		# Ids only go up (like the server): a guest that left signaling after connecting
		# keeps its id in the game, so it must never be handed out again.
		var id: int = next_ids.get(code, 2)
		next_ids[code] = id + 1
		s.id = id
		room[id] = s
		s.inbox.append({"type": "joined", "id": id})
		(room[1] as FakeSignaling).inbox.append({"type": "peer", "id": id})
		return s

	func relay(code: String, from: int, to: int, msg: Dictionary) -> void:
		var room: Dictionary = rooms.get(code, {})
		if room.has(to) and (from == 1 or to == 1):
			var m := msg.duplicate()
			m.from = from
			(room[to] as FakeSignaling).inbox.append(m)

	func left(code: String, id: int) -> void:
		var room: Dictionary = rooms.get(code, {})
		if not room.has(id):
			return
		room.erase(id)
		for other: FakeSignaling in room.values():
			other.inbox.append({"type": "host_left"} if id == 1 else {"type": "peer_left", "id": id})
		if id == 1:
			rooms.erase(code)
			next_ids.erase(code)

	## Drops every connection (breaks the hub <-> connection references).
	func clear() -> void:
		rooms.clear()
		next_ids.clear()


var inbox: Array = []
var id: int
var sent: Array = [] # [to, msg] for assertions
var _hub: Hub
var _code: String
var _closed: bool = false


func _init(hub: Hub, code: String, p_id: int) -> void:
	_hub = hub
	_code = code
	id = p_id


func send(to: int, msg: Dictionary) -> void:
	if _closed:
		return
	sent.append([to, msg])
	_hub.relay(_code, id, to, msg)


func poll() -> void:
	while not inbox.is_empty() and not _closed:
		_dispatch(inbox.pop_front())


func close() -> void:
	if _closed:
		return
	_closed = true
	if id > 0:
		_hub.left(_code, id)
	_hub = null
