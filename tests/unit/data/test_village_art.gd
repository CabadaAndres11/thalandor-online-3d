extends GutTest
## Plan 8.3d: the village houses, the barn and the cows.

const PIECES := ["house_timber", "house_log", "house_stone", "house_burnt_timber", "house_burnt_log", "house_burnt_stone", "barn", "cow", "trough"]


func test_pieces_exist() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZoneLayout.PIECES_PATH))
	for id: String in PIECES:
		assert_true(table.has(id), id)
		var def: Dictionary = table.get(id, {})
		var files: Array = []
		if def.has("parts"):
			for part: String in def.parts:
				files.append(str(def.parts[part].vox))
		else:
			files.append(str(def.get("vox", "")))
		for f: String in files:
			assert_true(FileAccess.file_exists(f), f)
