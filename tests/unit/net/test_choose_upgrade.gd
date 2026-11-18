extends GutTest
## A level 50 player picks a class upgrade from Brann; everyone hears it, late joiners
## see it, and the new abilities go to free bar slots.

const VERSION := "0.1.0"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "brann", "at": [22, 20], "facing": 0}]})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.add_transport(host_t)
	var hit := {"type": "melee_arc", "angle_deg": 360, "range": 3, "damage": {"base": 1, "coef": 0, "kind": "magic"}}
	host.world.abilities = AbilityDB.from_list([
		{"id": "w_basic", "class": "warrior", "kind": "basic", "level": 1, "cooldown_s": 0, "effects": [hit]},
		{"id": "w_a1", "class": "warrior", "kind": "active", "level": 1, "cooldown_s": 0, "effects": [hit]},
		{"id": "w_up", "class": "warrior", "kind": "active", "level": 50, "upgrade": "berserker", "cooldown_s": 0, "effects": [hit]}])
	host.world.upgrades = UpgradeDB.from_list([{"id": "berserker", "class": "warrior", "actives": ["w_up"], "passives": [], "evolves": {}}])


func _guest(name: String, progress := {"level": 50}) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}, [], progress), true)
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


func test_messages_roundtrip() -> void:
	assert_eq(Protocol.decode(Protocol.choose_upgrade("berserker")), {"type": Protocol.Msg.CHOOSE_UPGRADE, "id": "berserker"})
	assert_eq(Protocol.decode(Protocol.player_upgrade(3, "hunter")), {"type": Protocol.Msg.PLAYER_UPGRADE, "id": 3, "upgrade": "hunter"})
	assert_eq(Protocol.decode(Protocol.pack([Protocol.Msg.CHOOSE_UPGRADE, 5])), {})
	var j := Protocol.decode(Protocol.player_joined(2, "Bea", 1, "mage", {}, "arcanist"))
	assert_eq(j.upgrade, "arcanist")
	var w := Protocol.decode(Protocol.welcome(1, 0, [[1, "Ana", 0, "warrior", {}, "berserker"]]))
	assert_eq(w.roster[0][5], "berserker")


func test_upgrade_reaches_everyone() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea", {})
	_msgs(a, Protocol.Msg.PLAYER_UPGRADE)
	_msgs(b, Protocol.Msg.PLAYER_UPGRADE)
	_send(a, Protocol.choose_upgrade("berserker"))
	for c: MemoryTransport in [a, b]:
		var got := _msgs(c, Protocol.Msg.PLAYER_UPGRADE)
		assert_eq(got.size(), 1)
		assert_eq([got[0].id, got[0].upgrade], [1, "berserker"])
	assert_eq(host.world.players[1].progress.upgrade, "berserker")


func test_the_owner_gets_progress_and_the_new_ability_in_the_bar() -> void:
	var a := _guest("Ana")
	var first := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(first[0].bar, ["w_a1", "", "", ""])
	_send(a, Protocol.choose_upgrade("berserker"))
	var got := _msgs(a, Protocol.Msg.PROGRESS)
	assert_eq(got.size(), 1)
	assert_eq(PlayerProgress.from_dict(got[0].progress).upgrade, "berserker")
	assert_eq(got[0].bar, ["w_a1", "w_up", "", ""])


func test_rejections_change_nothing() -> void:
	var low := _guest("Ana", {"level": 49})
	_msgs(low, Protocol.Msg.PLAYER_UPGRADE)
	_send(low, Protocol.choose_upgrade("berserker"))
	assert_eq(_msgs(low, Protocol.Msg.PLAYER_UPGRADE).size(), 0)
	assert_eq(host.world.players[1].progress.upgrade, "")


func test_late_joiner_sees_upgrade() -> void:
	var a := _guest("Ana")
	_send(a, Protocol.choose_upgrade("berserker"))
	var b := _guest("Bea", {})
	var w := _msgs(b, Protocol.Msg.WELCOME)
	assert_eq(w[0].roster[0][5], "berserker")


func test_hello_with_upgrade_is_announced_to_the_others() -> void:
	var a := _guest("Ana", {})
	_msgs(a, Protocol.Msg.PLAYER_JOINED)
	_guest("Bea", {"level": 50, "upgrade": "berserker"})
	var j := _msgs(a, Protocol.Msg.PLAYER_JOINED)
	assert_eq(j[0].upgrade, "berserker")


func test_reset_removes_the_upgrade_ability_from_the_bar() -> void:
	var a := _guest("Ana", {"level": 50, "upgrade": "berserker"})
	assert_eq(host._players[1].bar, ["w_a1", "w_up", "", ""])
	_msgs(a, Protocol.Msg.PLAYER_UPGRADE)
	_send(a, Protocol.reset("upgrade"))
	assert_eq(host._players[1].bar, ["w_a1", "", "", ""])
	assert_eq(_msgs(a, Protocol.Msg.PLAYER_UPGRADE)[0].upgrade, "")
