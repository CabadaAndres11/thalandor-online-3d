extends GutTest


func test_load_both_ambiences() -> void:
	assert_eq(Ambience.ids(), PackedStringArray(["exterior_dia", "mazmorra_noche"]))
	var night := Ambience.load_id("mazmorra_noche")
	assert_eq(night.id, "mazmorra_noche")
	assert_eq(night.particles, "embers")
	assert_true(night.glow)
	assert_true(night.volumetric_density > 0.0)
	var day := Ambience.load_id("exterior_dia")
	assert_eq(day.particles, "dust")
	assert_true(day.sun_shadows)


func test_missing_sections_use_defaults() -> void:
	var a := Ambience.from_dict("x", {})
	assert_eq(a.id, "x")
	assert_false(a.glow)
	assert_false(a.ssao)
	assert_false(a.dof)
	assert_false(a.ssr)
	assert_eq(a.particles, "none")
	assert_gt(a.sun_energy, 0.0)
	assert_eq(a.tonemap, "aces")
	assert_eq(a.contrast, 1.0)


func test_bad_values_fall_back() -> void:
	var defaults := Ambience.from_dict("d", {})
	var a := Ambience.from_dict("x", {"sun": {"color": "notacolor", "energy": "x"},
		"tonemap": {"mode": "weird"}, "particles": {"type": "rain", "amount": 10}})
	assert_eq(a.sun_color, defaults.sun_color)
	assert_eq(a.sun_energy, defaults.sun_energy)
	assert_eq(a.tonemap, "aces")
	assert_eq(a.particles, "none")


func test_present_section_turns_effect_on() -> void:
	var a := Ambience.from_dict("x", {"glow": {"intensity": 0.7}, "ssao": {}, "ssr": true})
	assert_true(a.glow)
	assert_almost_eq(a.glow_intensity, 0.7, 0.001)
	assert_true(a.ssao)
	assert_true(a.ssr)


func test_unknown_id_falls_back() -> void:
	var a := Ambience.load_id("nope")
	assert_eq(a.id, Ambience.DEFAULT_ID)
