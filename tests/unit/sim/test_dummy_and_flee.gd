extends GutTest
## The training dummy (never dies, never fights back) and a boss that flees at 10 % of its
## health (Plan 8.3a): it counts as defeated for quests and experience, without loot.

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(40, 40))
	f.world.quests = QuestDB.load_dir("res://tests/data/quests/")


func _hero() -> PlayerState:
	var p := f.world.add_player(1, Vector3(10.5, 0, 10.5))
	p.progress.level = 3
	ClassRules.setup_player(p, "warrior", null, f.world)
	return p


func _spawn(type: String) -> MonsterState:
	var m := MonsterDB.load_default().make(type, f.world.next_monster_id(), Vector3(11.5, 0, 10.5), f.world, 2)
	f.world.add_entity(m)
	return m


func _hurt(m: MonsterState, amount: float, src: PlayerState) -> void:
	f.world.current_source = src.id
	Damage.apply(m, {"amount": amount, "crit": false, "dodged": false, "absorbed": 0.0}, f.world)


func _step(seconds: float) -> void:
	for i in f.world.ticks(seconds):
		f.world.step({})


func test_dummy_never_dies_and_refills() -> void:
	var p := _hero()
	var d := _spawn("training_dummy")
	_hurt(d, 10000.0, p)
	assert_eq(d.hp, 1.0)
	assert_true(d.is_alive())
	_step(3.1)
	assert_eq(d.hp, d.stats.max_hp)


func test_dummy_is_harmless() -> void:
	var p := _hero()
	var d := _spawn("training_dummy")
	var hp := p.hp
	_hurt(d, 5.0, p)
	_step(5.0)
	assert_eq(p.hp, hp)
	assert_eq(d.position, Vector3(11.5, 0, 10.5), "it does not move")
	assert_eq(f.world.events.filter(func(e: Array) -> bool: return e[0] == "died").size(), 0)


func test_dummy_gives_nothing() -> void:
	var p := _hero()
	var d := _spawn("training_dummy")
	var xp := p.progress.xp
	_hurt(d, 10000.0, p)
	assert_eq(p.progress.xp, xp)
	assert_true(f.world.loot.is_empty())


func test_flee_at_ten_percent() -> void:
	var p := _hero()
	var q := QuestDB.load_dir("res://tests/data/quests/")
	q.add({"id": "q_her", "giver": "", "steps": [{"objectives": [{"type": "kill", "monster": "heraldo", "count": 1}]},
		{"objectives": [{"type": "scene", "scene": "x"}]}]})
	f.world.quests = q
	QuestRules.start(f.world, p, "q_her")
	var h := _spawn("heraldo")
	var xp := p.progress.xp
	_hurt(h, h.stats.max_hp * 0.5, p)
	assert_false(h.fled)
	_hurt(h, h.stats.max_hp * 0.45, p)
	assert_true(h.fled, "below 10 %")
	assert_gt(h.hp, 0.0)
	assert_eq(f.world.events.filter(func(e: Array) -> bool: return e[0] == "fled").size(), 1)
	assert_eq(int(p.quests.active.q_her.step), 1, "it counts as defeated")
	assert_gt(p.progress.xp, xp, "experience")
	assert_true(f.world.loot.is_empty(), "no loot")
	var hp := h.hp
	_hurt(h, 1000.0, p)
	assert_eq(h.hp, hp, "it cannot be hurt any more")
	_step(3.1)
	assert_null(f.world.entity(h.id), "gone after 3 s")


func test_overkill_still_flees() -> void:
	var p := _hero()
	var h := _spawn("heraldo")
	_hurt(h, h.stats.max_hp * 5.0, p)
	assert_true(h.fled)
	assert_true(h.is_alive())
	assert_eq(f.world.events.filter(func(e: Array) -> bool: return e[0] == "died").size(), 0)


func test_heraldo_is_a_lesser_acolyte() -> void:
	var a := MonsterDB.load_default().get_type("cult_acolyte")
	var h := MonsterDB.load_default().get_type("heraldo")
	assert_eq(float(h.stats.max_hp), float(a.stats.max_hp) / 4.0)
	assert_false(h.has("summon"))
	assert_eq(float(h.flee_at), 0.1)
