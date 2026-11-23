class_name SettingsStore
extends RefCounted
## Local player settings in user://settings.json (versioned from the start).
## Version 2 remembers the last chosen character; version 1's player name is still
## read (to suggest the first character's name) but no longer written.
## Version 3 adds video (quality, resolution scale, window, VSync, FPS cap) and audio
## (bus volumes, mute). Missing or invalid values fall back to their defaults.

const VERSION := 4
const DEFAULT_PATH := "user://settings.json"
const FPS_CHOICES := [0, 30, 60, 120, 144]
const MIN_RENDER_SCALE := 0.5
const RENDER_SCALE_STEP := 0.05
const DEFAULT_VOLUMES := {"Master": 1.0, "Music": 1.0, "SFX": 1.0, "UI": 1.0}

var player_name: String = ""
var last_code: String = ""
var last_character_id: String = ""

var quality: int = GraphicsQuality.MEDIUM
var render_scale: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var max_fps: int = 0
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var muted: bool = false
## The minimap under the icon bar (Plan 8.1.1; version 4, on in older files).
var minimap: bool = true


static func load_from(path: String = DEFAULT_PATH) -> SettingsStore:
	var s := SettingsStore.new()
	if not FileAccess.file_exists(path):
		return s
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return s
	var data: Dictionary = json.data
	if data.get("player_name") is String:
		s.player_name = data.player_name
	if data.get("last_code") is String:
		s.last_code = data.last_code
	if data.get("last_character_id") is String:
		s.last_character_id = data.last_character_id
	if _is_num(data.get("quality")):
		s.quality = GraphicsQuality.clamp_level(int(data.quality))
	if _is_num(data.get("render_scale")):
		s.render_scale = clamp_render_scale(float(data.render_scale))
	if data.get("fullscreen") is bool:
		s.fullscreen = data.fullscreen
	if data.get("vsync") is bool:
		s.vsync = data.vsync
	if _is_num(data.get("max_fps")):
		s.max_fps = nearest_fps(int(data.max_fps))
	if data.get("volumes") is Dictionary:
		for bus: String in DEFAULT_VOLUMES:
			var v: Variant = data.volumes.get(bus)
			if _is_num(v):
				s.volumes[bus] = clampf(float(v), 0.0, 1.0)
	if data.get("muted") is bool:
		s.muted = data.muted
	if data.get("minimap") is bool:
		s.minimap = data.minimap
	return s


static func clamp_render_scale(v: float) -> float:
	return clampf(snappedf(v, RENDER_SCALE_STEP), MIN_RENDER_SCALE, 1.0)


static func nearest_fps(v: int) -> int:
	var best: int = FPS_CHOICES[0]
	for c: int in FPS_CHOICES:
		if absi(c - v) < absi(best - v):
			best = c
	return best


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


func save_to(path: String = DEFAULT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({
		"version": VERSION, "last_code": last_code, "last_character_id": last_character_id,
		"quality": quality, "render_scale": render_scale, "fullscreen": fullscreen,
		"vsync": vsync, "max_fps": max_fps, "volumes": volumes, "muted": muted, "minimap": minimap,
	}, "\t"))
	f.close()
	return OK


## Back to the default video and audio settings (keeps the remembered character and code).
func reset_video_audio() -> void:
	quality = GraphicsQuality.MEDIUM
	render_scale = 1.0
	fullscreen = false
	vsync = true
	max_fps = 0
	volumes = DEFAULT_VOLUMES.duplicate()
	muted = false


func duplicate_store() -> SettingsStore:
	var d := SettingsStore.new()
	d.player_name = player_name
	d.last_code = last_code
	d.last_character_id = last_character_id
	d.quality = quality
	d.render_scale = render_scale
	d.fullscreen = fullscreen
	d.vsync = vsync
	d.max_fps = max_fps
	d.volumes = volumes.duplicate()
	d.muted = muted
	d.minimap = minimap
	return d
