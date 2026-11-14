class_name NetHarness
extends RefCounted
## Test rig: one HostSession, its own player over a zero-latency loopback and remote
## guests over a MemoryNetwork with configurable latency, jitter and loss.

const VERSION := "0.1.0"

var balance: Balance
var map: CollisionMap
var host: HostSession
var loopback: MemoryNetwork
var remote: MemoryNetwork
var clients: Dictionary = {} # name -> ClientSession
var chats: Dictionary = {} # name -> Array of [author, text, is_system]
var host_paused: bool = false

var _loop_host: MemoryTransport
var _remote_host: MemoryTransport


func _init(latency_ms: float, jitter_ms: float, loss: float, seed_value: int) -> void:
	balance = Balance.load_from()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/test_arena.json"))
	map = CollisionMap.from_layout(data)
	host = HostSession.new(balance, map, VERSION)
	loopback = MemoryNetwork.new(seed_value)
	remote = MemoryNetwork.new(seed_value + 1)
	remote.latency_ms = latency_ms
	remote.jitter_ms = jitter_ms
	remote.loss = loss
	_loop_host = loopback.create_host()
	_remote_host = remote.create_host()
	host.add_transport(_loop_host)
	host.add_transport(_remote_host)


## The first client plays on the host machine (loopback); the rest are remote guests.
func add_client(name: String, version: String = VERSION) -> ClientSession:
	var c := ClientSession.new(balance, map, version, name)
	if clients.is_empty():
		c.connect_to(loopback.connect_client(_loop_host))
	else:
		c.connect_to(remote.connect_client(_remote_host))
	clients[name] = c
	chats[name] = []
	c.chat_received.connect(func(author: String, text: String, sys: bool) -> void:
		chats[name].append([author, text, sys]))
	return c


func remove_client(name: String) -> void:
	(clients[name] as ClientSession).leave()
	clients.erase(name)


## Advances n ticks. `moves` maps client name -> Vector2 (world XZ direction).
func run_ticks(n: int, moves: Dictionary = {}) -> void:
	var dt := balance.dt()
	for i in n:
		loopback.advance(dt * 1000.0)
		remote.advance(dt * 1000.0)
		for name: String in clients:
			(clients[name] as ClientSession).tick(moves.get(name, Vector2.ZERO), Vector3(20.5, 0, 35))
		if not host_paused:
			host.tick()
		for name: String in clients:
			(clients[name] as ClientSession).update(dt)


func id_of(name: String) -> int:
	return (clients[name] as ClientSession).my_id
