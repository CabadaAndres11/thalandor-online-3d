extends GutTest
## Quest engine additions for the prologue (Plan 8.3a): hit, dodge and class objectives,
## quests with their own story moment, and quests that hand over normal items.

const QUESTS := "res://tests/data/quests/"

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new()
	f.world.quests = QuestDB.load_dir(QUESTS)


func _hero(class_id := "warrior") -> PlayerState:
	var p := f.world.add_player(1, Vector3(5.5, 0, 5.5))
	p.progress.level = 5
	ClassRules.setup_player(p, class_id, null, f.world)
	return p


func _wolf() -> MonsterState:
	var m := MonsterDB.load_default().make("hunter_wolf", f.world.next_monster_id(), Vector3(6.5, 0, 5.5), f.world, 3)
	m.stats.max_hp = 100000.0
	m.hp = 100000.0
	f.world.add_entity(m)
	return m


func _counts(p: PlayerState) -> Array:
	return p.quests.active.q_train.counts


func test_hit_counts_only_that_monster_and_attack() -> void:
	var p := _hero()
	QuestRules.start(f.world, p, "q_train")
	var w := _wolf()
	QuestRules.on_hit(f.world, p, w, "basic")
	assert_eq(_counts(p), [1, 0, 0])
	QuestRules.on_hit(f.world, p, w, "secondary")
	assert_eq(_counts(p), [1, 1, 0])
	var hound := MonsterDB.load_default().make("marked_hound", f.world.next_monster_id(), Vector3(6.5, 0, 5.5), f.world, 3)
	f.world.add_entity(hound)
	QuestRules.on_hit(f.world, p, hound, "basic")
	assert_eq(_counts(p), [1, 1, 0], "another monster does not count")


func test_hits_from_real_casts() -> void:
	f.world.abilities = AbilityDB.load_default()
	var p := _hero("villager")
	p.level = 5
	p.stats.crit_chance = 0.0
	QuestRules.start(f.world, p, "q_train")
	var w := _wolf()
	w.stats.dodge_chance = 0.0
	p.facing = PI / 2.0
	assert_true(Combat.try_cast(f.world, p, f.world.abilities.kind_of("villager", "basic"), w.position))
	f.run(1.0)
	assert_eq(int(_counts(p)[0]), 1, "a basic attack that lands counts")


func test_dodge_counts() -> void:
	var p := _hero()
	QuestRules.start(f.world, p, "q_train")
	for i in 3:
		QuestRules.on_dodge(f.world, p)
	assert_eq(int(_counts(p)[2]), 3)


func test_dodge_from_movement() -> void:
	var p := _hero()
	QuestRules.start(f.world, p, "q_train")
	var inp := PlayerInput.new(1, Vector2(1, 0), Vector3.ZERO, PlayerInput.BTN_DODGE)
	f.world.step({1: inp})
	assert_eq(int(_counts(p)[2]), 1)


func test_class_objective() -> void:
	var p := _hero("villager")
	QuestRules.start(f.world, p, "q_train")
	assert_false(QuestRules.allows_class_choice(f.world, p))
	QuestRules.force_start(f.world, p, "q_train")
	p.quests.active.q_train = {"step": 1, "counts": [0]}
	assert_true(QuestRules.allows_class_choice(f.world, p))
	ClassRules.setup_player(p, "mage", null, f.world)
	QuestRules.on_class_chosen(f.world, p)
	assert_eq(int(p.quests.active.q_train.step), 2)
	assert_false(QuestRules.allows_class_choice(f.world, p))


func test_class_objective_done_if_already_classed() -> void:
	var p := _hero("warrior")
	QuestRules.start(f.world, p, "q_train")
	p.quests.active.q_train = {"step": 1, "counts": [0]}
	QuestRules.complete_step(f.world, p, "q_train")
	assert_eq(int(p.quests.active.q_train.step), 2)


func test_quest_moment_from_start() -> void:
	var p := _hero()
	QuestRules.start(f.world, p, "q_mom")
	var moments := f.world.events.filter(func(e: Array) -> bool: return e[0] == "quest_moment")
	assert_eq(moments, [["quest_moment", 1, "zone_m", "noche"]])
	assert_eq(QuestRules.current_moment(f.world, p), {"zone": "zone_m", "variant": "noche"})


func test_give_normal_items() -> void:
	var p := _hero()
	QuestRules.start(f.world, p, "q_mom")
	assert_eq(p.inventory.count_of("potion_health"), 2)


func test_validate_knows_new_types() -> void:
	var db := QuestDB.load_dir(QUESTS)
	var errors := db.validate(NpcDB.load_default(), MonsterDB.load_default(), ItemDB.load_default(),
		"res://tests/data/zones/", "res://tests/data/dialogues/", "res://tests/data/cutscenes/")
	assert_false("\n".join(errors).contains("q_train: tipo"), "\n".join(errors))


func test_variant_walkers() -> void:
	var z := ZoneLayout.from_dict("t", {"size": [20, 20], "walkers": [{"npc": "brann", "route": [[1, 1], [5, 1]]}],
		"variants": {"v": {"walkers": [{"npc": "merchant", "route": [[2, 2], [3, 3]]}]}}})
	assert_eq(z.apply_variant("v").walkers.size(), 1)
	assert_eq(str(z.apply_variant("v").walkers[0].npc), "merchant")
