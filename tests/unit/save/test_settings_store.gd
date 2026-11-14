extends GutTest

const PATH := "user://test_settings_tmp.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_roundtrip() -> void:
	var s := SettingsStore.new()
	s.last_code = "ABCD-EFGH"
	s.last_character_id = "0123456789abcdef"
	assert_eq(s.save_to(PATH), OK)
	var loaded := SettingsStore.load_from(PATH)
	assert_eq(loaded.last_code, "ABCD-EFGH")
	assert_eq(loaded.last_character_id, "0123456789abcdef")


## Version 1 stored the player's name; it is only read now (to suggest the first
## character's name) and no longer written.
func test_reads_v1_player_name() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "player_name": "Andrés", "last_code": "ABCD-EFGH"}')
	f.close()
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.player_name, "Andrés")
	assert_eq(s.last_code, "ABCD-EFGH")
	assert_eq(s.last_character_id, "")
	s.save_to(PATH)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(saved.version, SettingsStore.VERSION)
	assert_false(saved.has("player_name"))


func test_missing_file_defaults() -> void:
	var s := SettingsStore.load_from("user://nope_settings.json")
	assert_eq(s.player_name, "")
	assert_eq(s.last_code, "")


func test_corrupt_file_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.player_name, "")


func test_wrong_types_default() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "player_name": 42, "last_code": ["x"]}')
	f.close()
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.player_name, "")
	assert_eq(s.last_code, "")


func test_saves_version_field() -> void:
	SettingsStore.new().save_to(PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(int(data.version), SettingsStore.VERSION)
