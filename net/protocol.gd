class_name Protocol
extends RefCounted
## Network messages: Arrays [type, fields...] encoded with var_to_bytes (never objects).

const VERSION := 2

enum Msg { HELLO = 1, WELCOME, REJECT, INPUT, SNAPSHOT, PLAYER_JOINED, PLAYER_LEFT, CHAT }

## Field names and Variant types per message type.
const SCHEMAS := {
	Msg.HELLO: [["game_version", TYPE_STRING], ["protocol", TYPE_INT], ["name", TYPE_STRING],
		["class_id", TYPE_STRING], ["appearance", TYPE_DICTIONARY]],
	Msg.WELCOME: [["player_id", TYPE_INT], ["tick", TYPE_INT], ["roster", TYPE_ARRAY]],
	Msg.REJECT: [["reason", TYPE_STRING], ["host_version", TYPE_STRING]],
	Msg.INPUT: [["inputs", TYPE_ARRAY]],
	Msg.SNAPSHOT: [["tick", TYPE_INT], ["players", TYPE_ARRAY]],
	Msg.PLAYER_JOINED: [["id", TYPE_INT], ["name", TYPE_STRING], ["slot", TYPE_INT],
		["class_id", TYPE_STRING], ["appearance", TYPE_DICTIONARY]],
	Msg.PLAYER_LEFT: [["id", TYPE_INT]],
	Msg.CHAT: [["from_id", TYPE_INT], ["text", TYPE_STRING]],
}

## Element types of the nested arrays.
const ROW_SCHEMAS := {
	"roster": [TYPE_INT, TYPE_STRING, TYPE_INT, TYPE_STRING, TYPE_DICTIONARY],
	"inputs": [TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3],
	"players": [TYPE_INT, TYPE_VECTOR3, TYPE_VECTOR3, TYPE_FLOAT, TYPE_INT],
}

const MAX_PACKET_BYTES := 16384
## [type, game_version, protocol, name]: HELLO of protocol 1 (game 0.1.x).
const LEGACY_HELLO_SIZE := 4
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
		appearance: Dictionary) -> PackedByteArray:
	return pack([Msg.HELLO, game_version, protocol, name, class_id, appearance])


static func welcome(player_id: int, tick: int, roster: Array) -> PackedByteArray:
	return pack([Msg.WELCOME, player_id, tick, roster])


static func reject(reason: String, host_version: String) -> PackedByteArray:
	return pack([Msg.REJECT, reason, host_version])


static func input(inputs: Array) -> PackedByteArray:
	return pack([Msg.INPUT, inputs])


static func snapshot(tick: int, players: Array) -> PackedByteArray:
	return pack([Msg.SNAPSHOT, tick, players])


static func player_joined(id: int, name: String, slot: int, class_id: String,
		appearance: Dictionary) -> PackedByteArray:
	return pack([Msg.PLAYER_JOINED, id, name, slot, class_id, appearance])


static func player_left(id: int) -> PackedByteArray:
	return pack([Msg.PLAYER_LEFT, id])


static func chat(from_id: int, text: String) -> PackedByteArray:
	return pack([Msg.CHAT, from_id, text])


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
	# Protocol 1 HELLO had no character: decode it so the host can answer "version".
	if arr[0] == Msg.HELLO and arr.size() == LEGACY_HELLO_SIZE:
		arr = arr + ["", {}]
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
