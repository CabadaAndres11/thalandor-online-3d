class_name SettingsStore
extends RefCounted
## Local player settings in user://settings.json (versioned from the start).

const VERSION := 1
const DEFAULT_PATH := "user://settings.json"

var player_name: String = ""
var last_code: String = ""


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
	return s


func save_to(path: String = DEFAULT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "player_name": player_name, "last_code": last_code}, "\t"))
	f.close()
	return OK
