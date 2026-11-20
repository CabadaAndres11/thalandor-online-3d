extends GutTest
## The cleric's level 50 upgrades (Healer and Templar).

var f: CombatFixture


func before_each() -> void:
	f = CombatFixture.new([], Vector2i(60, 60))
	f.world.abilities = AbilityDB.load_default()
	f.world.upgrades = UpgradeDB.load_default()


func _hero(upgrade: String) -> PlayerState:
	var p := f.world.add_player(1, Vector3(10, 0, 10))
	p.progress.level = 50
	p.progress.upgrade = upgrade
	ClassRules.setup_player(p, "cleric", null, f.world)
	p.stats.crit_chance = 0.0
	p.resource = p.stats.max_resource
	p.resource_def["regen_per_s"] = 0.0
	return p


func _ally(id: int, pos: Vector3, hp := 100.0) -> PlayerState:
	var a := f.player(id, pos, 1000.0)
	a.hp = hp
	return a


func _foe(id: int, pos: Vector3) -> CombatEntity:
	var d := f.dummy(id, pos, 5000.0)
	d.stats.dodge_chance = 0.0
	return d


# --- Healer ------------------------------------------------------------------------------

func test_healing_circle() -> void:
	var p := _hero("healer")
	var inside := _ally(2, Vector3(20, 0, 10))
	var outside := _ally(3, Vector3(27, 0, 10))
	var mana := p.resource
	assert_true(Combat.try_cast(f.world, p, "cleric_healing_circle", Vector3(18, 0, 10)))
	assert_eq(p.resource, mana - 40.0)
	assert_eq(p.cooldowns["cleric_healing_circle"], f.world.tick + f.world.ticks(20.0))
	f.run(5.0)
	var pulse := (8.0 + 0.5 * p.stats.spell_power) * p.stats.healing_done_mult
	assert_almost_eq(inside.hp - 100.0, 5.0 * pulse, 0.05, "5 pulses of 8 + 0.5 x PH")
	assert_eq(outside.hp, 100.0)


func test_divine_hymn() -> void:
	var p := _hero("healer")
	var near := _ally(2, Vector3(22, 0, 10))
	var far := _ally(3, Vector3(40, 0, 10))
	var mana := p.resource
	p.passives = p.passives.filter(func(m: Dictionary) -> bool: return m.get("hook") != "heal_leaves_hot") # no echo: exact numbers
	assert_true(Combat.try_cast(f.world, p, "cleric_divine_hymn", p.position))
	assert_eq(p.resource, mana - 60.0)
	assert_eq(p.cooldowns["cleric_divine_hymn"], f.world.tick + f.world.ticks(60.0))
	assert_true(Combat.channeling(f.world, p.id))
	f.run(7.0)
	var pulse := (12.0 + 0.6 * p.stats.spell_power) * p.stats.healing_done_mult * near.stats.healing_received_mult
	assert_almost_eq(near.hp - 100.0, 6.0 * pulse, 0.05, "6 pulses")
	assert_eq(far.hp, 100.0, "beyond 15 m")


func test_divine_hymn_is_cut_by_moving() -> void:
	var p := _hero("healer")
	var near := _ally(2, Vector3(22, 0, 10))
	p.passives = p.passives.filter(func(m: Dictionary) -> bool: return m.get("hook") != "heal_leaves_hot") # no echo: exact numbers
	assert_true(Combat.try_cast(f.world, p, "cleric_divine_hymn", p.position))
	f.run(2.5)
	p.position += Vector3(1, 0, 0)
	f.run(4.0)
	var pulse := (12.0 + 0.6 * p.stats.spell_power) * p.stats.healing_done_mult * near.stats.healing_received_mult
	assert_almost_eq(near.hp - 100.0, 3.0 * pulse, 0.05, "three pulses before the move")


func test_guardian_angel() -> void:
	var p := _hero("healer")
	var h := Passives.has_hook(p, "guardian_angel")
	assert_eq([h.radius, h.hp_pct, h.cooldown_s], [20.0, 0.25, 120.0])
	var ally := _ally(2, Vector3(25, 0, 10), 100.0)
	var foe := _foe(2000, Vector3(26, 0, 10))
	Combat.deal(f.world, foe, ally, {"damage": {"base": 5000, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_true(ally.is_alive())
	assert_almost_eq(ally.hp, 250.0, 0.01)


func test_greater_grace() -> void:
	var healer := _hero("healer")
	var done := healer.stats.healing_done_mult
	f.world.players.clear()
	var templar := _hero("templar")
	assert_almost_eq(done - templar.stats.healing_done_mult, 0.2, 0.001)


func test_heal_evolution_bounces() -> void:
	var p := _hero("healer")
	var healed := _ally(2, Vector3(12, 0, 10))
	var second := _ally(3, Vector3(18, 0, 10), 50.0)
	assert_true(Combat.try_cast(f.world, p, "cleric_heal", healed.position))
	var amount := (25.0 + 1.0 * p.stats.spell_power) * p.stats.healing_done_mult * healed.stats.healing_received_mult
	assert_almost_eq(healed.hp, 100.0 + amount, 0.05)
	assert_almost_eq(second.hp, 50.0 + amount * 0.5, 0.05, "half to a second ally within 10 m")
	f.world.players.clear()
	var plain := _hero("templar")
	var a := _ally(2, Vector3(12, 0, 10))
	var b := _ally(3, Vector3(18, 0, 10), 50.0)
	assert_true(Combat.try_cast(f.world, plain, "cleric_heal", a.position))
	assert_eq(b.hp, 50.0, "without the upgrade it does not bounce")


# --- Templar -----------------------------------------------------------------------------

func test_crusader_strike() -> void:
	var p := _hero("templar")
	var foe := _foe(2000, Vector3(10, 0, 11.5))
	p.hp = 100.0
	var mana := p.resource
	assert_true(Combat.try_cast(f.world, p, "cleric_crusader_strike", foe.position))
	var damage := 16.0 + 1.2 * p.stats.spell_power
	assert_almost_eq(5000.0 - foe.hp, damage, 0.01)
	assert_almost_eq(p.hp, 100.0 + damage * 0.3, 0.05, "30 % life steal")
	assert_eq(p.resource, mana - 15.0 + 4.0, "15 mana, 4 back from Celo")
	assert_eq(p.cooldowns["cleric_crusader_strike"], f.world.tick + f.world.ticks(4.0))


func test_consecration() -> void:
	var p := _hero("templar")
	var foe := _foe(2000, Vector3(13, 0, 10))
	var ally := _ally(2, Vector3(8, 0, 10))
	var far_foe := _foe(2001, Vector3(25, 0, 10))
	var mana := p.resource
	assert_true(Combat.try_cast(f.world, p, "cleric_consecration", p.position))
	assert_eq(p.resource, mana - 35.0)
	f.run(8.0)
	assert_almost_eq(5000.0 - foe.hp, 8.0 * (6.0 + 0.4 * p.stats.spell_power), 0.1, "8 pulses")
	var heal := (3.0 + 0.2 * p.stats.spell_power) * p.stats.healing_done_mult * ally.stats.healing_received_mult
	assert_almost_eq(ally.hp - 100.0, 8.0 * heal, 0.1)
	assert_eq(far_foe.hp, 5000.0)


func test_armor_of_faith() -> void:
	var base := _hero("healer")
	var armor := base.stats.armor
	var hp := base.stats.max_hp
	f.world.players.clear()
	var t := _hero("templar")
	assert_almost_eq(t.stats.armor, armor * 1.4, 0.01)
	assert_almost_eq(t.stats.max_hp, hp * 1.15, 0.01)


func test_zeal() -> void:
	var p := _hero("templar")
	assert_eq(Passives.has_hook(p, "melee_hit_restores").amount, 4)
	p.resource = 50.0
	Combat.deal(f.world, p, _foe(2000, Vector3(11, 0, 10)), {"type": "melee_arc", "damage": {"base": 1, "coef": 0, "kind": "magic", "can_crit": false}}, {})
	assert_eq(p.resource, 54.0)


func test_smite_evolution_is_a_melee_strike() -> void:
	var p := _hero("templar")
	var foe := _foe(2000, Vector3(10, 0, 11.5))
	var far := _foe(2001, Vector3(10, 0, 20))
	var smite := f.world.abilities.resolved("cleric_smite", "templar", f.world.upgrades)
	assert_eq(smite.anim, "melee")
	assert_eq(smite.effects[0].type, "melee_arc")
	assert_eq(smite.effects[0].range, 2.5)
	assert_eq(smite.effects[0].angle_deg, 100)
	assert_true(Combat.try_cast(f.world, p, "cleric_smite", foe.position))
	assert_almost_eq(5000.0 - foe.hp, (9.0 + 0.6 * p.stats.spell_power) * 1.15 * 0.75, 0.01, "15 % more damage, at 0.6 s instead of 0.8 s")
	assert_eq(f.world.projectiles.size(), 0)
	assert_eq(far.hp, 5000.0)
	assert_eq(f.world.abilities.get_ability("cleric_smite").effects[0].type, "projectile", "the base data stays")


# --- Look and shape -----------------------------------------------------------------------

func test_templar_wears_the_helm() -> void:
	var cat := CharacterCatalog.load_default()
	var plain := cat.resolve("cleric", {}, "")
	var templar := cat.resolve("cleric", {}, "templar")
	var ids := func(look: Dictionary) -> Array: return look.pieces.map(func(p: Dictionary) -> String: return p.id)
	assert_has(ids.call(plain), "hood_cleric")
	assert_does_not_have(ids.call(templar), "hood_cleric")
	assert_has(ids.call(templar), "helm_templar")
	assert_does_not_have(ids.call(cat.resolve("cleric", {}, "healer")), "helm_templar")
	var rig := HumanRig.create("cleric", {}, null, "templar")
	add_child_autofree(rig)
	assert_has(rig.pieces(), "helm_templar")
	var avatar := PlayerAvatar.new()
	add_child_autofree(avatar)
	avatar.setup("Ana", 0, "cleric", {}, "templar")
	assert_has(avatar.rig.pieces(), "helm_templar")
	assert_true(FileAccess.file_exists("res://assets/characters/pieces/helm_templar.vox"))


func test_the_helm_hides_the_hair() -> void:
	assert_has(CharacterCatalog.load_default().piece("helm_templar").hides, "hair")


func test_each_upgrade_is_complete_with_texts_and_icons() -> void:
	for id: String in ["healer", "templar"]:
		var u := f.world.upgrades.upgrade(id)
		assert_eq(u.actives.size(), 2)
		assert_eq(u.passives.size(), 2)
		assert_false(u.evolves.is_empty())
		for aid: String in u.actives + u.passives:
			var a := f.world.abilities.get_ability(aid)
			assert_eq(int(a.level), 50, aid)
			assert_ne(tr(str(a.name)), str(a.name), aid)
			assert_ne(tr(str(a.desc)), str(a.desc), aid)
			assert_true(ResourceLoader.exists(CombatHud.ICON_DIR % a.icon), aid)
		assert_ne(tr(str(u.evolves.desc)), str(u.evolves.desc))


func test_divine_hymn_makes_the_cleric_invulnerable_while_singing() -> void:
	var p := _hero("healer")
	var near := _ally(2, Vector3(22, 0, 10))
	assert_true(Combat.try_cast(f.world, p, "cleric_divine_hymn", p.position))
	assert_true(p.has_status("invulnerable"), "the cleric")
	assert_false(near.has_status("invulnerable"), "only the cleric")
	f.run(2.0)
	assert_true(p.has_status("invulnerable"), "the whole song")
	f.run(4.5)
	assert_false(p.has_status("invulnerable"), "gone when the song ends")


func test_moving_ends_the_hymn_invulnerability() -> void:
	var p := _hero("healer")
	assert_true(Combat.try_cast(f.world, p, "cleric_divine_hymn", p.position))
	f.run(1.5)
	f.log.clear()
	p.position += Vector3(1, 0, 0)
	f.run(0.2)
	assert_false(p.has_status("invulnerable"))
	assert_has(f.log, ["status_end", p.id, "invulnerable"])


func test_dodging_out_of_the_hymn_keeps_the_dodge_frames() -> void:
	var p := _hero("healer")
	assert_true(Combat.try_cast(f.world, p, "cleric_divine_hymn", p.position))
	f.run(1.0)
	# The dodge starts this tick: its invulnerability merges into the song's, and the move
	# cuts the channel.
	p.add_status(StatusEffect.make("invulnerable", f.world.tick + f.world.ticks(f.world.balance.dodge_invuln_s)), 1)
	p.dash_ticks = 5
	p.position += Vector3(1, 0, 0)
	f.run(1.0 / 30.0)
	assert_true(p.has_status("invulnerable"), "the dodge still protects")
	f.run(f.world.balance.dodge_invuln_s + 0.1)
	assert_false(p.has_status("invulnerable"), "only for the dodge")
