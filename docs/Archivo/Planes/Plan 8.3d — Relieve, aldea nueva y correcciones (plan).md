---
tags: [plan]
plan: 8.3d
fecha: 2026-11-26
estado: hecho
actualizado: 2026-11-26
---
# Plan 8.3d — Relieve, aldea nueva y correcciones: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [x]`. Cada tarea: test que falla → código → tests en verde → commit.

**Objetivo:** relieve en el terreno, la aldea rediseñada con cuatro tipos de casa, calles y rancho, el asalto con el primer combate ya con clase, y 14 correcciones de la prueba de la 0.14.1. Sale como **0.15.0**.

**Arquitectura:**
- El relieve es un dato de zona: `ZoneLayout.height_at` es la única fuente de altura.
- La simulación sigue en 2D: el relieve solo vuelve sólidas las casillas de acantilado. Cada cliente dibuja a la altura del suelo.
- La aldea, el asalto y las piezas de historia son datos. Las correcciones tocan `ui/` y `game/`.

**Técnica:** Godot 4.7.2, GDScript, GUT (`./run_tests.sh [res://tests/...]`). Arte en Node (`node --test tools/art/tests/`).

**Spec:** [[Plan 8.3d — Relieve, aldea nueva y correcciones (spec)]]

## Restricciones globales
- **Relieve:**
  - un desnivel de más de **0,6 m** entre casillas vecinas vuelve sólidas las dos;
  - el agua mantiene su nivel;
  - la simulación no usa la altura.
- **Aldea:**
  - **4 diseños** de casa más la casa grande y la herrería;
  - **12 casas o más**, en hilera a los lados de las calles;
  - rancho con vacas (paseantes con `"model": "piece:cow"`).
- **Asalto:** sin enemigos hasta la marca `despertar`, que pone el paso de clase. El recuadro dice *Cultistas derrotados*.
- **Versión y compatibilidad:**
  - guardado: sigue la versión 7;
  - protocolo: sigue el 9 (los avisos nuevos van como eventos);
  - sale como **0.15.0**.
- Textos en `data/texts/textos.csv`. Ninguna ventana con scroll a 1280×720.

## Puntos de revisión
1. **Un jugador guardado en la aldea vieja**, en una casilla que ahora es casa o acantilado: aparece en una casilla libre (la entrada de la zona). → T5.
2. **Un desnivel en una salida o en un punto de misión:** las salidas, entradas, PNJ y puntos quedan en casillas alcanzables. → T5 (test de alcance con el relieve puesto).
3. **Volver a la partida a mitad del asalto, ya con clase:** las hordas aparecen (la marca está en el log). → T3.
4. **Un monstruo de objetivo en una casilla alta:** su punto rojo y su brillo se dibujan donde está. → T7.
5. **Las vacas no entran en las casas ni salen del cercado:** sus rutas son válidas y quedan dentro del cercado. → T5.

---

### T1. Relieve en los datos
**Archivos:** `sim/zone_layout.gd`; test `tests/unit/sim/test_relief.gd`.

**Produce:**
- `ZoneLayout.relief: Array` (formas `hill`, `hollow` y `plateau` de la spec §1).
- `ZoneLayout.height_at(x: float, z: float) -> float`:
  - suma de las formas;
  - `hill` y `hollow`: `h × (1 + cos(π·d/r)) / 2` dentro del radio;
  - `plateau`: `h` dentro del área y una cuesta lineal de `slope` casillas fuera de ella.
- `ZoneLayout.corner_height(c: Vector2i) -> float` (la altura en la esquina de una casilla, en caché).
- `collision()` marca sólidas las casillas con una vecina a más de `CLIFF_M := 0.6` de diferencia, comparando la altura del centro.

- [x] Tests:
  - `test_hill_height`: en el centro vale `h`, en el borde 0 y es monótona en medio.
  - `test_plateau_reached_by_slope`: una meseta con cuesta se alcanza por ella; una sin cuesta (`slope: 0`) tiene el borde sólido.
  - `test_flat_zone_unchanged`: sin `relief`, todo da 0 y el mapa de colisión no cambia.
- [x] Commit `feat: relief in zone data`.

### T2. Relieve en el dibujo
**Archivos:** `game/zone_view.gd` (suelo con alturas por esquina; `placement` suma `layout.height_at`; casas, antorchas, detalles, marcas de salida y rejas), `game/house_view.gd`, `game/game_session.gd` (jugadores, PNJ, paseantes, monstruos, marcas de punto, actores de escena, `_scene_fx`), `game/loot_view.gd`, `game/combat_fx.gd` (impactos y áreas), `game/iso_camera.gd` (sigue la altura); test `tests/unit/game/test_relief_view.gd`.

**Produce:**
- `GameSession.ground_y(x: float, z: float) -> float` (0 sin zona). Todos los avatares se dibujan en `y = ground_y`.
- `ZoneView`: el suelo usa `layout.corner_height` en cada vértice.

- [x] Tests:
  - `test_ground_mesh_follows_relief`: un vértice del suelo en el centro de una colina está a su altura.
  - `test_piece_and_npc_on_the_hill`: una pieza y un PNJ en la colina tienen su `y` igual a `height_at`.
  - `test_player_avatar_on_the_hill`: el avatar del jugador en la colina está a esa altura.
- [x] Commit `feat: everything stands on the relief`.

### T3. Enemigos y piezas que dependen de la historia
**Archivos:** `sim/ai/spawner.gd` (hordas y puntos con `requires`), `sim/zone_layout.gd` (`story_pieces`), `game/zone_view.gd` (`show_story_pieces(log, quests)`), `game/game_session.gd` (las refresca con `refresh_quest_marks`); test `tests/unit/sim/test_story_gates.gd`.

**Produce:**
- Las hordas y los `spawns` admiten `"requires": {"flags": [...]}`. `Spawner.tick` no los llena mientras ningún jugador de esa copia tenga las marcas.
- `story_pieces: [{"id", "at", "rot", "point"}]`:
  - la pieza se ve hasta que el jugador haya cumplido el objetivo `interact` o `reach` de ese punto, o haya terminado la misión que lo contiene;
  - solo se dibuja, nunca es sólida.
- `QuestText.point_done(log: QuestLog, quests: QuestDB, point: String) -> bool`.

- [x] Tests:
  - `test_horde_waits_for_flag` (punto de revisión 3): sin la marca no aparece nadie; al ponerla, aparecen. Un log que ya trae la marca los hace aparecer al entrar.
  - `test_story_piece_hides_when_point_done`: se ve, se cumple el punto y deja de verse; con la misión terminada tampoco se ve.
- [x] Commit `feat: hordes and pieces that follow the story`.

### T4. Arte nuevo
**Archivos:** `tools/art/make_world.mjs` y su test, `data/zones/pieces.json`, `assets/world/*.vox`; test `tests/unit/data/test_village_art.gd`.

**Produce:**
- **Casas** (visitables, cuatro partes), cada una con su versión quemada `house_burnt_<nombre>` y la misma huella, como `house_burnt_small` y `house_burnt_large`:
  - `house_timber`: entramado de dos plantas, yeso con vigas, tejado de tablas;
  - `house_log`: troncos horizontales, tejado de tablas;
  - `house_stone`: piedra, con horno de ladrillo y chimenea.
- **Rancho:**
  - `barn`: establo abierto con heno y comederos, como `forge_shed` pero más grande;
  - `cow`: vaca vóxel quieta, pieza para paseantes, sin huella;
  - `trough`: comedero.
- **Escenas y heridos:**
  - efecto `blood`, un charco: disco plano oscuro que dibuja `_scene_fx`;
  - para los heridos, solo PNJ con pose (T6).

- [x] Tests:
  - Node: las piezas caben en 126 vóxeles; cada casa tiene puerta e interior libres, y su quemada la misma huella.
  - GUT: las piezas están en `pieces.json` con su `.vox`.
- [x] Commit `art: village houses, barn and cows`.

### T5. La aldea nueva
**Archivos:** `data/zones/aldea.json` (base, `vispera` y `asalto`), `game/game_session.gd` (paseantes con `model: piece:<id>`: se dibujan con `MonsterAvatar` o un `MeshInstance3D` de la pieza), `tests/helpers/render_loading.gd` (capturas de la aldea); tests `tests/unit/data/test_zones_data.gd`, `tests/unit/game/test_walkers.gd`.

**Produce:**
- **Relieve:**
  - la colina al noroeste, con cuesta, las tumbas y el sitio de Mira;
  - la hondonada del río al suroeste;
  - el pueblo en una terraza suave.
- **Calles:** la calle mayor de oeste a este hasta la salida, la plaza en el cruce y callejones de tierra.
- **Casas:**
  - unas 14 en hilera mirando a la calle, de los cinco diseños;
  - la herrería y su cobertizo;
  - el rancho (`barn`, cercado con `fence` y `trough`) con 4 vacas paseantes dentro.
- Los jabalíes, al prado del sureste fuera del pueblo.
- **Los tres momentos:**
  - la base en ruinas usa la versión `house_burnt_*` en el sitio de cada casa;
  - `vispera` y `asalto` usan las casas sanas;
  - se recolocan los puntos, los PNJ, la fiesta, el campamento de Verrin y las rutas.
- **Puntos de misión:**
  - los que solo lanzan una escena (`colina`, `plaza`, `alarma`, `tras_mira`, `puerta`) se quedan sin `look`;
  - en el bosque, la capital y el palacio, lo mismo para `rio`, `emboscada`, `puerta_capital` y `salon_trono`.
- **Pantallas de carga:** capturas nuevas de la aldea.

- [x] Tests:
  - `test_village_houses`: 4 diseños o más además de `house_large` y la herrería, 12 casas o más, rancho con `barn` y vacas paseantes.
  - Los de siempre, en los tres momentos: carga sin errores, todo alcanzable, casas fuera de las calles, reaparición del asalto segura.
  - `test_cows_stay_in_the_paddock` (punto de revisión 5): todos los puntos de las rutas de las vacas caen dentro del rectángulo del cercado.
  - `test_saved_place_on_a_wall_moves` (punto de revisión 1): un sitio guardado sólido lleva a la entrada.
  - `test_scene_points_have_no_glow`.
  - `test_cow_walker_draws_a_piece`: un paseante `piece:cow` se dibuja.
- [x] Commit `content: the new village`.

### T6. El asalto rehecho y las escenas
**Archivos:**
- `data/quests/prologo_2.json`, `data/cutscenes/prologo_secuestro.json` (peleas y secuestro), `prologo_brann.json`, `data/zones/aldea.json` (hordas del asalto con `requires`);
- `game/cutscene_player.gd` (pose inicial del actor: `"pose"` en el actor, aplicada ya terminada);
- `game/characters/human_rig.gd` (`set_pose_now(pose)`), `game/npc_avatar.gd` (PNJ con `"pose"` en sus datos);
- `data/npcs/herido_1.json` y `herida_2.json` (tumbados, con vendas);
- `story_pieces` con los escombros en `escombros_1`;
- textos; tests `tests/integration/test_prologue.gd`, `tests/unit/game/test_cutscene_player.gd`.

**Produce:** los pasos de la spec §3. El paso de clase pone la marca `despertar`. El de los cultistas tiene la etiqueta `QUEST_P2_O_CULTISTAS` (*Cultistas derrotados*) y el texto *Habilidades: 1–9. Q bebe una poción de vida*.

- [x] Tests:
  - El test del prólogo, con los pasos nuevos:
    - hasta la clase, ningún monstruo vivo en la copia;
    - tras elegirla, aparecen cultistas;
    - 6 cultistas cuentan para *Cultistas derrotados*.
  - `test_actor_starts_in_pose`: un actor con `"pose": "lie"` ya está tumbado en el primer fotograma.
  - `test_blood_fx`: la escena de Brann pide `blood` en su sitio.
  - `test_wounded_lie`: los heridos están tumbados junto a sus puntos.
- [x] Commit `content: the assault fought with your class; the fallen and the wounded`.

### T7. Correcciones de interfaz
**Archivos:** `ui/pause_menu.gd` (recuadro vacío, *Cerrar juego* con confirmación, aviso del tutorial), `game/main.gd`, `game/game_session.gd`, `game/zone_view.gd` (casas que tapan), `ui/minimap.gd` y `ui/map_window.gd` (puntos rojos, flecha en vivo), `game/npc_avatar.gd`, `game/player_avatar.gd` y `game/monster_avatar.gd` (nombres ocultos en escena), `ui/quest_notice.gd` (aviso de nivel), `game/combat_fx.gd` (destello azul de nivel); tests en `tests/unit/ui/test_main_flow.gd`, `tests/unit/ui/test_minimap.gd` y `tests/unit/ui/test_pause_menu.gd`.

**Produce:**
- `settings.last_code` deja de usarse: el recuadro de unirse empieza vacío.
- `PauseMenu.quit_button` → diálogo de confirmación → `Main._quit_game()`, que guarda el personaje y llama a `get_tree().quit()`.
- `ZoneView.occluders(cam_pos: Vector3, target: Vector3) -> Array[int]`: las casas cuyo rectángulo corta el segmento entre la cámara y el jugador. `GameSession` las abre mientras tapan y las cierra cuando no.
- Durante una escena, `GameSession.set_labels_visible(false)`: nombres, avisos, marcas y barras sobre las cabezas.
- `QuestText.target_monsters(log: QuestLog, quests: QuestDB) -> Array[String]`: los tipos de los objetivos activos `kill`, `hit` y `collect`. El minimapa y el mapa los dibujan como puntos rojos. Sobre el muñeco hay un brillo mientras haga falta golpearlo.
- El mapa (M) redibuja al jugador cada fotograma mientras está abierto.
- Sin `camera.focus` al hablar.
- Evento `level_up`:
  - aviso `UI_LEVEL_UP` (*¡Nivel %d!*) en el centro, durante 2,5 s;
  - destello azul (columna de luz y chispas, 1,2 s) en el avatar del que sube, que también ven los compañeros.
- El aviso del tutorial del menú de pausa se quita en cuanto llega `tutorial_done`.

- [x] Tests:
  - `test_join_code_starts_empty`;
  - `test_quit_asks_first`;
  - `test_house_opens_when_it_hides_you`;
  - `test_no_labels_in_scenes`;
  - `test_quest_targets_on_minimap` (punto de revisión 4);
  - `test_map_arrow_follows_player`;
  - `test_no_zoom_when_talking`;
  - `test_level_up_notice_and_glow`;
  - `test_tutorial_hint_goes_when_done`.
- [x] Commit `fix: playtest corrections of the 0.14.1`.

### T8. Versión, documentación y revisión
- [x] Suite completa en verde, sin avisos de test que no comprueba nada.
- [x] `config/version="0.15.0"`; notas de la versión.
- [x] GDD: 06 Mundo (relieve, aldea), 07 Misiones (asalto), 09 Interfaz y 11 Arte; registro; `Planes.md` → *Hecho (0.15.0, sin publicar)*; nota de sesión.
- [x] Revisión final del conjunto; decir al usuario qué probar.
- [x] Commit `chore: 0.15.0 — relief, new village and corrections`. La subida a main, solo si el usuario la pide.

---
← [[Planes]]
