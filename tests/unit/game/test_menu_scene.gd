extends GutTest
## The black sun altar behind the menus (Plan 7).

var scene: MenuScene


func before_each() -> void:
	scene = MenuScene.new()
	add_child_autofree(scene)
	scene.build()


func test_builds_from_data() -> void:
	assert_eq(scene.cultists.size(), 6)
	for c: HumanRig in scene.cultists:
		assert_eq(c.current_animation(), "pray")
	assert_not_null(scene.find_child("altar_sun", true, false))
	assert_gte(scene.lights.size(), 1)


func test_shots_move_the_camera() -> void:
	scene.set_shot("select", true)
	var select := scene.camera.global_position
	assert_almost_eq(select, Vector3(-0.35, 1.45, 7.8), Vector3.ONE * 0.01)
	scene.set_shot("create", true)
	assert_ne(scene.camera.global_position, select)
	scene.set_shot("title", true)
	scene._process(1.0)
	var r := Vector2(scene.camera.global_position.x, scene.camera.global_position.z).length()
	assert_almost_eq(r, 9.0, 0.05, "orbiting the altar")


func test_shot_change_is_smooth() -> void:
	scene.set_shot("select", true)
	var start := scene.camera.global_position
	scene.set_shot("create")
	scene._process(0.1)
	var mid := scene.camera.global_position
	assert_ne(mid, start)
	assert_gt(mid.distance_to(Vector3(-1.5, 1.3, 8.4)), 0.05, "not there yet")
	scene._process(2.0)
	assert_almost_eq(scene.camera.global_position, Vector3(-1.5, 1.3, 8.4), Vector3.ONE * 0.01)


func test_show_character_replaces_hero() -> void:
	var look := CharacterCatalog.load_default().resolve("villager", {"race": "dwarf"})
	scene.show_character(look)
	var second := scene.show_character(look)
	assert_eq(scene.hero, second)
	assert_eq(scene.find_children("*", "HumanRig", true, false).size(), 7, "6 cultists and one hero")
	assert_almost_eq(second.position, Vector3(0, 0, 3.8), Vector3.ONE * 0.01)
	assert_null(scene.show_character({}))
	assert_null(scene.hero)


func test_turn_hero() -> void:
	scene.show_character(CharacterCatalog.load_default().resolve("villager", {}))
	var before := scene.hero.rotation_degrees.y
	scene.turn_hero(30.0)
	assert_almost_eq(scene.hero.rotation_degrees.y, before + 30.0, 0.01)


## Dragging the hero round and then changing the hair must not turn it back to the front.
func test_new_look_keeps_the_turn() -> void:
	var catalog := CharacterCatalog.load_default()
	scene.show_character(catalog.resolve("villager", {}))
	scene.turn_hero(120.0)
	var turned := scene.hero.rotation.y
	scene.show_character(catalog.resolve("villager", {"hair_style": "hair_long"}))
	assert_almost_eq(scene.hero.rotation.y, turned, 0.001)
