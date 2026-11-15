extends GutTest


func test_roundtrip_hello() -> void:
	var m := Protocol.decode(Protocol.hello("0.1.0", 1, "Andrés", "warrior", {}))
	assert_eq(m.type, Protocol.Msg.HELLO)
	assert_eq(m.game_version, "0.1.0")
	assert_eq(m.protocol, 1)
	assert_eq(m.name, "Andrés")


func test_roundtrip_welcome() -> void:
	var roster := [[1, "Ana", 0, "warrior", {}], [2, "Bea", 1, "mage", {"skin": "skin_2"}]]
	var m := Protocol.decode(Protocol.welcome(2, 77, roster))
	assert_eq(m.type, Protocol.Msg.WELCOME)
	assert_eq(m.player_id, 2)
	assert_eq(m.tick, 77)
	assert_eq(m.roster, roster)


func test_roundtrip_reject() -> void:
	var m := Protocol.decode(Protocol.reject("version", "0.1.0"))
	assert_eq(m.type, Protocol.Msg.REJECT)
	assert_eq(m.reason, "version")
	assert_eq(m.host_version, "0.1.0")


func test_roundtrip_input() -> void:
	var inputs := [[5, Vector2(1, 0), Vector3(3, 0, 4), PlayerInput.BTN_BASIC], [6, Vector2(0, -1), Vector3(1, 0, 1), 0]]
	var m := Protocol.decode(Protocol.input(inputs))
	assert_eq(m.type, Protocol.Msg.INPUT)
	assert_eq(m.inputs, inputs)


func test_roundtrip_snapshot() -> void:
	var players := [[1, Vector3(1.5, 0, 2.5), Vector3(4, 0, 4), 0.5, 12, 80.0, 100.0, 30.0, 100.0, 0, 0, 0, Vector2.ZERO, 0, 1.0]]
	var m := Protocol.decode(Protocol.snapshot(99, players))
	assert_eq(m.type, Protocol.Msg.SNAPSHOT)
	assert_eq(m.tick, 99)
	assert_eq(m.players.size(), 1)
	assert_eq(m.players[0][0], 1)
	assert_eq(m.players[0][1], Vector3(1.5, 0, 2.5))
	assert_almost_eq(float(m.players[0][3]), 0.5, 0.0001)
	assert_eq(m.players[0][4], 12)


func test_roundtrip_player_joined() -> void:
	var m := Protocol.decode(Protocol.player_joined(3, "Carla", 2, "warrior", {}))
	assert_eq(m.type, Protocol.Msg.PLAYER_JOINED)
	assert_eq([m.id, m.name, m.slot], [3, "Carla", 2])


func test_roundtrip_player_left() -> void:
	var m := Protocol.decode(Protocol.player_left(3))
	assert_eq(m.type, Protocol.Msg.PLAYER_LEFT)
	assert_eq(m.id, 3)


func test_roundtrip_chat() -> void:
	var m := Protocol.decode(Protocol.chat(2, "¡Hola!"))
	assert_eq(m.type, Protocol.Msg.CHAT)
	assert_eq(m.from_id, 2)
	assert_eq(m.text, "¡Hola!")


func test_garbage_bytes_decode_to_empty() -> void:
	assert_eq(Protocol.decode(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9])), {})
	assert_eq(Protocol.decode(var_to_bytes([Protocol.Msg.PLAYER_LEFT, 1])), {}, "missing header")


func test_unknown_type_decodes_to_empty() -> void:
	assert_eq(Protocol.decode(Protocol.pack([99, "x"])), {})


func test_wrong_field_type_decodes_to_empty() -> void:
	assert_eq(Protocol.decode(Protocol.pack([Protocol.Msg.HELLO, "0.1.0", "1", "Ana"])), {})
	assert_eq(Protocol.decode(Protocol.pack([Protocol.Msg.INPUT, [[1, "up", Vector3.ZERO]]])), {})
	assert_eq(Protocol.decode(Protocol.pack([Protocol.Msg.SNAPSHOT, 1, [[1, Vector3.ZERO]]])), {})


func test_missing_fields_decode_to_empty() -> void:
	assert_eq(Protocol.decode(Protocol.pack([Protocol.Msg.CHAT, 1])), {})


func test_empty_bytes_decode_to_empty() -> void:
	assert_eq(Protocol.decode(PackedByteArray()), {})


func test_truncated_array_decodes_to_empty() -> void:
	var full := Protocol.chat(2, "hola que tal")
	assert_eq(Protocol.decode(full.slice(0, full.size() - 5)), {})


func test_hello_carries_class_and_appearance() -> void:
	var app := {"skin": "skin_3", "hair_style": "hair_bun"}
	var m := Protocol.decode(Protocol.hello("0.2.0", Protocol.VERSION, "Lyra", "archer", app))
	assert_eq(m.class_id, "archer")
	assert_eq(m.appearance, app)


func test_hello_with_wrong_types_is_rejected() -> void:
	var bad := Protocol.pack([Protocol.Msg.HELLO, "0.2.0", Protocol.VERSION, "Lyra", "archer", [1, 2]])
	assert_eq(Protocol.decode(bad), {})
	var bad_class := Protocol.pack([Protocol.Msg.HELLO, "0.2.0", Protocol.VERSION, "Lyra", 7, {}])
	assert_eq(Protocol.decode(bad_class), {})


func test_player_joined_carries_class_and_appearance() -> void:
	var m := Protocol.decode(Protocol.player_joined(3, "Carla", 2, "cleric", {"beard": "full"}))
	assert_eq([m.class_id, m.appearance], ["cleric", {"beard": "full"}])


func test_roster_rows_carry_class_and_appearance() -> void:
	var rows := [[1, "Ana", 0, "mage", {"skin": "skin_2"}]]
	var m := Protocol.decode(Protocol.welcome(1, 10, rows))
	assert_eq(m.roster, rows)
	var short_rows := Protocol.pack([Protocol.Msg.WELCOME, 1, 10, [[1, "Ana", 0]]])
	assert_eq(Protocol.decode(short_rows), {}, "rows without class and appearance are invalid")


func test_legacy_hello_decodes_without_character() -> void:
	var m := Protocol.decode(Protocol.pack([Protocol.Msg.HELLO, "0.1.2", 1, "Ana"]))
	assert_eq(m.type, Protocol.Msg.HELLO)
	assert_eq(m.protocol, 1)
	assert_eq(m.class_id, "")
	assert_eq(m.appearance, {})


## Attention point 4: 4 players with statuses and 30 monsters fit in one packet.
func test_snapshot_fits_with_4_players_30_monsters() -> void:
	var players := []
	for i in 4:
		players.append([i + 1, Vector3(123.456, 0, 98.765), Vector3(130.1, 0, 90.2), 1.234, 99999,
			1234.5, 2000.0, 87.5, 100.0, 0, 0x3FFF, 5, Vector2(0.7, 0.7), 123456, 0.6])
	var monsters := []
	for i in 30:
		monsters.append([1000 + i, "skeleton_archer", Vector3(100.5 + i, 0, 80.25), 2.5, 4567.8, 9000.0, 0x3FFF, 4])
	var packet := Protocol.snapshot(123456, players, monsters)
	assert_lt(packet.size(), Protocol.MAX_PACKET_BYTES, "%d bytes" % packet.size())
	assert_false(Protocol.decode(packet).is_empty())
	gut.p("snapshot with 4 players and 30 monsters: %d bytes" % packet.size())
