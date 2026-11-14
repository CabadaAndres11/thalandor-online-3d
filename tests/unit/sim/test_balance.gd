extends GutTest

const TMP_PATH := "user://test_balance_tmp.json"


func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))


func test_loads_values_from_file() -> void:
	var b := Balance.load_from()
	assert_almost_eq(b.move_speed, 5.0, 0.0001)
	assert_eq(b.tick_rate, 30)
	assert_eq(b.port, 24680)
	assert_eq(b.max_players, 4)


func test_missing_keys_keep_defaults() -> void:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	f.store_string('{"move_speed": 7}')
	f.close()
	var b := Balance.load_from(TMP_PATH)
	assert_almost_eq(b.move_speed, 7.0, 0.0001)
	assert_eq(b.tick_rate, 30)


func test_missing_file_returns_defaults() -> void:
	var b := Balance.load_from("user://does_not_exist.json")
	assert_almost_eq(b.move_speed, 5.0, 0.0001)
	assert_eq(b.chat_max_len, 120)


func test_loads_string_values() -> void:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	f.store_string('{"signaling_url": "wss://example.test", "stun_url": "stun:x:1"}')
	f.close()
	var b := Balance.load_from(TMP_PATH)
	assert_eq(b.signaling_url, "wss://example.test")
	assert_eq(b.stun_url, "stun:x:1")
