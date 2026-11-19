class_name ClientSession
extends RefCounted
## A player's view of the game: predicts its own movement, reconciles with the host's
## snapshots and interpolates everybody else ~100 ms in the past.

signal welcomed(my_id: int)
signal rejected(reason: String, host_version: String)
signal disconnected(reason: String)
signal roster_changed()
signal chat_received(author: String, text: String, is_system: bool)
## One combat event from the host (see SimWorld.events), in order.
signal combat_event(ev: Array)
## A player (maybe this one) learned a class from a class trainer.
signal class_changed(id: int, class_id: String)
## The host sent this player their progress (and ability bar).
signal progress_changed()
## A player (maybe this one) reached a new level.
signal leveled_up(id: int, level: int)
signal arena_level_changed(level: int)
## A player (maybe this one) chose or lost a class upgrade ("" = none).
signal upgrade_changed(id: int, upgrade: String)
## This player's inventory came from the host (INVENTORY).
signal inventory_changed()
## A player's visible equipment changed (roster[id].gear).
signal gear_changed(id: int)
## What the merchant sells to this player (Item list), after merchant_open or a purchase.
signal merchant_stock_received(items: Array)

enum Status { CONNECTING, IN_GAME, CLOSED }

const SNAP_DISTANCE := 2.0
const RENDER_SNAP_TICKS := 10.0
const RENDER_CATCH_UP := 0.1
## Upper bound for unacknowledged inputs kept for replay (2 s at 30 ticks/s).
const MAX_REPLAY := 60

var status: Status = Status.CONNECTING
var my_id: int = 0
var roster: Dictionary = {} # id -> {"name": String, "slot": int}
var last_correction: float = 0.0
var render_tick: float = 0.0

var balance: Balance
var map: CollisionMap
var game_version: String
var player_name: String
var class_id: String
var appearance: Dictionary
## Abilities in slots 1-4 (sent in HELLO and with send_bar).
var bar: Array = []
## This player's progress, as the host last sent it (what HELLO carries at first).
var progress := PlayerProgress.new()
## This player's gold, bag and equipment, as the host last sent it (what HELLO carries at first).
var inventory := Inventory.new()
## Monster level of the arena.
var arena_level: int = 1
## Combat state from the last snapshot: player id -> {hp, max_hp, resource,
## max_resource, life, status_bits}; monster id -> {type, hp, max_hp, status_bits, target}.
var combat: Dictionary = {}
var monsters: Dictionary = {}

var _transport: Transport
var _seq: int = 0
var _pending: Array = [] # PlayerInput not yet acknowledged by the host
var _predicted: PlayerState = null
var _offset: Vector3 = Vector3.ZERO
var _offset_speed: float = 0.0
var _buffers: Dictionary = {} # id -> InterpolationBuffer
var _latest_tick: int = -1
var _silence: float = 0.0
var _clock_ms: float = 0.0
var _sent_at: Dictionary = {} # seq -> _clock_ms when sent
var _ping_ms: float = 0.0
var _own_move_mult: float = 1.0
var _monster_buffers: Dictionary = {} # id -> InterpolationBuffer
var _potion_ready_ms: float = 0.0


func _init(p_balance: Balance, p_map: CollisionMap, p_game_version: String, p_name: String,
		p_class_id: String = CharacterCatalog.DEFAULT_CLASS, p_appearance: Dictionary = {}, p_progress: Dictionary = {},
		p_inventory: Dictionary = {}) -> void:
	balance = p_balance
	map = p_map
	game_version = p_game_version
	player_name = p_name
	class_id = p_class_id
	appearance = p_appearance
	progress = PlayerProgress.from_dict(p_progress)
	inventory = Inventory.from_dict(p_inventory, p_class_id, progress.level, ItemDB.load_default()) if not p_inventory.is_empty() else Inventory.new()
	bar = AbilityDB.load_default().default_bar(p_class_id, progress.level, progress.upgrade)


func connect_to(t: Transport) -> void:
	_transport = t
	t.peer_connected.connect(_on_peer_connected)
	t.peer_disconnected.connect(_on_peer_disconnected)
	t.connection_failed.connect(_close.bind("failed"))


## Called once per physics tick with this tick's movement (world XZ) and aim point.
func tick(move: Vector2, aim: Vector3, buttons: int = 0) -> void:
	if _transport == null or status == Status.CLOSED:
		return
	for packet: Dictionary in _transport.poll():
		_silence = 0.0
		_handle(Protocol.decode(packet.data))
		if status == Status.CLOSED:
			return
	if status != Status.IN_GAME or _predicted == null:
		return
	_seq += 1
	var input := PlayerInput.new(_seq, move.limit_length(1.0), aim, buttons)
	_predicted.lock_facing = StatusEffect.has_bit(int((combat.get(my_id, {}) as Dictionary).get("status_bits", 0)), "ice_block")
	Movement.apply(_predicted, input, balance.dt(), balance, map, _own_move_mult)
	_pending.append(input)
	while _pending.size() > MAX_REPLAY:
		_pending.pop_front()
	_sent_at[_seq] = _clock_ms
	var rows := []
	for i in range(maxi(0, _pending.size() - balance.input_redundancy), _pending.size()):
		var p: PlayerInput = _pending[i]
		rows.append([p.seq, p.move, p.aim, p.buttons])
	_transport.send(Transport.HOST_PEER, Protocol.input(rows), false)


## Called once per rendered frame.
func update(delta: float) -> void:
	if status == Status.CLOSED:
		return
	_clock_ms += delta * 1000.0
	_silence += delta
	if _silence > balance.timeout_s:
		_close("timeout")
		return
	if _latest_tick >= 0:
		render_tick += delta * balance.tick_rate
		var diff := target_render_tick() - render_tick
		if absf(diff) > RENDER_SNAP_TICKS:
			render_tick = target_render_tick()
		else:
			render_tick += diff * RENDER_CATCH_UP
	_offset = _offset.move_toward(Vector3.ZERO, _offset_speed * delta)


func target_render_tick() -> float:
	return float(_latest_tick) - balance.interp_delay_ms * balance.tick_rate / 1000.0


func send_chat(text: String) -> void:
	var t := text.strip_edges().left(balance.chat_max_len)
	if status == Status.IN_GAME and t != "":
		_transport.send(Transport.HOST_PEER, Protocol.chat(0, t), true)


func leave() -> void:
	if status == Status.CLOSED:
		return
	status = Status.CLOSED
	if _transport != null:
		_transport.close()


## {"position", "aim", "facing"} for drawing; {} when unknown.
func render_state(id: int) -> Dictionary:
	var level: int = combat[id].get("level", 1) if combat.has(id) else 1
	if id == my_id and _predicted != null:
		return {"position": _predicted.position + _offset, "aim": _predicted.aim, "facing": _predicted.facing, "level": level}
	if _buffers.has(id):
		var s: Dictionary = (_buffers[id] as InterpolationBuffer).sample(render_tick)
		if not s.is_empty():
			s["level"] = level
		return s
	return {}


func pending_count() -> int:
	return _pending.size()


func ping_ms() -> float:
	return _ping_ms


func latest_tick() -> int:
	return _latest_tick


func _on_peer_connected(peer: int) -> void:
	if peer == Transport.HOST_PEER:
		_transport.send(Transport.HOST_PEER,
			Protocol.hello(game_version, Protocol.VERSION, player_name, class_id, appearance, bar, progress.to_dict(), inventory.to_wire()), true)


func _on_peer_disconnected(peer: int) -> void:
	if peer == Transport.HOST_PEER:
		_close("host_left")


func _close(reason: String) -> void:
	if status == Status.CLOSED:
		return
	status = Status.CLOSED
	if _transport != null:
		_transport.close()
	disconnected.emit(reason)


func _handle(msg: Dictionary) -> void:
	if msg.is_empty():
		return
	match msg.type:
		Protocol.Msg.WELCOME:
			if status != Status.CONNECTING:
				return
			my_id = msg.player_id
			arena_level = msg.arena_level
			status = Status.IN_GAME
			for row: Array in msg.roster:
				roster[row[0]] = {"name": row[1], "slot": row[2], "class_id": row[3], "appearance": row[4], "upgrade": row[5], "gear": row[6]}
			welcomed.emit(my_id)
			roster_changed.emit()
		Protocol.Msg.REJECT:
			status = Status.CLOSED
			_transport.close()
			rejected.emit(msg.reason, msg.host_version)
		Protocol.Msg.SNAPSHOT:
			_on_snapshot(msg.tick, msg.players, msg.monsters)
		Protocol.Msg.EVENTS:
			for ev: Variant in msg.events:
				if ev is Array and not (ev as Array).is_empty():
					combat_event.emit(ev)
					if ev[0] == "level_up" and (ev as Array).size() >= 3:
						if combat.has(ev[1]):
							combat[ev[1]].level = ev[2]
						leveled_up.emit(ev[1], ev[2])
		Protocol.Msg.PLAYER_JOINED:
			roster[msg.id] = {"name": msg.name, "slot": msg.slot, "class_id": msg.class_id, "appearance": msg.appearance, "upgrade": msg.upgrade, "gear": msg.gear}
			roster_changed.emit()
			chat_received.emit("", tr_text("CHAT_JOINED") % msg.name, true)
		Protocol.Msg.PLAYER_CLASS:
			if roster.has(msg.id):
				roster[msg.id].class_id = msg.class_id
			if msg.id == my_id:
				class_id = msg.class_id
				bar = (msg.bar as Array).duplicate()
			class_changed.emit(msg.id, msg.class_id)
		Protocol.Msg.PLAYER_UPGRADE:
			if roster.has(msg.id):
				roster[msg.id].upgrade = msg.upgrade
			upgrade_changed.emit(msg.id, msg.upgrade)
		Protocol.Msg.PROGRESS:
			progress = PlayerProgress.from_dict(msg.progress)
			bar = (msg.bar as Array).duplicate()
			progress_changed.emit()
		Protocol.Msg.INVENTORY:
			inventory = Inventory.from_wire(msg.inventory, class_id, progress.level, ItemDB.load_default())
			_potion_ready_ms = _clock_ms + float(msg.potion_cd_s) * 1000.0
			inventory_changed.emit()
		Protocol.Msg.PLAYER_GEAR:
			if roster.has(msg.id):
				roster[msg.id].gear = msg.gear
			gear_changed.emit(msg.id)
		Protocol.Msg.MERCHANT_STOCK:
			var items: Array = []
			for w: Variant in msg.items:
				var it := Item.from_wire(w, ItemDB.load_default())
				if it != null:
					items.append(it)
			merchant_stock_received.emit(items)
		Protocol.Msg.ARENA_LEVEL:
			arena_level = msg.level
			arena_level_changed.emit(arena_level)
		Protocol.Msg.PLAYER_LEFT:
			var name: String = roster[msg.id].name if roster.has(msg.id) else "?"
			roster.erase(msg.id)
			_buffers.erase(msg.id)
			combat.erase(msg.id)
			roster_changed.emit()
			chat_received.emit("", tr_text("CHAT_LEFT") % name, true)
		Protocol.Msg.CHAT:
			if msg.from_id == 0: # a system message from the host: the text is a translation key
				chat_received.emit("", tr_text(msg.text), true)
				return
			var author: String = roster[msg.from_id].name if roster.has(msg.from_id) else "?"
			chat_received.emit(author, msg.text, false)


func _on_snapshot(tick: int, rows: Array, monster_rows: Array) -> void:
	if status != Status.IN_GAME or tick <= _latest_tick:
		return
	var first := _latest_tick < 0
	_latest_tick = tick
	if first:
		render_tick = target_render_tick()
	for row: Array in rows:
		var id: int = row[0]
		combat[id] = {"hp": row[5], "max_hp": row[6], "resource": row[7], "max_resource": row[8],
			"life": row[9], "status_bits": row[10], "combo": row[15], "charge": row[16], "level": row[17]}
		if id == my_id:
			_own_move_mult = row[14]
			_reconcile(row)
		else:
			if not _buffers.has(id):
				_buffers[id] = InterpolationBuffer.new()
			(_buffers[id] as InterpolationBuffer).push(tick, row[1], row[2], row[3])
	var seen := {}
	for row: Array in monster_rows:
		var id: int = row[0]
		seen[id] = true
		monsters[id] = {"type": row[1], "hp": row[4], "max_hp": row[5], "status_bits": row[6], "target": row[7], "elite": row[8] & 1 != 0, "ally": row[8] & 2 != 0, "level": row[9]}
		if not _monster_buffers.has(id):
			_monster_buffers[id] = InterpolationBuffer.new()
		(_monster_buffers[id] as InterpolationBuffer).push(tick, row[2], row[2], row[3])
	for id: int in monsters.keys():
		if not seen.has(id):
			monsters.erase(id)
			_monster_buffers.erase(id)


## {"position", "aim", "facing"} of a monster for drawing; {} when unknown.
func monster_render_state(id: int) -> Dictionary:
	if _monster_buffers.has(id):
		var s: Dictionary = (_monster_buffers[id] as InterpolationBuffer).sample(render_tick)
		if not s.is_empty():
			s["level"] = int(monsters[id].get("level", 1)) if monsters.has(id) else 1
		return s
	return {}


## Dodge cooldown left from the prediction: 1 just after dodging, 0 when ready.
func dodge_cooldown_ratio() -> float:
	if _predicted == null:
		return 0.0
	var total := balance.ticks(balance.dodge_cooldown_s)
	return clampf(float(_predicted.dodge_ready_seq - _seq) / float(total), 0.0, 1.0) if total > 0 else 0.0


## Asks the host to learn a class (it checks this player is a villager next to a
## class trainer); class_changed follows if it agrees.
func choose_class(new_class: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.choose_class(new_class), true)


## Item requests (Protocol.item_action): the host checks each one and answers with INVENTORY.
func request_item(action: String, args: Array = []) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.item_action(action, args), true)


## Visible equipment of a player (8 base ids, see Inventory.VISIBLE); [] when unknown.
func gear_of(id: int) -> Array:
	return roster[id].get("gear", []) if roster.has(id) else []


## Seconds until a potion can be drunk again (0 when ready).
func potion_cooldown_left() -> float:
	return maxf(0.0, (_potion_ready_ms - _clock_ms) / 1000.0)


## Progress requests: the host checks each one and answers with PROGRESS when it accepts.
func spend_attribute(attr: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.spend_attribute(attr), true)


func buy_talent(id: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.buy_talent(id), true)


func buy_mastery(dir: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.buy_mastery(dir), true)


## what: "attributes", "talents" or "upgrade" (next to the trainer, out of combat).
func reset_progress(what: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.reset(what), true)


## Only the host player, next to the trainer (the host checks).
func set_arena_level(level: int) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.set_arena_level(level), true)


## Asks Brann for a class upgrade (level 50, next to him); upgrade_changed follows.
func choose_upgrade(id: String) -> void:
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.choose_upgrade(id), true)


## Replaces slots 1-4 (the host checks they are this class's abilities).
func send_bar(new_bar: Array) -> void:
	bar = new_bar.duplicate()
	if status == Status.IN_GAME:
		_transport.send(Transport.HOST_PEER, Protocol.set_bar(bar), true)


## row: a SNAPSHOT player row of this player (see Protocol.ROW_SCHEMAS.players).
func _reconcile(row: Array) -> void:
	var position: Vector3 = row[1]
	var aim: Vector3 = row[2]
	var facing: float = row[3]
	var acked: int = row[4]
	while not _pending.is_empty() and (_pending[0] as PlayerInput).seq <= acked:
		_pending.pop_front()
	if _sent_at.has(acked):
		_ping_ms = _clock_ms - float(_sent_at[acked])
	for seq: int in _sent_at.keys():
		if seq <= acked:
			_sent_at.erase(seq)
	if _predicted == null:
		_predicted = PlayerState.new()
		_predicted.id = my_id
		_predicted.position = position
		_predicted.aim = aim
		_predicted.facing = facing
		_seq = maxi(_seq, acked)
		return
	var old_predicted := _predicted.position
	var old_visual := old_predicted + _offset
	_predicted.position = position
	_predicted.aim = aim
	_predicted.facing = facing
	_predicted.dash_ticks = row[11]
	_predicted.dash_dir = row[12]
	_predicted.dodge_ready_seq = row[13]
	for p: PlayerInput in _pending:
		Movement.apply(_predicted, p, balance.dt(), balance, map, _own_move_mult)
	last_correction = old_predicted.distance_to(_predicted.position)
	_offset = old_visual - _predicted.position
	if _offset.length() > SNAP_DISTANCE:
		_offset = Vector3.ZERO
	_offset_speed = _offset.length() / (balance.correction_ms / 1000.0)


## Translation lookup usable from a RefCounted (tr() needs an Object; TranslationServer works anywhere).
static func tr_text(key: String) -> String:
	return TranslationServer.translate(key)
