---
tags: [plan]
plan: 8.3a
fecha: 2026-11-26
estado: borrador
actualizado: 2026-11-26
---
# Plan 8.3a — Prólogo en la aldea: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [ ]`. Cada tarea: test que falla → código → tests en verde → commit.

**Objetivo:** el prólogo (misiones 1–3) como tutorial, sobre el motor de la 0.12.0. La aldea en tres momentos, la clase elegida en el asalto, el muñeco, el Heraldo que huye, aldeanos que pasean y los personajes antiguos apartados. Sale como **0.13.0**.

**Arquitectura:** casi todo son datos (`data/quests/prologo_*`, `data/dialogues/`, `data/cutscenes/`, `data/zones/aldea.json` con sus variantes, `data/npcs/`). El motor gana cuatro tipos de objetivo, un muñeco y una huida (en `sim/`), paseantes que mueve cada cliente con el reloj del anfitrión (`game/`) y arte nuevo hecho por código (`tools/art/`).

**Técnica:** Godot 4.7.2, GDScript, GUT (`./run_tests.sh [res://tests/...]`). Arte en Node (`node --test tools/art/tests/`).

**Spec:** [[Plan 8.3a — Prólogo en la aldea (spec)]]

## Restricciones globales
- `CharacterData.VERSION = 7`. Las versiones anteriores se mueven a `user://saves/characters/antiguos/`.
- Protocolo: sigue el 9 si no cambian los mensajes. Si cambian, sube a 10.
- El Heraldo huye al **10 %** (`flee_at: 0.1`) y desaparece a los **3 s**.
- El muñeco no baja de **1** de vida y se rellena a los **3 s** sin golpes.
- Aldeanos: velocidad por defecto **1,2 m/s** y pausa por defecto **3 s**; nunca sólidos.
- Recompensas: el asalto da **2 niveles** y «llegan tarde» **1**.
- Cultistas del asalto: **nivel 1–2**. Heraldo: **nivel 2**, un cuarto de la vida del Acólito, sin invocaciones.
- Textos en `data/texts/textos.csv`. Arte propio por código.
- Ninguna ventana con scroll a 1280×720.

## Puntos de revisión
1. **Salir o caerse la conexión en el despertar** (paso `class` activo, aún aldeano): al volver, dentro del asalto, la ventana de clase se abre sola y no se puede cerrar. → T4.
2. **Morir como aldeano en el asalto:** reaparece dentro del asalto, en un punto seguro de la variante, con la misión en el mismo paso. → T8.
3. **Un golpe que lleva al Heraldo de más del 10 % a 0 de una vez:** huye igual (no muere ni suelta botín) y la misión avanza. → T2.
4. **Una ruta de aldeano que pasa por casillas sólidas o sale del mapa** (error en los datos): la validación lo dice con el nombre y el punto. → T5.
5. **Un amigo que se une mientras el anfitrión está en su víspera:** imposible (grupo bloqueado sin `tutorial_done`). Si el anfitrión ya lo tiene, el amigo aparece en la aldea en ruinas, nunca en la copia del anfitrión. → T9.

---

### T1. Motor: objetivos nuevos, momento de misión y entregas
**Archivos:** `sim/quests/quest_db.gd`, `sim/quests/quest_rules.gd`, `sim/combat/combat.gd`, `sim/movement.gd` (o `sim/sim_world.gd`, donde se usa `dodge_started`), `sim/sim_world.gd` (`current_ability`), `net/host_session.gd` (`_on_choose_class`), `sim/zone_layout.gd` (`walkers` en variantes); test `tests/unit/sim/test_quest_rules_83.gd`.

**Produce:**
- Tipos `hit` (`monster`, `with: "basic"|"secondary"|""`), `hit_secondary` (equivale a `hit` con `with: "secondary"`), `dodge` y `class`, en `QuestDB.TYPES`.
- `QuestRules.on_hit(world, source: CombatEntity, target: CombatEntity, ability_kind: String)`: la llama `Combat` al aplicar daño de un jugador. `SimWorld.current_ability_kind: String` es `basic | secondary | ""` mientras se resuelve el lanzamiento.
- `QuestRules.on_dodge(world, p)`: la llama la simulación cuando empieza una esquiva.
- `QuestRules.on_class_chosen(world, p)` y `QuestRules.allows_class_choice(world, p) -> bool` (paso actual con objetivo `class`). `HostSession._on_choose_class` acepta sin instructor cerca si `allows_class_choice`.
- `moment` en la raíz de una misión: `QuestRules.current_moment` lo toma desde el paso 0, y `start()` emite `quest_moment` si lo tiene.
- `give` acepta cualquier base: los objetos normales van a la bolsa con su nivel mínimo.
- `ZoneLayout.apply_variant` reemplaza `walkers`.
- `QuestDB.validate` conoce los tipos nuevos y comprueba que `hit` lleve un monstruo existente.

- [ ] Tests:
  - `test_hit_counts_only_that_monster_and_attack`: golpe básico al muñeco cuenta para `hit with basic`; secundario no; golpe a un sabueso no.
  - `test_dodge_counts`: tres esquivas → 3/3.
  - `test_class_objective`: con el objetivo activo, `allows_class_choice` es true; al elegir clase el paso avanza; sin el objetivo es false.
  - `test_choose_class_without_trainer_only_with_objective` (red): `CHOOSE_CLASS` lejos de todo PNJ se acepta con el objetivo y se rechaza sin él.
  - `test_quest_moment_from_start`: una misión con `moment` emite `quest_moment` al empezar y `current_moment` lo devuelve en el paso 0.
  - `test_give_normal_items`: `give [["potion_health", 2]]` mete dos pociones en la bolsa.
  - `test_variant_walkers`: una variante con `walkers` los reemplaza.
- [ ] Falla → implementar → verde → suite → commit `feat: hit, dodge and class objectives; quest moments from the start`.

### T2. El muñeco y la huida del Heraldo
**Archivos:** `sim/ai/monster_ai.gd` (`behavior: "dummy"`), `sim/combat/damage.gd` o `combat.gd` (vida mínima, huida), `sim/progression/xp.gd`, `sim/items/loot.gd`, `game/monster_avatar.gd` (`fled`), `game/game_session.gd`; datos `data/monsters/training_dummy.json` y `data/monsters/heraldo.json`; test `tests/unit/sim/test_dummy_and_flee.gd`.

**Produce:**
- `"behavior": "dummy"`: no se mueve, no ataca, no tiene amenaza; con `"immortal": true` no baja de 1 de vida y se rellena a los 3 s sin golpes (`MonsterState.last_hurt_tick`); con `"xp": 0` no da experiencia ni botín.
- `"flee_at": f`: si un golpe lo deja en `hp <= max_hp * f` o en 0, queda en `max(1, …)` e invulnerable, sale del combate y cuenta como derrotado. `Xp.share` y `QuestRules.on_monster_died` se llaman; `Loot.drop` no. Emite `["fled", id]` y se quita a los 3 s.
- Cliente: `["fled", id]` oculta el modelo con una nube de humo (`VoxelFx`), sin disolución en binario.
- `heraldo.json`: copia del Acólito con `max_hp` a un cuarto, sin `summon`, `flee_at: 0.1`, nombre `MON_HERALDO` (*El Heraldo*).

- [ ] Tests:
  - `test_dummy_never_dies_and_refills`: 10 000 de daño lo dejan en 1; a los 3,1 s sin golpes vuelve al máximo.
  - `test_dummy_is_harmless`: un jugador a 1 m durante 5 s no recibe daño ni amenaza; matarlo es imposible y no hay `died`.
  - `test_dummy_gives_nothing`: ni experiencia ni botín.
  - `test_flee_at_ten_percent`: un golpe que lo baja del 10 % emite `fled`, cuenta el `kill` de la misión y da experiencia sin botín; deja de recibir daño y desaparece a los 3 s.
  - `test_overkill_still_flees` (punto de revisión 3): un golpe del 100 % a 0 también huye.
- [ ] Falla → implementar → verde → suite → commit `feat: training dummy and a boss that flees at 10%`.

### T3. Personajes antiguos apartados (guardado v7)
**Archivos:** `save/character_data.gd`, `save/character_store.gd`, `ui/character_select_screen.gd`, `game/main.gd` (aviso una vez, guardado en ajustes); test `tests/unit/save/test_old_characters.gd`.

**Produce:**
- `CharacterData.VERSION = 7`; `migrate` ya no admite versiones < 7 (`from_dict` → null).
- `CharacterStore.retire_old() -> int`: mueve los `.json` de versión < 7 a `antiguos/` y devuelve cuántos. `load_all()` la llama primero.
- `CharacterStore.import_from` rechaza versiones < 7 con `last_error = "ERR_OLD_CHARACTER"`.
- `SettingsStore.old_characters_notice_seen: bool`. La pantalla de selección muestra el aviso `UI_OLD_CHARACTERS` la primera vez que `retire_old` devuelve más de 0.

- [ ] Tests:
  - `test_v6_moved_to_antiguos`: un archivo v6 desaparece de la lista y aparece en `antiguos/` con el mismo nombre.
  - `test_v7_loads`: un v7 carga.
  - `test_import_old_refused`: importar un v6 da null y el error.
  - `test_notice_once`: el aviso sale una vez y no la segunda.
- [ ] Falla → implementar → verde → suite → commit `feat: older characters are set aside (save v7)`.

### T4. Sin Brann: clase en el asalto, sin reinicios, mejora fija
**Archivos:** `game/npc_interaction.gd`, `game/main.gd`, `ui/class_choice_window.gd` (`mandatory`), `ui/trainer_menu.gd` (se retira de `main`), `net/host_session.gd` (`/arena <n>`), `data/npcs/brann.json` (sin rol `class_trainer`); tests `tests/unit/game/test_npc_interaction.gd`, `tests/unit/ui/test_main_flow.gd`.

**Produce:**
- `ClassChoiceWindow.mandatory: bool`: sin botón de cerrar; Esc no la cierra.
- `Main`: cuando el paso actual del log tiene un objetivo `class` sin cumplir y el personaje es aldeano, abre la ventana obligatoria (al llegar `QUESTS`, al acabar una escena y al volver a la partida).
- `NpcInteraction.decide` ya no devuelve `CHOOSE_CLASS`. `trainer_options` sale del código, junto con el menú de Brann y sus tests.
- Comando `/arena <n>` (solo el anfitrión) para el nivel de la arena.
- El menú del nivel 50 sigue siendo obligatorio. No existe forma de reiniciar la mejora.

- [ ] Tests:
  - `test_class_window_opens_for_class_objective` (main): con el objetivo `class` activo la ventana se abre sola y es obligatoria.
  - `test_class_window_reopens_after_rejoin` (punto de revisión 1): al volver con el log en ese paso, se abre otra vez.
  - `test_no_reset_upgrade`: no hay ningún camino (petición `reset upgrade`) que borre una mejora: el anfitrión lo rechaza.
  - `test_arena_command`: `/arena 12` cambia el nivel de la arena; un invitado no puede.
  - Se borran los tests del menú de Brann y de `CHOOSE_CLASS` por cercanía.
- [ ] Falla → implementar → verde → suite → commit `feat: the class is chosen in the assault; no resets or upgrade changes`.

### T5. Aldeanos que pasean
**Archivos:** crear `sim/walker_path.gd` (lógica pura); modificar `sim/zone_layout.gd` (`walkers`, validación), `game/game_session.gd` (avatares de paseantes), `game/npc_avatar.gd` (andar y saludar); test `tests/unit/sim/test_walkers.gd`.

**Produce:**
- `ZoneLayout.walkers: Array` (`{npc, route: Array[Vector2], speed, pause_s, loop}`) y errores de validación `walker <npc>: punto (x, z) sólido o fuera del mapa` (punto de revisión 4).
- `WalkerPath.at(route: Array, speed: float, pause_s: float, loop: bool, t: float) -> Dictionary` → `{position: Vector3, facing: float, moving: bool}`. `loop` vuelve al principio; si no, va y vuelve.
- `GameSession`: un `NpcAvatar` por paseante, que se mueve cada frame con `t = client.target_render_tick() / tick_rate`. Andan con la animación de caminar y se paran en los puntos. Con E dicen su `lines.greet` en el chat (sin pasar por el anfitrión).
- Los paseantes no van al `CollisionMap` (no son sólidos) ni a `map.npcs`.

- [ ] Tests:
  - `test_same_position_for_same_time`: dos llamadas con el mismo `t` dan lo mismo.
  - `test_pauses_at_points`: en los `pause_s` después de llegar a un punto, `moving` es false y la posición no cambia.
  - `test_loop_and_back`: con `loop` vuelve al primer punto; sin él, recorre la ruta al revés.
  - `test_bad_route_reported`: un punto sólido o fuera del mapa da su error.
  - `test_walkers_drawn` (sesión): la aldea con dos paseantes crea dos avatares que no están en `map.npcs`.
- [ ] Falla → implementar → verde → suite → commit `feat: villagers walk their routes`.

### T6. Poses y efectos de escena
**Archivos:** `game/characters/human_rig.gd` (`kneel`, `point`, `lie`), `sim/quests/cutscene_data.gd` (`POSES`, `FX`), `game/game_session.gd` (`fx` en el contexto de la escena), `game/voxel_fx.gd` o `game/combat_fx.gd` (fuego, humo, destello); `ui/cutscene_overlay.gd` (destello a pantalla); tests `tests/unit/characters/test_human_rig.gd`, `tests/unit/game/test_cutscene_player.gd`.

**Produce:**
- `HumanRig.ACTIONS` gana `kneel` (duradera), `point` (1,2 s) y `lie` (duradera, tumbado de espaldas y quieto). `LASTING` incluye `kneel` y `lie`.
- `CutsceneData.POSES` y `FX` las aceptan. El `fx` de la escena llama a `GameSession._scene_fx(name, at)`: `fire` (llamas vóxel que duran lo que dure la escena), `smoke` (columna de humo) y `flash` (destello blanco en pantalla, `CutsceneOverlay.flash()`).

- [ ] Tests:
  - `test_new_poses`: `play_action("kneel")` baja la cadera; `lie` deja el cuerpo horizontal; `point` levanta el brazo derecho por delante.
  - `test_fx_calls_context`: un paso `fx` llama a `ctx.fx` con el nombre y la casilla.
  - `test_flash`: `CutsceneOverlay.flash()` pone el blanco y lo baja en 0,4 s.
- [ ] Falla → implementar → verde → suite → commit `feat: kneel, point and lie poses; fire, smoke and flash in cutscenes`.

### T7. Arte nuevo y PNJ
**Archivos:** `tools/art/make_world.mjs` (piezas nuevas) y su test en `tools/art/tests/`, `data/zones/pieces.json`, `assets/world/*.vox`, `game/monster_avatar.gd` (modelo `piece:<id>` para el muñeco); datos `data/npcs/` nuevos; test `tests/unit/data/test_prologue_art.gd`.

**Produce:**
- Piezas:
  - fiesta: `garland`, `lantern_post`, `feast_table`, `bonfire`;
  - ruina: `house_burnt_small`, `house_burnt_large` (huellas iguales a las sanas), `rubble`, `fallen_beam`, `grave`;
  - ejército: `army_tent`, `kingdom_banner`;
  - bosque: `camp_ruined`, `cart_tracks`, `river_bank`;
  - el muñeco `training_dummy` (poste, cuerpo de paja atado, brazos de madera y base).
- Con `"model": "piece:training_dummy"`, `MonsterAvatar` dibuja la pieza (sin rig) y la sacude al recibir un golpe.
- PNJ con nombre (`mira`, `verrin`, `soldado_reino`, `anciana_cantora`, `panadero`, `cazador`) y genéricos (`aldeano_anciano_1…4`, `aldeana_anciana_1…3`, `aldeano_1…2`), con su `look` y su `lines.greet`.

- [ ] Tests:
  - `node --test tools/art/tests/`: cada pieza nueva se genera y cabe en su huella.
  - `test_pieces_exist`: cada pieza nueva está en `pieces.json` y su `.vox` existe.
  - `test_npc_looks_valid`: cada PNJ nuevo tiene nombre traducido y un aspecto que el catálogo acepta sin cambiarlo.
  - `test_dummy_model`: el avatar del muñeco se construye con la pieza.
- [ ] Implementar → verde → commit `art: festive, ruined, army and forest pieces; the training dummy; prologue NPCs`.

### T8. La aldea en tres momentos y el bosque
**Archivos:** `data/zones/aldea.json` (base en ruinas y variantes `vispera` y `asalto`), `data/zones/bosque.json` (rastro), `data/loading.json` (capturas nuevas con `tests/helpers/render_loading.gd`); test `tests/unit/data/test_zones_data.gd`.

**Produce:**
- **Base:** casas quemadas en el sitio de las sanas, escombros, tumbas, campamento de Verrin y paseantes. PNJ: `verrin`, `anciana_cantora`, `panadero` y `cazador`. Sin Brann ni mercader.
- **`vispera`:** casas sanas, fiesta, muñeco junto a la forja, ambiente `atardecer`, más paseantes. PNJ: Brann, Mira, panadero, cazador y anciana. Puntos: `mira_casa`, `colina` y `plaza`.
- **`asalto`:** casas sanas, `noche_fuego`, hordas sin reaparición (cultistas de nivel 1–2 en grupos junto a los vecinos), vecinos quietos y reaparición segura en el sótano de la forja. Puntos: `tras_mira`, `puerta`. Heraldo en la plaza (`spawns`, una vez).
- **Bosque:** puntos `campamento`, `huellas_carro`, `mascara` y `rio`, con sus piezas.

- [ ] Tests:
  - `test_village_moments`: las dos variantes existen, cambian las casas quemadas por sanas y tienen sus puntos.
  - `test_assault_respawn_is_safe` (punto de revisión 2): la reaparición del asalto es una casilla libre a más de 15 m de toda horda.
  - Las rutas de todos los paseantes son válidas (T5).
- [ ] Commit `content: the village in three moments and the trail in the forest`.

### T9. Las tres misiones
**Archivos:** `data/quests/prologo_1.json`, `prologo_2.json`, `prologo_3.json`; diálogos y escenas en `data/dialogues/prologo_*` y `data/cutscenes/prologo_*`; textos; borrar `data/quests/ej_*`, `data/dialogues/ej_*`, `data/cutscenes/ej_*` y `data/npcs/vecina.json`. Test `tests/integration/test_prologue.gd`.

**Produce:** las misiones de la spec §2, paso por paso, con sus textos de tutorial. Escenas:
- víspera: amanecer, atardecer en la colina, la fiesta y el cuerno;
- asalto: la alarma, la plaza y el secuestro, el despertar (con `flash`) y la ventana de clase al acabar, el alba, la huida del Heraldo, y Brann caído (`lie`);
- llegan tarde: la llegada de Verrin y *Thal An Dor*.

- [ ] Tests:
  - Los «datos válidos» de misiones, diálogos y escenas siguen en verde.
  - `test_prologue` (integración): un personaje nuevo recorre las tres misiones con las peticiones del cliente. Acaba en la aldea en ruinas con clase, `tutorial_done`, `apodo`, `prologo_3_hecho`, la máscara en la bolsa y 3 niveles más que al empezar.
  - `test_guest_never_in_host_moment` (punto de revisión 5): con el anfitrión en la víspera, un invitado con `tutorial_done` aparece en la aldea en ruinas.
- [ ] Commit `content: prologue missions 1-3 as the tutorial`.

### T10. Documentación, versión y revisión
- [ ] Suite completa en verde; versión **0.13.0**; notas de la versión.
- [ ] GDD: [[07 Misiones]], [[06 Mundo]], [[04 Personajes y progresión]] (clase en el asalto, sin reinicios, mejora fija), [[10 Guardado]] (v7) y [[09 Interfaz]]; `Registro de cambios`; `Planes.md`; sesión.
- [ ] Revisión final y commit `docs: Plan 8.3a implemented (0.13.0)`.
- [ ] Decir al usuario qué probar.

---
← [[Planes]]
