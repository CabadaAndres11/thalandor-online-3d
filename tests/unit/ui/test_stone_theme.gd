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


## Play: a rounded ember pill (blood red to orange) with a play icon, like a launcher button.
func test_primary_button_is_an_ember_pill_with_an_icon() -> void:
	var b := Button.new()
	StoneTheme.primary_button(b)
	for state: String in ["normal", "hover", "pressed"]:
		var box := b.get_theme_stylebox(state) as StyleBoxTexture
		assert_not_null(box, state)
		assert_not_null(box.texture, state)
		assert_gt(box.texture_margin_left, 20.0, state + ": the round ends do not stretch")
	assert_ne(b.get_theme_stylebox("hover"), b.get_theme_stylebox("normal"), "it lights up under the mouse")
	b.free()


## The triangle sits right before the word, the pair centred on the button (as in the reference).
func test_primary_button_centres_icon_and_text_together() -> void:
	var b := Button.new()
	b.text = "Jugar"
	b.size = Vector2(300, 76)
	StoneTheme.primary_button(b)
	add_child_autofree(b)
	await wait_frames(2)
	var icon := b.find_child("PlayIcon", true, false) as TextureRect
	var label := b.find_child("PlayText", true, false) as Label
	assert_not_null(icon)
	assert_eq(label.text, "Jugar")
	assert_eq(label.get_theme_color("font_color"), Color.WHITE)
	assert_gte(label.get_theme_font_size("font_size"), 40)
	var gap := label.get_global_rect().position.x - icon.get_global_rect().end.x
	assert_between(gap, 0.0, 24.0, "the icon next to the word")
	var group := icon.get_global_rect().merge(label.get_global_rect())
	assert_almost_eq(group.get_center().x, b.get_global_rect().get_center().x, 6.0, "centred together")
	assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
