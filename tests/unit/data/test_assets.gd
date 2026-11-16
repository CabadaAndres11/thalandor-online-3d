extends GutTest
## All the art is made by the project's own scripts: no third-party model packs.


func _files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_files(dir.path_join(sub), out)


func test_no_kenney_left() -> void:
	var files: Array = []
	_files("res://assets", files)
	for f: String in files:
		assert_false(f.ends_with(".glb") or f.ends_with(".glb.import"), f)
		assert_false(f.contains("characters/base/") or f.contains("characters/layers/"), f)
		assert_false(f.ends_with("character.gdshader"), f)
	assert_false(FileAccess.file_exists("res://tools/art/extract_layers.mjs"))
	assert_false(FileAccess.file_exists("res://tools/art/paint_outfits.mjs"))
	assert_false(FileAccess.get_file_as_string("res://CREDITS.md").contains("Kenney"))
