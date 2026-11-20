extends GutTest
## Items over the network (protocol 7): HELLO carries the inventory (sanitized), the host
## sends INVENTORY and loot only to their owner, PLAYER_GEAR to everyone, and checks
## every ITEM_ACTION.

const VERSION := "0.1.0"

var balance: Balance
var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var db: ItemDB


func before_each() -> void:
	balance = Balance.load_from()
	db = ItemDB.load_default()
	var map := CollisionMap.from_layout({"size": [60, 60], "spawn": [20, 20], "blocks": [],
		"npcs": [{"id": "merchant", "at": [22, 20], "facing": 0}]})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(balance, map, VERSION)
	host.add_transport(host_t)


func _guest(name: String, inv: Inventory = null, class_id := "warrior", level := 1) -> MemoryTransport:
	var c := net.connect_client(host_t)
	var wire := inv.to_wire() if inv != null else {}
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, class_id, {}, [], {"level": level}, wire), true)
	host.tick()
	return c


func _msgs(c: MemoryTransport, type: int) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		var m := Protocol.decode(p.data)
		if m.get("type") == type:
			out.append(m)
	return out


func _all(c: MemoryTransport) -> Array:
	return c.poll().map(func(p: Dictionary) -> Dictionary: return Protocol.decode(p.data))


func _send(c: MemoryTransport, data: PackedByteArray) -> void:
	c.send(Transport.HOST_PEER, data, true)
	host.tick()


func test_protocol_is_7() -> void:
	assert_eq(Protocol.VERSION, 7)


func test_old_protocol_hello_decodes_for_a_version_answer() -> void:
	var old := Protocol.pack([Protocol.Msg.HELLO, "0.6.1", 6, "Ana", "mage", {}, [], {}])
	var m := Protocol.decode(old)
	assert_eq(m.protocol, 6)
	assert_eq(m.inventory, {})


func test_hello_inventory_sanitized() -> void:
	var inv := Inventory.new()
	inv.gold = 50
	inv.equipment["offhand"] = ItemRoll.new_item("orb_t1", 1) # a caster's off-hand on a warrior
	inv.equipment["main"] = ItemRoll.new_item("sword_t1", 1)
	var a := _guest("Ana", inv)
	var got := _msgs(a, Protocol.Msg.INVENTORY)
	assert_eq(got.size(), 1)
	var back := Inventory.from_wire(got[0].inventory, "warrior", 1, db)
	assert_eq(back.gold, 50)
	assert_eq(back.equipment.keys(), ["main"])
	assert_eq(back.bag[0].base_id, "orb_t1", "moved to the bag, not lost")
	var p: PlayerState = host.world.players[1]
	assert_true(p.inventory.equipment.has("main"))


func test_full_inventory_fits_a_packet() -> void:
	var inv := Inventory.new()
	var rng := RandomNumberGenerator.new()
	for i in Inventory.SIZE:
		inv.bag[i] = ItemRoll.roll_gear("warrior_chest_t1", 999, "epic", rng, db)
	for s: String in Inventory.SLOTS:
		inv.equipment[s] = ItemRoll.roll_gear("ring_t1", 999, "epic", rng, db)
	assert_lt(Protocol.inventory(inv.to_wire(), 30.0).size(), Protocol.MAX_PACKET_BYTES)


func test_inventory_only_owner() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_all(a)
	_all(b)
	var p: PlayerState = host.world.players[1]
	p.inventory.gold = 10
	p.inventory_dirty = true
	host.tick()
	assert_eq(_msgs(a, Protocol.Msg.INVENTORY).size(), 1)
	assert_eq(_msgs(b, Protocol.Msg.INVENTORY).size(), 0)


func test_loot_events_only_owner() -> void:
	var evs := HostSession.events_for(1, [["loot", 1, 77, {}, Vector3.ZERO], ["gold", 2, 5, Vector3.ZERO], ["died", 9]])
	assert_eq(evs.map(func(e: Array) -> String: return e[0]), ["loot", "died"])
	evs = HostSession.events_for(2, [["loot", 1, 77, {}, Vector3.ZERO], ["gold", 2, 5, Vector3.ZERO], ["died", 9]])
	assert_eq(evs.map(func(e: Array) -> String: return e[0]), ["gold", "died"])


func test_joined_and_roster_carry_gear() -> void:
	var inv := Inventory.new()
	inv.equipment["main"] = ItemRoll.new_item("greatsword_t1", 1)
	var a := _guest("Ana", inv)
	var b := _guest("Bea")
	var joined := _msgs(a, Protocol.Msg.PLAYER_JOINED)
	assert_eq(joined.size(), 1)
	assert_eq((joined[0].gear as Array).size(), 8)
	var welcome := _msgs(b, Protocol.Msg.WELCOME)
	assert_eq(welcome[0].roster[0][6][0], "greatsword_t1")


func test_equip_roundtrip() -> void:
	var a := _guest("Ana")
	var b := _guest("Bea")
	_all(a)
	_all(b)
	var p: PlayerState = host.world.players[1]
	p.inventory.add(ItemRoll.new_item("warrior_chest_t1", 1), db)
	_send(a, Protocol.item_action("equip", [0]))
	assert_eq(p.inventory.equipment.chest.base_id, "warrior_chest_t1")
	assert_eq(_msgs(a, Protocol.Msg.INVENTORY).size(), 1)
	var gear := _msgs(b, Protocol.Msg.PLAYER_GEAR)
	assert_eq(gear.size(), 1)
	assert_eq(gear[0].id, 1)
	assert_eq(gear[0].gear[4], "warrior_chest_t1")


func test_bad_item_actions_ignored() -> void:
	var a := _guest("Ana")
	_all(a)
	_send(a, Protocol.item_action("equip", ["x"]))
	_send(a, Protocol.item_action("nope", []))
	_send(a, Protocol.item_action("equip", [999]))
	_send(a, Protocol.item_action("sell", []))
	assert_eq(_msgs(a, Protocol.Msg.INVENTORY).size(), 0)


func test_potion_action() -> void:
	var a := _guest("Ana", null, "mage")
	var p: PlayerState = host.world.players[1]
	var pot := ItemRoll.new_item("potion_health", 1)
	pot.count = 3
	p.inventory.add(pot, db)
	p.hp = 1.0
	_all(a)
	_send(a, Protocol.item_action("potion", ["health"]))
	assert_gt(p.hp, 1.0)
	var inv := _msgs(a, Protocol.Msg.INVENTORY)
	assert_eq(inv.size(), 1)
	assert_almost_eq(float(inv[0].potion_cd_s), 30.0, 0.1)


func test_merchant_open_and_buy() -> void:
	var a := _guest("Ana", null, "mage", 10)
	var p: PlayerState = host.world.players[1]
	p.position = Vector3(21.5, 0, 20.5)
	p.inventory.gold = 1000
	_all(a)
	_send(a, Protocol.item_action("merchant_open", []))
	var stock := _msgs(a, Protocol.Msg.MERCHANT_STOCK)
	assert_eq(stock.size(), 1)
	assert_eq((stock[0].items as Array).size(), 4)
	_send(a, Protocol.item_action("buy", [-1]))
	assert_eq(p.inventory.bag[0].base_id, "potion_health")
	_send(a, Protocol.item_action("buy", [0]))
	var after := _msgs(a, Protocol.Msg.MERCHANT_STOCK)
	assert_eq((after[-1].items as Array).size(), 3)


func test_client_mirrors_inventory_and_gear() -> void:
	var h := NetHarness.new(0, 0, 0, 3)
	var ana := h.add_client("Ana")
	var bea := h.add_client("Bea")
	h.run_ticks(10)
	var changed := []
	ana.inventory_changed.connect(func() -> void: changed.append(true))
	var p: PlayerState = h.host.world.players[ana.my_id]
	p.inventory.gold = 42
	p.inventory.add(ItemRoll.new_item("wood_sword", 1), db)
	ana.request_item("equip", [0])
	h.run_ticks(10)
	assert_eq(ana.inventory.gold, 42)
	assert_false(changed.is_empty())
	assert_eq(bea.gear_of(ana.my_id)[0], "wood_sword")


func test_crossbow_fires_charged_on_press() -> void:
	var a := _guest("Ana", null, "archer")
	var p: PlayerState = host.world.players[1]
	p.inventory.equipment["main"] = ItemRoll.new_item("crossbow_t1", 1)
	p.resource = 100.0
	_send(a, Protocol.input([[1, Vector2.ZERO, Vector3(30, 0, 20), PlayerInput.BTN_BASIC]]))
	assert_lt(p.resource, 100.0, "the charged shot's focus was spent on a single press")
	assert_gt(int(p.cooldowns.get("archer_shot", 0)), host.world.tick)


func test_merchant_stock_sent_within_the_trade_margin() -> void:
	var a := _guest("Ana", null, "mage", 10)
	var p: PlayerState = host.world.players[1]
	var at: Vector3 = NpcDB.load_default().placed(host.world.map).filter(func(n: Dictionary) -> bool: return str(NpcDB.load_default().npc(n.id).get("role", "")) == "merchant")[0].position
	p.position = at + Vector3(NpcDB.TALK_RANGE + 0.3, 0, 0)
	p.inventory.gold = 1000
	_all(a)
	_send(a, Protocol.item_action("merchant_open", []))
	assert_eq(_msgs(a, Protocol.Msg.MERCHANT_STOCK).size(), 1, "opens at the edge too")
	_send(a, Protocol.item_action("buy", [0]))
	var after := _msgs(a, Protocol.Msg.MERCHANT_STOCK)
	assert_eq(after.size(), 1, "the bought item leaves the list")
	assert_eq((after[-1].items as Array).size(), 3)
