extends GutTest
## Progress over the network: HELLO carries it (sanitized), the host sends PROGRESS only
## to its owner, validates every request, spreads level-ups, and the arena level is the
## host player's call next to the trainer.

const VERSION := "0.1.0"

var balance: Balance
var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func _start(brann_at := [22, 20]) -> void:
	balance = Balance.load_from()
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": brann_at, "facing": 0}]})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(balance, map, VERSION)
	host.add_transport(host_t)


func before_each() -> void:
	_start()


func _guest(name: String, progress := {}, class_id := "warrior", bar := []) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, class_id, {}, bar, progress), true)
	host.tick()
	return c


func _msgs(c: MemoryTransport, type: int) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == type:
			out.append(m)
	return out


func _send(c: MemoryTransport, data: PackedByteArray) -> void:
	c.send(Transport.HOST_PEER, data, true)
	host.tick()


func _kill_cultist(at := Vector3(21, 0, 21)) -> void:
	var m := MonsterDB.load_default().make("cultist", host.world.next_monster_id(), at, host.world)
	host.world.add_entity(m)
	m.hp = 0.0
	host.world.on_zero_hp(m)


func test_hello_progress_sanitized_and_echoed() -> void:
	var a := _guest("Ana", {"level": 5, "xp": 10, "attributes": {"strength": 999}, "talents": ["r3_0"]})
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(got.size(), 1)
	var pr := PlayerProgress.from_dict(got[0].progress)
	assert_eq(pr.level, 5)
	assert_eq(pr.xp, 10)
	assert_eq(pr.attributes.strength, 0, "more points than the level gives")
	assert_eq(pr.talents, [], "orphan node")
	assert_eq(host.world.players[1].progress.level, 5)
	assert_eq(host.world.players[1].level, 5)


func test_garbage_progress_still_enters() -> void:
	var a := _guest("Ana", {"level": "lots", "attributes": [1], "talents": 7, "upgrade": 3})
	assert_eq(host.player_count(), 1)
	assert_eq(host.world.players[1].progress.level, 1)
	assert_eq(_msgs(a, Protocol.Msg.PROGRESS).size(), 1)


func test_huge_progress_is_clamped() -> void:
	_guest("Ana", {"level": 1e15, "xp": -3, "attributes": {"agility": 1e15}})
	assert_eq(host.world.players[1].progress.level, 65535)
	assert_eq(host.world.players[1].progress.xp, 0)


func test_protocol5_hello_is_answered_with_version() -> void:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.pack([Protocol.Msg.HELLO, VERSION, 5, "Ana", "warrior", {}, []]), true)
	host.tick()
	var r := _msgs(c, Protocol.Msg.REJECT)
	assert_eq(r.size(), 1)
	assert_eq(r[0].reason, "version")


func test_progress_only_to_owner() -> void:
	var a := _guest("Ana", {"level": 3})
	var b := _guest("Bea", {"level": 4})
	_msgs(a, Protocol.Msg.PROGRESS)
	_msgs(b, Protocol.Msg.PROGRESS)
	_kill_cultist()
	host.tick()
	var pa := _msgs(a, Protocol.Msg.PROGRESS)
	var pb := _msgs(b, Protocol.Msg.PROGRESS)
	assert_eq(pa.size(), 1)
	assert_eq(pb.size(), 1)
	assert_eq(PlayerProgress.from_dict(pa[0].progress).level, 3)
	assert_eq(PlayerProgress.from_dict(pb[0].progress).level, 4)


func test_progress_message_is_the_receivers_own() -> void:
	var a := _guest("Ana", {"level": 3})
	var b := _guest("Bea", {"level": 8})
	var pa := _msgs(a, Protocol.Msg.PROGRESS)
	var pb := _msgs(b, Protocol.Msg.PROGRESS)
	assert_eq(PlayerProgress.from_dict(pa[0].progress).level, 3)
	assert_eq(PlayerProgress.from_dict(pb[0].progress).level, 8)
	assert_eq(pa.size(), 1, "Ana never got Bea's")


func test_spend_attribute_roundtrip() -> void:
	var a := _guest("Ana", {"level": 5})
	_msgs(a, Protocol.Msg.PROGRESS)
	_send(a, Protocol.spend_attribute("stamina"))
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(got.size(), 1)
	assert_eq(PlayerProgress.from_dict(got[0].progress).attributes.stamina, 1)
	assert_eq(host.world.players[1].progress.attributes.stamina, 1)
	assert_gt(host.world.players[1].stats.max_hp, 200.0)


func test_buy_talent_and_mastery_roundtrip() -> void:
	var db := TalentDB.load_default()
	var might: Array = [] # every might node, each next to the start or an earlier one
	var have := {db.start_id(): true}
	var grew := true
	while grew:
		grew = false
		for id: String in db.ids():
			if not have.has(id) and str(db.node(id).dir) == "might" and (db.node(id).links as Array).any(func(n: String) -> bool: return have.has(n)):
				have[id] = true
				might.append(id)
				grew = true
	var a := _guest("Ana", {"level": might.size() + 2})
	_msgs(a, Protocol.Msg.PROGRESS)
	for id: String in might:
		_send(a, Protocol.buy_talent(id))
	_send(a, Protocol.buy_mastery("might"))
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	var pr := PlayerProgress.from_dict(got[got.size() - 1].progress)
	assert_eq(pr.talents.size(), might.size())
	assert_eq(pr.masteries.get("might", 0), 1)


func test_buy_talent_rejected_keeps_state() -> void:
	var a := _guest("Ana", {"level": 5})
	_msgs(a, Protocol.Msg.PROGRESS)
	_send(a, Protocol.buy_talent("r3_0"))
	_send(a, Protocol.spend_attribute("luck"))
	_send(a, Protocol.buy_mastery("might"))
	assert_eq(_msgs(a, Protocol.Msg.PROGRESS).size(), 0)
	assert_eq(host.world.players[1].progress.talents, [])


func test_no_resets_without_a_trainer() -> void:
	var a := _guest("Ana", {"level": 5, "attributes": {"strength": 4}})
	_msgs(a, Protocol.Msg.PROGRESS)
	_send(a, Protocol.reset("attributes"))
	assert_eq(host.world.players[1].progress.attributes.strength, 4, "Brann no longer trains; resets come with the capital (Plan 8.3b)")


func test_level_up_reaches_everyone() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_msgs(a, Protocol.Msg.EVENTS)
	_msgs(b, Protocol.Msg.EVENTS)
	_send(a, Protocol.chat(0, "/xp 100")) # the first player is the host: a level-up inside the tick
	for c: MemoryTransport in [a, b]:
		var evs := []
		for m: Dictionary in _msgs(c, Protocol.Msg.EVENTS):
			evs.append_array(m.events)
		assert_true(evs.any(func(e: Array) -> bool: return e == ["level_up", 1, 2]), "everyone hears Ana level up")


func test_xp_progress_throttled() -> void:
	var a := _guest("Ana")
	_msgs(a, Protocol.Msg.PROGRESS)
	for i in 10:
		_kill_cultist()
		host.tick()
	assert_lte(_msgs(a, Protocol.Msg.PROGRESS).size(), 2, "10 kills in a third of a second")
	for i in 40:
		host.tick()
	var late := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(late.size(), 1, "the pending experience arrives after a second")
	assert_eq(PlayerProgress.from_dict(late[0].progress).xp, host.world.players[1].progress.xp)


func test_level_up_is_sent_at_once() -> void:
	var a := _guest("Ana")
	_msgs(a, Protocol.Msg.PROGRESS)
	_kill_cultist()
	host.tick()
	_msgs(a, Protocol.Msg.PROGRESS)
	host.world.players[1].progress.xp = 99
	_kill_cultist()
	host.tick()
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(got.size(), 1)
	assert_eq(PlayerProgress.from_dict(got[0].progress).level, 2)


func test_level_up_places_new_ability_in_bar() -> void:
	var a := _guest("Ana", {"level": 2, "xp": 0})
	var first := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(first[0].bar, ["warrior_charge", "", "", "", "", "", "", "", ""])
	host.world.players[1].progress.xp = Xp.to_next(2, balance) - 1
	_kill_cultist()
	host.tick()
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(got[0].bar, ["warrior_charge", "warrior_battle_cry", "", "", "", "", "", "", ""])
	assert_eq(host._players[1].bar, ["warrior_charge", "warrior_battle_cry", "", "", "", "", "", "", ""])


func test_arena_level_in_welcome() -> void:
	host.world.set_arena_level(5)
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, "Ana", "warrior", {}), true)
	host.tick()
	var w := _msgs(c, Protocol.Msg.WELCOME)
	assert_eq(w[0].arena_level, 5)


func test_host_player_sets_arena_level_next_to_trainer() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_msgs(a, Protocol.Msg.ARENA_LEVEL)
	_msgs(b, Protocol.Msg.ARENA_LEVEL)
	_send(a, Protocol.set_arena_level(12))
	assert_eq(host.world.arena_level, 12)
	assert_eq(_msgs(a, Protocol.Msg.ARENA_LEVEL)[0].level, 12)
	assert_eq(_msgs(b, Protocol.Msg.ARENA_LEVEL)[0].level, 12)


func test_guest_cannot_set_arena_level() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_msgs(a, Protocol.Msg.ARENA_LEVEL)
	_send(b, Protocol.set_arena_level(12))
	assert_eq(host.world.arena_level, 1)
	assert_eq(_msgs(a, Protocol.Msg.ARENA_LEVEL).size(), 0)


func test_arena_level_without_trainer() -> void:
	_start([50, 50])
	var a := _guest("Ana")
	_send(a, Protocol.set_arena_level(12))
	assert_eq(host.world.arena_level, 12, "the host sets it anywhere now (Plan 8.3a)")
