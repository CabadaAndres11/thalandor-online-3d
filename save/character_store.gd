class_name CharacterStore
extends RefCounted
## The player's characters on disk: one JSON file per character in `dir`. Damaged or
## unknown files are skipped (and reported), never deleted.

const MAX_CHARACTERS := 8
const DEFAULT_DIR := "user://saves/characters"
## Where characters older than CharacterData.MIN_VERSION are moved (Plan 8.3a).
const OLD_DIR := "antiguos"

## Text key of the last failure (ERR_CHAR_FULL, ERR_NAME, ERR_NAME_TAKEN,
## ERR_IMPORT_INVALID, ERR_SAVE).
var last_error: String = ""
## Files of the last load_all() that could not be read as characters.
var skipped_files: Array[String] = []
## How many times save() wrote a file (lets tests check the coalescing).
var writes: int = 0
## How many old characters the last load_all() set aside.
var retired: int = 0

var _dir: String
var _catalog: CharacterCatalog
## Characters waiting for the next frame's write (id -> CharacterData).
var _pending: Dictionary = {}


func _init(dir: String = DEFAULT_DIR, catalog: CharacterCatalog = null) -> void:
	_dir = dir
	_catalog = catalog if catalog != null else CharacterCatalog.load_default()


func load_all() -> Array[CharacterData]:
	skipped_files.clear()
	retired = retire_old()
	var list: Array[CharacterData] = []
	var abs_dir := ProjectSettings.globalize_path(_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return list
	for file in DirAccess.get_files_at(abs_dir):
		if not file.ends_with(".json"):
			continue
		var c := _read(_dir.path_join(file))
		# Only "<id>.json" is that character: a copy under another name (Windows
		# "copy here") could never be deleted or exported, so it is reported instead.
		if c == null or file.get_basename() != c.id or not _is_safe_id(c.id):
			skipped_files.append(file)
		else:
			list.append(c)
	list.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return a.created_at < b.created_at if a.created_at != b.created_at else a.id < b.id)
	return list


func create(char_name: String, class_id: String, appearance: Dictionary) -> CharacterData:
	if not _can_add(char_name):
		return null
	var c := CharacterData.new()
	c.id = _new_id()
	c.name = char_name.strip_edges()
	c.class_id = _catalog.sanitize_class(class_id)
	c.appearance = _catalog.sanitize_appearance(appearance)
	c.created_at = int(Time.get_unix_time_from_system())
	c.bar = AbilityDB.load_default().default_bar(c.class_id)
	return c if save(c) == OK else null


## Asks for a save without writing yet: however many times it is called for a character
## before the next frame (or flush), the file is written once. Progress changes often
## (experience), so this keeps the disk quiet.
func queue_save(c: CharacterData) -> void:
	var first := _pending.is_empty()
	_pending[c.id] = c
	if first:
		var loop := Engine.get_main_loop()
		if loop is SceneTree and not (loop as SceneTree).process_frame.is_connected(flush):
			(loop as SceneTree).process_frame.connect(flush, CONNECT_ONE_SHOT)


## Writes the characters waiting in queue_save() now (on leaving the game and on quit).
func flush() -> void:
	var list := _pending.values()
	_pending.clear()
	for c: CharacterData in list:
		save(c)


func save(c: CharacterData) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	writes += 1
	var err := _write(_path(c.id), c)
	if err != OK:
		last_error = "ERR_SAVE"
	return err


func delete(id: String) -> bool:
	var path := _path(id)
	if not _is_safe_id(id) or not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func name_taken(char_name: String, except_id: String = "") -> bool:
	var key := char_name.strip_edges().to_lower()
	for c in load_all():
		if c.id != except_id and c.name.to_lower() == key:
			return true
	return false


func export_to(id: String, path: String) -> Error:
	var c := _read(_path(id)) if _is_safe_id(id) else null
	if c == null:
		return ERR_DOES_NOT_EXIST
	return _write(path, c)


## Moves the characters older than CharacterData.MIN_VERSION to OLD_DIR (never deletes
## them) and returns how many. Files that are not characters stay (reported by load_all).
func retire_old() -> int:
	var abs_dir := ProjectSettings.globalize_path(_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return 0
	var moved := 0
	for file in DirAccess.get_files_at(abs_dir):
		if not file.ends_with(".json"):
			continue
		var v := _version_of(_dir.path_join(file))
		if v < 0 or v >= CharacterData.MIN_VERSION:
			continue
		var old_abs := abs_dir.path_join(OLD_DIR)
		DirAccess.make_dir_recursive_absolute(old_abs)
		if DirAccess.rename_absolute(abs_dir.path_join(file), old_abs.path_join(file)) == OK:
			moved += 1
	return moved


## The version in a character file, or -1 when it is not one.
static func _version_of(path: String) -> int:
	var json := JSON.new() # quietly: a damaged file is reported by load_all, not logged
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return -1
	var d: Variant = json.data
	if not d is Dictionary or not (d as Dictionary).has("id"):
		return -1
	var v: Variant = (d as Dictionary).get("version", 0)
	return int(v) if (v is int or v is float) else -1


## Whether to tell the player their old characters were set aside (once).
static func should_notice(retired_count: int, settings: SettingsStore) -> bool:
	return retired_count > 0 and not settings.old_characters_notice_seen


## Imports a character exported from any PC under a new id; `new_name` replaces its
## name (for when the original name is already taken).
func import_from(path: String, new_name: String = "") -> CharacterData:
	var v := _version_of(path) if FileAccess.file_exists(path) else -1
	if v >= 0 and v < CharacterData.MIN_VERSION:
		last_error = "ERR_OLD_CHARACTER"
		return null
	var c := _read(path)
	if c == null:
		last_error = "ERR_IMPORT_INVALID"
		return null
	if new_name != "":
		c.name = new_name.strip_edges()
	if not _can_add(c.name):
		return null
	c.id = _new_id()
	c.created_at = int(Time.get_unix_time_from_system())
	return c if save(c) == OK else null


## The character in an exported file, without importing it (null if not one).
func peek(path: String) -> CharacterData:
	return _read(path)


func _can_add(char_name: String) -> bool:
	if not HostSession.is_valid_name(char_name.strip_edges()):
		last_error = "ERR_NAME"
		return false
	if load_all().size() >= MAX_CHARACTERS:
		last_error = "ERR_CHAR_FULL"
		return false
	if name_taken(char_name):
		last_error = "ERR_NAME_TAKEN"
		return false
	return true


func _read(path: String) -> CharacterData:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return CharacterData.from_dict(json.data, _catalog)


func _write(path: String, c: CharacterData) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(c.to_dict(), "\t"))
	f.close()
	return OK


func _path(id: String) -> String:
	return _dir.path_join(id + ".json")


## Ids are our own hex strings; anything else never becomes a file path.
func _is_safe_id(id: String) -> bool:
	return id.length() == 16 and id.is_valid_hex_number()


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()
