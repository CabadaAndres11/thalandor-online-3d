extends GutTest
## Light on the menus (Plan 7): buttons and panels glow, shine and breathe.


func _button() -> Button:
	var b := Button.new()
	b.size = Vector2(200, 50)
	add_child_autofree(b)
	return b


func _param(fx: ColorRect, name: String) -> float:
	return float((fx.material as ShaderMaterial).get_shader_parameter(name))


func test_decorate_adds_a_glow_layer_that_lets_clicks_through() -> void:
	var b := _button()
	var fx := MenuFx.decorate(b)
	assert_eq(fx.get_parent(), b)
	assert_eq(fx.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(fx.material is ShaderMaterial)
	assert_eq(fx.offset_left, -MenuFx.GROW, "the glow spills outside the button")
	assert_eq(MenuFx.decorate(b), fx, "decorated once")


func test_hover_lights_the_edges_up() -> void:
	var b := _button()
	var fx := MenuFx.decorate(b)
	assert_eq(_param(fx, "edge"), 0.0)
	MenuFx.set_hover(b, true, true)
	assert_eq(_param(fx, "edge"), 1.0)
	assert_gt(_param(fx, "sweep"), 0.0, "a shine runs across while hovered")
	MenuFx.set_hover(b, false, true)
	assert_eq(_param(fx, "edge"), 0.0)


func test_hover_follows_the_mouse() -> void:
	var b := _button()
	var fx := MenuFx.decorate(b)
	b.mouse_entered.emit()
	await wait_seconds(0.4)
	assert_almost_eq(_param(fx, "edge"), 1.0, 0.01)
	b.mouse_exited.emit()
	await wait_seconds(0.5)
	assert_almost_eq(_param(fx, "edge"), 0.0, 0.01)


func test_the_call_to_action_always_breathes_and_shines() -> void:
	var b := _button()
	var fx := MenuFx.decorate(b, MenuFx.CALL)
	assert_gt(_param(fx, "pulse"), 0.0)
	assert_gt(_param(fx, "sweep"), 0.0)


func test_decorate_tree_covers_buttons_and_panels() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	for i in 3:
		box.add_child(Button.new())
	MenuFx.decorate_tree(root)
	MenuFx.decorate_tree(root)
	assert_eq(root.find_children(MenuFx.FX_NAME, "ColorRect", true, false).size(), 4)


func test_menus_are_lit() -> void:
	for screen: Control in [TitleScreen.new(), CharacterSelectScreen.new(), CharacterCreateScreen.new()]:
		add_child_autofree(screen)
		for b: Node in screen.find_children("*", "Button", true, false):
			assert_not_null((b as Node).get_node_or_null(MenuFx.FX_NAME), "%s: %s" % [screen.get_class(), b.name])
