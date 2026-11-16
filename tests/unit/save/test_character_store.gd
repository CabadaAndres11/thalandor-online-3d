extends GutTest

const DIR := "user://test_chars"
const EXPORT_DIR := "user://test_chars_export"

var store: CharacterStore


func before_each() -> void:
	_clear(DIR)
	_clear(EXPORT_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	store = CharacterStore.new(DIR)


func after_each() -> void:
	_clear(DIR)
	_clear(EXPORT_DIR)


func _clear(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	DirAccess.remove_absolute(abs)


func _write(file: String, text: String) -> void:
	var f := FileAccess.open(DIR.path_join(file), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_create_and_load() -> void:
	var c := store.create("Aldric", "warrior", {"beard": "full"})
	assert_not_null(c)
	assert_eq(c.id.length(), 16)
	var again := CharacterStore.new(DIR).load_all()
	assert_eq(again.size(), 1)
	assert_eq(again[0].name, "Aldric")
	assert_eq(again[0].appearance.beard, "full")


func test_load_all_sorted_by_creation() -> void:
	var a := store.create("Primero", "warrior", {})
	var b := store.create("Segundo", "mage", {})
	b.created_at = a.created_at - 10
	store.save(b)
	var names := CharacterStore.new(DIR).load_all().map(func(c: CharacterData) -> String: return c.name)
	assert_eq(names, ["Segundo", "Primero"])


func test_max_eight() -> void:
	for i in 8:
		assert_not_null(store.create("Personaje %d" % i, "warrior", {}))
	assert_null(store.create("Noveno", "warrior", {}))
	assert_eq(store.last_error, "ERR_CHAR_FULL")
	assert_eq(store.load_all().size(), 8)


func test_duplicate_name_case_insensitive() -> void:
	assert_not_null(store.create("Ána", "warrior", {}))
	assert_null(store.create("ána", "mage", {}))
	assert_eq(store.last_error, "ERR_NAME_TAKEN")
	assert_null(store.create("  ÁNA ", "mage", {}))
	assert_eq(store.last_error, "ERR_NAME_TAKEN")


func test_accepts_accented_and_apostrophe_names() -> void:
	for n: String in ["Ñoño", "O'Brien", "Jean-Luc", "Íñigo 2"]:
		assert_not_null(store.create(n, "warrior", {}), n)


func test_invalid_name_is_rejected() -> void:
	assert_null(store.create("x", "warrior", {}))
	assert_eq(store.last_error, "ERR_NAME")


func test_damaged_file_is_skipped_not_deleted() -> void:
	store.create("Bueno", "warrior", {})
	_write("roto.json", "{ esto no es json")
	_write("raro.json", "[1, 2, 3]")
	var s := CharacterStore.new(DIR)
	var list := s.load_all()
	assert_eq(list.size(), 1)
	assert_eq(s.skipped_files.size(), 2)
	assert_true(FileAccess.file_exists(DIR.path_join("roto.json")), "never deleted")


func test_delete() -> void:
	var c := store.create("Borrable", "warrior", {})
	assert_true(store.delete(c.id))
	assert_eq(store.load_all().size(), 0)
	assert_false(store.delete("nope"))


func test_export_import_round_trip_gets_new_id() -> void:
	var c := store.create("Viajero", "archer", {"hair_style": "hair_bun"})
	var path := EXPORT_DIR.path_join("viajero.json")
	assert_eq(store.export_to(c.id, path), OK)
	assert_true(store.delete(c.id))
	var imported := store.import_from(path)
	assert_not_null(imported)
	assert_ne(imported.id, c.id, "a new id, so importing twice does not clash")
	assert_eq(imported.name, "Viajero")
	assert_eq(imported.class_id, "archer")
	assert_eq(imported.appearance, c.appearance)


func test_import_with_taken_name_needs_new_name() -> void:
	var c := store.create("Gemelo", "warrior", {})
	var path := EXPORT_DIR.path_join("gemelo.json")
	store.export_to(c.id, path)
	assert_null(store.import_from(path))
	assert_eq(store.last_error, "ERR_NAME_TAKEN")
	var renamed := store.import_from(path, "Gemelo Dos")
	assert_not_null(renamed)
	assert_eq(renamed.name, "Gemelo Dos")


func test_import_non_character_json_fails_cleanly() -> void:
	var path := EXPORT_DIR.path_join("otra_cosa.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"hola\": 1}")
	f.close()
	assert_null(store.import_from(path))
	assert_eq(store.last_error, "ERR_IMPORT_INVALID")
	assert_null(store.import_from(EXPORT_DIR.path_join("no_existe.json")))
	assert_eq(store.last_error, "ERR_IMPORT_INVALID")
	assert_eq(store.load_all().size(), 0)


func test_import_when_full_fails() -> void:
	var c := store.create("Extra", "warrior", {})
	var path := EXPORT_DIR.path_join("extra.json")
	store.export_to(c.id, path)
	for i in 7:
		store.create("Relleno %d" % i, "warrior", {})
	assert_null(store.import_from(path, "Otro Nombre"))
	assert_eq(store.last_error, "ERR_CHAR_FULL")


func test_export_to_unwritable_path_returns_error() -> void:
	var c := store.create("Sin Sitio", "warrior", {})
	assert_ne(store.export_to(c.id, "user://no/such/dir/x.json"), OK)
	assert_ne(store.export_to("unknown-id", EXPORT_DIR.path_join("x.json")), OK)


## Windows "copy here" makes "<id> - copia.json" with the same character inside: it
## must not show up as a character that can never be deleted.
func test_file_name_must_match_the_character_id() -> void:
	var c := store.create("Original", "warrior", {})
	DirAccess.copy_absolute(ProjectSettings.globalize_path(DIR.path_join(c.id + ".json")),
		ProjectSettings.globalize_path(DIR.path_join(c.id + " - copia.json")))
	var s := CharacterStore.new(DIR)
	var list := s.load_all()
	assert_eq(list.size(), 1, "the copy is not a second character")
	assert_eq(s.skipped_files, [c.id + " - copia.json"] as Array[String], "the copy is reported")
	assert_true(s.delete(c.id))
	assert_eq(s.load_all().size(), 0, "deleting really removes it from the list")
	assert_true(FileAccess.file_exists(DIR.path_join(c.id + " - copia.json")), "the copy is left alone")


func test_new_character_gets_the_default_bar() -> void:
	var c := store.create("Brann", "cleric", {})
	assert_eq(c.bar, AbilityDB.load_default().default_bar("cleric"))
	assert_eq(CharacterStore.new(DIR).load_all()[0].bar, c.bar)


func test_import_keeps_the_saved_bar() -> void:
	var c := store.create("Barra", "mage", {})
	c.level = 20
	c.bar = ["mage_fireball", "mage_frostbolt", "", ""]
	store.save(c)
	var path := EXPORT_DIR.path_join("barra.json")
	assert_eq(store.export_to(c.id, path), OK)
	store.delete(c.id)
	assert_eq(store.import_from(path).bar, ["mage_fireball", "mage_frostbolt", "", ""])
