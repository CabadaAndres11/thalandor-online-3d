---
tags: [plan]
plan: 8.1
fecha: 2026-11-22
estado: aprobado
actualizado: 2026-11-22
---
# Plan 8.1 — Zonas y mundo: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [ ]`.

**Objetivo:** varias zonas vivas en el anfitrión, descritas como datos de piezas, con salidas, hordas, mazmorras instanciadas, guardado de la ubicación y grupo bloqueado hasta el tutorial. Sale como **0.11.0**.

**Arquitectura:**
- **Lectura de zonas:** `ZoneLayout` (en `sim/`) lee `data/zones/<id>.json` y `data/zones/pieces.json` y crea el `CollisionMap`, las hordas, las salidas y las entradas.
- **Mundos en el anfitrión:** `ZoneManager` (en `net/`) guarda un `SimWorld` por zona abierta o instancia. `HostSession` sabe en qué mundo está cada jugador, avanza solo los mundos ocupados y envía a cada uno lo de su mundo.
- **Cliente:** recibe `ZONE` y `GameSession` cambia su `ZoneView` (sustituye a `Arena`) y el mapa de predicción.

**Técnica:**
- Godot 4.7.2 con GDScript y GUT; tests con `./run_tests.sh`.
- Generadores de arte en Node; tests con `node --test tools/art/tests/`.

**Spec:** [[Plan 8.1 — Zonas y mundo (spec)]]

## Restricciones globales
- Añadir una zona son solo datos: nada de `sim/` ni de la red cambia por zona.
- Un jugador no recibe snapshots, eventos ni botín de otro mundo.
- Las zonas vacías no avanzan. Las instancias vacías se cierran a los **300 s**.
- No se cambia de zona en combate: si un enemigo te golpeó hace menos de **5 s**.
- Las hordas reponen de una en una cada **8 s** por defecto.
- La dificultad de una mazmorra va del nivel del jugador **−5 a +10**, dentro de `[arena_min, arena_max]` del balance.
- **`CharacterData.VERSION = 5`**. Los guardados de la 0.10 se abren en la entrada `default` de `aldea` y con `tutorial_done = true`.
- Textos del juego en `data/texts/textos.csv`.
- Las piezas se hacen por código, a vóxel de 5 cm.

## Puntos de revisión
1. **Cerrar el juego o perder la conexión dentro de una mazmorra:** al volver se aparece en la entrada de la mazmorra, en la zona de fuera, nunca en una instancia que ya no existe.
2. **Dos jugadores pisan una salida a la vez, o uno muere justo al cruzar:** cada uno acaba en un único mundo, sin duplicarse ni quedarse sin mundo.
3. **Una zona con una pieza, un tipo de monstruo o una salida a una zona que no existen:** error claro con el nombre al cargarla, y la partida no se cae: la salida se ignora.
4. **El anfitrión cambia de zona mientras un invitado se queda en otra:** el invitado sigue jugando con normalidad, y su mundo no se duerme.
5. **Un invitado que se une con una zona guardada que el anfitrión no conoce** (otra versión de datos o un guardado tocado a mano): aparece en la aldea.

Cada punto tiene su test en la tarea correspondiente (1 → T9; 2 → T6; 3 → T1 y T6; 4 → T5; 5 → T9).

---

### Task 1: Zonas como datos (`ZoneLayout`)
**Archivos:**
- Crear `sim/zone_layout.gd`, `data/zones/pieces.json` (de momento a mano, con las huellas de 3 piezas de prueba) y `data/zones/test_small.json`, solo para los tests.
- Tests: `tests/unit/sim/test_zone_layout.gd`.

**Interfaces que produce:**
- `class_name ZoneLayout extends RefCounted`.
- `const DIR := "res://data/zones/"`.
- `static func load_id(id: String) -> ZoneLayout`: devuelve `null` y lanza `push_error` con el id si no existe.
- Campos:
  - `id`, `name: String`, `size: Vector2i`, `ambience: String`, `levels: Vector2i`;
  - `safe: bool`, `instanced: bool`;
  - `pieces: Array` (las colocadas, ya con el relleno expandido): `{id, at: Vector2i, rot: int}`;
  - `terrain: Array`, `paths: Array`, `npcs: Array`;
  - `exits: Array`: `{area: Rect2i, to: String, entry: String}`;
  - `entries: Dictionary`: nombre → `Vector2i`;
  - `respawn: Vector2i`;
  - `hordes: Array`, `spawns: Array`, `torches: Array`.
- `func collision() -> CollisionMap`:
  - los sólidos salen de las huellas giradas, el agua y los `blocks` antiguos;
  - `spawn_cell` es `entries.default` y `respawn_cell` es `respawn`;
  - incluye los `spawns`, las `hordes` y los `npcs`.
- `func entry(name: String) -> Vector3`: devuelve `default` si el nombre no existe.
- `func exit_at(pos: Vector3) -> Dictionary`: `{}` si no hay salida ahí.
- `static func piece_def(id: String) -> Dictionary`: lee `pieces.json` con `{vox, scale, footprint: [[dx, dz], …]}`.
- `CollisionMap` gana `var hordes: Array = []` y `var zone_id: String = ""`.

**Reglas:**
- **Giro de una huella** de 90 en 90 grados: `(dx, dz)` pasa a `(−dz, dx)` en cada paso.
- **Relleno (`scatter`):** RNG con la semilla del área. Coloca una pieza por casilla con probabilidad `density`, nunca en una casilla de un `path` (ni en su anchura), de otra pieza o de agua. Las salidas y entradas quedan libres en un radio de 2.
- **Caminos:** una polilínea de casillas con `width` y su `terrain`.

**Pasos:**
- [ ] Tests:
  - `test_loads_and_builds_collision`;
  - `test_rotated_footprint`: una pieza de 2×1 girada 90° ocupa `(x, z)` y `(x, z+1)`;
  - `test_scatter_skips_paths_and_is_deterministic`;
  - `test_water_is_solid`;
  - `test_old_blocks_still_work` (la arena);
  - `test_unknown_piece_errors_with_its_name`;
  - `test_exit_at_and_entry_default`.
- [ ] Ejecutar `./run_tests.sh res://tests/unit/sim/test_zone_layout.gd`: debe **fallar**.
- [ ] Implementar.
- [ ] Ejecutar: debe **pasar**.
- [ ] Commit: `feat: zones as data (ZoneLayout, pieces with footprints, scatter, paths)`.

### Task 2: Las piezas del mundo (arte)
**Archivos:**
- Crear `tools/art/make_world.mjs`, que escribe `assets/world/<id>.vox` y `data/zones/pieces.json`, con la huella calculada de la base del modelo: las casillas de 1 m con vóxeles por debajo de 1,2 m de alto.
- Tests: `tools/art/tests/world.test.mjs`.

**Piezas:**
- `house_small` (4×4 m), `house_large` (6×5 m) y `house_forge` (6×6 m, con yunque y chimenea);
- `fence` (2 m), `wall_low` (2 m), `well`, `cart` y `crates`;
- `tree_oak`, `tree_pine`, `bush`, `rock_small`, `rock_large` y `stump`;
- `bridge` (4×2 m, que **no** bloquea: huella vacía), `torch` (el modelo de hoy) y `crypt_arch`, `crypt_wall` y `crypt_pillar`.
- Paleta propia: madera, paja, piedra, musgo y hojas en dos o tres tonos, como el resto del arte.

**Pasos:**
- [ ] Tests de Node:
  - existen todas las piezas y caben en 126³;
  - la huella de una casa cubre su planta;
  - la del puente está vacía;
  - la del árbol es su tronco (1 casilla) y no su copa;
  - `pieces.json` tiene `vox`, `scale` (0.5) y `footprint`.
- [ ] Comprobar que fallan.
- [ ] Implementar, generar y comprobar que pasan.
- [ ] Commit: `art: world pieces (village houses, forest, rocks, crypt) with footprints`.

### Task 3: Dibujar una zona (`ZoneView`)
**Archivos:**
- Crear `game/zone_view.gd`, a partir de `game/arena.gd`, que se borra.
- Convertir `data/maps/test_arena.json` en `data/zones/arena.json`.
- Modificar `game/game_session.gd` (`arena` pasa a `zone_view`) y `tests/helpers/render_*.gd`.
- Tests: `tests/unit/game/test_zone_view.gd` (y los de la arena que haya, actualizados).

**Interfaces:**
- `class_name ZoneView extends Node3D`.
- `func build(layout: ZoneLayout, quality: int) -> void`:
  - **suelo:** un `MeshInstance3D` por tipo de terreno, a partir de las casillas pintadas;
  - **piezas:** un `MultiMeshInstance3D` por id de pieza;
  - las antorchas como hoy, con la iluminación de `layout.ambience`.
- Se conservan `set_ambience(id) -> bool`, `set_quality(q)`, `follow(pos)` y `torches`.

**Pasos:**
- [ ] Tests:
  - `test_one_multimesh_per_piece_kind` (con 50 árboles, un solo nodo de árboles);
  - `test_terrain_meshes_per_kind`;
  - `test_arena_zone_still_builds` (los mismos sólidos que antes);
  - `test_frees_cleanly`.
- [ ] Comprobar que fallan.
- [ ] Implementar y migrar `GameSession`.
- [ ] Comprobar que pasan, y también la suite completa.
- [ ] Commit: `feat: ZoneView draws zones from data (terrain, multimesh pieces); arena becomes a zone`.

### Task 4: Hordas
**Archivos:**
- Modificar `sim/ai/spawner.gd` y `sim/sim_world.gd`, para que el `Spawner` se cree con `map.spawns` y `map.hordes`.
- Tests: `tests/unit/sim/test_spawner.gd`.

**Reglas:**
- **Formato de horda:** `{"area": [x, z, w, d], "monsters": [["marked_hound", 3], ["marked_boar", 1]], "levels": [5, 9], "count": 12, "respawn_s": 8, "elite_chance": 0.08}`.
- **Al empezar** llena `count` monstruos. Cada muerto pide uno nuevo a los `respawn_s` de su muerte. El tipo sale por peso y el nivel, al azar en `levels`. Aparece en una casilla libre del área.
- **En una zona con nivel de instancia**, la horda usa ese nivel y no `levels`. En el mundo abierto no se usa `arena_level`.
- `MonsterState` gana `horde_index` (−1 si no es de horda).

**Pasos:**
- [ ] Tests:
  - `test_horde_fills_to_count`;
  - `test_horde_respawns_one_by_one_after_respawn_s`;
  - `test_horde_levels_within_band`;
  - `test_horde_types_by_weight` (con 400 apariciones, la proporción se acerca a 3:1);
  - `test_points_still_work`.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: hordes that keep zones full of monsters in their level band`.

### Task 5: Varias zonas en el anfitrión (`ZoneManager`)
**Archivos:**
- Crear `net/zone_manager.gd`.
- Modificar `net/host_session.gd`:
  - `world` deja de ser único: `func world_of(id: int) -> SimWorld`;
  - cada registro de jugador gana `zone_key`;
  - el tick avanza cada mundo ocupado, envía snapshots y eventos por mundo y aplica los mensajes de grupo a todos.
- Modificar `game/game_session.gd` y los tests que usan `host.world`: pasan a `host.world_of(id)` o a `host.zones.world(key)`.
- Tests: `tests/unit/net/test_zone_manager.gd` y `tests/unit/net/test_host_session.gd`.

**Interfaces:**
- `class_name ZoneManager extends RefCounted`.
- `func _init(balance: Balance, seed: int)`.
- `func open(zone_id: String, instance: String = "", level: int = 0) -> String`: devuelve la clave del mundo; para una zona normal es su id, y para una instancia, `"<id>#<instance>@<level>"`.
- `func world(key: String) -> SimWorld` y `func layout(key: String) -> ZoneLayout`.
- `func step_occupied(inputs_by_key: Dictionary) -> void`.
- `func occupants(key: String) -> Array[int]`.
- `func move(id: int, from_key: String, to_key: String, at: Vector3) -> PlayerState`: saca el `PlayerState` de un mundo y lo mete en otro, el mismo objeto.
- `func close_idle(now_s: float) -> void`: cierra las instancias vacías desde hace 300 s.
- `func keys() -> Array`.
- **Escala de vida:** el `Spawner` usa `world.players.size()`, que ya cuenta solo los de ese mundo.

**Pasos:**
- [ ] Tests:
  - `test_two_zones_only_their_snapshots`: un monstruo de la zona A no aparece en las filas que recibe B;
  - `test_events_stay_in_their_world` (golpes y botín);
  - `test_empty_zone_does_not_tick_and_keeps_monsters`;
  - `test_instance_closes_after_300s_empty`;
  - `test_chat_and_party_reach_everyone`;
  - `test_host_leaving_a_zone_does_not_sleep_the_guests_zone` (punto de revisión 4).
- [ ] Comprobar que fallan.
- [ ] Implementar.
- [ ] Comprobar que pasan, y también la suite completa: los tests de red e integración se adaptan a `world_of`.
- [ ] Commit: `feat: the host runs one world per zone and sends each player only its own`.

### Task 6: Pasar de una zona a otra
**Archivos:**
- Modificar `net/host_session.gd` (salidas, `/zona` y `/zonas`) y `net/protocol.gd` (`Msg.ZONE: [["zone", STRING], ["key", STRING], ["level", INT]]` y `Msg.PARTY: [["rows", ARRAY]]`, que sube `Protocol.VERSION`).
- Modificar `sim/combat/combat.gd` (reaparecer en el `respawn` del mapa del propio mundo, que ya ocurre) y `PlayerState` (`last_hit_tick`).
- Tests: `tests/unit/net/test_zone_travel.gd`.

**Reglas:**
- **Salida:** tras el `step`, el anfitrión mira la posición de cada jugador vivo. Si está en una salida y no ha recibido golpe en 5 s: abre o toma el destino, lo mueve a la entrada y le envía `ZONE`. Si está en combate, envía una vez cada 3 s el evento `zone_blocked` (el chat lo traduce).
- **Salida a una zona inexistente:** se ignora, con `push_error` una sola vez.
- **`PARTY`:** cada segundo, a cada jugador, `[id, zone_name, level, hp_ratio]` de los compañeros de **otros** mundos.
- **Un jugador derribado o muerto** no cruza.

**Pasos:**
- [ ] Tests:
  - `test_exit_moves_to_entry_keeping_inventory_level_hp`;
  - `test_exit_blocked_in_combat`;
  - `test_two_players_cross_the_same_tick` (punto de revisión 2);
  - `test_dead_player_does_not_cross`;
  - `test_exit_to_unknown_zone_is_ignored` (punto 3);
  - `test_zone_command_moves_and_lists`;
  - `test_party_rows_for_other_zones`.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: exits move players between zones, blocked in combat; party rows across zones`.

### Task 7: El cliente cambia de zona
**Archivos:**
- Modificar `net/client_session.gd`:
  - `signal zone_changed(zone_id: String, key: String, level: int)`;
  - al recibir `ZONE`, cambia `map` por `ZoneLayout.load_id(zone).collision()`, vacía monstruos y botín, y fija `party_rows`.
- Modificar `game/game_session.gd`: `func _on_zone_changed(...)` reconstruye `zone_view`, los PNJ, la cámara y el botín, muestra `LoadingOverlay` y la quita en la primera snapshot del mundo nuevo.
- Crear `ui/loading_overlay.gd`: el nombre de la zona sobre fondo oscuro, con `StoneTheme`.
- Modificar `ui/party_frames.gd`, para mostrar el nombre de la zona de un compañero lejano.
- Tests: `tests/unit/net/test_client_session.gd`, `tests/unit/ui/test_loading_overlay.gd` y `tests/integration/test_zone_travel_flow.gd`.

**Pasos:**
- [ ] Tests:
  - `test_zone_message_swaps_the_prediction_map`;
  - `test_game_rebuilds_view_and_npcs_on_zone` (sin nodos del mapa viejo, sin fugas);
  - `test_loading_overlay_until_first_snapshot`;
  - `test_party_frames_show_far_zone`;
  - integración: dos procesos, uno cruza al bosque y el otro sigue en la aldea, cada uno con sus monstruos.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: the client follows its player across zones with a loading screen`.

### Task 8: Mazmorras instanciadas
**Archivos:**
- Modificar `net/host_session.gd`:
  - una salida a una zona `instanced` no cruza directamente: envía `Msg.DUNGEON_OFFER [zone, min, max, default, current_level]`;
  - el cliente responde `Msg.ENTER_DUNGEON [zone, level]`;
  - si un compañero ya está en una instancia de esa zona, se entra en la suya.
- Modificar `sim/sim_world.gd`: `arena_level` pasa a ser `instance_level` y se fija al abrir el mundo. `set_arena_level` sigue sirviendo solo en la zona `arena` (Brann).
- Crear `ui/dungeon_window.gd`: el nivel con ◀ ▶, Entrar y Cancelar, con `HoloTheme`, porque es una ventana del juego.
- Crear `data/zones/cripta_prueba.json` (`instanced: true`).
- Tests: `tests/unit/net/test_dungeons.gd` y `tests/unit/ui/test_dungeon_window.gd`.

**Pasos:**
- [ ] Tests:
  - `test_instanced_exit_offers_level_range` (−5 a +10, recortado al balance);
  - `test_enter_creates_instance_at_level`: los monstruos de la instancia tienen ese nivel;
  - `test_partner_joins_existing_instance_even_with_other_level`;
  - `test_death_in_dungeon_respawns_at_its_entry`;
  - `test_window_fits_1280x720_and_emits`.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: instanced dungeons with a difficulty chosen at the door`.

### Task 9: Guardar dónde está el personaje
**Archivos:**
- Modificar:
  - `save/character_data.gd`: versión 5, con `place: {zone, at: [x, z]}`;
  - `net/protocol.gd`: HELLO gana `place: Dictionary`, y un mensaje `Msg.PLACE` va del anfitrión al cliente con la posición cada 30 s y al cambiar de zona;
  - `net/host_session.gd`: el `_on_hello` coloca al jugador según `place`, con validación;
  - `game/main.gd`: guarda al recibir `PLACE` y al salir.
- Tests: `tests/unit/save/test_character_data.gd`, `tests/unit/net/test_host_session.gd` y `tests/unit/ui/test_main_flow.gd`.

**Reglas:**
- **Validación de `place` en el anfitrión:**
  - si la zona no existe, se aparece en `aldea`;
  - si es `instanced`, se aparece en la entrada de su salida en la zona de fuera (la que tenga una salida hacia ella; si no hay ninguna, `aldea`);
  - si la posición es sólida o está fuera del mapa, en la entrada `default`.
- **El `PLACE` de una instancia** guarda ya la entrada de fuera.

**Pasos:**
- [ ] Tests:
  - `test_v4_save_opens_in_the_village`;
  - `test_place_roundtrip`;
  - `test_saved_inside_dungeon_returns_to_its_door` (punto de revisión 1);
  - `test_unknown_zone_place_goes_to_village` (punto 5);
  - `test_solid_place_goes_to_default_entry`;
  - `test_main_saves_place_on_message_and_on_leave`.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: characters remember their zone and position (save v5)`.

### Task 10: Sin juego en grupo hasta terminar el tutorial
**Archivos:**
- Modificar:
  - `save/character_data.gd`: `tutorial_done: bool`; la migración de v4 lo pone a `true`;
  - HELLO, que lo lleva dentro de `place`;
  - `net/host_session.gd`: rechaza a un invitado sin la marca con `reject("tutorial")` y añade el comando `/tutorial hecho`;
  - `ui/pause_menu.gd`: `set_group_locked(locked)` desactiva **Abrir grupo** y muestra el aviso `GROUP_LOCKED_TUTORIAL`;
  - `ui/character_select_screen.gd`: desactiva **Unirse** si el personaje elegido no tiene la marca;
  - `game/main.gd`: `ERR_TUTORIAL` y la actualización de la marca.
- Tests: `tests/unit/ui/test_main_flow.gd`, `tests/unit/net/test_host_session.gd` y `tests/unit/ui/test_character_screens.gd`.

**Pasos:**
- [ ] Tests:
  - `test_new_character_cannot_open_group_or_join`;
  - `test_old_character_can`;
  - `test_host_rejects_guest_without_tutorial`;
  - `test_tutorial_command_unlocks_and_saves`.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: playing in a group unlocks after the village tutorial`.

### Task 11: Aldea, bosque y cripta provisionales
**Archivos:**
- Crear `data/zones/aldea.json` (unos 96×96 m):
  - casas, forja, pozo, vallas, caminos y un claro;
  - Brann en la forja y el mercader en la plaza;
  - salida al este hacia el bosque;
  - nivel 1–5, con una horda pequeña de jabalíes fuera de la empalizada.
- Crear `data/zones/bosque.json` (unos 160×128 m):
  - bosque de relleno con un camino que lo cruza;
  - tres hordas (5–9 sabuesos y jabalíes, 9–14 cultistas y 14–20 una mezcla con élites);
  - el campamento de bandidos como horda de cultistas por ahora;
  - salida oeste a la aldea y entrada a la cripta de prueba.
- Completar `data/zones/cripta_prueba.json` (unos 48×64 m): pasillos con `crypt_wall` y `crypt_pillar`, dos hordas y el Acólito como jefe al fondo.
- Textos `ZONE_*`.
- Cambiar la zona de inicio: los personajes nuevos aparecen en la aldea.
- Renders: `tests/helpers/render_zone.gd -- --zone=aldea|bosque|cripta_prueba`, con una vista cenital y una isométrica.

**Pasos:**
- [ ] Test `test_demo_zones_load_and_connect`:
  - todas las zonas de `data/zones/` cargan sin errores;
  - cada salida apunta a una zona y una entrada existentes;
  - cada entrada es transitable y llega a la entrada `default` por casillas libres (BFS).
- [ ] Comprobar que falla.
- [ ] Crear las zonas y comprobar que pasa.
- [ ] Capturas para el usuario.
- [ ] Commit: `content: provisional village, forest and test crypt`.

### Task 12: Documentación y versión
**Archivos:**
- `project.godot` → `0.11.0`.
- GDD:
  - `06 Mundo.md` (§6.1 [Implementado], §6.3 con el formato de zona y la tabla de zonas de la demo nueva, según el guion);
  - `14 Hoja de ruta.md` (el Plan 8 en partes y el fin de la demo, misión 14);
  - `04 Personajes y progresión.md` (subir con hordas; las misiones dan 1–2 niveles);
  - `09 Interfaz.md` (grupo bloqueado en el tutorial; ventana de mazmorra);
  - `10 Guardado.md` (versión 5);
  - `Registro de cambios.md`.
- `docs/Decisiones/D-017 Mundo por zonas, hordas y demo del prólogo y arco 1.md` y el índice.
- `docs/Planes/Planes.md` y las sesiones.
- `tools/art/README.md` (`make_world.mjs`).

**Pasos:**
- [ ] Actualizar los documentos.
- [ ] Ejecutar la suite completa y los tests de Node: deben **pasar**.
- [ ] Commit: `docs: Plan 8.1 zones and world (0.11.0)`.
- [ ] Revisión final de la rama y prueba de juego del usuario.

---
← [[Planes]]
