class_name HostSession
extends RefCounted
## Authoritative simulation: accepts guests, consumes their inputs and broadcasts snapshots.

signal player_joined(id: int, name: String)
signal player_left(id: int)

const NAME_MIN := 2
const NAME_MAX := 16
const SPAWN_SPACING := 1.5

var world: SimWorld
## Sanitizes the class and appearance guests bring (they may send anything).
var catalog: CharacterCatalog = CharacterCatalog.load_default()
var balance: Balance
var map: CollisionMap
var game_version: String

var _transports: Array = []
var _players: Dictionary = {} # player id -> record
var _by_conn: Dictionary = {} # "transport_index:peer" -> player id
var _next_id: int = 1
static var _name_regex: RegEx


func _init(p_balance: Balance, p_map: CollisionMap, p_game_version: String) -> void:
	balance = p_balance
	map = p_map
	game_version = p_game_version
	world = SimWorld.new(balance, map, randi())


static func is_valid_name(name: String) -> bool:
	var n := name.strip_edges()
	if n != name and name.strip_edges() == "":
		return false
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return false
	if _name_regex == null:
		_name_regex = RegEx.create_from_string(r"^[\p{L}\p{N} '\-]+$")
	return _name_regex.search(n) != null


func add_transport(t: Transport) -> void:
	var index := _transports.size()
	_transports.append(t)
	t.peer_disconnected.connect(_on_peer_disconnected.bind(index))


func tick() -> void:
	for index in _transports.size():
		var t: Transport = _transports[index]
		for packet: Dictionary in t.poll():
			_handle(index, packet.peer, packet.data)
	world.events.clear()
	var inputs := {}
	for id: int in _players:
		var rec: Dictionary = _players[id]
		var queue: Array = rec.queue
		if not queue.is_empty():
			var next: PlayerInput = queue.pop_front()
			rec.last_input = next
			rec.last_seq = next.seq
			inputs[id] = next
			_cast_from_input(rec, next)
		elif rec.last_input != null:
			# No new input this tick: keep moving/holding, but never repeat presses.
			inputs[id] = (rec.last_input as PlayerInput).held_only()
	world.step(inputs)
	_broadcast(Protocol.snapshot(world.tick, _snapshot_rows(), _monster_rows()), false)
	if not world.events.is_empty():
		_broadcast(Protocol.events(world.tick, world.events.duplicate()), true)


## Presses of a new input become casts: basic, secondary and the bar slots.
func _cast_from_input(rec: Dictionary, input: PlayerInput) -> void:
	var p: PlayerState = world.players.get(rec.id)
	if p == null:
		return
	var basic := world.abilities.get_ability(rec.basic_id)
	if basic.has("charge"):
		# Archer: press starts charging, release fires (a quick tap = normal shot).
		if input.pressed(PlayerInput.BTN_BASIC) and p.charge_start < 0:
			p.charge_start = world.tick
		elif p.charge_start >= 0 and not input.pressed(PlayerInput.BTN_BASIC_HELD):
			var max_ticks := maxi(1, world.ticks(float(basic.charge.get("max_s", 1.5))))
			var ratio := float(world.tick - p.charge_start) / float(max_ticks)
			p.charge_start = -1
			ClassRules.release_charged(world, p, rec.basic_id, input.aim, ratio)
	elif input.pressed(PlayerInput.BTN_BASIC):
		Combat.try_cast(world, p, rec.basic_id, input.aim)
	if input.pressed(PlayerInput.BTN_SECONDARY):
		Combat.try_cast(world, p, rec.secondary_id, input.aim)
	for i in PlayerInput.SLOT_BITS.size():
		if input.pressed(PlayerInput.SLOT_BITS[i]) and str(rec.bar[i]) != "":
			Combat.try_cast(world, p, rec.bar[i], input.aim)


func close() -> void:
	for t: Transport in _transports:
		t.close()
	_transports.clear()


func player_count() -> int:
	return _players.size()


func last_seq(id: int) -> int:
	return int(_players[id].last_seq) if _players.has(id) else 0


func pending_inputs(id: int) -> int:
	return (_players[id].queue as Array).size() if _players.has(id) else 0


func roster() -> Array:
	var rows := []
	for id: int in _players:
		var p: Dictionary = _players[id]
		rows.append([id, p.name, p.slot, p.class_id, p.appearance])
	return rows


func _handle(index: int, peer: int, data: PackedByteArray) -> void:
	var msg := Protocol.decode(data)
	if msg.is_empty():
		return
	var key := "%d:%d" % [index, peer]
	if msg.type == Protocol.Msg.HELLO:
		if not _by_conn.has(key):
			_on_hello(index, peer, key, msg)
		return
	if not _by_conn.has(key):
		return
	var rec: Dictionary = _players[_by_conn[key]]
	match msg.type:
		Protocol.Msg.INPUT:
			_on_input(rec, msg.inputs)
		Protocol.Msg.SET_BAR:
			rec.bar = world.abilities.sanitize_bar(rec.class_id, msg.bar)
		Protocol.Msg.CHAT:
			var text: String = (msg.text as String).strip_edges().left(balance.chat_max_len)
			if text != "":
				_broadcast(Protocol.chat(rec.id, text), true)


func _on_hello(index: int, peer: int, key: String, msg: Dictionary) -> void:
	var t: Transport = _transports[index]
	if msg.game_version != game_version or msg.protocol != Protocol.VERSION:
		t.send(peer, Protocol.reject("version", game_version), true)
		return
	if not is_valid_name(msg.name):
		t.send(peer, Protocol.reject("name", game_version), true)
		return
	if _players.size() >= balance.max_players:
		t.send(peer, Protocol.reject("full", game_version), true)
		return
	var id := _next_id
	_next_id += 1
	var slot := _free_slot()
	var name: String = (msg.name as String).strip_edges()
	var class_id := catalog.sanitize_class(msg.class_id)
	var appearance := catalog.sanitize_appearance(msg.appearance)
	var spawn := map.spawn_point() + Vector3(slot % 2, 0, slot / 2) * SPAWN_SPACING
	var player := world.add_player(id, spawn)
	ClassRules.setup_player(player, class_id, catalog)
	_players[id] = {
		"id": id, "name": name, "slot": slot, "class_id": class_id, "appearance": appearance,
		"transport": index, "peer": peer,
		"queue": [], "last_input": null, "last_seq": 0, "last_received": 0,
		"basic_id": world.abilities.kind_of(class_id, "basic"),
		"secondary_id": world.abilities.kind_of(class_id, "secondary"),
		"bar": world.abilities.sanitize_bar(class_id, msg.bar),
	}
	_by_conn[key] = id
	t.send(peer, Protocol.welcome(id, world.tick, roster()), true)
	for other: int in _players:
		if other != id:
			_send_to(other, Protocol.player_joined(id, name, slot, class_id, appearance), true)
	player_joined.emit(id, name)


func _on_input(rec: Dictionary, rows: Array) -> void:
	var queue: Array = rec.queue
	for row: Array in rows:
		var seq: int = row[0]
		if seq <= rec.last_received:
			continue
		# NaN or infinity would spread through the simulation to every player.
		if not (row[1] as Vector2).is_finite() or not (row[2] as Vector3).is_finite():
			continue
		rec.last_received = seq
		queue.append(PlayerInput.new(seq, (row[1] as Vector2).limit_length(1.0), row[2], int(row[3])))
	queue.sort_custom(func(a: PlayerInput, b: PlayerInput) -> bool: return a.seq < b.seq)
	while queue.size() > balance.max_pending_inputs:
		queue.pop_front()


func _on_peer_disconnected(peer: int, index: int) -> void:
	var key := "%d:%d" % [index, peer]
	if not _by_conn.has(key):
		return
	var id: int = _by_conn[key]
	_by_conn.erase(key)
	_players.erase(id)
	world.remove_player(id)
	_broadcast(Protocol.player_left(id), true)
	player_left.emit(id)


func _free_slot() -> int:
	var used := {}
	for id: int in _players:
		used[_players[id].slot] = true
	for s in balance.max_players:
		if not used.has(s):
			return s
	return 0


func _snapshot_rows() -> Array:
	var rows := []
	for id: int in _players:
		var s: PlayerState = world.players[id]
		rows.append([id, s.position, s.aim, s.facing, int(_players[id].last_seq), s.hp, s.stats.max_hp,
			s.resource, s.stats.max_resource, s.life, StatusEffect.bits_of(s), s.dash_ticks, s.dash_dir,
			s.dodge_ready_seq, s.move_mult(), s.combo, _charge_ratio(s)])
	return rows


func _monster_rows() -> Array:
	var rows := []
	for e: CombatEntity in world.monsters.values():
		rows.append([e.id, e.type_id, e.position, e.facing, e.hp, e.stats.max_hp, StatusEffect.bits_of(e), e.target_id])
	return rows


func _send_to(id: int, data: PackedByteArray, reliable: bool) -> void:
	var rec: Dictionary = _players[id]
	(_transports[rec.transport] as Transport).send(rec.peer, data, reliable)


func _broadcast(data: PackedByteArray, reliable: bool) -> void:
	for id: int in _players:
		_send_to(id, data, reliable)


## How far the archer's held shot is charged (0..1), for the HUD.
func _charge_ratio(p: PlayerState) -> float:
	if p.charge_start < 0:
		return 0.0
	var basic := world.abilities.get_ability(world.abilities.kind_of(p.class_id, "basic"))
	var max_ticks := maxi(1, world.ticks(float((basic.get("charge", {}) as Dictionary).get("max_s", 1.5))))
	return clampf(float(world.tick - p.charge_start) / float(max_ticks), 0.0, 1.0)
