extends GutTest

const IDS := ["exterior_dia", "mazmorra_noche"]


func _ids() -> PackedStringArray:
	return PackedStringArray(IDS)


func test_lists_without_argument() -> void:
	var r := AmbienceCommand.handle("/ambiente", "exterior_dia", _ids())
	assert_true(r.handled)
	assert_eq(r.switch_to, "")
	assert_eq(r.message, tr("AMBIENCE_LIST") % ["exterior_dia", "exterior_dia, mazmorra_noche"])


func test_switches_to_valid_id() -> void:
	var r := AmbienceCommand.handle("/ambiente mazmorra_noche", "exterior_dia", _ids())
	assert_true(r.handled)
	assert_eq(r.switch_to, "mazmorra_noche")
	assert_eq(r.message, tr("AMBIENCE_SET") % "mazmorra_noche")


func test_case_and_spaces() -> void:
	var r := AmbienceCommand.handle("  /Ambiente   Mazmorra_Noche ", "exterior_dia", _ids())
	assert_true(r.handled)
	assert_eq(r.switch_to, "mazmorra_noche")


func test_unknown_id() -> void:
	var r := AmbienceCommand.handle("/ambiente lluvia", "exterior_dia", _ids())
	assert_true(r.handled)
	assert_eq(r.switch_to, "")
	assert_eq(r.message, tr("AMBIENCE_UNKNOWN") % ["lluvia", "exterior_dia, mazmorra_noche"])


func test_other_commands_not_handled() -> void:
	for text: String in ["/oro 5", "hola", "/ambientex", "ambiente"]:
		assert_false(AmbienceCommand.handle(text, "exterior_dia", _ids()).handled, text)
