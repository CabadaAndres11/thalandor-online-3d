extends GutTest
## Task 14: three clients in memory see the same health for everyone (players and a
## monster) after a fight, including a player going down and being revived.

const NAMES := ["Ana", "Bea", "Cris"]


func test_combat_group_three_clients_see_same_hp() -> void:
	var h := NetHarness.new(60, 10, 0.02, 4)
	for n: String in NAMES:
		h.add_client(n)
	h.run_ticks(30)
	var w := h.host.world
	var wolf := MonsterDB.load_default().make("wolf", w.next_monster_id(), Vector3(30, 0, 30), w)
	w.add_entity(wolf)
	Damage.apply(wolf, {"amount": 17.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	var bea: PlayerState = w.players[h.id_of("Bea")]
	Damage.apply(bea, {"amount": 33.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	var cris: PlayerState = w.players[h.id_of("Cris")]
	Damage.apply(cris, {"amount": 99999.0, "crit": false, "dodged": false, "absorbed": 0.0}, w)
	assert_eq(cris.life, CombatEntity.DOWNED)
	h.run_ticks(30)
	for viewer: String in NAMES:
		var c: ClientSession = h.clients[viewer]
		for n: String in NAMES:
			var id := h.id_of(n)
			var p: PlayerState = w.players[id]
			assert_almost_eq(float(c.combat[id].hp), p.hp, 0.01, "%s sees %s's health" % [viewer, n])
			assert_eq(int(c.combat[id].life), p.life, "%s sees %s's state" % [viewer, n])
		assert_almost_eq(float(c.monsters[wolf.id].hp), wolf.hp, 0.01, "%s sees the wolf" % viewer)
