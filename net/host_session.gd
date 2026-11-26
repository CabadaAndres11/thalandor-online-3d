class_name HostSession
extends RefCounted
## Authoritative simulation: accepts guests, consumes their inputs and broadcasts snapshots.

signal player_joined(id: int, name: String)
signal player_left(id: int)

const NAME_MIN := 2
const NAME_MAX := 16
const SPAWN_SPACING := 1.5
## Events that only their owner (ev[1]) receives: personal loot and gold.
const OWNER_EVENTS := ["gold", "loot", "loot_gone", "bag_full", "trade_refused", "zone_blocked",
	"quest_started", "quest_step", "quest_ready", "quest_done", "quest_scene", "quest_moment", "quest_bag_full"]
## No changing zone within this long of being hurt (Plan 8.1).
const EXIT_COMBAT_S := 5.0
## How often a player blocked at an exit is told why.
const EXIT_WARN_S := 3.0

## The world of the zone the host started in (its map). Each player lives in the world of
## its own zone: world_of(id).
var world: SimWorld
## Every open zone and dungeon instance (Plan 8.1).
var zones: ZoneManager
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
## Exits already reported as leading nowhere.
var _bad_exits: Dictionary = {}
## Where a player whose saved place is unknown (or a dungeon) appears (Plan 8.1).
var fallback_zone: String = CharacterData.START_ZONE
## How often each player is told where to save itself.
const PLACE_EVERY_S := 30.0
## The longest a player stays safe in a cutscene (Plan 8.2), should the client never say it ended.
const SCENE_MAX_S := 120.0


func _init(p_balance: Balance, p_map: CollisionMap, p_game_version: String) -> void:
	balance = p_balance
	map = p_map
	game_version = p_game_version
	zones = ZoneManager.new(balance, randi())
	world = zones.world(zones.adopt(map))


## The quests every world uses (tests give their own; by default data/quests).
func set_quests(db: QuestDB) -> void:
	zones.quests = db
	for key: String in zones.keys():
		zones.world(key).quests = db


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
	for key: String in zones.keys():
		zones.world(key).events.clear()
	for index in _transports.size():
		var t: Transport = _transports[index]
		for packet: Dictionary in t.poll():
			_handle(index, packet.peer, packet.data)
	var inputs_by_key := {}
	for id: int in _players:
		var rec: Dictionary = _players[id]
		if not inputs_by_key.has(rec.zone_key):
			inputs_by_key[rec.zone_key] = {}
		var inputs: Dictionary = inputs_by_key[rec.zone_key]
		var queue: Array = rec.queue
		var ps := state_of(id)
		if ps != null and ps.in_scene():
			queue.clear() # watching a cutscene: the player stands still
			rec.last_input = null
			continue
		if not queue.is_empty():
			var next: PlayerInput = queue.pop_front()
			rec.last_input = next
			rec.last_seq = next.seq
			inputs[id] = next
			_cast_from_input(rec, next)
		elif rec.last_input != null:
			# No new input this tick: keep moving/holding, but never repeat presses.
			inputs[id] = (rec.last_input as PlayerInput).held_only()
	zones.step_occupied(inputs_by_key)
	_follow_story_moments()
	_start_pending_scenes()
	_check_exits()
	_send_places()
	if zones.tick % balance.tick_rate == 0:
		_send_party()
	_flush_progress()
	_flush_inventory()
	_flush_quests()
	# Each player gets the players, monsters and events of its own world only.
	for key: String in zones.keys():
		var ids: Array = zones.occupants(key)
		if ids.is_empty():
			continue
		var w := zones.world(key)
		var player_rows := _snapshot_rows(w, ids)
		for id: int in ids:
			var viewer: Vector3 = w.players[id].position if w.players.has(id) else Vector3.ZERO
			_send_to(id, Protocol.snapshot(w.tick, player_rows, _monster_rows(w, viewer)), false)
		if not w.events.is_empty():
			for id: int in ids:
				var mine := events_for(id, w.events)
				if not mine.is_empty():
					_send_to(id, Protocol.events(w.tick, mine), true)
	zones.close_idle(zones.time_s)


## The events a player receives: everything except other players' loot and gold.
static func events_for(id: int, events: Array) -> Array:
	return events.filter(func(ev: Array) -> bool: return not (ev[0] in OWNER_EVENTS and ev.size() > 1 and ev[1] != id))


## Presses of a new input become casts: basic, secondary and the bar slots.
func _cast_from_input(rec: Dictionary, input: PlayerInput) -> void:
	var w := world_of(rec.id)
	var p: PlayerState = state_of(rec.id)
	if p == null:
		return
	var basic := w.abilities.get_ability(rec.basic_id)
	if basic.has("charge") and bool(WeaponFamily.of(p, w).get("auto_charge", false)):
		# A crossbow is never drawn: every press is the full charged shot.
		if input.pressed(PlayerInput.BTN_BASIC):
			ClassRules.release_charged(w, p, rec.basic_id, input.aim, 1.0)
	elif basic.has("charge"):
		# Archer: press starts charging, release fires (a quick tap = normal shot).
		if input.pressed(PlayerInput.BTN_BASIC) and p.charge_start < 0:
			p.charge_start = w.tick
		elif p.charge_start >= 0 and not input.pressed(PlayerInput.BTN_BASIC_HELD):
			var max_ticks := maxi(1, w.ticks(float(basic.charge.get("max_s", 1.5))))
			var ratio := float(w.tick - p.charge_start) / float(max_ticks)
			p.charge_start = -1
			ClassRules.release_charged(w, p, rec.basic_id, input.aim, ratio)
	elif input.pressed(PlayerInput.BTN_BASIC):
		Combat.try_cast(w, p, rec.basic_id, input.aim)
	if input.pressed(PlayerInput.BTN_SECONDARY):
		Combat.try_cast(w, p, rec.secondary_id, input.aim)
	for i in PlayerInput.SLOT_BITS.size():
		if input.pressed(PlayerInput.SLOT_BITS[i]) and str(rec.bar[i]) != "":
			Combat.try_cast(w, p, rec.bar[i], input.aim)


## The world of a player's zone (the start world for an unknown id).
func world_of(id: int) -> SimWorld:
	if not _players.has(id):
		return world
	var w := zones.world(str(_players[id].zone_key))
	return w if w != null else world


func state_of(id: int) -> PlayerState:
	return world_of(id).players.get(id)


## A player alive on an exit goes to the zone it leads to (not while hurt in the last
## EXIT_COMBAT_S; an exit to a zone that does not exist is ignored).
func _check_exits() -> void:
	for id: int in _players.keys():
		var rec: Dictionary = _players[id]
		var layout := zones.layout(rec.zone_key)
		var p := state_of(id)
		if layout == null or p == null or not p.is_alive():
			continue
		var ex := layout.exit_at(p.position)
		if ex.is_empty():
			rec.offered = ""
			continue
		var w := world_of(id)
		if _in_combat(id):
			if w.tick - int(rec.get("warned_tick", -100000)) >= w.ticks(EXIT_WARN_S):
				rec.warned_tick = w.tick
				_send_to(id, Protocol.events(w.tick, [["zone_blocked", id]]), true)
			continue
		var target := zones.peek(str(ex.to))
		if target != null and target.instanced:
			# A dungeon: the player chooses its level first (ENTER_DUNGEON), once per visit.
			if str(rec.get("offered", "")) != str(ex.to):
				rec.offered = str(ex.to)
				var r := dungeon_range(p.progress.level)
				_send_to(id, Protocol.dungeon_offer(str(ex.to), r.x, r.y, clampi(p.progress.level, r.x, r.y)), true)
			continue
		var key := zones.open(str(ex.to))
		if key == "":
			if not _bad_exits.has(ex.to):
				_bad_exits[ex.to] = true
				push_warning("HostSession: an exit of %s leads to an unknown zone %s" % [layout.id, ex.to])
			continue
		send_to_zone(id, key, zones.layout(key).entry(str(ex.entry)))


## The levels a player may choose for a dungeon: -5 to +10 of its own, within the balance.
func dungeon_range(level: int) -> Vector2i:
	var lo := int(balance.monster_scaling.get("arena_min", 1))
	var hi := int(balance.monster_scaling.get("arena_max", 60))
	return Vector2i(clampi(level - 5, lo, hi), clampi(level + 10, lo, hi))


## A player at a dungeon's door enters it: the instance a partner is already in, or a new
## one at the chosen level (clamped to the offered range).
func _on_enter_dungeon(rec: Dictionary, zone_id: String, level: int) -> void:
	var p := state_of(rec.id)
	var layout := zones.layout(rec.zone_key)
	if p == null or not p.is_alive() or layout == null:
		return
	var ex := layout.exit_at(p.position)
	if ex.is_empty() or str(ex.to) != zone_id or _in_combat(rec.id):
		return
	var key := ""
	for other: int in _players:
		var k := str(_players[other].zone_key)
		if other != rec.id and k.begins_with(zone_id + "#"):
			key = k
	if key == "":
		var r := dungeon_range(p.progress.level)
		key = zones.open(zone_id, "group", clampi(level, r.x, r.y))
	if key == "":
		return
	# Saved while inside: the entry the dungeon's way out leads to (not the door itself,
	# which would offer the dungeon again on return).
	var back := "default"
	for e: Dictionary in zones.layout(key).exits:
		if str(e.to) == layout.id:
			back = str(e.entry)
	var out: Vector2i = layout.entries.get(back, layout.entries.default)
	rec.outside = {"zone": layout.id, "at": [out.x, out.y]}
	send_to_zone(rec.id, key, zones.layout(key).entry(str(ex.entry)))


## Where a joining player appears: its saved place when the zone exists, is not a dungeon
## and the cell is free; the fallback zone's entry otherwise; the host's start when it
## brings no place at all. {key, at}.
func _place_for(place: Dictionary, spawn: Vector3) -> Dictionary:
	if place.is_empty() or str(place.get("zone", "")) == "":
		return {"key": zones.start_key, "at": spawn}
	var zone := str(place.zone)
	var layout := zones.peek(zone)
	if layout == null or layout.instanced:
		var fk := zones.open(fallback_zone)
		if fk == "":
			return {"key": zones.start_key, "at": spawn}
		return {"key": fk, "at": zones.layout(fk).entry("default")}
	var key := zones.open(zone)
	var at: Array = place.get("at", [])
	var map := zones.world(key).map
	if at.size() == 2 and not map.is_solid(Vector2i(int(at[0]), int(at[1]))):
		return {"key": key, "at": Vector3(int(at[0]) + 0.5, 0, int(at[1]) + 0.5)}
	return {"key": key, "at": zones.layout(key).entry("default")}


## Tells each player where to save itself: after a zone change and every PLACE_EVERY_S.
## Inside a dungeon that is its door outside.
func _send_places() -> void:
	var periodic := zones.tick % maxi(1, int(PLACE_EVERY_S * balance.tick_rate)) == 0
	for id: int in _players:
		var rec: Dictionary = _players[id]
		if not (periodic or bool(rec.get("place_dirty", false))):
			continue
		rec.place_dirty = false
		var p := state_of(id)
		var layout := zones.layout(rec.zone_key)
		if p == null or layout == null:
			continue
		if layout.instanced and rec.has("outside"):
			_send_to(id, Protocol.place(str(rec.outside.zone), rec.outside.at), true)
		else:
			_send_to(id, Protocol.place(layout.id, [floori(p.position.x), floori(p.position.z)]), true)


## Quest steps that open or close a story moment (Plan 8.2).
func _follow_story_moments() -> void:
	for key: String in zones.keys():
		for ev: Array in zones.world(key).events.duplicate():
			if ev[0] == "quest_moment" and _players.has(ev[1]):
				send_to_moment(ev[1], ev[2], ev[3])
			elif ev[0] == "quest_scene" and _players.has(ev[1]):
				_players[ev[1]].pending_scene = str(ev[2])


## A scene waits for its player to be out of combat; then the player is safe (in_scene)
## and its client is told to play it (scene_go, only to it).
func _start_pending_scenes() -> void:
	for id: int in _players:
		var rec: Dictionary = _players[id]
		var scene := str(rec.get("pending_scene", ""))
		var p := state_of(id)
		if scene == "" or p == null or not p.is_alive() or _in_combat(id):
			continue
		rec.pending_scene = ""
		var w := world_of(id)
		p.add_status(StatusEffect.make("in_scene", w.tick + w.ticks(SCENE_MAX_S)))
		rec.queue.clear()
		rec.last_input = null
		_send_to(id, Protocol.events(w.tick, [["scene_go", id, scene]]), true)


## Sends a player into its own copy of a zone variant; zone "" brings it back to the shared
## zone it stood in (its entry).
func send_to_moment(id: int, zone: String, variant: String) -> void:
	if not _players.has(id):
		return
	if zone == "":
		var here := zones.layout(_players[id].zone_key)
		if here == null or here.variant == "":
			return
		var back := zones.open(here.id)
		if back != "":
			send_to_zone(id, back, zones.layout(back).entry("default"))
		return
	var key := zones.open_personal(zone, variant, id)
	if key == "":
		push_warning("HostSession: no story moment %s/%s" % [zone, variant])
		return
	if key != _players[id].zone_key:
		send_to_zone(id, key, zones.layout(key).entry("default"))


## Hurt within EXIT_COMBAT_S: no leaving the zone.
func _in_combat(id: int) -> bool:
	var p := state_of(id)
	var w := world_of(id)
	return p != null and w.tick - p.last_hurt_tick < w.ticks(EXIT_COMBAT_S)


## Moves a player to another open world and tells its client (ZONE).
func send_to_zone(id: int, key: String, at: Vector3) -> void:
	if transfer(id, key, at) == null:
		return
	_players[id].place_dirty = true
	var to_layout := zones.layout(key)
	if to_layout == null or not to_layout.instanced:
		_players[id].erase("outside") # a door from an old visit is not this place
	var layout := zones.layout(key)
	var w := zones.world(key)
	_send_to(id, Protocol.zone(layout.id if layout != null else "", key, w.instance_level, layout.variant if layout != null else ""), true)


## Partners in other worlds: their zone, level and health, once a second.
func _send_party() -> void:
	for id: int in _players:
		var rows := []
		for other: int in _players:
			if other == id or _players[other].zone_key == _players[id].zone_key:
				continue
			var p := state_of(other)
			var layout := zones.layout(_players[other].zone_key)
			if p != null:
				rows.append([other, layout.name if layout != null else "", p.level, p.hp / maxf(p.stats.max_hp, 1.0)])
		if not rows.is_empty():
			_send_to(id, Protocol.party(rows), false)


## Moves a player to another open world (key), standing at a position.
func transfer(id: int, key: String, at: Vector3) -> PlayerState:
	if not _players.has(id) or zones.world(key) == null:
		return null
	var rec: Dictionary = _players[id]
	var p := zones.move(id, rec.zone_key, key, at)
	if p != null:
		p.remove_status("in_scene") # a scene never follows a player to another zone
	rec.zone_key = key
	return p


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
		rows.append([id, p.name, p.slot, p.class_id, p.appearance, p.upgrade, p.gear])
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
	var w := world_of(rec.id)
	match msg.type:
		Protocol.Msg.INPUT:
			_on_input(rec, msg.inputs)
		Protocol.Msg.SET_BAR:
			var bp: PlayerState = state_of(rec.id)
			rec.bar = w.abilities.sanitize_bar(rec.class_id, msg.bar, bp.level, bp.progress.upgrade)
			rec.sent_bar = rec.bar.duplicate() # the client already has it
		Protocol.Msg.CHOOSE_CLASS:
			_on_choose_class(rec, msg.class_id)
		Protocol.Msg.SPEND_ATTRIBUTE, Protocol.Msg.BUY_TALENT, Protocol.Msg.BUY_MASTERY, Protocol.Msg.RESET:
			_on_progress_request(rec, msg)
		Protocol.Msg.CHOOSE_UPGRADE:
			var cp: PlayerState = state_of(rec.id)
			if cp != null:
				ProgressRequests.choose_upgrade(w, cp, msg.id, NpcDB.load_default().near_with_role(w.map, cp.position, "class_trainer") != "")
		Protocol.Msg.SET_ARENA_LEVEL:
			_on_set_arena_level(rec, msg.level)
		Protocol.Msg.ENTER_DUNGEON:
			_on_enter_dungeon(rec, msg.zone, msg.level)
		Protocol.Msg.ITEM_ACTION:
			_on_item_action(rec, msg.action, msg.args)
		Protocol.Msg.QUEST_ACTION:
			_on_quest_action(rec, msg.action, msg.args)
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
	# A guest who has not finished the village tutorial cannot join (Plan 8.1).
	if _host_player_id != 0 and (msg.place as Dictionary).get("tutorial_done", true) == false:
		t.send(peer, Protocol.reject("tutorial", game_version), true)
		return
	var id := _next_id
	_next_id += 1
	var slot := _free_slot()
	var name: String = (msg.name as String).strip_edges()
	var class_id := catalog.sanitize_class(msg.class_id)
	var appearance := catalog.sanitize_appearance(msg.appearance)
	var spawn := map.spawn_point() + Vector3(slot % 2, 0, slot / 2) * SPAWN_SPACING
	var place: Dictionary = msg.place
	if place.has("zone"):
		place = CharacterData.sanitize_place(place) # a guest may send anything
	var start := _place_for(place, spawn)
	var player := zones.add_player(id, start.key, start.at)
	# Whatever progress the guest brings is fixed up, never refused.
	player.progress = ProgressRequests.sanitize(PlayerProgress.from_dict(msg.progress), class_id, world)
	player.inventory = Inventory.from_wire(msg.inventory, class_id, player.progress.level, world.items)
	player.quests = QuestLog.from_dict(msg.quests, zones.world(start.key).quests)
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
		"gear": player.inventory.visible_bases(),
		"zone_key": start.key,
		"place_dirty": true,
	}
	if _host_player_id == 0:
		_host_player_id = id
	_by_conn[key] = id
	t.send(peer, Protocol.welcome(id, world.tick, roster(), world.arena_level), true)
	t.send(peer, Protocol.progress(player.progress.to_dict(), bar), true)
	t.send(peer, Protocol.inventory(player.inventory.to_wire(), 0.0), true)
	player.inventory_dirty = false
	QuestRules.check_auto(zones.world(start.key), player)
	t.send(peer, Protocol.quests(player.quests.to_dict()), true)
	player.quests_dirty = false
	if start.key != zones.start_key:
		# Its client draws the start zone until told otherwise.
		var sl := zones.layout(start.key)
		t.send(peer, Protocol.zone(sl.id if sl != null else "", start.key, zones.world(start.key).instance_level, sl.variant if sl != null else ""), true)
	# Back inside the story moment it left (Plan 8.2), made anew.
	var moment := QuestRules.current_moment(zones.world(start.key), player)
	if not moment.is_empty():
		send_to_moment(id, str(moment.zone), str(moment.variant))
	for other: int in _players:
		if other != id:
			_send_to(other, Protocol.player_joined(id, name, slot, class_id, appearance, player.progress.upgrade, _players[id].gear), true)
	player_joined.emit(id, name)


## A villager next to a class trainer learns a class: final, for everyone to see.
func _on_choose_class(rec: Dictionary, class_id: String) -> void:
	var w := world_of(rec.id)
	var p: PlayerState = state_of(rec.id)
	if p == null or not p.is_alive() or catalog.is_selectable(rec.class_id) or not catalog.is_selectable(class_id):
		return
	if not QuestRules.allows_class_choice(w, p) and NpcDB.load_default().near_with_role(w.map, p.position, "class_trainer") == "":
		return # only next to a trainer, or when the story asks for it (Plan 8.3a)
	# Same share of health as before: learning a class mid-fight is not a free heal.
	var ratio := p.hp / maxf(p.stats.max_hp, 1.0)
	# The villager's gear goes; the class's starter kit is worn (bag and gold stay).
	p.inventory.wear_starter(class_id, w.items)
	p.inventory_dirty = true
	ClassRules.setup_player(p, class_id, catalog, w)
	p.hp = p.stats.max_hp * ratio
	rec.class_id = class_id
	rec.basic_id = w.abilities.kind_of(class_id, "basic")
	rec.secondary_id = w.abilities.kind_of(class_id, "secondary")
	rec.bar = w.abilities.default_bar(class_id, p.level, p.progress.upgrade)
	rec.sent_bar = rec.bar.duplicate()
	_broadcast(Protocol.player_class(rec.id, class_id, rec.bar), true)
	QuestRules.on_class_chosen(w, p)


## Spend a point, buy a node or reset: the host checks everything (ProgressRequests).
func _on_progress_request(rec: Dictionary, msg: Dictionary) -> void:
	var w := world_of(rec.id)
	var p: PlayerState = state_of(rec.id)
	if p == null:
		return
	match msg.type:
		Protocol.Msg.SPEND_ATTRIBUTE:
			ProgressRequests.spend_attribute(w, p, msg.attr)
		Protocol.Msg.BUY_TALENT:
			ProgressRequests.buy_talent(w, p, msg.id)
		Protocol.Msg.BUY_MASTERY:
			ProgressRequests.buy_mastery(w, p, msg.dir)
		Protocol.Msg.RESET:
			var near := NpcDB.load_default().near_with_role(w.map, p.position, "class_trainer") != ""
			if ProgressRequests.reset(w, p, msg.what, near):
				rec.bar = w.abilities.sanitize_bar(rec.class_id, rec.bar, p.level, p.progress.upgrade)


## Only the host player, next to the class trainer, sets the monster level of the arena.
func _on_set_arena_level(rec: Dictionary, level: int) -> void:
	var w := world_of(rec.id)
	var p: PlayerState = state_of(rec.id)
	if p == null or rec.id != _host_player_id or not p.is_alive():
		return
	w.set_arena_level(level)
	_broadcast(Protocol.arena_level(w.arena_level), true)


## Test commands (host player only): /xp <n> [name], /nivel <n> [name], /oro <n> [name] and
## /objeto <base> [level] [rarity] [name]. They are not chat. Anything else starting with
## "/" is refused with a system message to the author.
func _on_command(rec: Dictionary, text: String) -> void:
	var w := world_of(rec.id)
	if rec.id != _host_player_id:
		_send_to(rec.id, Protocol.chat(0, "CMD_HOST_ONLY"), true)
		return
	var parts := text.substr(1).split(" ", false)
	if parts.size() >= 1 and parts[0].to_lower() == "zonas":
		_send_to(rec.id, Protocol.chat(0, "ZONES: " + ", ".join(zones.keys())), true)
		return
	if parts.size() >= 2 and parts[0].to_lower() == "zona":
		var zkey := zones.open(parts[1])
		if zkey == "":
			_send_to(rec.id, Protocol.chat(0, "CMD_BAD"), true)
		else:
			send_to_zone(rec.id, zkey, zones.layout(zkey).entry("default"))
		return
	if parts.size() >= 2 and parts[0].to_lower() == "arena" and parts[1].is_valid_int():
		_on_set_arena_level(rec, parts[1].to_int()) # Brann's menu is gone (Plan 8.3a)
		return
	if parts.size() >= 2 and parts[0].to_lower() in ["mision", "misión", "marca"]:
		_quest_command(rec, parts)
		return
	if parts.size() >= 2 and parts[0].to_lower() == "objeto":
		_item_command(rec, parts)
		return
	if parts.size() >= 2 and parts[0].to_lower() == "oro" and parts[1].is_valid_int() and parts[1].to_int() > 0:
		var who := _command_target(rec, parts.slice(2))
		if who != null:
			who.inventory.gold = mini(Inventory.MAX_GOLD, who.inventory.gold + parts[1].to_int())
			who.inventory_dirty = true
		return
	if parts.size() < 2 or not parts[0].to_lower() in ["xp", "nivel"] or not parts[1].is_valid_int() or parts[1].to_int() < 1:
		_send_to(rec.id, Protocol.chat(0, "CMD_BAD"), true)
		return
	var target: PlayerState = state_of(rec.id)
	if parts.size() > 2:
		target = null
		var wanted := " ".join(parts.slice(2)).to_lower()
		for id: int in _players:
			if str(_players[id].name).to_lower() == wanted:
				target = state_of(id)
		if target == null:
			_send_to(rec.id, Protocol.chat(0, "CMD_NO_PLAYER"), true)
			return
	var n := parts[1].to_int()
	var tw := world_of(target.id) # the target may be in another zone
	if parts[0].to_lower() == "xp":
		Xp.award(tw, target, clampi(n, 1, Xp.MAX_AMOUNT))
	elif n > target.progress.level:
		Xp.set_level(tw, target, mini(n, PlayerProgress.MAX_LEVEL))


## Sends each owner their changed progress (and the bar). Level-ups also place the newly
## unlocked abilities in free bar slots. Only experience changing is sent at most once a
## second; anything else goes at once.
func _flush_progress() -> void:
	for id: int in _players:
		var rec: Dictionary = _players[id]
		var p: PlayerState = state_of(id)
		if p == null:
			continue
		var w := world_of(id)
		if p.progress.upgrade != rec.upgrade:
			# An upgrade was chosen (its abilities go to free slots) or reset (they leave the bar).
			var old_upgrade: String = rec.upgrade
			rec.upgrade = p.progress.upgrade
			rec.bar = w.abilities.sanitize_bar(rec.class_id, rec.bar, p.level, p.progress.upgrade)
			if old_upgrade == "":
				rec.bar = w.abilities.place_unlocked(rec.bar, rec.class_id, ProgressRequests.UPGRADE_LEVEL - 1, p.level, p.progress.upgrade)
			p.progress_dirty = true
			_broadcast(Protocol.player_upgrade(id, p.progress.upgrade), true)
		if p.progress.level != rec.bar_level:
			rec.bar = w.abilities.place_unlocked(rec.bar, rec.class_id, rec.bar_level, p.progress.level, p.progress.upgrade)
			rec.bar_level = p.progress.level
			p.progress_dirty = true
		if not p.progress_dirty:
			continue
		var d := p.progress.to_dict()
		var other := _without_xp(d)
		var only_xp: bool = other == rec.sent_other and rec.bar == rec.sent_bar
		if only_xp and w.tick - int(rec.sent_tick) < balance.tick_rate:
			continue
		_send_to(id, Protocol.progress(d, rec.bar), true)
		rec.sent_other = other
		rec.sent_bar = (rec.bar as Array).duplicate()
		rec.sent_tick = w.tick
		p.progress_dirty = false


## Sends each owner their quest log when it changed.
func _flush_quests() -> void:
	for id: int in _players:
		var p := state_of(id)
		if p != null and p.quests_dirty:
			p.quests_dirty = false
			_send_to(id, Protocol.quests(p.quests.to_dict()), true)


## Quest requests (Plan 8.2): the host checks each one (QuestRules); malformed ones are ignored.
func _on_quest_action(rec: Dictionary, action: String, args: Array) -> void:
	var w := world_of(rec.id)
	var p := state_of(rec.id)
	if p == null or not args.all(func(a: Variant) -> bool: return a is String):
		return
	var a0: String = args[0] if args.size() >= 1 else ""
	var a1: String = args[1] if args.size() >= 2 else ""
	match action:
		"accept":
			var q := w.quests.quest(a0)
			if not q.is_empty() and (str(q.giver) == "" or QuestRules.near_npc(w, p, str(q.giver))):
				QuestRules.start(w, p, a0)
		"talk_done":
			QuestRules.report(w, p, "talk", a0, a1)
		"interact":
			QuestRules.report(w, p, "interact", a0)
		"scene_start":
			if a0 != "":
				rec.pending_scene = a0
		"scene_done":
			p.remove_status("in_scene")
			QuestRules.report(w, p, "scene", a0)
		"choose_flag":
			if a1 in DialogueRunner.offered_flags(a0, p.quests):
				QuestRules.set_flag(w, p, a1)
		"turn_in":
			if args.size() >= 1:
				QuestRules.turn_in(w, p, a0, a1)
		"track":
			if p.quests.is_active(a0) and p.quests.tracked != a0:
				p.quests.tracked = a0
				p.quests_dirty = true
		"abandon":
			QuestRules.abandon(w, p, a0)
	QuestRules.check_auto(w, p)


## /mision <id> | paso | fin | borrar <id>; /marca <name> | quitar <name> (host only, Plan 8.2).
func _quest_command(rec: Dictionary, parts: Array) -> void:
	var w := world_of(rec.id)
	var p := state_of(rec.id)
	var sub: String = str(parts[1]).to_lower()
	if parts[0].to_lower() == "marca":
		if sub == "quitar" and parts.size() >= 3:
			p.quests.flags.erase(str(parts[2]))
			p.quests_dirty = true
		else:
			QuestRules.set_flag(w, p, str(parts[1]))
		return
	var tracked := p.quests.tracked
	match sub:
		"paso":
			if tracked != "":
				QuestRules.complete_step(w, p, tracked)
		"fin":
			while tracked != "" and p.quests.is_active(tracked) and not QuestRules.is_ready(w, p, tracked):
				QuestRules.complete_step(w, p, tracked)
		"borrar":
			if parts.size() >= 3:
				p.quests.active.erase(str(parts[2]))
				p.quests.done.erase(str(parts[2]))
				if p.quests.tracked == str(parts[2]):
					p.quests.tracked = ""
				p.quests_dirty = true
		_:
			if not QuestRules.force_start(w, p, str(parts[1])):
				_send_to(rec.id, Protocol.chat(0, "CMD_BAD"), true)


## The player a command names (by name after its arguments), or its author; null (and a
## message) when nobody has that name.
func _command_target(rec: Dictionary, name_parts: Array) -> PlayerState:
	if name_parts.is_empty():
		return state_of(rec.id)
	var wanted := " ".join(name_parts).to_lower()
	for id: int in _players:
		if str(_players[id].name).to_lower() == wanted:
			return state_of(id)
	_send_to(rec.id, Protocol.chat(0, "CMD_NO_PLAYER"), true)
	return null


## /objeto <base> [level] [rarity] [name]: the item goes straight to the bag.
func _item_command(rec: Dictionary, parts: Array) -> void:
	var w := world_of(rec.id)
	var db := w.items
	var base_id := str(parts[1])
	if db.base(base_id).is_empty():
		_send_to(rec.id, Protocol.chat(0, "CMD_BAD"), true)
		return
	var rest: Array = parts.slice(2)
	var level := -1
	var rarity := "common"
	if not rest.is_empty() and str(rest[0]).is_valid_int():
		level = clampi(str(rest.pop_front()).to_int(), 1, 65535)
	if not rest.is_empty() and str(rest[0]).to_lower() in (db.loot().get("rarities", []) as Array):
		rarity = str(rest.pop_front()).to_lower()
	var who := _command_target(rec, rest)
	if who == null:
		return
	var it := ItemRoll.roll_gear(base_id, level if level > 0 else who.progress.level, rarity, w.rng, db) \
		if not db.is_consumable(base_id) else ItemRoll.new_item(base_id, 1)
	if not who.inventory.add(it, db):
		_send_to(rec.id, Protocol.chat(0, "ITEM_BAG_FULL"), true)
		return
	who.inventory_dirty = true


## Sends each owner their changed inventory, and everyone the visible gear that changed.
func _flush_inventory() -> void:
	for id: int in _players:
		var rec: Dictionary = _players[id]
		var p: PlayerState = state_of(id)
		if p == null or not p.inventory_dirty:
			continue
		var w := world_of(id)
		p.inventory_dirty = false
		var cd := maxf(0.0, float(p.potion_ready_tick - w.tick) / float(balance.tick_rate))
		_send_to(id, Protocol.inventory(p.inventory.to_wire(), cd), true)
		var gear := p.inventory.visible_bases()
		if gear != rec.gear:
			rec.gear = gear
			_broadcast(Protocol.player_gear(id, gear), true)


## Item requests: the host checks everything (ItemRequests, Merchant); malformed ones are ignored.
func _on_item_action(rec: Dictionary, action: String, args: Array) -> void:
	var w := world_of(rec.id)
	var p: PlayerState = state_of(rec.id)
	if p == null:
		return
	var int_arg := args.size() >= 1 and args[0] is int
	var str_arg := args.size() >= 1 and args[0] is String
	match action:
		"equip":
			if int_arg:
				ItemRequests.equip(w, p, args[0], str(args[1]) if args.size() > 1 and args[1] is String else "")
		"unequip":
			if str_arg:
				ItemRequests.unequip(w, p, args[0])
		"use":
			if int_arg:
				ItemRequests.use(w, p, args[0])
		"potion":
			if str_arg:
				ItemRequests.use_potion(w, p, args[0])
		"merchant_open":
			_send_stock(rec.id, p)
		"buy":
			if int_arg and Merchant.buy(w, p, args[0]):
				_send_stock(rec.id, p)
		"sell":
			if int_arg:
				Merchant.sell(w, p, args[0])
		"repair":
			Merchant.repair_all(w, p)
		"sort":
			p.inventory.sort_bag(w.items)
			p.inventory_dirty = true


func _send_stock(id: int, p: PlayerState) -> void:
	var w := world_of(id)
	if Merchant.near(w, p, Merchant.TRADE_MARGIN): # the same reach as the trades
		_send_to(id, Protocol.merchant_stock(Merchant.stock(w, p).map(func(it: Item) -> Array: return it.to_wire())), true)


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
	zones.remove_player(id, str(_players[id].zone_key))
	_players.erase(id)
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


func _snapshot_rows(w: SimWorld, ids: Array) -> Array:
	var rows := []
	for id: int in ids:
		var s: PlayerState = w.players[id]
		rows.append([id, s.position, s.aim, s.facing, int(_players[id].last_seq), s.hp, s.stats.max_hp,
			s.resource, s.stats.max_resource, s.life, StatusEffect.bits_of(s), s.dash_ticks, s.dash_dir,
			s.dodge_ready_seq, s.move_mult(), s.combo, _charge_ratio(w, s), s.level])
	return rows


## Monster rows for one player: the nearest max_monsters_per_snapshot (all of them when
## there are fewer), so a big map never overflows the packet.
func _monster_rows(w: SimWorld, viewer: Vector3) -> Array:
	var list: Array = w.monsters.values()
	var cap := w.balance.max_monsters_per_snapshot
	if list.size() > cap:
		var at := Effects.flat(viewer)
		list.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool:
			var da := Effects.flat(a.position).distance_squared_to(at)
			var db := Effects.flat(b.position).distance_squared_to(at)
			return da < db if da != db else a.id < b.id)
		list = list.slice(0, cap)
	var rows := []
	for e: CombatEntity in list:
		# flags: bit 0 elite, bit 1 allied (a player summon)
		var flags := (1 if (e is MonsterState and (e as MonsterState).elite) else 0) | (2 if e.team == CombatEntity.TEAM_PLAYERS else 0)
		rows.append([e.id, e.type_id, e.position, e.facing, e.hp, e.stats.max_hp, StatusEffect.bits_of(e), e.target_id, flags, e.level])
	return rows


func _send_to(id: int, data: PackedByteArray, reliable: bool) -> void:
	var rec: Dictionary = _players[id]
	(_transports[rec.transport] as Transport).send(rec.peer, data, reliable)


func _broadcast(data: PackedByteArray, reliable: bool) -> void:
	for id: int in _players:
		_send_to(id, data, reliable)


## How far the archer's held shot is charged (0..1), for the HUD.
func _charge_ratio(w: SimWorld, p: PlayerState) -> float:
	if p.charge_start < 0:
		return 0.0
	var basic := w.abilities.get_ability(w.abilities.kind_of(p.class_id, "basic"))
	var max_ticks := maxi(1, w.ticks(float((basic.get("charge", {}) as Dictionary).get("max_s", 1.5))))
	return clampf(float(w.tick - p.charge_start) / float(max_ticks), 0.0, 1.0)
