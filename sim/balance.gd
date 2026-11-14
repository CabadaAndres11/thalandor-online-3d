class_name Balance
extends RefCounted
## Game-wide tuning constants loaded from data/balance.json.

const DEFAULT_PATH := "res://data/balance.json"

var move_speed: float = 5.0
var player_radius: float = 0.4
var tick_rate: int = 30
var interp_delay_ms: int = 100
var correction_ms: int = 100
var input_redundancy: int = 3
var max_pending_inputs: int = 4
var timeout_s: float = 5.0
var chat_max_len: int = 120
var port: int = 24680
var max_players: int = 4


static func load_from(path: String = DEFAULT_PATH) -> Balance:
	var b := Balance.new()
	if not FileAccess.file_exists(path):
		return b
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return b
	var data: Dictionary = parsed
	for key: String in data:
		var current: Variant = b.get(key)
		if current == null:
			continue
		match typeof(current):
			TYPE_INT:
				b.set(key, int(data[key]))
			TYPE_FLOAT:
				b.set(key, float(data[key]))
	return b


## Seconds per simulation tick.
func dt() -> float:
	return 1.0 / float(tick_rate)
