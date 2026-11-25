class_name Protocol
extends RefCounted
## Network messages: Arrays [type, fields...] encoded with var_to_bytes (never objects).

const VERSION := 9

enum Msg { HELLO = 1, WELCOME, REJECT, INPUT, SNAPSHOT, PLAYER_JOINED, PLAYER_LEFT, CHAT, EVENTS, SET_BAR, CHOOSE_CLASS, PLAYER_CLASS,
	SPEND_ATTRIBUTE, BUY_TALENT, BUY_MASTERY, RESET, SET_ARENA_LEVEL, PROGRESS, ARENA_LEVEL, CHOOSE_UPGRADE, PLAYER_UPGRADE,
	ITEM_ACTION, INVENTORY, PLAYER_GEAR, MERCHANT_STOCK, ZONE, PARTY, DUNGEON_OFFER, ENTER_DUNGEON, PLACE,
	QUESTS, QUEST_ACTION }

## Field names and Variant types per message type.
const SCHEMAS := {
	Msg.HELLO: [["game_version", TYPE_STRING], ["protocol", TYPE_INT], ["name", TYPE_STRING],
		["class_id", TYPE_STRING], ["appearance", TYPE_DICTIONARY], ["bar", TYPE_ARRAY], ["progress", TYPE_DICTIONARY],
		["inventory", TYPE_DICTIONARY], ["place", TYPE_DICTIONARY], ["quests", TYPE_DICTIONARY]],
	Msg.WELCOME: [["player_id", TYPE_INT], ["tick", TYPE_INT], ["roster", TYPE_ARRAY], ["arena_level", TYPE_INT]],
	Msg.REJECT: [["reason", TYPE_STRING], ["host_version", TYPE_STRING]],
	Msg.INPUT: [["inputs", TYPE_ARRAY]],
	Msg.SNAPSHOT: [["tick", TYPE_INT], ["players", TYPE_PACKED_BYTE_ARRAY], ["monsters", TYPE_PACKED_BYTE_ARRAY]],
	Msg.EVENTS: [["tick", TYPE_INT], ["events", TYPE_ARRAY]],
	Msg.SET_BAR: [["bar", TYPE_ARRAY]],
	Msg.CHOOSE_CLASS: [["class_id", TYPE_STRING]],
	Msg.PLAYER_CLASS: [["id", TYPE_INT], ["class_id", TYPE_STRING], ["bar", TYPE_ARRAY]],
	Msg.PLAYER_JOINED: [["id", TYPE_INT], ["name", TYPE_STRING], ["slot", TYPE_INT],
		["class_id", TYPE_STRING], ["appearance", TYPE_DICTIONARY], ["upgrade", TYPE_STRING], ["gear", TYPE_ARRAY]],
	Msg.PLAYER_LEFT: [["id", TYPE_INT]],
	Msg.CHAT: [["from_id", TYPE_INT], ["text", TYPE_STRING]],
	Msg.SPEND_ATTRIBUTE: [["attr", TYPE_STRING]],
	Msg.BUY_TALENT: [["id", TYPE_STRING]],
	Msg.BUY_MASTERY: [["dir", TYPE_STRING]],
	Msg.RESET: [["what", TYPE_STRING]],
	Msg.SET_ARENA_LEVEL: [["level", TYPE_INT]],
	Msg.PROGRESS: [["progress", TYPE_DICTIONARY], ["bar", TYPE_ARRAY]],
	Msg.ARENA_LEVEL: [["level", TYPE_INT]],
	Msg.CHOOSE_UPGRADE: [["id", TYPE_STRING]],
	Msg.PLAYER_UPGRADE: [["id", TYPE_INT], ["upgrade", TYPE_STRING]],
	Msg.ITEM_ACTION: [["action", TYPE_STRING], ["args", TYPE_ARRAY]],
	Msg.INVENTORY: [["inventory", TYPE_DICTIONARY], ["potion_cd_s", TYPE_FLOAT]],
	Msg.PLAYER_GEAR: [["id", TYPE_INT], ["gear", TYPE_ARRAY]],
	Msg.MERCHANT_STOCK: [["items", TYPE_ARRAY]],
	# Plan 8.1: the player now stands in another zone (its world key and dungeon level).
	Msg.ZONE: [["zone", TYPE_STRING], ["key", TYPE_STRING], ["level", TYPE_INT]],
	# Partners in other zones: [[id, zone name key, level, hp ratio], ...], once a second.
	Msg.PARTY: [["rows", TYPE_ARRAY]],
	# At a dungeon's door: the levels the player may choose (host -> client), and the choice.
	Msg.DUNGEON_OFFER: [["zone", TYPE_STRING], ["min_level", TYPE_INT], ["max_level", TYPE_INT], ["default_level", TYPE_INT]],
	Msg.ENTER_DUNGEON: [["zone", TYPE_STRING], ["level", TYPE_INT]],
	# Where to save the player (outside a dungeon: its door), at each zone change and every 30 s.
	Msg.PLACE: [["zone", TYPE_STRING], ["at", TYPE_ARRAY]],
	# Plan 8.2: the owner's quest log (host -> client), and what the client asks or reports.
	Msg.QUESTS: [["quests", TYPE_DICTIONARY]],
	Msg.QUEST_ACTION: [["action", TYPE_STRING], ["args", TYPE_ARRAY]],
}

## Element types of the nested arrays.
const ROW_SCHEMAS := {
	"roster": [TYPE_INT, TYPE_STRING, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY, TYPE_STRING, TYPE_ARRAY],
	"inputs": [TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_INT],
}


## SNAPSHOT rows travel packed: Variant arrays cost ~8 bytes per field and overflowed
## the ENet MTU (1392 bytes) in the arena's boss fight. The game still sees rows:
##   players: [id, position, aim, facing, last_seq, hp, max_hp, resource, max_resource,
##             life, status_bits, dash_ticks, dash_dir, dodge_ready_seq, move_mult, combo,
##             charge (0..1), level]
##            PLAYER_RECORD bytes: id s32, position 3×f32, aim 3×f32, facing f32,
##            last_seq s32, hp, max_hp, resource, max_resource f32, life u8,
##            status_bits u32, dash_ticks u16, dash_dir 2×f32, dodge_ready_seq s32,
##            move_mult f32, combo u8, charge f32, level u16.
##   monsters: [id, type, position, facing, hp, max_hp, status_bits, target_id, flags (bit 0 elite, bit 1 allied), level]
##            MONSTER_RECORD bytes: id u32, type u8 (index in monster_types(), 255
##            unknown), position 3×f32, facing u16 (angle / TAU), hp f32, max_hp f32,
##            status_bits u32, target_id u32, flags u8, level u16.
const PLAYER_RECORD := 82
const MONSTER_RECORD := 38

static var _monster_types: Array = []
const MAX_PACKET_BYTES := 16384
## HELLO sizes of older games, padded so the host can answer "different version":
## protocol 1 (0.1.x) had no character, protocol 2 (0.2.x) had no ability bar, protocol 5
## (0.5.x) had no progress, protocol 6 (0.6.x) had no inventory.
const LEGACY_HELLO_SIZE := 4
const PROTOCOL2_HELLO_SIZE := 6
const PROTOCOL5_HELLO_SIZE := 7
const PROTOCOL6_HELLO_SIZE := 8
const PROTOCOL7_HELLO_SIZE := 9
const PROTOCOL8_HELLO_SIZE := 10
const MAGIC_0 := 0x54 # "T"
const MAGIC_1 := 0x4F # "O"
const HEADER_SIZE := 6


static func pack(message: Array) -> PackedByteArray:
	var payload := var_to_bytes(message)
	var out := PackedByteArray([MAGIC_0, MAGIC_1, 0, 0, 0, 0])
	out.encode_u32(2, payload.size())
	out.append_array(payload)
	return out


static func hello(game_version: String, protocol: int, name: String, class_id: String,
		appearance: Dictionary, bar: Array = [], progress: Dictionary = {}, inventory: Dictionary = {},
		place: Dictionary = {}, quests: Dictionary = {}) -> PackedByteArray:
	return pack([Msg.HELLO, game_version, protocol, name, class_id, appearance, bar, progress, inventory, place, quests])


static func welcome(player_id: int, tick: int, roster: Array, arena_level: int = 1) -> PackedByteArray:
	return pack([Msg.WELCOME, player_id, tick, roster, arena_level])


static func reject(reason: String, host_version: String) -> PackedByteArray:
	return pack([Msg.REJECT, reason, host_version])


static func input(inputs: Array) -> PackedByteArray:
	return pack([Msg.INPUT, inputs])


static func snapshot(tick: int, players: Array, monsters: Array = []) -> PackedByteArray:
	return pack([Msg.SNAPSHOT, tick, pack_players(players), pack_monsters(monsters)])


static func events(tick: int, list: Array) -> PackedByteArray:
	return pack([Msg.EVENTS, tick, list])


static func set_bar(bar: Array) -> PackedByteArray:
	return pack([Msg.SET_BAR, bar])


## A villager asks to learn a class (from a class trainer next to them).
static func choose_class(class_id: String) -> PackedByteArray:
	return pack([Msg.CHOOSE_CLASS, class_id])


## The host tells everyone a player has a new class (and its default bar).
static func player_class(id: int, class_id: String, bar: Array) -> PackedByteArray:
	return pack([Msg.PLAYER_CLASS, id, class_id, bar])


static func player_joined(id: int, name: String, slot: int, class_id: String,
		appearance: Dictionary, upgrade: String = "", gear: Array = []) -> PackedByteArray:
	return pack([Msg.PLAYER_JOINED, id, name, slot, class_id, appearance, upgrade, gear])


static func player_left(id: int) -> PackedByteArray:
	return pack([Msg.PLAYER_LEFT, id])


static func chat(from_id: int, text: String) -> PackedByteArray:
	return pack([Msg.CHAT, from_id, text])


## A player asks to spend a free attribute point.
static func spend_attribute(attr: String) -> PackedByteArray:
	return pack([Msg.SPEND_ATTRIBUTE, attr])


static func buy_talent(id: String) -> PackedByteArray:
	return pack([Msg.BUY_TALENT, id])


static func buy_mastery(dir: String) -> PackedByteArray:
	return pack([Msg.BUY_MASTERY, dir])


## what: "attributes", "talents" or "upgrade" (next to the class trainer, out of combat).
static func reset(what: String) -> PackedByteArray:
	return pack([Msg.RESET, what])


## The host player asks the trainer to change the arena's monster level.
static func set_arena_level(level: int) -> PackedByteArray:
	return pack([Msg.SET_ARENA_LEVEL, level])


## The host sends a player their own progress and ability bar (nobody else's).
static func progress(progress_data: Dictionary, bar: Array) -> PackedByteArray:
	return pack([Msg.PROGRESS, progress_data, bar])


static func arena_level(level: int) -> PackedByteArray:
	return pack([Msg.ARENA_LEVEL, level])


## A player asks to do something with their items: equip [index, target?], unequip [slot],
## use [index], potion [kind], merchant_open [], buy [index], sell [index], repair [].
static func item_action(action: String, args: Array = []) -> PackedByteArray:
	return pack([Msg.ITEM_ACTION, action, args])


## The host sends a player their own inventory (Inventory.to_wire) and potion cooldown left.
static func inventory(wire: Dictionary, potion_cd_s: float) -> PackedByteArray:
	return pack([Msg.INVENTORY, wire, potion_cd_s])


## A player's visible equipment changed: 8 base ids (Inventory.VISIBLE), for everyone.
static func player_gear(id: int, gear: Array) -> PackedByteArray:
	return pack([Msg.PLAYER_GEAR, id, gear])


## What the merchant sells to this player: item wire arrays.
static func merchant_stock(items: Array) -> PackedByteArray:
	return pack([Msg.MERCHANT_STOCK, items])


## Returns {"type": Msg, <fields>} or {} when the packet is invalid.
static func decode(data: PackedByteArray) -> Dictionary:
	# Header: 2 magic bytes + u32 payload length. Truncated or foreign packets are
	# rejected here, before the engine decoder (which logs errors on bad input).
	if data.size() < HEADER_SIZE + 4 or data.size() > MAX_PACKET_BYTES:
		return {}
	if data[0] != MAGIC_0 or data[1] != MAGIC_1:
		return {}
	var payload := data.slice(HEADER_SIZE)
	if data.decode_u32(2) != payload.size():
		return {}
	if payload.decode_u32(0) & 0xFF != TYPE_ARRAY:
		return {}
	var value: Variant = bytes_to_var(payload)
	if not value is Array:
		return {}
	var arr: Array = value
	if arr.is_empty() or typeof(arr[0]) != TYPE_INT or not SCHEMAS.has(arr[0]):
		return {}
	var schema: Array = SCHEMAS[arr[0]]
	# Older HELLOs (0.1.x, 0.2.x) are padded so the host can answer "version".
	if arr[0] == Msg.HELLO and arr.size() == LEGACY_HELLO_SIZE:
		arr = arr + ["", {}, [], {}, {}, {}, {}]
	elif arr[0] == Msg.HELLO and arr.size() == PROTOCOL2_HELLO_SIZE:
		arr = arr + [[], {}, {}, {}, {}]
	elif arr[0] == Msg.HELLO and arr.size() == PROTOCOL5_HELLO_SIZE:
		arr = arr + [{}, {}, {}, {}]
	elif arr[0] == Msg.HELLO and arr.size() == PROTOCOL6_HELLO_SIZE:
		arr = arr + [{}, {}, {}]
	elif arr[0] == Msg.HELLO and arr.size() == PROTOCOL7_HELLO_SIZE:
		arr = arr + [{}, {}]
	elif arr[0] == Msg.HELLO and arr.size() == PROTOCOL8_HELLO_SIZE:
		arr = arr + [{}]
	if arr.size() != schema.size() + 1:
		return {}
	var out := {"type": arr[0]}
	for i in schema.size():
		var field_name: String = schema[i][0]
		var v: Variant = arr[i + 1]
		if typeof(v) != schema[i][1]:
			return {}
		if ROW_SCHEMAS.has(field_name) and not _rows_valid(v, ROW_SCHEMAS[field_name]):
			return {}
		if field_name == "players" and v is PackedByteArray:
			v = unpack_players(v)
			if v == null:
				return {}
		if field_name == "monsters":
			v = unpack_monsters(v)
			if v == null:
				return {}
		out[field_name] = v
	return out


static func _rows_valid(rows: Array, types: Array) -> bool:
	for row: Variant in rows:
		if not row is Array or (row as Array).size() != types.size():
			return false
		for j in types.size():
			if typeof(row[j]) != types[j]:
				return false
	return true


## Monster type ids in a fixed order (both ends load the same data/monsters).
static func monster_types() -> Array:
	if _monster_types.is_empty():
		_monster_types = MonsterDB.load_default().type_ids()
		_monster_types.sort()
	return _monster_types


static func pack_monsters(rows: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	var types := monster_types()
	for row: Array in rows:
		var pos: Vector3 = row[2]
		var type_index := types.find(str(row[1]))
		buf.put_u32(int(row[0]))
		buf.put_u8(type_index if type_index >= 0 and type_index < 255 else 255)
		buf.put_float(pos.x)
		buf.put_float(pos.y)
		buf.put_float(pos.z)
		buf.put_u16(int(roundf(fposmod(float(row[3]), TAU) / TAU * 65536.0)) & 0xFFFF)
		buf.put_float(float(row[4]))
		buf.put_float(float(row[5]))
		buf.put_u32(int(row[6]))
		buf.put_u32(int(row[7]))
		buf.put_u8(clampi(int(row[8]), 0, 255))
		buf.put_u16(clampi(int(row[9]), 0, 65535))
	return buf.data_array


## The rows back (facing in -PI..PI); null when the bytes are not whole records.
static func unpack_monsters(data: PackedByteArray) -> Variant:
	if data.size() % MONSTER_RECORD != 0:
		return null
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var types := monster_types()
	var rows := []
	for _at in range(0, data.size(), MONSTER_RECORD):
		var id := buf.get_u32()
		var t := buf.get_u8()
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var facing := wrapf(float(buf.get_u16()) / 65536.0 * TAU, -PI, PI)
		var hp := buf.get_float()
		var max_hp := buf.get_float()
		var bits := buf.get_u32()
		var target := buf.get_u32()
		var elite := buf.get_u8()
		var level := buf.get_u16()
		rows.append([id, types[t] if t < types.size() else "", pos, facing, hp, max_hp, bits, target, elite, level])
	return rows


static func pack_players(rows: Array) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	for row: Array in rows:
		var pos: Vector3 = row[1]
		var aim: Vector3 = row[2]
		var dash: Vector2 = row[12]
		buf.put_32(int(row[0]))
		for v: float in [pos.x, pos.y, pos.z, aim.x, aim.y, aim.z, float(row[3])]:
			buf.put_float(v)
		buf.put_32(int(row[4]))
		for v: float in [float(row[5]), float(row[6]), float(row[7]), float(row[8])]:
			buf.put_float(v)
		buf.put_u8(clampi(int(row[9]), 0, 255))
		buf.put_u32(int(row[10]))
		buf.put_u16(clampi(int(row[11]), 0, 65535))
		buf.put_float(dash.x)
		buf.put_float(dash.y)
		buf.put_32(int(row[13]))
		buf.put_float(float(row[14]))
		buf.put_u8(clampi(int(row[15]), 0, 255))
		buf.put_float(float(row[16]))
		buf.put_u16(clampi(int(row[17]), 0, 65535))
	return buf.data_array


## The rows back; null when the bytes are not whole records.
static func unpack_players(data: PackedByteArray) -> Variant:
	if data.size() % PLAYER_RECORD != 0:
		return null
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var rows := []
	for _at in range(0, data.size(), PLAYER_RECORD):
		var id := buf.get_32()
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var aim := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var facing := buf.get_float()
		var seq := buf.get_32()
		var hp := buf.get_float()
		var max_hp := buf.get_float()
		var res := buf.get_float()
		var max_res := buf.get_float()
		var life := buf.get_u8()
		var bits := buf.get_u32()
		var dash_ticks := buf.get_u16()
		var dash_dir := Vector2(buf.get_float(), buf.get_float())
		var dodge := buf.get_32()
		var move_mult := buf.get_float()
		var combo := buf.get_u8()
		var charge := buf.get_float()
		var level := buf.get_u16()
		rows.append([id, pos, aim, facing, seq, hp, max_hp, res, max_res, life, bits, dash_ticks, dash_dir,
			dodge, move_mult, combo, charge, level])
	return rows


## A level 50 player asks Brann for a class upgrade.
static func zone(zone_id: String, key: String, level: int) -> PackedByteArray:
	return pack([Msg.ZONE, zone_id, key, level])


static func dungeon_offer(zone_id: String, min_level: int, max_level: int, default_level: int) -> PackedByteArray:
	return pack([Msg.DUNGEON_OFFER, zone_id, min_level, max_level, default_level])


static func enter_dungeon(zone_id: String, level: int) -> PackedByteArray:
	return pack([Msg.ENTER_DUNGEON, zone_id, level])


static func quests(quest_log: Dictionary) -> PackedByteArray:
	return pack([Msg.QUESTS, quest_log])


static func quest_action(action: String, args: Array) -> PackedByteArray:
	return pack([Msg.QUEST_ACTION, action, args])


static func place(zone_id: String, at: Array) -> PackedByteArray:
	return pack([Msg.PLACE, zone_id, at])


static func party(rows: Array) -> PackedByteArray:
	return pack([Msg.PARTY, rows])


static func choose_upgrade(id: String) -> PackedByteArray:
	return pack([Msg.CHOOSE_UPGRADE, id])


## The host tells everyone a player's upgrade ("" = none).
static func player_upgrade(id: int, upgrade: String) -> PackedByteArray:
	return pack([Msg.PLAYER_UPGRADE, id, upgrade])
