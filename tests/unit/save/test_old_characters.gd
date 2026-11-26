extends GutTest
## Characters from before the prologue (Plan 8.3a): set aside in antiguos/, never loaded or
## imported; a notice says so once.

const DIR := "user://test_old_chars"

var store: CharacterStore


func before_each() -> void:
	_clear(DIR.path_join(CharacterStore.OLD_DIR))
	_clear(DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	store = CharacterStore.new(DIR)


func after_each() -> void:
	_clear(DIR.path_join(CharacterStore.OLD_DIR))
	_clear(DIR)


func _clear(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	DirAccess.remove_absolute(abs)


func _old(id: String, version := 6) -> String:
	var path := DIR.path_join(id + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": version, "id": id, "name": "Viejo" + id, "class_id": "warrior"}))
	f.close()
	return path


func test_version_is_7() -> void:
	assert_eq(CharacterData.VERSION, 7)


func test_v6_moved_to_antiguos() -> void:
	_old("aaaa1111")
	var list := store.load_all()
	assert_eq(list.size(), 0)
	assert_eq(store.retired, 1)
	assert_false(FileAccess.file_exists(DIR.path_join("aaaa1111.json")))
	assert_true(FileAccess.file_exists(DIR.path_join(CharacterStore.OLD_DIR).path_join("aaaa1111.json")))
	assert_eq(store.skipped_files, [] as Array[String], "set aside, not reported as damaged")


func test_v7_loads() -> void:
	var c := store.create("Nueva", "villager", {})
	var list := store.load_all()
	assert_eq(list.size(), 1)
	assert_eq(list[0].id, c.id)
	assert_eq(store.retired, 0)


func test_import_old_refused() -> void:
	var path := _old("bbbb2222")
	var copy := "user://test_old_import.json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
	assert_null(store.import_from(copy))
	assert_eq(store.last_error, "ERR_OLD_CHARACTER")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))


func test_notice_once() -> void:
	var s := SettingsStore.new()
	assert_true(CharacterStore.should_notice(1, s))
	s.old_characters_notice_seen = true
	assert_false(CharacterStore.should_notice(1, s))
	assert_false(CharacterStore.should_notice(0, SettingsStore.new()))
