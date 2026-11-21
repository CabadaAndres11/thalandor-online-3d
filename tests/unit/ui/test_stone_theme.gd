extends GutTest
## The stone and gold look of the menus (Plan 7).


func test_apply_sets_the_button_states() -> void:
	var theme := Theme.new()
	StoneTheme.apply(theme)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		assert_true(theme.has_stylebox(state, "Button"), state)
	var normal := theme.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_eq(normal.border_color, StoneTheme.GOLD_DIM)
	assert_eq((theme.get_stylebox("pressed", "Button") as StyleBoxFlat).bg_color, StoneTheme.BLOOD)
	assert_eq(theme.get_color("font_color", "Button"), StoneTheme.TEXT)
	assert_true(theme.has_stylebox("panel", "PanelContainer"))


func test_panel_is_stone_with_a_gold_border() -> void:
	var p := StoneTheme.panel()
	assert_eq(p.bg_color, StoneTheme.STONE)
	assert_eq(p.border_color, StoneTheme.GOLD_DIM)
	assert_gt(p.border_width_left, 0)


func test_primary_button_is_gold() -> void:
	var b := Button.new()
	StoneTheme.primary_button(b)
	assert_eq((b.get_theme_stylebox("normal") as StyleBoxFlat).border_color, StoneTheme.GOLD)
	assert_gte(b.get_theme_font_size("font_size"), 40)
	b.free()
