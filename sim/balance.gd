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
## WebRTC: relay server that introduces players (tools/signaling) and STUN server.
var signaling_url: String = ""
var stun_url: String = ""
## Combat (Plan 3). Times in seconds; the simulation converts them to ticks.
var armor_k: float = 60.0
var mitigation_cap: float = 0.75
var crit_multiplier: float = 1.5
var damage_variance: float = 0.1
var gcd_s: float = 0.5
var dodge_distance: float = 3.0
var dodge_s: float = 0.2
var dodge_invuln_s: float = 0.3
var dodge_cooldown_s: float = 3.0
var in_combat_s: float = 5.0
var revive_hold_s: float = 3.0
var revive_range: float = 2.0
var revive_hp_pct: float = 0.3
var respawn_s: float = 3.0
var group_hp_scale: float = 0.75
var threat_switch_margin: float = 0.1
var boss_respawn_s: float = 180.0
var max_monsters_per_snapshot: int = 32


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
			TYPE_STRING:
				b.set(key, str(data[key]))
			TYPE_FLOAT:
				b.set(key, float(data[key]))
	return b


## Seconds per simulation tick.
func dt() -> float:
	return 1.0 / float(tick_rate)
