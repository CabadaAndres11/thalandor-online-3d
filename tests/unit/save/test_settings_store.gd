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


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_v3_round_trip() -> void:
	var s := SettingsStore.new()
	s.quality = GraphicsQuality.HIGH
	s.render_scale = 0.75
	s.fullscreen = true
	s.vsync = false
	s.max_fps = 144
	s.volumes = {"Master": 0.5, "Music": 0.25, "SFX": 0.0, "UI": 1.0}
	s.muted = true
	s.last_character_id = "abc"
	assert_eq(s.save_to(PATH), OK)
	var l := SettingsStore.load_from(PATH)
	assert_eq(l.quality, GraphicsQuality.HIGH)
	assert_almost_eq(l.render_scale, 0.75, 0.001)
	assert_true(l.fullscreen)
	assert_false(l.vsync)
	assert_eq(l.max_fps, 144)
	assert_almost_eq(float(l.volumes.Music), 0.25, 0.001)
	assert_almost_eq(float(l.volumes.SFX), 0.0, 0.001)
	assert_true(l.muted)
	assert_eq(l.last_character_id, "abc")


func test_v2_file_gets_video_defaults() -> void:
	_write('{"version": 2, "last_code": "ABCD-EFGH", "last_character_id": "xyz"}')
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.quality, GraphicsQuality.MEDIUM)
	assert_almost_eq(s.render_scale, 1.0, 0.001)
	assert_false(s.fullscreen)
	assert_true(s.vsync)
	assert_eq(s.max_fps, 0)
	assert_eq(s.volumes, {"Master": 1.0, "Music": 1.0, "SFX": 1.0, "UI": 1.0})
	assert_false(s.muted)
	assert_eq(s.last_character_id, "xyz")
	assert_eq(s.last_code, "ABCD-EFGH")


func test_out_of_range_values_are_clamped() -> void:
	_write('{"version": 3, "quality": 7, "render_scale": 0.1, "max_fps": 75, ' +
		'"volumes": {"Master": -3, "Music": "x", "SFX": 2.5}, "fullscreen": "yes"}')
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.quality, GraphicsQuality.HIGH)
	assert_almost_eq(s.render_scale, 0.5, 0.001)
	assert_eq(s.max_fps, 60)
	assert_almost_eq(float(s.volumes.Master), 0.0, 0.001)
	assert_almost_eq(float(s.volumes.Music), 1.0, 0.001)
	assert_almost_eq(float(s.volumes.SFX), 1.0, 0.001)
	assert_almost_eq(float(s.volumes.UI), 1.0, 0.001)
	assert_false(s.fullscreen)


func test_render_scale_rounds_to_steps() -> void:
	_write('{"version": 3, "render_scale": 0.83}')
	assert_almost_eq(SettingsStore.load_from(PATH).render_scale, 0.85, 0.001)


func test_reset_video_audio_keeps_last_character() -> void:
	var s := SettingsStore.new()
	s.last_character_id = "keep"
	s.quality = GraphicsQuality.LOW
	s.muted = true
	s.volumes.Music = 0.1
	s.reset_video_audio()
	assert_eq(s.quality, GraphicsQuality.MEDIUM)
	assert_false(s.muted)
	assert_almost_eq(float(s.volumes.Music), 1.0, 0.001)
	assert_eq(s.last_character_id, "keep")


func test_duplicate_store_is_independent() -> void:
	var s := SettingsStore.new()
	var d := s.duplicate_store()
	d.volumes.Music = 0.2
	d.quality = GraphicsQuality.LOW
	assert_almost_eq(float(s.volumes.Music), 1.0, 0.001)
	assert_eq(s.quality, GraphicsQuality.MEDIUM)


func test_corrupt_file_gives_defaults() -> void:
	_write("{not json")
	var s := SettingsStore.load_from(PATH)
	assert_eq(s.quality, GraphicsQuality.MEDIUM)
	assert_true(s.vsync)
