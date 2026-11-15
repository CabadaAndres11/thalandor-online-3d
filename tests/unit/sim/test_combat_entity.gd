extends GutTest


func test_stats_from_dict_with_defaults() -> void:
	var s := CombatStats.from_dict({"max_hp": 150, "armor": 40})
	assert_eq(s.max_hp, 150.0)
	assert_eq(s.armor, 40.0)
	assert_eq(s.crit_chance, 0.05, "5 % base crit")
	assert_eq(s.move_speed_mult, 1.0)
	assert_eq(s.damage_taken_mult, 1.0)


func test_player_state_is_a_combat_entity() -> void:
	var p := PlayerState.new()
	assert_true(p is CombatEntity)
	assert_eq(p.team, CombatEntity.TEAM_PLAYERS)
	assert_eq(p.radius, 0.4)


func test_player_state_clone_copies_only_predicted_fields() -> void:
	var p := PlayerState.new()
	p.id = 3
	p.position = Vector3(1, 0, 2)
	p.aim = Vector3(4, 0, 4)
	p.facing = 1.0
	p.hp = 55.0
	p.resource = 20.0
	var c := p.clone()
	assert_eq([c.id, c.position, c.aim, c.facing], [3, Vector3(1, 0, 2), Vector3(4, 0, 4), 1.0])
	assert_eq(c.hp, 0.0, "combat values are not predicted")


func test_world_finds_entities_by_id() -> void:
	var w := SimWorld.new(Balance.load_from(), CollisionMap.from_layout({"size": [10, 10], "spawn": [1, 1], "blocks": []}))
	var p := w.add_player(2, Vector3(1, 0, 1))
	assert_eq(w.entity(2), p)
	assert_null(w.entity(99))
	assert_eq(w.entities(), [p])
