---
tags: [plan]
plan: 8.2
fecha: 2026-11-25
estado: borrador
actualizado: 2026-11-25
---
# Plan 8.2 — Misiones, diálogos y escenas: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [ ]`. Cada tarea: test que falla → código → tests en verde → commit.

**Objetivo:** el motor de la historia: misiones como datos que lleva el anfitrión, diálogos, escenas con los modelos del juego, momentos a solas en una zona propia, diario y marcas, con una cadena de ejemplo para probarlo. Sale como **0.12.0**.

**Arquitectura:**
- **Reglas en `sim/quests/`** (sin nodos ni red): `QuestDB` lee los datos, `QuestLog` es el estado de un jugador y `QuestRules` avanza objetivos con los sucesos de la simulación y con las peticiones validadas.
- **Red:** como el progreso y la bolsa. El estado viaja en `HELLO`, el anfitrión lo lleva en `PlayerState.quests` y devuelve `QUESTS` al cambiar. El cliente pide con `QUEST_ACTION`.
- **Cliente:** `DialogueRunner` (lógica pura) con `DialogueWindow`, `CutscenePlayer` (nodo con reloj inyectable) con `CutsceneOverlay`, y diario, objetivo seguido y marcas en `ui/`.
- **Momentos:** `ZoneLayout.apply_variant()` y una instancia personal en `ZoneManager` con la clave `"<zona>~<variante>#p<id>"`.

**Técnica:** Godot 4.7.2, GDScript, GUT (`./run_tests.sh [res://tests/...]`).

**Spec:** [[Plan 8.2 — Misiones, diálogos y escenas (spec)]]

## Restricciones globales
- Una misión, un diálogo o una escena nuevos son **solo datos** (`data/quests/`, `data/dialogues/`, `data/cutscenes/`). Nada de `sim/`, `net/` ni `ui/` cambia por misión.
- Textos del juego en `data/texts/textos.csv` (claves `QUEST_*`, `DLG_*`, `SCN_*`, `UI_QUEST_*`), con `{nombre}` y `{apodo}`.
- `CharacterData.VERSION = 6`, `Protocol.VERSION = 9`.
- Radio de grupo para `kill`, `collect` y `reach`: `balance.xp.share_range` (30 m), el mismo que la experiencia.
- `reach` se comprueba cada **0,5 s**. Hablar exige estar a `NpcDB.TALK_RANGE` (2,5 m) del PNJ; examinar, a **2,5 m** del punto.
- Recompensa `levels: N`: la experiencia que falta para subir N niveles desde el nivel y la experiencia actuales.
- Objetos de misión: `slot: "quest"` en `bases.json`, se apilan hasta **99**, bloqueados para equipar, usar y vender; Ordenar los pone al final.
- Saltar escena: mantener **Esc 0,5 s**. Fundido de luz por defecto: **3 s**.
- Ninguna ventana con scroll a 1280×720.
- Lo que nadie del mundo lleva no cuesta: si ningún jugador tiene un objetivo de un tipo, `QuestRules` no recorre nada por él.

## Puntos de revisión
1. **Salir o desconectarse a mitad de una escena o un diálogo:** al volver, el objetivo sigue pendiente y el jugador no se queda «en escena» (invulnerable) para siempre. El anfitrión quita `in_scene` al salir, al cambiar de zona y a los **120 s**. → T7.
2. **Un guardado con una misión, un paso o una marca que ya no existen en los datos** (versión anterior o editado a mano): se sanea sin caerse y la misión desaparece o se recorta. → T3.
3. **Bolsa llena al recoger o al cobrar una recompensa con objetos:** el objeto de misión no cuenta y sale *Bolsa llena*. Una entrega con objetos se rechaza con el mismo aviso y la misión sigue sin entregar, sin perder nada. → T1 y T5.
4. **Morir, quedar abatido o cerrar el juego dentro de un momento a solas:** reaparece dentro de su zona propia (recreada si se cerró), nunca en el mundo compartido a mitad de la historia. → T8.
5. **Dos amigos en pasos distintos hablan con el mismo PNJ:** cada uno ve sus marcas y su diálogo; nada de uno cambia lo del otro. → T9 y T12.

---

### T1. Objetos de misión en la bolsa, bloqueados

**Archivos:** modificar `sim/items/item_db.gd`, `sim/items/inventory.gd`, `sim/items/item_requests.gd`, `sim/items/merchant.gd`, `data/items/bases.json`, `ui/inventory_window.gd`, `ui/item_tooltip.gd`; test `tests/unit/sim/test_quest_items.gd`.

**Interfaces que produce:**
- `ItemDB.is_quest(base_id: String) -> bool` (`slot == "quest"`).
- `Inventory.count_of(base_id: String) -> int`, `Inventory.remove_count(base_id: String, n: int) -> int` (devuelve cuántos quitó).
- `Inventory.add()` apila los de misión hasta `QUEST_STACK := 99`.

- [ ] **Test** `test_quest_items.gd`:
  - `test_quest_item_stacks`: añadir 3 + 2 de `q_colmillo` → `count_of == 5` en una casilla.
  - `test_quest_item_locked`: `ItemRequests.equip`, `ItemRequests.use` y `Merchant.sell` sobre su índice devuelven `false` y la bolsa no cambia.
  - `test_sort_puts_quest_last`: tras `sort_bag`, el objeto de misión ocupa la última casilla ocupada.
  - `test_add_fails_when_full`: bolsa llena sin pila de ese tipo → `add` devuelve `false` (punto de revisión 3).
  - `test_remove_count`: 5 en bolsa, quitar 3 → quedan 2; quitar 9 → devuelve 2 y la casilla queda vacía.
- [ ] Ejecutar: `./run_tests.sh res://tests/unit/sim/test_quest_items.gd` → falla.
- [ ] Implementar. Bases nuevas `q_paquete` y `q_colmillo` (`slot: "quest"`, `level: 1`, nombre `ITEM_Q_PAQUETE` / `ITEM_Q_COLMILLO`). `ItemDB.validate()` acepta `quest`. La ficha muestra *Objeto de misión*; la ventana de bolsa no ofrece equipar, usar ni vender sobre ellos.
- [ ] Tests en verde; `./run_tests.sh` completo en verde.
- [ ] Commit `feat: quest items stack in the bag and cannot be equipped, used or sold`.

### T2. Datos de misiones (`QuestDB`) y su validación

**Archivos:** crear `sim/quests/quest_db.gd`, la carpeta `data/quests/` y los datos de prueba `tests/data/quests/*.json`; test `tests/unit/data/test_quests_data.gd`.

**Interfaces que produce:**
- `QuestDB.load_default() -> QuestDB`, `QuestDB.load_dir(dir: String) -> QuestDB`.
- `quest(id: String) -> Dictionary`, `ids() -> Array`, `by_giver(npc: String) -> Array`, `by_turn_in(npc: String) -> Array`.
- `validate(npcs: NpcDB, monsters: MonsterDB, items: ItemDB, zones_dir: String, dialogues_dir: String, cutscenes_dir: String) -> Array[String]`: un error legible por referencia rota (`"ej_lobos: monstruo desconocido 'lobo'"`).
- Tipos válidos: `talk, deliver, kill, collect, reach, interact, scene, choice`. Cada objetivo normalizado con sus claves (`count` por defecto 1).

- [ ] **Test** `test_quests_data.gd`:
  - `test_every_quest_is_valid`: `QuestDB.load_default().validate(...)` está vacío (protege los datos reales de T13).
  - `test_broken_refs_reported`: un JSON de prueba con PNJ, monstruo, objeto, punto, diálogo y escena inexistentes da un error por cada uno.
  - `test_unknown_objective_type`: tipo `"bailar"` → error.
  - `test_text_keys_exist`: cada `name`, `summary` y `text` existe en `textos.csv`.
- [ ] Falla → implementar → verde → commit `feat: quest data with validation`.

### T3. Estado de misiones y guardado v6

**Archivos:** crear `sim/quests/quest_log.gd`; modificar `save/character_data.gd`, `sim/player_state.gd`; test `tests/unit/save/test_quest_log.gd`.

**Interfaces que produce:**
- `QuestLog`: `active: Dictionary` (`id -> {step: int, counts: Array[int]}`), `done: Array[String]`, `flags: Array[String]`, `marks: Array[String]` (marcas del personaje que pone la historia, p. ej. `tutorial_done`), `tracked: String`.
- `to_dict() -> Dictionary`, `static from_dict(v: Variant, db: QuestDB) -> QuestLog` (saneado), `has_flag(f) -> bool`, `is_done(id) -> bool`, `is_active(id) -> bool`.
- `CharacterData.quests: QuestLog`; al guardar, si `quests.marks` tiene `tutorial_done`, `CharacterData.tutorial_done = true`; `PlayerState.quests: QuestLog`, `PlayerState.quests_dirty: bool`, `PlayerState.in_scene_until_tick: int = -1`.

- [ ] **Test** `test_quest_log.gd`:
  - `test_round_trip`: `from_dict(to_dict())` conserva `active`, `done`, `flags` y `tracked`.
  - `test_migrate_v5`: un guardado v5 abre con `quests` vacío y `version == 6`.
  - `test_sanitize_unknown`: misión desconocida en `active` y en `done` → se quita; `step` mayor que los pasos → se quita la misión; `counts` negativos o mayores que `count` → recortados; `tracked` a una misión no activa → `""` (punto de revisión 2).
  - `test_garbage`: `from_dict("x")` y `from_dict({"active": 5})` → registro vacío, sin errores.
- [ ] Falla → implementar → verde → commit `feat: per-character quest log saved in character files (v6)`.

### T4. Puntos de misión y variantes de zona

**Archivos:** modificar `sim/zone_layout.gd`, `sim/collision_map.gd`; datos de prueba `tests/data/zones/zone_q.json`; test `tests/unit/sim/test_zone_variants.gd`.

**Interfaces que produce:**
- `ZoneLayout.quest_points: Dictionary` (`id -> {at: Vector2i, radius: float, look: String}`); `CollisionMap.quest_points` igual (lo llena `collision()`).
- `ZoneLayout.variants: Dictionary` (datos crudos); `ZoneLayout.apply_variant(name: String) -> ZoneLayout` (copia nueva: `ambience`, `add_pieces`, `remove_pieces` por id de pieza o `at`, `npcs` reemplaza, `hordes` reemplaza, `quest_points` se suman); `has_variant(name) -> bool`.
- Hordas con `"respawn": false` no reponen.

- [ ] **Test** `test_zone_variants.gd`:
  - `test_quest_points_loaded`: el punto `claro` está en `layout.quest_points` y en `collision().quest_points`.
  - `test_variant_adds_and_removes`: la variante `noche` cambia `ambience`, añade una pieza, quita otra y reemplaza los PNJ; la base no cambia.
  - `test_unknown_variant`: `apply_variant("nada")` devuelve `null` y `has_variant` es `false`.
  - `test_no_respawn_horde`: en un `SimWorld` con una horda `respawn: false`, tras matarlos y esperar 60 s no reaparece ninguno.
- [ ] Falla → implementar → verde → commit `feat: quest points and zone variants`.

### T5. Reglas de misiones

**Archivos:** crear `sim/quests/quest_rules.gd`; modificar `sim/progression/xp.gd` (sacar `sharers`), `sim/combat/combat.gd` (llamar a `QuestRules.on_monster_died`), `sim/sim_world.gd` (`quests: QuestDB` y paso de `reach`); test `tests/unit/sim/test_quest_rules.gd`.

**Interfaces que consume:** `QuestDB`, `QuestLog`, `Inventory.count_of/remove_count/add`, `CollisionMap.quest_points`.

**Interfaces que produce** (todas estáticas; `world: SimWorld`, `p: PlayerState`):
- `Xp.sharers(world, m: MonsterState) -> Array` (jugadores vivos a `share_range`; `Xp.share` la usa).
- `can_start(world, p, id) -> bool`, `start(world, p, id) -> bool`.
- `on_monster_died(world, m: MonsterState) -> void` (`kill` y `collect` para cada `sharer` con ese objetivo; `collect` tira `chance` por jugador y mete el objeto en su bolsa).
- El objetivo `choice` se cumple en cuanto el registro tiene alguna marca de su `any_flag` (se comprueba al poner marcas).
- `step_reach(world) -> void` (cada 0,5 s: quien pisa el punto lo cumple, y también los del mundo a `share_range` de él que tengan ese objetivo).
- `report(world, p, kind: String, arg: String) -> bool`, con `kind` en `talk | interact | scene`: valida distancia y que el paso actual lo pida.
- `set_flag_from_dialogue(world, p, dialogue_id: String, flag: String) -> bool` (usa `DialogueRunner.offered_flags`, T9).
- `turn_in(world, p, id: String, choice: String) -> bool`: comprueba que el último paso está hecho, que hay sitio para las recompensas y que `choice` está en `rewards.choice`; si falta sitio emite `["quest_bag_full", p.id]` y devuelve `false` (punto de revisión 3).
- `abandon(world, p, id) -> bool` (no las `story`; quita sus objetos de misión).
- `reward_xp(level: int, xp: int, levels: int, b: Balance) -> int`.
- `check_auto(world, p) -> void`: empieza las `auto` cuyos requisitos se cumplan.
- Efectos de `on_done` (paso o misión): marcas, `clear_flags`, `marks` (se añaden a `p.quests.marks`), `next`, y `scene` y `moment`, que se emiten como sucesos para el anfitrión: `["quest_scene", p.id, scene_id]`, `["quest_moment", p.id, zone, variant]`. También `["quest_step", p.id, id, step]` y `["quest_done", p.id, id]`. Siempre `p.quests_dirty = true`.
- Al terminar o abandonar, se quitan los objetos de misión de sus objetivos `collect` y `deliver`.

- [ ] **Test** `test_quest_rules.gd` (con `CombatFixture` y `tests/data/quests/`):
  - `test_requirements`: sin la misión previa, con nivel bajo, con clase equivocada o con una marca prohibida, `can_start` es `false`.
  - `test_steps_in_order`: un objetivo del paso 1 no avanza mientras el paso actual es el 0.
  - `test_kill_shared_nearby`: A y B cerca con el objetivo cuentan 1; C lejos (40 m) y D sin la misión no.
  - `test_collect_rolls_per_player`: con `chance: 1.0` cada uno recibe su objeto; con `0.0`, ninguno.
  - `test_collect_full_bag`: bolsa llena → no cuenta (punto de revisión 3).
  - `test_reach_group`: A pisa el punto; B a 10 m con el objetivo lo cumple; C sin él no.
  - `test_talk_needs_range`: `report(talk)` a 5 m del PNJ → `false`; a 2 m → `true`.
  - `test_deliver_takes_item`: sin el objeto → `false`; con él, se cumple y se quita.
  - `test_on_done_effects`: marcas puestas y quitadas, `next` empieza la siguiente, sucesos `quest_scene` y `quest_moment` emitidos, `tutorial_done` marcado.
  - `test_reward_levels`: nivel 3 con 40 % de experiencia y `levels: 1` → nivel 4 con la misma experiencia sobrante; `levels: 2` → nivel 5.
  - `test_turn_in_bag_full`: recompensa con objeto y bolsa llena → `false`, la misión sigue activa y el oro no cambia.
  - `test_choice_must_be_offered`: `choice` fuera de la lista → `false`.
  - `test_auto_start`: al terminar la previa, la `auto` siguiente está activa.
  - `test_cost_free`: sin objetivos activos de `reach`, `step_reach` no consulta posiciones (contador interno de comprobaciones = 0).
- [ ] Falla → implementar → verde → `./run_tests.sh` completo → commit `feat: host-side quest rules`.

### T6. Red: estado y peticiones de misiones

**Archivos:** modificar `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/game_session.gd`, `game/main.gd` (guardar `quests`); test `tests/unit/net/test_quests_net.gd`.

**Interfaces que produce:**
- `Protocol.VERSION = 9`; `HELLO` gana `quests: TYPE_DICTIONARY`; `Msg.QUESTS: [["quests", TYPE_DICTIONARY]]`; `Msg.QUEST_ACTION: [["action", TYPE_STRING], ["args", TYPE_ARRAY]]`; `Protocol.quests(d)`, `Protocol.quest_action(a, args)`.
- Anfitrión: `_on_quest_action(rec, action, args)` con `accept, talk_done, interact, scene_start, scene_done, choose_flag, turn_in, track, abandon`; `_flush_quests()` en cada tick (manda `QUESTS` si `quests_dirty`); `check_auto` al entrar y tras cada cambio; los sucesos `quest_*` van solo a su dueño.
- Comandos: `/mision <id>`, `/mision paso`, `/mision fin`, `/mision borrar <id>`, `/marca <nombre>`, `/marca quitar <nombre>`.
- Cliente: `signal quests_changed()`, `var quests: QuestLog`, `func request_quest(action: String, args: Array = []) -> void`.

- [ ] **Test** `test_quests_net.gd` (`MemoryNetwork`):
  - `test_hello_carries_quests`: el invitado entra con una misión activa y el anfitrión la tiene en `state_of(id).quests`.
  - `test_change_flows_back`: una muerte que cuenta llega al cliente en `QUESTS` y `client.quests` coincide.
  - `test_guest_completes_chain`: un invitado acepta, mata, habla y entrega una misión de prueba de punta a punta.
  - `test_bad_requests_ignored`: `choose_flag` de una marca no ofrecida, `turn_in` sin terminar, argumentos de tipo erróneo → nada cambia.
  - `test_events_only_to_owner`: `quest_step` de A no le llega a B.
  - `test_commands`: `/mision ej_lobos` la empieza; `/marca x` la pone.
- [ ] Falla → implementar → verde → commit `feat: quests travel between host and guests`.

### T7. A salvo durante una escena

**Archivos:** modificar `sim/player_state.gd`, `sim/ai/monster_ai.gd` (no elegir objetivo en escena), `sim/combat/combat.gd` (sin daño), `net/host_session.gd`; test `tests/unit/sim/test_in_scene.gd`.

**Interfaces que produce:** `PlayerState.in_scene(world) -> bool` (`world.tick < in_scene_until_tick`). `scene_start` solo se acepta fuera de combate (`not _in_combat`) y pone `in_scene_until_tick = tick + 120 s`; `scene_done`, salir, cambiar de zona o morir lo quitan. Suceso de zona `["in_scene", id, bool]` para que los demás pinten el icono. Mientras está en escena, el anfitrión ignora su entrada de movimiento y habilidades.

- [ ] **Test** `test_in_scene.gd`:
  - `test_no_damage_in_scene`: un monstruo pegado al jugador durante 5 s no le baja la vida y no lo tiene de objetivo.
  - `test_not_in_combat`: `scene_start` con un golpe recibido hace 1 s se rechaza.
  - `test_cleared_on_leave_and_timeout`: al desconectarse, al cambiar de zona y a los 121 s, `in_scene` es `false` (punto de revisión 1).
  - `test_objective_survives_disconnect`: desconectarse en escena deja el objetivo `scene` sin cumplir y la misión activa al volver.
- [ ] Falla → implementar → verde → commit `feat: players are safe while watching a cutscene`.

### T8. Momentos a solas (zona propia)

**Archivos:** modificar `net/zone_manager.gd`, `net/host_session.gd`, `net/protocol.gd` (`ZONE` gana `variant`), `net/client_session.gd`, `game/game_session.gd` (construir la variante); datos `data/ambiences/atardecer.json`, `data/ambiences/noche_fuego.json`, `data/ambiences/alba.json`; test `tests/unit/net/test_moments.gd`.

**Interfaces que produce:**
- `ZoneManager.open_personal(zone_id: String, variant: String, player_id: int) -> String` → clave `"%s~%s#p%d"`; se cierra como una instancia vacía.
- `HostSession.send_to_moment(id: int, zone: String, variant: String) -> void`; responde al suceso `quest_moment`. `moment: null` o terminar la misión → vuelve a la zona compartida, a la entrada `default` de esa zona.
- `PLACE` dentro de un momento manda la zona base. Al entrar (`_on_hello`), si el paso activo de alguna misión tiene `moment`, se le manda a su zona propia, recreada (punto de revisión 4).
- La reaparición tras morir dentro de un momento es en la misma instancia (`layout.respawn` de la variante).
- Nadie más entra: `_on_enter_dungeon` y las salidas nunca llevan a una clave `~`.
- `GameSession`: `ZONE` con `variant != ""` → `ZoneLayout.load_id(zone).apply_variant(variant)`. `set_ambience(id: String, fade_s: float = 3.0)`, con interpolación de sol, cielo, niebla y ambiente.

- [ ] **Test** `test_moments.gd`:
  - `test_personal_instance_only_owner`: A va a `zone_q~noche#p1`; B pisa la misma salida y acaba en la zona base.
  - `test_moment_has_variant`: el mundo personal tiene las piezas y PNJ de la variante.
  - `test_return_on_done`: terminar la misión devuelve a A a la zona base y la instancia se cierra a los 300 s.
  - `test_rejoin_inside_moment`: A se desconecta dentro; al volver con su guardado aparece en una zona propia nueva de la misma variante (punto de revisión 4).
  - `test_death_respawns_inside`: A muere dentro y reaparece en la misma clave.
  - `test_ambience_files_load`: los tres ambientes nuevos se leen con `Ambience.load_id`.
- [ ] Falla → implementar → verde → commit `feat: personal story moments in zone variants`.

### T9. Diálogos: datos y lógica

**Archivos:** crear `sim/quests/dialogue_runner.gd` (lógica pura, la usan el cliente y el anfitrión), `sim/quests/npc_talk.gd`; modificar `sim/npc_db.gd` (lee `talk`); datos de prueba `tests/data/dialogues/`; test `tests/unit/sim/test_dialogues.gd`.

**Interfaces que produce:**
- `DialogueRunner.load_id(id: String) -> DialogueRunner` (`null` si no existe); `start(log: QuestLog) -> void`; `current_line() -> Array` (`[speaker, text_key]`); `advance() -> bool` (`false` al llegar a opciones o al final); `choices() -> Array` (filtradas por `if_flags`, `not_flags` y `once`); `choose(i: int) -> Dictionary` (`{flags, action, next}`); `finished() -> bool`.
- `static DialogueRunner.offered_flags(id: String, log: QuestLog) -> Array` (marcas que el diálogo puede poner en este estado; el anfitrión valida con esto).
- `static DialogueRunner.format(key: String, player_name: String, epithet: String) -> String` (`{nombre}`, `{apodo}`).
- `NpcTalk.pick(npc_id: String, log: QuestLog, level: int, class_id: String, quests: QuestDB) -> Dictionary` → `{dialogue: String, quest: String, kind: "offer"|"progress"|"turn_in"|"talk"|"greet"}`. Prioridad: entregar > objetivo `talk`/`deliver` de ese PNJ > ofrecer > progreso > `talk` del PNJ > saludo.
- `NpcTalk.mark(npc_id, log, level, class_id, quests) -> String`: `"!"`, `"!grey"`, `"?"` o `""`.

- [ ] **Test** `test_dialogues.gd`:
  - `test_linear_then_choices`: tres líneas y después dos opciones.
  - `test_once_and_flags`: una opción `once` desaparece al volver; `if_flags` la muestra solo con la marca.
  - `test_offered_flags`: solo incluye marcas de nodos alcanzables en ese estado.
  - `test_format`: `{nombre}` y `{apodo}` sustituidos; `{apodo}` vacío sin la marca `apodo`.
  - `test_pick_priority`: con una misión para entregar y otra para ofrecer en el mismo PNJ, gana entregar.
  - `test_two_players_differ`: dos `QuestLog` en pasos distintos dan diálogos y marcas distintos para el mismo PNJ (punto de revisión 5).
  - `test_all_dialogues_valid`: cada diálogo de `data/dialogues/` carga, cada `next` existe y cada clave de texto está en `textos.csv`.
- [ ] Falla → implementar → verde → commit `feat: dialogue data and logic`.

### T10. Ventana de diálogo y hablar con los PNJ

**Archivos:** crear `ui/dialogue_window.gd`; modificar `game/main.gd` (`_on_interact`), `game/npc_interaction.gd` (`TALK` para cualquier PNJ al alcance; revivir sigue ganando), `game/npc_avatar.gd` (girarse hacia el jugador), `game/iso_camera.gd` (`focus(target: Vector3, amount: float)`); test `tests/unit/ui/test_dialogue_window.gd`.

**Interfaces que produce:**
- `DialogueWindow` con `signal finished(dialogue_id: String)`, `signal action(name: String, arg: String)` y `signal closed()`; `show_for(runner: DialogueRunner, npc_name: String, player_name: String, epithet: String)`. Texto letra a letra a **40 caracteres/s**; E, espacio o clic completa o avanza; teclas 1–4 eligen. Tema de piedra (`StoneTheme`).
- En `main.gd`: al terminar, `request_quest("talk_done", [npc, dialogue])`; las opciones con marca → `choose_flag`; `accept`/`turn_in` → `request_quest`; `trade` → abre la tienda; `train` → el menú de Brann de antes (`trainer_options`). Recibir daño (`combat_event` `hit` sobre mí) o Esc → `closed` sin avisar al anfitrión.

- [ ] **Test** `test_dialogue_window.gd`:
  - `test_fits_without_scroll`: con 4 opciones largas, a 1280×720 nada se sale ni hay barra de scroll (ayudante `render_ui`).
  - `test_advance_and_choose`: avanzar con la acción de interactuar y elegir con la tecla 2 emite `action` con la opción correcta.
  - `test_damage_closes`: un `hit` sobre el jugador cierra la ventana sin `finished`.
  - `test_brann_still_trains`: hablar con Brann siendo aldeano ofrece elegir clase; con clase, el menú de siempre.
- [ ] Falla → implementar → verde → commit `feat: dialogue window; talking to any NPC`.

### T11. Escenas

**Archivos:** crear `game/cutscene_player.gd`, `ui/cutscene_overlay.gd`, `sim/quests/cutscene_data.gd` (carga y valida `data/cutscenes/`); modificar `game/main.gd` (suceso `quest_scene` → `scene_start`, reproducir, `scene_done`), `game/player_avatar.gd` (icono de escena con `["in_scene", id, on]`); test `tests/unit/game/test_cutscene_player.gd`.

**Interfaces que produce:**
- `CutsceneData.load_id(id) -> Dictionary`; `CutsceneData.validate(id) -> Array[String]` (actores, poses, PNJ, monstruos, textos, zona y variante del escenario).
- `CutscenePlayer` (`Node3D`): `play(data: Dictionary, ctx: Dictionary) -> void` (`ctx`: `camera`, `zone_view`, `player_look`, `player_name`); `advance(dt: float) -> void` (el reloj; en juego lo llama `_process`); `skip() -> void` (todos los pasos a su estado final); `signal line(speaker: String, text: String)`; `signal finished()`.
- Pasos: `camera, move, pose, line, wait, fade, ambience, show, hide, shake, fx`. Pistas en paralelo; un paso sin `time` espera a que acabe su movimiento.
- `stage` distinto de `"here"`: se construye esa zona (con su variante) aparte, con `LoadingOverlay` si tarda más de **0,3 s**, y se quita al acabar.
- `CutsceneOverlay`: barras negras (**12 %** de alto cada una), subtítulo con nombre, interfaz del juego oculta, barra de «mantén Esc».

- [ ] **Test** `test_cutscene_player.gd`:
  - `test_tracks_run_in_parallel`: una cámara de 4 s y tres líneas de 1 s: a los 2 s la cámara va por la mitad y ya ha salido la segunda línea.
  - `test_move_waits`: un `move` sin `time` termina al llegar y el paso siguiente empieza entonces.
  - `test_skip_final_state`: `skip()` deja los actores en su última posición y pose, la luz en la del último `ambience` y emite `finished` una vez.
  - `test_all_cutscenes_valid`: cada escena de `data/cutscenes/` pasa `validate`.
- [ ] Falla → implementar → verde → commit `feat: in-engine cutscenes with letterbox and subtitles`.

### T12. Diario, objetivo seguido, marcas y avisos

**Archivos:** crear `ui/quest_journal.gd`, `ui/quest_tracker.gd`, `ui/quest_turn_in_window.gd`, `ui/quest_notice.gd`; modificar `game/npc_avatar.gd` (marca `!`/`?`), `ui/minimap.gd`, `game/zone_map_image.gd` (marcas del objetivo seguido), `ui/icon_bar.gd`, `game/input_setup.gd` (acción `quest_journal`, tecla **J**), `game/zone_view.gd` (puntos de misión con su `look`, visibles solo si el jugador local tiene ese objetivo activo), `game/main.gd`; test `tests/unit/ui/test_quest_ui.gd`.

**Interfaces que produce:**
- `QuestJournal.show_for(log: QuestLog, quests: QuestDB, items: ItemDB)`; `signal track_requested(id)` y `signal abandon_requested(id)`. Pestañas *Activas* y *Hechas*; **8** misiones por página.
- `QuestTracker.refresh(log, quests, bag: Inventory)`: nombre, texto del paso y contadores (`collect` y `deliver` leen `bag.count_of`).
- `QuestTurnInWindow.show_for(quest: Dictionary, items: ItemDB)`; `signal confirmed(choice: String)`.
- `QuestNotice.show_text(key: String, arg: String)`: **3 s**.
- `ZoneMapImage.quest_target(layout, log, quests) -> Dictionary` (`{at: Vector2}` en esta zona, o `{exit: Vector2}` hacia la salida que lleva a la zona del objetivo).

- [ ] **Test** `test_quest_ui.gd`:
  - `test_journal_no_scroll`: 20 misiones activas → 3 páginas; cada página cabe a 1280×720.
  - `test_tracker_counts`: `Lobos 3/5` y `Colmillos 1/3` con 1 colmillo en la bolsa.
  - `test_npc_marks_per_player`: el `!` y el `?` salen de `NpcTalk.mark` con el registro del jugador local (punto de revisión 5).
  - `test_target_in_other_zone`: con el objetivo en `bosque`, estando en `aldea`, `quest_target` da la salida hacia `bosque`.
  - `test_turn_in_choice`: sin elegir no se puede confirmar si hay `choice`.
  - `test_quest_point_visibility`: el brillo del punto `claro` se ve con el objetivo `reach claro` activo y no sin él.
  - `test_journal_key`: la acción `quest_journal` abre y cierra el diario.
- [ ] Falla → implementar → verde → commit `feat: quest journal, tracker, NPC marks and notices`.

### T13. Cadena de ejemplo

**Archivos:** crear `data/quests/ej_encargo.json`, `ej_lobos.json`, `ej_noche.json`; `data/dialogues/ej_*.json`; `data/cutscenes/ej_huellas.json`, `ej_alba.json`; `data/npcs/vecina.json`; modificar `data/zones/aldea.json` (la vecina y la variante `noche`), `data/zones/bosque.json` (punto `claro`, punto `huellas`), `data/npcs/brann.json` y `merchant.json` (`talk`), `data/texts/textos.csv`.

Contenido (spec §9):
1. **Un encargo de Brann** (`auto`): diálogo con opción *¿Qué se cuenta de los forasteros?* (`once`, marca `ej_pregunto`) → `deliver` de `q_paquete` al mercader → 25 de oro.
2. **Lobos en el camino** (da el mercader, pide la 1): `kill hunter_wolf ×5` + `collect q_colmillo ×3` (`chance 0.5`) en el bosque → `reach claro` (`on_done.scene: ej_huellas`) → `interact huellas` → `talk brann`. Recompensa: `levels: 1`, `choice` entre dos armas de nivel 2 de la clase.
3. **Lo que vio la noche** (Brann, pide la 2): decisión *Vigilar el camino* / *Avisar a la aldea* (`ej_vigilar` o `ej_avisar`; objetivo `choice` con `any_flag`) → `moment: aldea/noche` → `kill cultist ×4` (horda `respawn: false`) → `scene ej_alba` (cambia a `alba`) → `on_done.moment: null`. Brann dice una frase distinta según la marca.

- [ ] **Test:** `test_quests_data`, `test_dialogues` y `test_cutscene_player` (sus tests «todos los datos válidos») en verde con los datos nuevos; además `test_example_chain` en `tests/integration/test_example_chain.gd`: un anfitrión con un jugador recorre las tres misiones mandando las peticiones que mandaría el cliente y acaba con las tres hechas, un nivel más y de vuelta en `aldea`.
- [ ] Commit `content: example quest chain for testing the story engine`.

### T14. Documentación y versión

- [ ] `./run_tests.sh` completo en verde.
- [ ] Versión **0.12.0**; notas de la versión.
- [ ] GDD: [[07 Misiones]] (motor, tipos, objetos de misión, grupo) a [Implementado]; [[09 Interfaz]] (diálogo, escenas, diario, objetivo, marcas); [[10 Guardado]] (v6); [[06 Mundo]] (variantes y momentos); `Registro de cambios`.
- [ ] `Planes.md`: 8.2 hecho; la spec y este plan a `estado: implementado`.
- [ ] Sesión en `docs/Sesiones/`.
- [ ] Commit `docs: Plan 8.2 implemented (0.12.0)`.
- [ ] Decir al usuario exactamente qué probar (la cadena de ejemplo, en solitario y con un amigo).

---
← [[Planes]]
