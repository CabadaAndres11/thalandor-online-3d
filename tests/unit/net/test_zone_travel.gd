extends GutTest
## Exits move players between zones (Plan 8.1).

const VERSION := "0.1.0"
const ZONES := "res://tests/data/zones/"

var net: MemoryNetwork
var host_t: MemoryTransport
var host: HostSession
var a_key: String


func before_each() -> void:
	var map := CollisionMap.from_layout({"size": [40, 40], "spawn": [20, 20], "blocks": []})
	net = MemoryNetwork.new(7)
	host_t = net.create_host()
	host = HostSession.new(Balance.load_from(), map, VERSION)
	host.zones.zone_dir = ZONES
	host.add_transport(host_t)
	a_key = host.zones.open("zone_a")


func _guest(name: String) -> MemoryTransport:
	var c := net.connect_client(host_t)
	c.send(Transport.HOST_PEER, Protocol.hello(VERSION, Protocol.VERSION, name, "warrior", {}), true)
	return c


func _messages(c: MemoryTransport) -> Array:
	var out := []
	for p: Dictionary in c.poll():
		out.append(Protocol.decode(p.data))
	return out


func _of(msgs: Array, type: int) -> Array:
	return msgs.filter(func(m: Dictionary) -> bool: return m.type == type)


## A player in zone_a standing on `cell`.
func _in_a(name: String, cell: Vector2) -> MemoryTransport:
	var c := _guest(name)
	host.tick()
	var id := host.player_count()
	host.transfer(id, a_key, Vector3(cell.x + 0.5, 0, cell.y + 0.5))
	_messages(c)
	return c


func test_exit_moves_to_entry_keeping_inventory_level_hp() -> void:
	var c := _in_a("Ana", Vector2(10, 5))
	var p := host.state_of(1)
	p.progress.level = 7
	p.hp = p.stats.max_hp * 0.5
	var gold := p.inventory.gold
	p.position = Vector3(25.5, 0, 5.5)
	host.tick()
	var zone_msgs := _of(_messages(c), Protocol.Msg.ZONE)
	assert_eq(zone_msgs.size(), 1)
	assert_eq(zone_msgs[0].zone, "zone_b")
	var q := host.state_of(1)
	assert_same(q, p, "the same player state")
	assert_eq(host.world_of(1), host.zones.world("zone_b"))
	assert_almost_eq(q.position, Vector3(3.5, 0, 3.5), Vector3.ONE * 0.6)
	assert_eq(q.progress.level, 7)
	assert_almost_eq(q.hp, q.stats.max_hp * 0.5, 1.0, "the same health (and a tick of regeneration)")
	assert_eq(q.inventory.gold, gold)


func test_exit_blocked_in_combat() -> void:
	var c := _in_a("Ana", Vector2(10, 5))
	var p := host.state_of(1)
	var w := host.world_of(1)
	p.last_hurt_tick = w.tick
	p.position = Vector3(25.5, 0, 5.5)
	host.tick()
	var msgs := _messages(c)
	assert_eq(_of(msgs, Protocol.Msg.ZONE).size(), 0)
	assert_eq(host.world_of(1), w)
	var blocked := false
	for m: Dictionary in _of(msgs, Protocol.Msg.EVENTS):
		for ev: Array in m.events:
			blocked = blocked or ev[0] == "zone_blocked"
	assert_true(blocked, "told why")
	for i in w.ticks(5.1):
		host.tick()
	assert_eq(host.world_of(1), host.zones.world("zone_b"), "after 5 s it lets you through")


func test_two_players_cross_the_same_tick() -> void:
	var a := _in_a("Ana", Vector2(10, 5))
	var b := _in_a("Bea", Vector2(11, 5))
	host.state_of(1).position = Vector3(25.5, 0, 5.5)
	host.state_of(2).position = Vector3(26.5, 0, 6.5)
	host.tick()
	var wb := host.zones.world("zone_b")
	assert_eq(wb.players.size(), 2)
	assert_eq(host.zones.world(a_key).players.size(), 0)
	assert_eq(host.zones.occupants("zone_b").size(), 2)


func test_dead_player_does_not_cross() -> void:
	_in_a("Ana", Vector2(10, 5))
	var p := host.state_of(1)
	p.life = CombatEntity.DOWNED
	p.position = Vector3(25.5, 0, 5.5)
	host.tick()
	assert_eq(host.world_of(1), host.zones.world(a_key))


func test_exit_to_unknown_zone_is_ignored() -> void:
	_in_a("Ana", Vector2(10, 5))
	host.state_of(1).position = Vector3(5.5, 0, 25.5)
	host.tick()
	host.tick()
	assert_eq(host.world_of(1), host.zones.world(a_key))


func test_zone_command_moves_and_lists() -> void:
	var c := _guest("Ana")
	host.tick()
	_messages(c)
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/zona zone_b"), true)
	host.tick()
	assert_eq(host.world_of(1), host.zones.world("zone_b"))
	assert_eq(_of(_messages(c), Protocol.Msg.ZONE).size(), 1)
	c.send(Transport.HOST_PEER, Protocol.chat(0, "/zonas"), true)
	host.tick()
	var chats := _of(_messages(c), Protocol.Msg.CHAT)
	assert_true(chats.any(func(m: Dictionary) -> bool: return str(m.text).contains("zone_b")))


func test_party_rows_for_other_zones() -> void:
	var a := _in_a("Ana", Vector2(10, 5))
	var b := _guest("Bea")
	for i in host.world.ticks(1.1):
		host.tick()
	var party := _of(_messages(b), Protocol.Msg.PARTY)
	assert_gt(party.size(), 0)
	var row: Array = party.back().rows[0]
	assert_eq(row[0], 1)
	assert_eq(row[1], "ZONE_TEST_A")
	assert_eq(_of(_messages(a), Protocol.Msg.PARTY).back().rows[0][0], 2)


func test_combat_state_stays_behind() -> void:
	_in_a("Ana", Vector2(10, 5))
	var p := host.state_of(1)
	var w := host.world_of(1)
	var dot := StatusEffect.new()
	dot.kind = "poison"
	dot.source_id = 1005
	dot.end_tick = w.tick + 1000
	p.statuses.append(dot)
	p.charge_start = w.tick
	var wolf := MonsterDB.load_default().make("marked_hound", w.next_monster_id(), p.position, w, 5)
	wolf.team = CombatEntity.TEAM_PLAYERS
	wolf.summoned_by = 1
	w.add_entity(wolf)
	host.send_to_zone(1, host.zones.open("zone_b"), Vector3(3.5, 0, 3.5))
	assert_false(p.statuses.any(func(s: StatusEffect) -> bool: return s.source_id == 1005), "a monster's DoT does not follow")
	assert_eq(p.charge_start, -1)
	assert_false(w.monsters.has(wolf.id), "the summon is dismissed")


func test_open_reuses_an_open_zone() -> void:
	var key := host.zones.open("zone_b")
	var w := host.zones.world(key)
	assert_eq(host.zones.open("zone_b"), key)
	assert_same(host.zones.world(key), w)
	assert_same(host.zones.layout(key), host.zones.peek("zone_b"), "parsed once")
