extends GutTest
## Chat commands for testing progression: /xp <n> [name] and /nivel <n> [name], only
## from the host player. They are not chat; bad ones are ignored with a system message.

const VERSION := "0.1.0"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.add_transport(host_t)


func _guest(name: String, progress := {}) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}, [], progress), true)
	host.tick()
	return c


func _say(c: MemoryTransport, text: String) -> void:
	c.send(Transport.HOST_PEER, Protocol.chat(0, text), true)
	host.tick()


func _msgs(c: MemoryTransport, type: int) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == type:
			out.append(m)
	return out


func _drain(c: MemoryTransport) -> void:
	c.poll()


func _p(id: int) -> PlayerState:
	return host.world.players[id]


func test_xp_command_host_only() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_drain(a)
	_drain(b)
	_say(b, "/xp 500")
	assert_eq(_p(2).progress.xp, 0)
	assert_eq(_p(1).progress.xp, 0)
	var sys := _msgs(b, Protocol.Msg.CHAT)
	assert_eq(sys.size(), 1, "the author is told")
	assert_eq(sys[0].from_id, 0)
	assert_eq(_msgs(a, Protocol.Msg.CHAT).size(), 0, "nobody else hears it")
	_say(a, "/xp 500")
	assert_eq(_p(1).progress.level, 3)
	assert_eq(_p(1).progress.xp, 97)


func test_command_is_not_broadcast_as_chat() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_drain(a)
	_drain(b)
	_say(a, "/xp 10")
	assert_eq(_msgs(a, Protocol.Msg.CHAT).size(), 0)
	assert_eq(_msgs(b, Protocol.Msg.CHAT).size(), 0)


func test_level_command_never_lowers() -> void:
	var a := _guest("Ana", {"level": 8})
	_say(a, "/nivel 5")
	assert_eq(_p(1).progress.level, 8)
	_say(a, "/nivel 12")
	assert_eq(_p(1).progress.level, 12)
	assert_eq(_p(1).progress.xp, 0)
	assert_eq(_p(1).level, 12)


func test_command_with_ally_name() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea Mora")
	_say(a, "/xp 500 bea mora")
	assert_eq(_p(2).progress.level, 3)
	assert_eq(_p(1).progress.level, 1)
	_say(a, "/nivel 7 Bea Mora")
	assert_eq(_p(2).progress.level, 7)
	_drain(b)
	_say(a, "/xp 5 Nadie")
	assert_eq(_msgs(a, Protocol.Msg.CHAT).size(), 1, "unknown name: told, nothing changes")


func test_bad_command_ignored() -> void:
	var a := _guest("Ana")
	_drain(a)
	for bad: String in ["/xp abc", "/xp -5", "/xp", "/xp 0", "/nivel abc", "/nivel", "/nivel -3", "/foo 3", "/"]:
		_say(a, bad)
		assert_eq(_p(1).progress.xp, 0, bad)
		assert_eq(_p(1).progress.level, 1, bad)
	assert_eq(_msgs(a, Protocol.Msg.CHAT).size(), 9, "each one answered with a system message")


func test_level_command_is_limited_to_65535() -> void:
	var a := _guest("Ana")
	_say(a, "/nivel 999999")
	assert_eq(_p(1).progress.level, 65535)
	assert_eq(_p(1).level, 65535)


func test_huge_xp_command_ends() -> void:
	var a := _guest("Ana")
	_say(a, "/xp 99999999999999")
	assert_gt(_p(1).progress.level, 100)
	assert_true(_p(1).progress.level <= 65535)


func test_xp_command_many_levels_one_tick() -> void:
	var a := _guest("Ana")
	_drain(a)
	var before := host.world.tick
	_say(a, "/xp 99999999")
	assert_eq(host.world.tick, before + 1)
	assert_gt(_p(1).progress.level, 50)
	assert_eq(_msgs(a, Protocol.Msg.PROGRESS).size(), 1)


func test_plain_slash_text_in_the_middle_is_chat() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_drain(a)
	_drain(b)
	_say(a, "hola /xp 5")
	assert_eq(_msgs(b, Protocol.Msg.CHAT).size(), 1)
	assert_eq(_p(1).progress.xp, 0)


func _chats(c: MemoryTransport) -> Array:
	return _msgs(c, Protocol.Msg.CHAT).map(func(m: Dictionary) -> String: return m.text)


func test_gold_command() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_drain(a)
	_say(a, "/oro 250")
	assert_eq(_p(1).inventory.gold, 250)
	_say(a, "/oro 30 bea")
	assert_eq(_p(2).inventory.gold, 30)


func test_item_command() -> void:
	var a := _guest("Ana")
	_drain(a)
	_say(a, "/objeto plate_chest_t1 12 epic")
	var it: Item = _p(1).inventory.bag[0]
	assert_eq([it.base_id, it.level, it.rarity, it.affixes.size()], ["plate_chest_t1", 12, "epic", 3])
	_say(a, "/objeto sword_t1")
	assert_eq(_p(1).inventory.bag[1].level, _p(1).progress.level, "level defaults to the player's")
	_drain(a)
	_say(a, "/objeto nope")
	assert_has(_chats(a), "CMD_BAD")


func test_item_command_full_bag() -> void:
	var a := _guest("Ana")
	while _p(1).inventory.add(ItemRoll.new_item("ring_t1", 1), ItemDB.load_default()):
		pass
	_drain(a)
	_say(a, "/objeto sword_t1")
	assert_has(_chats(a), "ITEM_BAG_FULL")


func test_guest_refused() -> void:
	_guest("Ana")
	var b := _guest("Bea")
	_drain(b)
	_say(b, "/oro 100")
	assert_eq(_p(2).inventory.gold, 0)
	assert_has(_chats(b), "CMD_HOST_ONLY")
