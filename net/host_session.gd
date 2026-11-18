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
## The first player to join: the only one who may set the arena level and use commands.
var _host_player_id: int = 0
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
	world.events.clear()
	for index in _transports.size():
		var t: Transport = _transports[index]
		for packet: Dictionary in t.poll():
			_handle(index, packet.peer, packet.data)
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
	_flush_progress()
	var player_rows := _snapshot_rows()
	for id: int in _players:
		var viewer: Vector3 = world.players[id].position if world.players.has(id) else Vector3.ZERO
		_send_to(id, Protocol.snapshot(world.tick, player_rows, _monster_rows(viewer)), false)
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
		rows.append([id, p.name, p.slot, p.class_id, p.appearance, p.upgrade])
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
			var bp: PlayerState = world.players.get(rec.id)
			rec.bar = world.abilities.sanitize_bar(rec.class_id, msg.bar, bp.level, bp.progress.upgrade)
			rec.sent_bar = rec.bar.duplicate() # the client already has it
		Protocol.Msg.CHOOSE_CLASS:
			_on_choose_class(rec, msg.class_id)
		Protocol.Msg.SPEND_ATTRIBUTE, Protocol.Msg.BUY_TALENT, Protocol.Msg.BUY_MASTERY, Protocol.Msg.RESET:
			_on_progress_request(rec, msg)
		Protocol.Msg.CHOOSE_UPGRADE:
			var cp: PlayerState = world.players.get(rec.id)
			if cp != null:
				ProgressRequests.choose_upgrade(world, cp, msg.id, NpcDB.load_default().near_with_role(map, cp.position, "class_trainer") != "")
		Protocol.Msg.SET_ARENA_LEVEL:
			_on_set_arena_level(rec, msg.level)
		Protocol.Msg.CHAT:
			var text: String = (msg.text as String).strip_edges().left(balance.chat_max_len)
			if text.begins_with("/"):
				_on_command(rec, text)
			elif text != "":
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
	# Whatever progress the guest brings is fixed up, never refused.
	player.progress = ProgressRequests.sanitize(PlayerProgress.from_dict(msg.progress), class_id, world)
	ClassRules.setup_player(player, class_id, catalog, world)
	var bar := world.abilities.sanitize_bar(class_id, msg.bar, player.level, player.progress.upgrade)
	_players[id] = {
		"id": id, "name": name, "slot": slot, "class_id": class_id, "appearance": appearance,
		"transport": index, "peer": peer,
		"queue": [], "last_input": null, "last_seq": 0, "last_received": 0,
		"basic_id": world.abilities.kind_of(class_id, "basic"),
		"secondary_id": world.abilities.kind_of(class_id, "secondary"),
		"bar": bar,
		# What the owner was last sent (PROGRESS), to send only what changed.
		"upgrade": player.progress.upgrade, "bar_level": player.progress.level, "sent_other": _without_xp(player.progress.to_dict()),
		"sent_bar": bar.duplicate(), "sent_tick": -100000,
	}
	if _host_player_id == 0:
		_host_player_id = id
	_by_conn[key] = id
	t.send(peer, Protocol.welcome(id, world.tick, roster(), world.arena_level), true)
	t.send(peer, Protocol.progress(player.progress.to_dict(), bar), true)
	for other: int in _players:
		if other != id:
			_send_to(other, Protocol.player_joined(id, name, slot, class_id, appearance, player.progress.upgrade), true)
	player_joined.emit(id, name)


## A villager next to a class trainer learns a class: final, for everyone to see.
func _on_choose_class(rec: Dictionary, class_id: String) -> void:
	var p: PlayerState = world.players.get(rec.id)
	if p == null or not p.is_alive() or catalog.is_selectable(rec.class_id) or not catalog.is_selectable(class_id):
		return
	if NpcDB.load_default().near_with_role(map, p.position, "class_trainer") == "":
		return
	# Same share of health as before: learning a class mid-fight is not a free heal.
	var ratio := p.hp / maxf(p.stats.max_hp, 1.0)
	ClassRules.setup_player(p, class_id, catalog, world)
	p.hp = p.stats.max_hp * ratio
	rec.class_id = class_id
	rec.basic_id = world.abilities.kind_of(class_id, "basic")
	rec.secondary_id = world.abilities.kind_of(class_id, "secondary")
	rec.bar = world.abilities.default_bar(class_id, p.level, p.progress.upgrade)
	rec.sent_bar = rec.bar.duplicate()
	_broadcast(Protocol.player_class(rec.id, class_id, rec.bar), true)


## Spend a point, buy a node or reset: the host checks everything (ProgressRequests).
func _on_progress_request(rec: Dictionary, msg: Dictionary) -> void:
	var p: PlayerState = world.players.get(rec.id)
	if p == null:
		return
	match msg.type:
		Protocol.Msg.SPEND_ATTRIBUTE:
			ProgressRequests.spend_attribute(world, p, msg.attr)
		Protocol.Msg.BUY_TALENT:
			ProgressRequests.buy_talent(world, p, msg.id)
		Protocol.Msg.BUY_MASTERY:
			ProgressRequests.buy_mastery(world, p, msg.dir)
		Protocol.Msg.RESET:
			var near := NpcDB.load_default().near_with_role(map, p.position, "class_trainer") != ""
			if ProgressRequests.reset(world, p, msg.what, near):
				rec.bar = world.abilities.sanitize_bar(rec.class_id, rec.bar, p.level, p.progress.upgrade)


## Only the host player, next to the class trainer, sets the monster level of the arena.
func _on_set_arena_level(rec: Dictionary, level: int) -> void:
	var p: PlayerState = world.players.get(rec.id)
	if p == null or rec.id != _host_player_id or not p.is_alive():
		return
	if NpcDB.load_default().near_with_role(map, p.position, "class_trainer") == "":
		return
	world.set_arena_level(level)
	_broadcast(Protocol.arena_level(world.arena_level), true)


## Test commands (host player only): /xp <n> [name] and /nivel <n> [name]. They are not
## chat. Anything else starting with "/" is refused with a system message to the author.
func _on_command(rec: Dictionary, text: String) -> void:
	if rec.id != _host_player_id:
		_send_to(rec.id, Protocol.chat(0, "CMD_HOST_ONLY"), true)
		return
	var parts := text.substr(1).split(" ", false)
	if parts.size() < 2 or not parts[0].to_lower() in ["xp", "nivel"] or not parts[1].is_valid_int() or parts[1].to_int() < 1:
		_send_to(rec.id, Protocol.chat(0, "CMD_BAD"), true)
		return
	var target: PlayerState = world.players.get(rec.id)
	if parts.size() > 2:
		target = null
		var wanted := " ".join(parts.slice(2)).to_lower()
		for id: int in _players:
			if str(_players[id].name).to_lower() == wanted:
				target = world.players.get(id)
		if target == null:
			_send_to(rec.id, Protocol.chat(0, "CMD_NO_PLAYER"), true)
			return
	var n := parts[1].to_int()
	if parts[0].to_lower() == "xp":
		Xp.award(world, target, clampi(n, 1, Xp.MAX_AMOUNT))
	elif n > target.progress.level:
		Xp.set_level(world, target, mini(n, PlayerProgress.MAX_LEVEL))


## Sends each owner their changed progress (and the bar). Level-ups also place the newly
## unlocked abilities in free bar slots. Only experience changing is sent at most once a
## second; anything else goes at once.
func _flush_progress() -> void:
	for id: int in _players:
		var rec: Dictionary = _players[id]
		var p: PlayerState = world.players.get(id)
		if p == null:
			continue
		if p.progress.upgrade != rec.upgrade:
			# An upgrade was chosen (its abilities go to free slots) or reset (they leave the bar).
			var old_upgrade: String = rec.upgrade
			rec.upgrade = p.progress.upgrade
			rec.bar = world.abilities.sanitize_bar(rec.class_id, rec.bar, p.level, p.progress.upgrade)
			if old_upgrade == "":
				rec.bar = world.abilities.place_unlocked(rec.bar, rec.class_id, ProgressRequests.UPGRADE_LEVEL - 1, p.level, p.progress.upgrade)
			p.progress_dirty = true
			_broadcast(Protocol.player_upgrade(id, p.progress.upgrade), true)
		if p.progress.level != rec.bar_level:
			rec.bar = world.abilities.place_unlocked(rec.bar, rec.class_id, rec.bar_level, p.progress.level, p.progress.upgrade)
			rec.bar_level = p.progress.level
			p.progress_dirty = true
		if not p.progress_dirty:
			continue
		var d := p.progress.to_dict()
		var other := _without_xp(d)
		var only_xp: bool = other == rec.sent_other and rec.bar == rec.sent_bar
		if only_xp and world.tick - int(rec.sent_tick) < balance.tick_rate:
			continue
		_send_to(id, Protocol.progress(d, rec.bar), true)
		rec.sent_other = other
		rec.sent_bar = (rec.bar as Array).duplicate()
		rec.sent_tick = world.tick
		p.progress_dirty = false


static func _without_xp(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out.erase("xp")
	return out


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
			s.dodge_ready_seq, s.move_mult(), s.combo, _charge_ratio(s), s.level])
	return rows


## Monster rows for one player: the nearest max_monsters_per_snapshot (all of them when
## there are fewer), so a big map never overflows the packet.
func _monster_rows(viewer: Vector3) -> Array:
	var list: Array = world.monsters.values()
	var cap := world.balance.max_monsters_per_snapshot
	if list.size() > cap:
		var at := Effects.flat(viewer)
		list.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool:
			var da := Effects.flat(a.position).distance_squared_to(at)
			var db := Effects.flat(b.position).distance_squared_to(at)
			return da < db if da != db else a.id < b.id)
		list = list.slice(0, cap)
	var rows := []
	for e: CombatEntity in list:
		var elite := 1 if (e is MonsterState and (e as MonsterState).elite) else 0
		rows.append([e.id, e.type_id, e.position, e.facing, e.hp, e.stats.max_hp, StatusEffect.bits_of(e), e.target_id, elite, e.level])
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
