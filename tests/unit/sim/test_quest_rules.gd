extends GutTest
## QuestRules (Plan 8.2): the host advances quests with what happens in the simulation and
## with the requests it validated.

const QUESTS := "res://tests/data/quests/"

var f: CombatFixture
var db: ItemDB


func before_each() -> void:
	f = CombatFixture.new()
	f.world.quests = QuestDB.load_dir(QUESTS)
	f.world.map.npcs = [{"id": "brann", "at": [3, 3], "facing": 0}, {"id": "merchant", "at": [8, 3], "facing": 0}]
	f.world.map.quest_points = {"claro": {"at": Vector2i(20, 20), "radius": 2.0, "look": ""}}
	db = f.world.items


func _hero(id: int, pos: Vector3, level := 5, class_id := "warrior") -> PlayerState:
	var p := f.world.add_player(id, pos)
	p.progress.level = level
	ClassRules.setup_player(p, class_id, null, f.world)
	return p


func _wolf(pos: Vector3) -> MonsterState:
	var m := MonsterDB.load_default().make("hunter_wolf", f.world.next_monster_id(), pos, f.world, 3)
	f.world.add_entity(m)
	return m


func _kill(m: MonsterState) -> void:
	m.hp = 0.0
	f.world.on_zero_hp(m)


## Walks over every drop of this player (quest items fall to the ground, Plan 8.3c).
func _pick(p: PlayerState) -> void:
	for id: int in f.world.loot.keys():
		if f.world.loot.has(id) and int(f.world.loot[id].owner) == p.id:
			p.position = f.world.loot[id].pos
			Loot.step(f.world)


func _counts(p: PlayerState, id: String) -> Array:
	return p.quests.active[id].counts


func _events(type: String) -> Array:
	return f.world.events.filter(func(e: Array) -> bool: return e[0] == type)


func test_requirements() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	assert_false(QuestRules.can_start(f.world, p, "q_req"), "q_one not done")
	p.quests.done.append("q_one")
	p.quests.flags.append("visto")
	assert_true(QuestRules.can_start(f.world, p, "q_req"))
	p.progress.level = 4
	assert_false(QuestRules.can_start(f.world, p, "q_req"), "level")
	p.progress.level = 5
	p.quests.flags.append("malo")
	assert_false(QuestRules.can_start(f.world, p, "q_req"), "forbidden flag")
	var mage := _hero(2, Vector3(3.5, 0, 4.5), 5, "mage")
	mage.quests.done.append("q_one")
	mage.quests.flags.append("visto")
	assert_false(QuestRules.can_start(f.world, mage, "q_req"), "class")
	assert_false(QuestRules.can_start(f.world, p, "nope"))


func test_start_marks_dirty_and_tracks() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	assert_true(QuestRules.start(f.world, p, "q_one"))
	assert_true(p.quests_dirty)
	assert_eq(p.quests.tracked, "q_one")
	assert_eq(_counts(p, "q_one"), [0])
	assert_false(QuestRules.start(f.world, p, "q_one"), "already active")


func test_steps_in_order() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_one")
	assert_false(QuestRules.report(f.world, p, "talk", "brann", "d_test"), "the talk is step 1")
	assert_eq(int(p.quests.active.q_one.step), 0)


func test_kill_shared_nearby() -> void:
	var a := _hero(1, Vector3(5.5, 0, 5.5))
	var b := _hero(2, Vector3(9.5, 0, 5.5))
	var c := _hero(3, Vector3(5.5, 0, 48.5))
	var d := _hero(4, Vector3(6.5, 0, 6.5))
	for p: PlayerState in [a, b, c]:
		QuestRules.start(f.world, p, "q_one")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	assert_eq(_counts(a, "q_one"), [1])
	assert_eq(_counts(b, "q_one"), [1])
	assert_eq(_counts(c, "q_one"), [0], "too far (more than share_range)")
	assert_false(d.quests.is_active("q_one"))


func test_kill_finishes_step() -> void:
	var p := _hero(1, Vector3(5.5, 0, 5.5))
	QuestRules.start(f.world, p, "q_one")
	for i in 3:
		_kill(_wolf(Vector3(6.5, 0, 5.5)))
	assert_eq(int(p.quests.active.q_one.step), 1)
	assert_eq(_counts(p, "q_one"), [0])
	assert_eq(_events("quest_step").size(), 1)


func test_collect_rolls_per_player() -> void:
	var a := _hero(1, Vector3(5.5, 0, 5.5))
	var b := _hero(2, Vector3(7.5, 0, 5.5))
	QuestRules.start(f.world, a, "q_collect")
	QuestRules.start(f.world, b, "q_nochance")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	assert_eq(a.inventory.count_of("q_colmillo"), 0, "it falls to the ground first (Plan 8.3c)")
	assert_eq(Loot.on_ground(f.world, a.id, "q_colmillo"), 1)
	_pick(a)
	assert_eq(a.inventory.count_of("q_colmillo"), 1)
	assert_eq(_counts(a, "q_collect"), [1], "picked up, it counts")
	assert_eq(Loot.on_ground(f.world, b.id, "q_colmillo"), 0, "chance 0")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	assert_eq(Loot.on_ground(f.world, a.id, "q_colmillo"), 1, "no more than the objective needs, counting the ground")
	_pick(a)
	assert_eq(a.inventory.count_of("q_colmillo"), 2)
	assert_eq(int(a.quests.active.q_collect.step), 1, "ready to turn in")


func test_collect_full_bag() -> void:
	var p := _hero(1, Vector3(5.5, 0, 5.5))
	for i in Inventory.SIZE:
		p.inventory.bag[i] = ItemRoll.new_item("warrior_chest_t1", 1)
	QuestRules.start(f.world, p, "q_collect")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	_pick(p)
	assert_eq(_counts(p, "q_collect"), [0])
	assert_eq(_events("bag_full").size(), 1, "it stays on the ground with the bag full")


func test_reach_group() -> void:
	var a := _hero(1, Vector3(20.5, 0, 20.5))
	var b := _hero(2, Vector3(28.5, 0, 20.5))
	var c := _hero(3, Vector3(21.5, 0, 20.5))
	QuestRules.start(f.world, a, "q_reach")
	QuestRules.start(f.world, b, "q_reach")
	QuestRules.step_reach(f.world)
	assert_eq(int(a.quests.active.q_reach.step), 1)
	assert_eq(int(b.quests.active.q_reach.step), 1, "near a partner who reached it")
	assert_false(c.quests.is_active("q_reach"))


func test_interact_needs_range() -> void:
	var p := _hero(1, Vector3(20.5, 0, 20.5))
	QuestRules.start(f.world, p, "q_reach")
	QuestRules.step_reach(f.world)
	p.position = Vector3(26.5, 0, 20.5)
	assert_false(QuestRules.report(f.world, p, "interact", "claro"))
	p.position = Vector3(21.5, 0, 20.5)
	assert_true(QuestRules.report(f.world, p, "interact", "claro"))
	assert_eq(int(p.quests.active.q_reach.step), 2)


func test_talk_needs_range() -> void:
	var p := _hero(1, Vector3(5.5, 0, 5.5))
	QuestRules.start(f.world, p, "q_one")
	p.quests.active.q_one = {"step": 1, "counts": [0]}
	p.position = Vector3(3.5, 0, 8.5)
	assert_false(QuestRules.report(f.world, p, "talk", "brann", "d_test"), "5 m away")
	p.position = Vector3(3.5, 0, 5.0)
	assert_false(QuestRules.report(f.world, p, "talk", "brann", "otro"), "another dialogue")
	assert_true(QuestRules.report(f.world, p, "talk", "brann", "d_test"))


func test_deliver_takes_item() -> void:
	var p := _hero(1, Vector3(8.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_deliver")
	assert_false(QuestRules.report(f.world, p, "talk", "merchant"), "no parcel")
	p.inventory.add(ItemRoll.new_item("q_paquete", 1), db)
	assert_true(QuestRules.report(f.world, p, "talk", "merchant"))
	assert_eq(p.inventory.count_of("q_paquete"), 0)
	assert_true(p.quests.is_done("q_deliver"), "no turn_in NPC: done at once")


func test_on_done_effects() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	p.quests.flags.append("antes")
	QuestRules.start(f.world, p, "q_effects")
	QuestRules.report(f.world, p, "scene", "s1")
	assert_eq(_events("quest_scene")[0], ["quest_scene", 1, "s2"])
	assert_eq(_events("quest_moment")[0], ["quest_moment", 1, "aldea", "asalto"])
	QuestRules.report(f.world, p, "scene", "s3")
	assert_eq(_events("quest_moment")[1], ["quest_moment", 1, "", ""], "moment null: back to the world")
	assert_true(p.quests.is_done("q_effects"))
	assert_true(p.quests.has_flag("hecho"))
	assert_false(p.quests.has_flag("antes"))
	assert_true("tutorial_done" in p.quests.marks)
	assert_true(p.quests.is_active("q_next"), "next starts at once")


func test_reward_xp() -> void:
	var b := f.world.balance
	assert_eq(QuestRules.reward_xp(3, 1, b), Xp.to_next(3, b))
	assert_eq(QuestRules.reward_xp(3, 2, b), Xp.to_next(3, b) + Xp.to_next(4, b))
	assert_eq(QuestRules.reward_xp(3, 0, b), 0)


func test_reward_levels() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5), 3)
	var forty := roundi(Xp.to_next(3, f.world.balance) * 0.4)
	p.progress.xp = forty
	QuestRules.start(f.world, p, "q_reward")
	QuestRules.set_flag(f.world, p, "si")
	var gold := p.inventory.gold
	assert_true(QuestRules.turn_in(f.world, p, "q_reward", "sword_t1"))
	assert_eq(p.progress.level, 4)
	assert_eq(p.progress.xp, forty, "the experience over is kept")
	assert_eq(p.inventory.gold, gold + 30)
	assert_eq(p.inventory.count_of("potion_health"), 1)
	assert_eq(p.inventory.count_of("sword_t1"), 1)
	assert_true(p.quests.is_done("q_reward"))


func test_turn_in_bag_full() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_reward")
	QuestRules.set_flag(f.world, p, "no")
	for i in Inventory.SIZE:
		p.inventory.bag[i] = ItemRoll.new_item("warrior_chest_t1", 1)
	var gold := p.inventory.gold
	assert_false(QuestRules.turn_in(f.world, p, "q_reward", "sword_t1"))
	assert_true(p.quests.is_active("q_reward"))
	assert_eq(p.inventory.gold, gold)
	assert_eq(_events("quest_bag_full").size(), 1)


func test_turn_in_checks() -> void:
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_reward")
	assert_false(QuestRules.turn_in(f.world, p, "q_reward", "sword_t1"), "not finished")
	QuestRules.set_flag(f.world, p, "si")
	assert_false(QuestRules.turn_in(f.world, p, "q_reward", "ring_t1"), "choice not offered")
	assert_false(QuestRules.turn_in(f.world, p, "q_reward", ""), "a choice is required")
	p.position = Vector3(15.5, 0, 15.5)
	assert_false(QuestRules.turn_in(f.world, p, "q_reward", "sword_t1"), "far from the NPC")


func test_auto_start() -> void:
	var p := _hero(1, Vector3(8.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_deliver")
	p.inventory.add(ItemRoll.new_item("q_paquete", 1), db)
	QuestRules.report(f.world, p, "talk", "merchant")
	assert_true(p.quests.is_active("q_auto"))


func test_abandon() -> void:
	var p := _hero(1, Vector3(5.5, 0, 5.5))
	QuestRules.start(f.world, p, "q_collect")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	assert_true(QuestRules.abandon(f.world, p, "q_collect"))
	assert_false(p.quests.is_active("q_collect"))
	assert_eq(p.inventory.count_of("q_colmillo"), 0, "its quest items go away")
	QuestRules.start(f.world, p, "q_one")
	assert_false(QuestRules.abandon(f.world, p, "q_one"), "story quests cannot be abandoned")


func test_cost_free() -> void:
	_hero(1, Vector3(20.5, 0, 20.5))
	QuestRules.reach_checks = 0
	QuestRules.step_reach(f.world)
	assert_eq(QuestRules.reach_checks, 0)


func test_reach_runs_in_world_step() -> void:
	var p := _hero(1, Vector3(20.5, 0, 20.5))
	QuestRules.start(f.world, p, "q_reach")
	for i in f.world.ticks(1.0):
		f.world.step({})
	assert_eq(int(p.quests.active.q_reach.step), 1)


func test_give_on_start_and_reward_without_turn_in() -> void:
	var p := _hero(1, Vector3(8.5, 0, 4.5))
	var gold := p.inventory.gold
	QuestRules.start(f.world, p, "q_give")
	assert_eq(p.inventory.count_of("q_paquete"), 1, "the quest hands its parcel over")
	assert_true(QuestRules.report(f.world, p, "talk", "merchant"))
	assert_true(p.quests.is_done("q_give"))
	assert_eq(p.inventory.gold, gold + 25, "rewards come even with nobody to hand it in to")
	assert_eq(p.inventory.count_of("q_paquete"), 0)


func test_step_gives_items() -> void:
	var q := QuestDB.load_dir(QUESTS)
	q.add({"id": "q_stepgive", "giver": "brann", "turn_in": "", "steps": [
		{"objectives": [{"type": "scene", "scene": "a"}], "on_done": {"give": [["q_paquete", 2]]}},
		{"objectives": [{"type": "scene", "scene": "b"}]}]})
	f.world.quests = q
	var p := _hero(1, Vector3(3.5, 0, 4.5))
	QuestRules.start(f.world, p, "q_stepgive")
	assert_eq(p.inventory.count_of("q_paquete"), 0)
	QuestRules.report(f.world, p, "scene", "a")
	assert_eq(p.inventory.count_of("q_paquete"), 2)


func test_kill_and_collect_from_the_same_monster() -> void:
	var p := _hero(1, Vector3(5.5, 0, 5.5))
	var q := QuestDB.load_dir(QUESTS)
	q.add({"id": "q_both", "giver": "brann", "steps": [{"objectives": [
		{"type": "kill", "monster": "hunter_wolf", "count": 2},
		{"type": "collect", "item": "q_colmillo", "from": "hunter_wolf", "chance": 1.0, "count": 2}]}]})
	f.world.quests = q
	QuestRules.start(f.world, p, "q_both")
	_kill(_wolf(Vector3(6.5, 0, 5.5)))
	_pick(p)
	assert_eq(_counts(p, "q_both"), [1, 1], "one wolf counts for both objectives")
