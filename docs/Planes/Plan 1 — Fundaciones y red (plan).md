---
tags: [plan]
plan: 1
fecha: 2026-11-14
estado: en revisión
actualizado: 2026-11-14
---
# Plan 1 — Fundaciones y red: plan de implementación

> **Ejecución:** nativa en el chat (norma 5), tarea a tarea, con TDD. Pasos con casillas `- [ ]` para el seguimiento.

**Objetivo:** proyecto Godot con cápsulas que se mueven en red host-autoritativa (predicción + interpolación), grupo por código, chat, control de versiones, ejecutable de Windows en GitHub Releases y prueba entre casas.

**Arquitectura:** reglas puras en `sim/` (sin nodos); red propia en `net/` sobre una interfaz `Transport` (memoria, ENet, WebRTC); `game/` y `ui/` solo leen el estado y lo dibujan. Siempre hay `HostSession`; el jugador local es un `ClientSession` conectado por memoria.

**Tecnología:** Godot 4.7.2, GDScript tipado, GUT 9.6.1, ENet, GitHub Actions, `gh`.

**Spec:** [[Plan 1 — Fundaciones y red (spec)]]

## Restricciones globales
- Godot **4.7.2-stable**; GDScript con tipos en variables, parámetros y retornos.
- Código, nombres y commits en **inglés**; textos del juego en `data/texts/textos.csv` (`keys,es`) usados con `tr()`.
- Constantes en `data/balance.json`; ningún número de reglas escrito en el código.
- Resolución base **1280×720**, `canvas_items`; ninguna ventana con scroll.
- Versión del juego `0.1.0` en `application/config/version`. `Protocol.VERSION = 1`.
- Máximo **4** jugadores; **30** ticks/s; interpolación **100 ms**; tiempo de espera **5 s**; chat **120** caracteres; nombre **2–16** caracteres (letras con tildes, números, espacios, `-`, `'`).
- Puerto UDP **24680** (fijo; el código de grupo solo lleva la IP — ver tarea 11).
- Commits con el email del usuario (configuración local del repositorio). Cada commit termina con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Ejecutables de trabajo: `GODOT="/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"`.
- Tests: `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` (un archivo: añadir `-gtest=res://tests/...`). "PASA" = salida con `---- All tests passed! ----` y código 0.

## Puntos de atención en la revisión
1. **Escribir en el chat no mueve al personaje** y Enter con el texto vacío solo cierra el campo → test en la tarea 15.
2. **Códigos mal escritos** (minúsculas, espacios, sin guion, `O` por `0`, longitud errónea) se normalizan o dan un error claro, nunca un fallo → test en la tarea 11.
3. **Nombres con tildes** ("Andrés", "O'Brien") se aceptan; texto de chat de más de 120 caracteres se recorta en el host → tests en la tarea 8.
4. **Fotogramas lentos** (el render a 10 FPS o una pausa de 2 s de la ventana) no aceleran ni rompen la simulación: el reloj de render y la cola de entradas se recuperan → tests en las tareas 9 y 10.
5. **Huecos en el grupo:** 4 jugadores, sale uno y entra otro → reutiliza el color libre y la lista es coherente para todos → test en la tarea 10.

---

## Mapa de archivos
| Archivo | Responsabilidad |
|---|---|
| `project.godot`, `icon.svg`, `.gitignore`, `.gitattributes`, `.gutconfig.json`, `docs/.gdignore`, `README.md` | Proyecto y repositorio |
| `addons/gut/` | GUT 9.6.1 (copiado de `D:\Tools\_downloads\gut`) |
| `data/balance.json` | Constantes |
| `data/texts/textos.csv` | Textos en español |
| `data/maps/test_arena.json` | Escenario de pruebas como datos |
| `sim/balance.gd` | Carga de constantes |
| `sim/collision_map.gd` | Celdas sólidas de 1 m |
| `sim/player_input.gd`, `sim/player_state.gd` | Datos de entrada y estado |
| `sim/movement.gd` | Movimiento y colisión (función pura) |
| `sim/sim_world.gd` | Tick y jugadores |
| `net/protocol.gd` | Codificar/decodificar mensajes |
| `net/transport.gd` | Interfaz de transporte |
| `net/memory_network.gd`, `net/memory_transport.gd` | Red en memoria con latencia/pérdida |
| `net/enet_transport.gd` | ENet |
| `net/laggy_transport.gd` | Retraso/pérdida de depuración |
| `net/interpolation_buffer.gd` | Interpolación de otros jugadores |
| `net/host_session.gd` | Autoridad |
| `net/client_session.gd` | Predicción, reconciliación, render |
| `net/group_code.gd` | Código ↔ IP; elección de IP |
| `save/settings_store.gd` | `user://settings.json` |
| `game/main.tscn`, `game/main.gd` | Raíz: cambia entre título y partida |
| `game/game_session.gd` | Nodo que une host, cliente, transportes y escena |
| `game/arena.gd` | Construye `GridMap` y `CollisionMap` desde el JSON |
| `game/player_avatar.gd` | Cápsula, nombre y flecha de apuntado |
| `game/iso_camera.gd` | Cámara isométrica |
| `game/input_reader.gd` | WASD relativo a cámara y punto del ratón (funciones puras + lectura) |
| `ui/title_screen.gd`, `ui/pause_menu.gd`, `ui/chat_box.gd`, `ui/debug_overlay.gd`, `ui/message_dialog.gd` | Interfaz construida por código |
| `export_presets.cfg` | Preajuste Windows |
| `.github/workflows/ci.yml` | Tests y exportación |
| `tests/unit/**`, `tests/integration/**` | GUT |

---

### Tarea 1: Proyecto, GUT y constantes
**Archivos:** crear los de proyecto de la tabla, `addons/gut/`, `data/balance.json`, `data/texts/textos.csv`, `sim/balance.gd`, `tests/unit/sim/test_balance.gd`.

**Interfaces — produce:**
- `class_name Balance extends RefCounted` con campos `move_speed: float = 5.0`, `player_radius: float = 0.4`, `tick_rate: int = 30`, `interp_delay_ms: int = 100`, `correction_ms: int = 100`, `input_redundancy: int = 3`, `max_pending_inputs: int = 4`, `timeout_s: float = 5.0`, `chat_max_len: int = 120`, `port: int = 24680`, `max_players: int = 4`.
- `static func load_from(path: String = "res://data/balance.json") -> Balance` — campos ausentes conservan el valor por defecto; claves desconocidas se ignoran.

- [ ] `git init`; `git config user.name "Andrés"`; `git config user.email <email del usuario>` (local). `.gitignore`: `.godot/`, `exports/`, `*.tmp`. `.gitattributes`: `* text=auto eol=lf`.
- [ ] `project.godot`: nombre "Thalandor Online", `config/version="0.1.0"`, ventana 1280×720 con `stretch/mode="canvas_items"`, `physics/common/physics_ticks_per_second=30`, traducción `res://data/texts/textos.es.translation`, plugin GUT activado. `docs/.gdignore` vacío.
- [ ] Copiar `addons/gut`. `.gutconfig.json`: `{"dirs":["res://tests"],"include_subdirs":true,"should_exit":true,"log_level":1}`.
- [ ] `textos.csv` con al menos `GAME_TITLE,Thalandor Online`. `"$GODOT" --headless --path . --import` sin errores.
- [ ] Test (falla): `test_loads_values_from_file` (`load_from()` → `move_speed == 5.0`, `tick_rate == 30`, `port == 24680`); `test_missing_keys_keep_defaults` (JSON temporal en `user://` con solo `{"move_speed": 7}` → `move_speed == 7.0`, `tick_rate == 30`); `test_missing_file_returns_defaults`.
- [ ] Implementar `Balance`. Pasar tests: PASA.
- [ ] Commit `chore: bootstrap Godot project with GUT and balance data`.

### Tarea 2: Repositorio en GitHub y CI de tests
**Archivos:** `.github/workflows/ci.yml`, `README.md`.
- [ ] `ci.yml`, trabajo `test` en `ubuntu-latest` en cada `push` y `pull_request`: descargar `Godot_v4.7.2-stable_linux.x86_64.zip` del release oficial, `--headless --import`, ejecutar GUT con `.gutconfig.json`; falla si GUT falla.
- [ ] `README.md` breve en español (qué es, cómo ejecutar los tests, enlace al GDD).
- [ ] Commit `ci: run GUT tests on push`. `gh repo create CabadaAndres11/thalandor-online-3d --public --source . --push`.
- [ ] `gh run watch` → el trabajo `test` termina en verde.

### Tarea 3: Mapa de colisión y escenario como datos
**Archivos:** `data/maps/test_arena.json`, `sim/collision_map.gd`, `tests/unit/sim/test_collision_map.gd`.

**Interfaces — produce:**
- `test_arena.json`: `{"size":[40,40],"spawn":[20,20],"blocks":[[x,z,height],...]}` (≥ 10 bloques/columnas, alturas 1–3, ninguno en un radio de 3 del spawn).
- `class_name CollisionMap extends RefCounted`: `size: Vector2i`; `func set_solid(cell: Vector2i, solid: bool) -> void`; `func is_solid(cell: Vector2i) -> bool` (fuera de `[0,size)` → `true`); `static func from_layout(layout: Dictionary) -> CollisionMap`; `func spawn_point() -> Vector3` (centro de la celda spawn, y = 0).
- Convención: la celda `(x, z)` ocupa `[x, x+1) × [z, z+1)` en metros.

- [ ] Tests: `test_outside_bounds_is_solid`, `test_blocks_from_layout_are_solid`, `test_floor_cells_are_free`, `test_spawn_point_is_cell_center` (spawn `[20,20]` → `Vector3(20.5, 0, 20.5)`). Fallan.
- [ ] Implementar. PASA. Commit `feat(sim): collision map loaded from map data`.

### Tarea 4: Movimiento y mundo de simulación
**Archivos:** `sim/player_input.gd`, `sim/player_state.gd`, `sim/movement.gd`, `sim/sim_world.gd`, `tests/unit/sim/test_movement.gd`, `tests/unit/sim/test_sim_world.gd`.

**Interfaces — produce:**
- `class_name PlayerInput extends RefCounted`: `seq: int`, `move: Vector2` (x → eje X, y → eje Z del mundo), `aim: Vector3`; `func _init(p_seq := 0, p_move := Vector2.ZERO, p_aim := Vector3.ZERO)`; `func duplicate_input() -> PlayerInput`.
- `class_name PlayerState extends RefCounted`: `id: int`, `position: Vector3`, `aim: Vector3`, `facing: float` (radianes, 0 = +Z); `func copy_from(other: PlayerState) -> void`; `func clone() -> PlayerState`.
- `class_name Movement`: `static func apply(state: PlayerState, input: PlayerInput, dt: float, balance: Balance, map: CollisionMap) -> void`.
- `class_name SimWorld extends RefCounted`: `tick: int`; `players: Dictionary` (id → `PlayerState`); `func _init(p_balance: Balance, p_map: CollisionMap)`; `func add_player(id: int, position: Vector3) -> PlayerState`; `func remove_player(id: int) -> void`; `func step(inputs: Dictionary) -> void` (id → `PlayerInput`; los jugadores sin entrada no se mueven); `func dt() -> float` (= 1 / tick_rate).

**Algoritmo de `Movement.apply`** (lo que el test no determina): `move` se recorta a longitud ≤ 1; desplazamiento = `move × move_speed × dt`; se divide en subpasos de como mucho `radius × 0.5`; en cada subpaso se mueve primero en X y se resuelve, luego en Z y se resuelve (así se desliza por las paredes). Resolver un eje: para cada celda sólida que toque la caja del círculo, si el punto más cercano de la celda está a menos de `radius`, empujar al círculo solo en ese eje hasta quedar a `radius` del borde. `aim` se copia de la entrada; `facing = atan2(dx, dz)` hacia `aim` si la distancia horizontal > 0,01 m, si no se conserva.

- [ ] Tests (fallan): `test_moves_at_move_speed` (1 s de ticks hacia +X desde el spawn → x aumenta 5,0 ± 0,01); `test_diagonal_is_normalized` (move `(1,1)` → distancia recorrida en 1 s = 5,0 ± 0,01); `test_cannot_enter_solid_cell` (empujando 2 s contra un bloque, el borde del círculo nunca entra en la celda); `test_slides_along_wall` (move `(1,1)` contra una pared en X → z sigue avanzando); `test_large_step_does_not_tunnel` (dt = 0,5 contra una pared de 1 celda → no la atraviesa); `test_faces_aim_point`; `test_keeps_facing_when_aim_is_on_player`; `test_world_is_deterministic` (dos `SimWorld` con la misma secuencia de 200 entradas pseudoaleatorias con semilla fija → posiciones idénticas); `test_player_without_input_stays`.
- [ ] Implementar. PASA. Commit `feat(sim): deterministic movement with grid collision`.

### Tarea 5: Protocolo
**Archivos:** `net/protocol.gd`, `tests/unit/net/test_protocol.gd`.

**Interfaces — produce** (`class_name Protocol`):
- `const VERSION := 1`; `enum Msg { HELLO = 1, WELCOME, REJECT, INPUT, SNAPSHOT, PLAYER_JOINED, PLAYER_LEFT, CHAT }`.
- Codificadores estáticos, todos `-> PackedByteArray` usando `var_to_bytes` de un `Array` `[tipo, campos…]`:
  - `hello(game_version: String, protocol: int, name: String)`
  - `welcome(player_id: int, tick: int, roster: Array)` — roster: `[[id, name, slot], …]`
  - `reject(reason: String, host_version: String)` — `reason` ∈ `"version"`, `"full"`, `"name"`
  - `input(inputs: Array)` — `[[seq, move: Vector2, aim: Vector3], …]`
  - `snapshot(tick: int, players: Array)` — `[[id, position: Vector3, aim: Vector3, facing: float, last_seq: int], …]`
  - `player_joined(id: int, name: String, slot: int)`, `player_left(id: int)`, `chat(from_id: int, text: String)`
- `static func decode(data: PackedByteArray) -> Dictionary` — `{"type": Msg, …campos con los mismos nombres que los parámetros…}`; devuelve `{}` si los bytes no son un `Array`, el tipo es desconocido, faltan campos o un campo tiene otro tipo. Usar `bytes_to_var` (nunca `bytes_to_var_with_objects`).

- [ ] Tests (fallan): ida y vuelta de cada mensaje (`test_roundtrip_<msg>`); `test_garbage_bytes_decode_to_empty`; `test_unknown_type_decodes_to_empty`; `test_wrong_field_type_decodes_to_empty` (p. ej. `HELLO` con `protocol` como texto); `test_empty_bytes_decode_to_empty`.
- [ ] Implementar. PASA. Commit `feat(net): message protocol`.

### Tarea 6: Interfaz de transporte y red en memoria
**Archivos:** `net/transport.gd`, `net/memory_network.gd`, `net/memory_transport.gd`, `tests/unit/net/test_memory_transport.gd`.

**Interfaces — produce:**
- `class_name Transport extends RefCounted`: señales `peer_connected(peer: int)`, `peer_disconnected(peer: int)`, `connection_failed()`; `const HOST_PEER := 1`; `func send(peer: int, data: PackedByteArray, reliable: bool) -> void`; `func poll() -> Array` (de `{"peer": int, "data": PackedByteArray}`; emite las señales de conexión durante el poll); `func disconnect_peer(peer: int) -> void`; `func close() -> void`. Métodos base vacíos.
- `class_name MemoryNetwork extends RefCounted`: `latency_ms: float = 0`, `jitter_ms: float = 0`, `loss: float = 0` (0–1, solo afecta a no fiables); `func _init(seed: int = 1)`; `func create_host() -> MemoryTransport`; `func connect_client(host: MemoryTransport) -> MemoryTransport` (la conexión se anuncia a ambos lados tras `latency_ms`); `func advance(ms: float) -> void` (reloj manual).
- `MemoryTransport extends Transport`: el host ve a los clientes con ids 2, 3, 4…; el cliente ve al host como `HOST_PEER`. Los fiables llegan siempre y en orden; los no fiables pueden perderse o desordenarse por la variación. `close()` en un lado → `peer_disconnected` en el otro.

- [ ] Tests (fallan): `test_connect_announces_both_sides`; `test_zero_latency_delivers_on_next_poll`; `test_latency_delays_delivery` (latencia 100: tras `advance(99)` nada, tras `advance(1)` llega); `test_reliable_never_lost_and_ordered` (pérdida 0,5, 100 mensajes fiables → los 100 en orden); `test_unreliable_loss_rate` (pérdida 0,2, 1000 mensajes, semilla fija → entre 150 y 250 perdidos); `test_close_notifies_peer`; `test_host_assigns_incrementing_peer_ids`.
- [ ] Implementar. PASA. Commit `feat(net): transport interface and in-memory network`.

### Tarea 7: Búfer de interpolación
**Archivos:** `net/interpolation_buffer.gd`, `tests/unit/net/test_interpolation_buffer.gd`.

**Interfaces — produce** (`class_name InterpolationBuffer extends RefCounted`): `func push(tick: int, position: Vector3, aim: Vector3, facing: float) -> void` (ignora ticks repetidos o más antiguos que el último; guarda como mucho 32); `func sample(render_tick: float) -> Dictionary` → `{"position", "aim", "facing"}` interpolando linealmente (facing por el ángulo más corto) entre las dos muestras que rodean `render_tick`; antes de la primera → la primera; después de la última → la última (sin extrapolar); vacío → `{}`.

- [ ] Tests (fallan): `test_midpoint_interpolates`, `test_before_first_clamps`, `test_after_last_holds`, `test_ignores_old_ticks`, `test_facing_wraps_shortest_way` (de 3,0 a −3,0 rad pasa por π), `test_empty_returns_empty`, `test_capacity_is_bounded`.
- [ ] Implementar. PASA. Commit `feat(net): snapshot interpolation buffer`.

### Tarea 8: Sesión del host
**Archivos:** `net/host_session.gd`, `tests/unit/net/test_host_session.gd`.

**Interfaces:**
- Consume: `SimWorld`, `Protocol`, `Transport`, `Balance`, `CollisionMap`.
- Produce (`class_name HostSession extends RefCounted`): `func _init(p_balance: Balance, p_map: CollisionMap, p_game_version: String)`; `func add_transport(t: Transport) -> void`; `func tick() -> void` (poll de todos los transportes, procesar mensajes, consumir una entrada por jugador, `world.step`, enviar `SNAPSHOT` no fiable a todos); `func close() -> void`; `var world: SimWorld`; `func player_count() -> int`; señales `player_joined(id: int, name: String)`, `player_left(id: int)`. `static func is_valid_name(name: String) -> bool`.
- Reglas: ids de jugador 1–4 propios del host (no los ids de transporte); `slot` = el número 0–3 libre más bajo (color). `HELLO` con versión de juego distinta → `REJECT("version", host_version)`; con `protocol` distinto → igual; nombre inválido → `REJECT("name")`; con 4 jugadores → `REJECT("full")`; si no, `WELCOME` al nuevo, `PLAYER_JOINED` a los demás. Aparición: `map.spawn_point() + Vector3(slot % 2, 0, slot / 2) × 1.5`. Entradas: se aceptan solo con `seq` > último recibido; cola por jugador con máximo `max_pending_inputs` (se tiran las más antiguas); sin entrada en un tick se repite la última (sin avanzar `last_seq`). `CHAT` del cliente → se recorta el texto con `strip_edges()` y a `chat_max_len`; vacío se ignora; se reenvía a todos con el id del autor. Desconexión → `PLAYER_LEFT` a los demás.
- Nombres válidos: tras `strip_edges()`, 2–16 caracteres que cumplan `^[\p{L}\p{N} '\-]+$`.

- [ ] Tests (fallan; con `MemoryNetwork` y clientes "falsos" que envían bytes de `Protocol`): `test_hello_gets_welcome_with_roster`; `test_rejects_other_game_version` (motivo `"version"`, versión del host incluida); `test_rejects_other_protocol`; `test_rejects_fifth_player`; `test_rejects_invalid_name` (`"A"`, 17 caracteres, `"<b>"`); `test_accepts_accented_names` (`"Andrés"`, `"O'Brien"`, `"Ñu-2"`); `test_inputs_move_player`; `test_duplicate_inputs_ignored` (tres paquetes con la misma entrada redundante → un solo paso por seq); `test_input_queue_is_capped` (10 entradas en un tick → como mucho 4 pendientes); `test_missing_input_repeats_last`; `test_snapshot_reports_last_seq`; `test_chat_is_trimmed_and_relayed` (130 caracteres → 120); `test_empty_chat_ignored`; `test_disconnect_broadcasts_player_left`; `test_slot_reuse_after_leave`.
- [ ] Implementar. PASA. Commit `feat(net): authoritative host session`.

### Tarea 9: Sesión del cliente (predicción, reconciliación, render)
**Archivos:** `net/client_session.gd`, `tests/unit/net/test_client_session.gd`.

**Interfaces:**
- Consume: `Movement`, `PlayerState`, `PlayerInput`, `InterpolationBuffer`, `Protocol`, `Transport`.
- Produce (`class_name ClientSession extends RefCounted`): `enum Status { CONNECTING, IN_GAME, CLOSED }`; `func _init(p_balance: Balance, p_map: CollisionMap, p_game_version: String, p_name: String)`; `func connect_to(t: Transport) -> void` (envía `HELLO` al recibir `peer_connected(HOST_PEER)`); `func tick(move: Vector2, aim: Vector3) -> void` (una vez por tick de física: poll, procesar, y si está en partida crear entrada `seq+1`, aplicarla a la predicción, guardarla en pendientes y enviar `INPUT` con las últimas `input_redundancy`); `func update(delta: float) -> void` (por fotograma: reloj de render, suavizado de corrección, tiempo de espera); `func send_chat(text: String) -> void`; `func leave() -> void`; `var status: Status`; `var my_id: int`; `var roster: Dictionary` (id → `{"name", "slot"}`); `func render_state(id: int) -> Dictionary` (`{"position", "aim", "facing"}`; el propio = predicción + corrección suavizada; otros = interpolación); `var last_correction: float` (m); `func pending_count() -> int`; `func ping_ms() -> float` (estimado con `last_seq` reconocido); señales `welcomed(my_id: int)`, `rejected(reason: String, host_version: String)`, `disconnected(reason: String)` (`"host_left"`, `"timeout"`, `"failed"`), `roster_changed()`, `chat_received(author: String, text: String, is_system: bool)`.
- Reconciliación: al recibir `SNAPSHOT`, quitar pendientes con `seq ≤ last_seq` propio; guardar la posición predicha anterior; estado propio = el del host; volver a aplicar las pendientes; `error = anterior − nueva`; si `error.length() > 2 m` se ajusta de golpe; si no, el desfase visual decae linealmente a cero en `correction_ms`. `last_correction = error.length()`.
- Reloj de render: `render_tick += delta × tick_rate`; objetivo = último tick recibido − `interp_delay_ms × tick_rate / 1000`; si la diferencia con el objetivo es > 10 ticks se iguala de golpe; si no, se acerca un 10 % por fotograma.
- Mensajes del sistema en el chat (`is_system = true`): unirse y salir, con textos `CHAT_JOINED` y `CHAT_LEFT` del CSV.
- Tiempo de espera: sin paquetes durante `timeout_s` → `disconnected("timeout")` y `CLOSED`.

- [ ] Tests (fallan; host real + `MemoryNetwork`): `test_welcome_sets_status_and_id`; `test_rejected_signal_carries_reason`; `test_prediction_moves_immediately` (tras un `tick` con move, la posición propia cambia antes de cualquier instantánea); `test_zero_latency_matches_host`; `test_reconcile_replays_pending` (latencia 100 ms: tras 30 ticks moviéndose y 30 parado, posición propia == host ± 0,001); `test_small_error_is_smoothed` (forzar un desfase de 0,5 m → `render_state` se aleja < 0,5 m del anterior en el siguiente fotograma y llega al estado real tras 100 ms); `test_large_error_snaps`; `test_others_are_interpolated_between_snapshots`; `test_slow_frames_do_not_break_render_clock` (`update(2.0)` y luego fotogramas de 0,1 s → `render_tick` vuelve a ±1 tick del objetivo en < 1 s); `test_timeout_disconnects`; `test_host_close_disconnects_with_host_left`; `test_chat_roundtrip` (texto y autor correctos); `test_system_messages_on_join_and_leave`.
- [ ] Implementar. PASA. Commit `feat(net): client prediction, reconciliation and interpolation`.

### Tarea 10: Pruebas de red simulada (1 host + 3 invitados)
**Archivos:** `tests/integration/test_network_sim.gd`, `tests/helpers/net_harness.gd`.

**Interfaces — produce:** `class_name NetHarness extends RefCounted`: `func _init(latency_ms: float, jitter_ms: float, loss: float, seed: int)`; `func add_client(name: String, version: String = "0.1.0") -> ClientSession` (el primero va por memoria sin latencia, como el jugador del host); `func run_ticks(n: int, moves: Dictionary = {}) -> void` (nombre → `Vector2`; avanza la red 1/30 s, hace `tick` en clientes y host y `update` en clientes); `var host: HostSession`.

- [ ] Tests: `test_four_players_converge_with_lag_and_loss` (150 ms, 20 ms de variación, 5 % de pérdida; cada uno se mueve 3 s en una dirección distinta y luego se para 2 s → la posición de cada jugador vista por **cada** cliente == host ± 0,05 m; corrección propia máxima < 0,5 m); `test_fifth_client_rejected`; `test_version_mismatch_rejected`; `test_rejoin_reuses_free_slot` (4 dentro, sale el 2.º, entra otro → `slot` 1 y todos los `roster` iguales); `test_chat_reaches_everyone_in_order` (3 mensajes de distintos autores → mismo orden en los 4); `test_host_stall_recovers` (el host no hace tick durante 1 s y luego sigue → a los 3 s todos convergen y `pending_count() ≤ max_pending_inputs + 1`).
- [ ] Ajustar implementación si algún test falla (con `systematic-debugging`). PASA. Commit `test(net): 1 host + 3 guests under latency and loss`.

### Tarea 11: Código de grupo y elección de IP
**Archivos:** `net/group_code.gd`, `tests/unit/net/test_group_code.gd`.

**Interfaces — produce** (`class_name GroupCode`):
- `const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"` (31 símbolos, sin 0/O/1/I/L).
- `static func encode(ip: String) -> String` — IPv4 a número de 32 bits → 7 símbolos en base 31 + 1 de control (suma de índices mod 31) → `"XXXX-XXXX"`.
- `static func decode(code: String) -> String` — normaliza (mayúsculas, quita espacios y guiones) y devuelve la IP, o `""` si es inválido: longitud ≠ 8, símbolo fuera del alfabeto (incluidos los ambiguos `0 O 1 I L`, que se rechazan en vez de adivinarse), control erróneo o valor > 2³²−1.
- `static func pick_host_ip(addresses: PackedStringArray) -> String` — prioridad: Tailscale `100.64.0.0/10` → privadas `192.168/16`, `10/8`, `172.16/12` → `""`. Ignora IPv6, `127.*` y `169.254.*`.

- [ ] Tests (fallan): `test_roundtrip` (varias IP incluidas `0.0.0.0`, `255.255.255.255`, `100.101.102.103`); `test_format_has_dash`; `test_decode_is_case_and_space_insensitive` (`" abcd efgh "` equivale a `"ABCD-EFGH"`); `test_rejects_wrong_length`; `test_rejects_ambiguous_chars` (códigos con `O`, `0`, `I`, `1`, `L` → `""`); `test_rejects_bad_checksum`; `test_pick_prefers_tailscale`; `test_pick_falls_back_to_lan`; `test_pick_ignores_loopback_linklocal_ipv6`; `test_pick_returns_empty_when_none`.
- [ ] Implementar. PASA. Commit `feat(net): group codes`.

### Tarea 12: Transporte ENet y transporte con retraso
**Archivos:** `net/enet_transport.gd`, `net/laggy_transport.gd`, `tests/unit/net/test_enet_transport.gd`, `tests/unit/net/test_laggy_transport.gd`.

**Interfaces — produce:**
- `class_name EnetTransport extends Transport`: `static func host(port: int, max_clients: int) -> EnetTransport` (devuelve `null` y deja `last_error` si el puerto está ocupado); `static func join(ip: String, port: int) -> EnetTransport`; usa `ENetMultiplayerPeer` directamente como `PacketPeer` (`set_target_peer`, `transfer_mode` `RELIABLE`/`UNRELIABLE`, canales 0 fiable y 1 no fiable); `poll()` traduce el estado de conexión a señales (`connection_failed` si la conexión del cliente falla).
- `class_name LaggyTransport extends Transport`: `func _init(inner: Transport, latency_ms: float, loss: float, seed: int = 1)`; retrasa la entrega y pierde no fiables; reloj con `Time.get_ticks_msec()`.

- [ ] Tests (fallan): `test_localhost_connect_and_exchange` (host en 24690 y cliente a `127.0.0.1`; bucle de `poll` hasta 2 s → conectados y un mensaje fiable y uno no fiable llegan); `test_port_in_use_returns_null`; `test_join_unreachable_fails` (puerto sin servidor → `connection_failed` en ≤ 6 s, test marcado lento); `test_laggy_delays_and_drops` (sobre `MemoryTransport`).
- [ ] Implementar. PASA. Commit `feat(net): ENet transport and debug lag wrapper`.

### Tarea 13: Ajustes guardados
**Archivos:** `save/settings_store.gd`, `tests/unit/save/test_settings_store.gd`.

**Interfaces — produce** (`class_name SettingsStore extends RefCounted`): `const VERSION := 1`; `var player_name: String = ""`; `var last_code: String = ""`; `static func load_from(path: String = "user://settings.json") -> SettingsStore` (archivo ausente o corrupto → valores por defecto, sin error); `func save_to(path: String = "user://settings.json") -> Error` (escribe `{"version":1,"player_name":…,"last_code":…}`).

- [ ] Tests (fallan): `test_roundtrip`, `test_missing_file_defaults`, `test_corrupt_file_defaults`, `test_saves_version_field`. Implementar. PASA. Commit `feat(save): settings store`.

### Tarea 14: Escena de juego jugando solo
**Archivos:** `game/main.tscn`, `game/main.gd`, `game/game_session.gd`, `game/arena.gd`, `game/player_avatar.gd`, `game/iso_camera.gd`, `game/input_reader.gd`, `tests/unit/game/test_input_reader.gd`, `tests/unit/game/test_arena.gd`; añadir textos al CSV.

**Interfaces — produce:**
- `class_name InputReader`: `static func camera_relative_move(raw: Vector2, camera_yaw: float) -> Vector2` (raw: x = derecha, y = arriba en pantalla; devuelve dirección en XZ del mundo, longitud ≤ 1); `static func ground_point(origin: Vector3, direction: Vector3, ground_y: float = 0.0) -> Variant` (`Vector3` o `null` si el rayo no corta el suelo hacia delante).
- `class_name Arena extends Node3D`: `func build(layout: Dictionary) -> CollisionMap` (crea `GridMap` con una `MeshLibrary` generada en código: suelo y 2 colores de bloque, cubos de 1 m; suelo en y = −1; bloques apilados según la altura; luz direccional con sombras y `WorldEnvironment`).
- `class_name PlayerAvatar extends Node3D`: `func setup(name: String, slot: int) -> void` (cápsula de 1,8 m del color del slot: `[#E5533D, #3D8BE5, #4CC26A, #E5C33D]`; `Label3D` con `billboard`, `fixed_size` y `no_depth_test` para que se vea nítido; flecha en el suelo hacia `facing`); `func apply_state(state: Dictionary) -> void`.
- `class_name IsoCamera extends Camera3D`: `@export pitch_deg := 55.0`, `yaw_deg := 45.0`, `distance := 18.0`, `min_distance := 10.0`, `max_distance := 30.0`; `func follow(target: Vector3) -> void`; rueda → zoom; `F9` alterna `PROJECTION_PERSPECTIVE`/`PROJECTION_ORTHOGONAL` (tamaño ortográfico proporcional a la distancia).
- `class_name GameSession extends Node`: `func start_host(player_name: String) -> void` (crea `HostSession`, `MemoryNetwork` de bucle local y su `ClientSession`); `func open_group() -> String` (crea `EnetTransport.host(port, 3)`, lo añade al host y devuelve `GroupCode.encode(pick_host_ip(IP.get_local_addresses()))`; `""` si falla, con `last_error`); `func join(code: String, player_name: String) -> Error`; `func leave() -> void`; `var client: ClientSession`; `var input_blocked: bool` (lo activa el chat); en `_physics_process` hace `client.tick` y `host.tick`; en `_process` hace `client.update`, sincroniza avatares con `roster` y mueve la cámara. Argumentos de usuario `--lag=<ms>` y `--loss=<pct>` envuelven el transporte remoto del cliente en `LaggyTransport`.
- Acciones de `InputMap` en `project.godot`: `move_up/down/left/right` (WASD), `chat` (Enter), `menu` (Esc), `debug_overlay` (F3), `toggle_projection` (F9).

- [ ] Tests (fallan): `test_w_moves_screen_up` (yaw 45° → `(0,1)` sale `(-0.707, -0.707)` ± 0,001 en la convención de la cámara; documentar la convención en el test); `test_diagonal_input_clamped`; `test_ground_point_hits_plane`; `test_ground_point_parallel_ray_is_null`; `test_arena_collision_matches_layout`.
- [ ] Implementar. PASA. Ejecutar el juego (`"$GODOT" --path .`) y comprobar a mano solo que arranca sin errores en la consola (las pruebas de juego son del usuario). Commit `feat(game): isometric camera and capsule playing solo`.

### Tarea 15: Interfaz — título, menú, chat, avisos y depuración
**Archivos:** `ui/title_screen.gd`, `ui/pause_menu.gd`, `ui/chat_box.gd`, `ui/debug_overlay.gd`, `ui/message_dialog.gd`, `tests/unit/ui/test_chat_box.gd`, `tests/unit/ui/test_title_screen.gd`; modificar `game/main.gd`, `data/texts/textos.csv`.

**Interfaces — produce:**
- `TitleScreen extends Control`: señales `play_requested(name: String)`, `join_requested(name: String, code: String)`, `quit_requested()`; muestra `tr("GAME_TITLE")` y `"v" + version`; botones desactivados mientras el nombre no sea válido (`HostSession.is_valid_name`); precarga `SettingsStore`.
- `PauseMenu extends Control`: señales `resume_requested`, `leave_requested`, `open_group_requested`; `func show_code(code: String)` (código grande y botón Copiar → `DisplayServer.clipboard_set`).
- `ChatBox extends Control`: señal `message_submitted(text: String)`, señal `typing_changed(is_typing: bool)`; `func add_message(author: String, text: String, is_system: bool)`; últimos 8, se desvanecen a los 10 s (vuelven a verse mientras se escribe); `Label` sin BBCode; `max_length = chat_max_len`.
- `DebugOverlay extends Label`: FPS, ping, tick, pendientes, última corrección; F3.
- `MessageDialog extends Control`: `func show_message(text: String)`.
- `main.gd` une todo: título → partida (solo); Esc → menú; "Abrir grupo" → código; "Unirse" → `GameSession.join`; `rejected` → diálogo `tr("ERR_VERSION") % [host_version, mi_version]` / `ERR_FULL` / `ERR_NAME`; `disconnected` → vuelta al título con `ERR_HOST_LEFT` / `ERR_TIMEOUT` / `ERR_CONNECT`; código inválido → `ERR_BAD_CODE` sin intentar conectar. Guarda nombre y último código.
- Textos (CSV): `ERR_VERSION` = "El grupo usa la versión %s y tú tienes la %s. Actualiza el juego para unirte.", más `ERR_FULL`, `ERR_NAME`, `ERR_HOST_LEFT`, `ERR_TIMEOUT`, `ERR_CONNECT`, `ERR_BAD_CODE`, `ERR_PORT`, `CHAT_JOINED` ("%s se ha unido al grupo"), `CHAT_LEFT`, y todas las etiquetas de botones y campos.

- [ ] Tests (fallan): `test_enter_opens_and_empty_enter_closes` (Enter con texto vacío → no emite `message_submitted`, `typing_changed(false)`); `test_typing_blocks_movement` (con `GameSession` en modo solo: escribir activa `input_blocked` y `tick` envía move cero); `test_keeps_last_8_messages`; `test_long_text_limited`; `test_title_buttons_disabled_for_invalid_name`; `test_all_ui_fits_1280x720` (cada pantalla instanciada a 1280×720 → ningún `Control` visible sale de la ventana y no hay `ScrollContainer`).
- [ ] Implementar. PASA. Commit `feat(ui): title, pause menu with group code, chat and dialogs`.

### Tarea 16: Arranque sin ventana
**Archivos:** `tests/integration/test_headless_boot.gd`.
- [ ] Test: instanciar `game/main.tscn`, simular "Jugar" con nombre "Prueba", conectar un `ClientSession` extra al host por `MemoryNetwork` (añadiendo su transporte al host), moverlo 1 s, enviar un chat, salir al título → sin errores en el registro (`assert_no_new_orphans`, cero errores de GUT) y el segundo jugador visible como avatar en la escena.
- [ ] PASA (suite completa). Commit `test: headless boot and join smoke test`.

### Tarea 17: Exportación y publicación de la 0.1.0
**Archivos:** `export_presets.cfg`, modificar `.github/workflows/ci.yml`, `README.md`.
- [ ] `export_presets.cfg`: preajuste `"Windows Desktop"`, `x86_64`, `binary_format/embed_pck=true`, `application/modify_resources=false`, salida `exports/windows/ThalandorOnline.exe`, excluye `tests/*`, `addons/gut/*`, `docs/*`.
- [ ] `"$GODOT" --headless --path . --export-release "Windows Desktop" exports/windows/ThalandorOnline.exe` → el `.exe` existe y arranca (`--headless --quit-after 60` sin errores).
- [ ] CI: trabajo `release` en etiquetas `v*` (tras `test`): descarga plantillas 4.7.2, exporta, comprime `ThalandorOnline-<versión>-windows.zip` y lo sube con `gh release create` con notas en español (cómo abrir, aviso de SmartScreen, cortafuegos, qué probar).
- [ ] Commit `build: Windows export and tagged releases`. Push; `git tag v0.1.0`; push de la etiqueta; `gh run watch` en verde; `gh release view v0.1.0` muestra el `.zip`.
- [ ] Documentación: GDD §2.4, §3, §9.4, §13 → [En curso]/[Implementado] según corresponda; `Registro de cambios`; tabla de `Planes`.
- [ ] **Entregar al usuario las instrucciones de prueba** (dos ventanas en su PC, con y sin `--lag=150 --loss=5`; y opcionalmente con un amigo por Tailscale). **Esperar su resultado** antes de la tarea 18.

### Tarea 18: Prueba entre casas (spike de red)
Se trata como spike: el código de WebRTC se queda solo si gana.
- [ ] **Pedir permiso** para descargar `webrtc-native 1.2.2` (35 MB, GitHub oficial) y copiar solo la versión de Windows a `addons/webrtc/`.
- [ ] **Preguntar al usuario** el alojamiento de la señalización (Cloudflare Workers o Deno Deploy, plan gratuito; necesita una cuenta suya). Escribir el servidor (`tools/signaling/`, < 150 líneas: salas por código, reenvío de oferta/respuesta/candidatos por WebSocket, salas que caducan) y desplegarlo con su permiso.
- [ ] `net/webrtc_transport.gd` (`WebRTCMultiplayerPeer` en malla con el host como id 1, STUN `stun:stun.l.google.com:19302`) y un `Lobby` WebRTC que usa el código de sala; alternar con el argumento `--net=webrtc|enet`. Test con dos pares en localhost.
- [ ] Publicar `0.1.1` con ambas opciones. **Instrucciones de la prueba** al usuario: las dos opciones, qué mirar en F3, plantilla de resultados (conecta sí/no, ping, tirones, esfuerzo de preparación).
- [ ] Con los resultados: aplicar la regla de la spec §10; nueva decisión `D-010` en `Decisiones/`; actualizar §2.5 y §15; si gana ENet, quitar WebRTC y el servidor; si gana WebRTC, convertirlo en la opción por defecto con sus tests. Publicar `0.2.0`.

### Tarea 19: Cierre del plan
- [ ] Suite completa PASA en local y en CI.
- [ ] Revisión final de toda la rama (`requesting-code-review`) y corrección de lo que salga.
- [ ] GDD: estados finales, `Registro de cambios`, `Planes.md` (Plan 1 → Hecho), nota de sesión en `Sesiones/`.
- [ ] Resumen al usuario: qué se hizo, qué falta, qué probar.

---
← [[Planes]]
