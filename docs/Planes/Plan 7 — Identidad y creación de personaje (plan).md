---
tags: [plan]
plan: 7
fecha: 2026-11-21
estado: aprobado
actualizado: 2026-11-21
---
# Plan 7 — Identidad y creación de personaje: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [ ]`.

**Objetivo:** cinco razas solo de aspecto, apariencia ampliada y pantallas de inicio, selección y creación definitivas sobre una escena vóxel del altar del Sol Negro. Sale como **0.10.0**.

**Arquitectura:**
- La raza es un dato (`races.json`) que `CharacterCatalog.resolve()` convierte en claves nuevas del *look*: altura, proporciones, cabeza y ajuste de cabeza.
- `HumanRig` las aplica sobre el cuerpo v2 compartido. Las proporciones también mueven los pivotes, para que los pies sigan en el suelo, y escalan las piezas de cada parte.
- Las tres pantallas de menú son capas de interfaz (tema de piedra y oro) sobre una única `MenuScene` 3D, que se construye desde `data/scenes/title_altar.json` y cambia de plano de cámara según la pantalla.

**Técnica:**
- Godot 4.7.2 con GDScript y GUT. Ejecución: `./run_tests.sh [res://tests/...]`.
- Generadores de arte en Node sin dependencias (`tools/art/`). Ejecución: `node --test tools/art/tests/`.

**Spec:** [[Plan 7 — Identidad y creación de personaje (spec)]]

## Restricciones globales
- Las razas son **solo aspecto**: no tocan `sim/`, ni la colisión, ni la velocidad, ni la cámara de juego.
- Alturas respecto al humano: humano 1,00, elfo 1,04, **enano 0,80**, ogro 1,30, lagarto 1,05.
- Ninguna pantalla puede tener scroll ni salirse de 1280×720.
- Un personaje sin `race` se abre como `human` y `marks` como `none`. `CharacterData.VERSION` sigue en 4.
- Textos del juego en `data/texts/textos.csv`, en español. Código y commits en inglés.
- El arte se hace por código en `tools/art/`. La fuente sigue siendo Teko, y no se descarga nada.
- Las ventanas del juego siguen con `HoloTheme`. Solo el inicio, la selección y la creación usan `StoneTheme`.

## Puntos de revisión
1. **Cambiar de raza en la creación** con un peinado, barba o piel que la nueva raza no admite: pasa a la primera opción válida, nunca a un valor vacío ni a un error.
2. **Pies en el suelo:** con las piernas cortas del enano y el cuerpo alto del ogro, el pie más bajo queda a ±1 vóxel del suelo y la barra de vida queda sobre la cabeza real.
3. **Equipo en las cabezas propias:** todos los cascos, capuchas y sombreros se enganchan a la cabeza del ogro y del lagarto, y el hocico y los colmillos nunca se ocultan.
4. **Personaje importado o recibido por la red** con raza u opciones de otra raza: se sanea igual que al cargar.
5. **Volver del juego al menú:** la escena del altar se reconstruye o reaparece, y la partida no deja nodos 3D del menú vivos (sin fugas en GUT).

Cada punto tiene su test en la tarea que lo implementa (1 → T1 y T10; 2 → T3; 3 → T5; 4 → T2; 5 → T11).

---

### T1 · Razas en el catálogo
**Archivos:**
- Crear `data/characters/races.json`.
- Modificar `game/characters/character_catalog.gd` y `data/characters/appearance.json` (añadir las filas `race` y `marks`; de momento solo `none` en `marks`).
- Tests: `tests/unit/characters/test_character_catalog.gd`.

**Interfaces que produce:**
- `KINDS := ["race", "body", "skin", "eyes", "hair_style", "hair_color", "beard", "marks"]`.
- Formato de cada raza en `races.json`:
  ```json
  {"id":"dwarf","name":"RACE_DWARF","desc":"RACE_DWARF_DESC","height":0.8,
   "scale":{"torso":[1.2,0.9,1.15],"arm":[1.12,0.85,1.12],"leg":[1.1,0.7,1.1],"head":[1.08,1.08,1.08]},
   "head":"human","pieces":["nose_dwarf"],"head_fit":{"scale":1.0,"offset":[0,0,0]}}
  ```
  La fila `race` de `appearance.json` lista los ids. El resto vive en `races.json`.
- `func race_def(id: String) -> Dictionary`.
- `func options_for(kind: String, race: String) -> Array`: las opciones sin `races` o cuya lista `races` incluye la raza.
- `sanitize_appearance(app)`: primero sanea `race` y después cada fila contra `options_for(kind, race)`. Un valor que no vale pasa a la primera opción válida.
- `random_appearance(rng)`: elige la raza y después solo opciones válidas para ella.
- `resolve()` añade al *look*:
  - `race_height: float`;
  - `race_scale: Dictionary`, con el mismo formato que `body_scale` y el grupo nuevo `head`;
  - `head_file: String` (`""` = la cabeza del rig);
  - `head_fit: {scale: float, offset: Array}`;
  - las piezas de la raza dentro de `pieces`.

**Pasos:**
- [ ] Tests nuevos:
  - `test_races_loaded`: hay 5 razas, `human` es la primera y `race_def("dwarf").height == 0.8`.
  - `test_options_filtered_by_race`: una opción con `races: ["lizard"]` sale solo para `lizard`.
  - `test_sanitize_fixes_options_of_other_race`: `{race: "lizard", hair_style: "short"}` da una cresta válida para el lagarto.
  - `test_sanitize_missing_race_is_human`.
  - `test_random_is_always_valid`: 200 tiradas con semilla fija, y cada una sale igual al sanearla.
  - `test_resolve_has_race_keys`: el enano tiene `race_height` 0.8; el humano, `head_file == ""`.
- [ ] Ejecutar `./run_tests.sh res://tests/unit/characters/test_character_catalog.gd` y comprobar que **fallan**.
- [ ] Implementar las cinco razas en `races.json` con los valores de la tabla de la spec. Las piezas de las razas son ids que crea T4; mientras no existan, `piece_entry` las salta, como hace hoy con las piezas que faltan.
- [ ] Ejecutar los tests: deben **pasar**, y también la suite completa (los tests de apariencia que esperaban 6 filas se actualizan a 8).
- [ ] Commit: `feat: races and per-race appearance options in the character catalog`.

### T2 · Guardado, importación y red
**Archivos:**
- Tests: `tests/unit/save/test_character_data.gd` y `tests/unit/net/test_host_session.gd`.
- Código: solo si algún test lo pide. Los tres caminos ya pasan por `sanitize_appearance`.

**Pasos:**
- [ ] Tests:
  - `test_v4_without_race_loads_as_human`: un diccionario de la 0.9.7 da `appearance.race == "human"`, `marks == "none"` y el resto igual.
  - `test_unknown_race_falls_back`.
  - `test_host_sanitizes_foreign_race_options`: un `join` con `{race: "ogre", skin: "skin_1"}` acaba con una piel de ogro.
- [ ] Ejecutar: deben pasar sin cambiar código. Si alguno falla, arreglar el saneado en el sitio donde falle.
- [ ] Commit: `test: old saves and network appearances with races`.

### T3 · HumanRig con proporciones de raza
**Archivos:**
- Modificar `game/characters/human_rig.gd` y `game/monster_avatar.gd` (`hover_height` y la altura de la barra de vida, si usan una constante).
- Tests: `tests/unit/characters/test_human_rig.gd`.

**Interfaces:**
- Usa las claves del *look* de T1.
- Produce:
  - `func height() -> float`: altura real en metros (la parte superior del AABB de la cabeza, en el espacio del rig).
  - `func overhead_height() -> float`, usada por la barra de vida del jugador.

**Reglas:**
- `race_height` multiplica la escala raíz: `BODIES[body].scale * race_height`.
- `race_scale` se multiplica componente a componente con `body_scale` en el `Scale` de cada parte. El grupo `head` se aplica a `head`.
- La **Y** de cada grupo escala también la posición de los pivotes hijos dentro de ese grupo. Las caderas bajan según la Y de las piernas, para que el pie más bajo quede en el suelo.
- Las piezas enganchadas a una parte se escalan con el factor `race_scale` de esa parte, **no** con `body_scale`.
- `head_file != ""` sustituye la malla de `head`. `head_fit` se aplica a las piezas de cabeza de etiqueta `headgear`, `hair` y `hood`.

**Pasos:**
- [ ] Tests:
  - `test_dwarf_shorter_than_human_and_elf` y `test_ogre_taller_than_human`, con `height()`.
  - `test_feet_on_ground_every_race`: el mínimo Y global de las mallas `shin_*` está en [-1, +1] vóxeles para las 5 razas.
  - `test_pieces_scale_with_race_part`: el ogro con una hombrera tiene `scale.x` igual a 1.3 por el factor del torso.
  - `test_body_scale_still_does_not_scale_pieces`.
  - `test_custom_head_replaces_mesh`.
- [ ] Ejecutar: deben **fallar**.
- [ ] Implementar.
- [ ] Ejecutar `test_human_rig`, `test_cloth` y la suite: deben **pasar**. Las capas (`CAPE_ANCHORS`) siguen funcionando con el ogro.
- [ ] Commit: `feat: race proportions in HumanRig (pivots, pieces and custom heads)`.

### T4 · Arte de las razas y la apariencia nueva
**Archivos:**
- Modificar:
  - `tools/art/human_v2.mjs`, con `headOgreV2()` y `headLizardV2()` exportadas; las escribe `make_humans.mjs` como `head_ogre.vox` y `head_lizard.vox` en `assets/characters/vox_v2/`;
  - `tools/art/make_pieces_v2.mjs`, que añade `ears_elf`, `nose_dwarf`, `tusks_ogre` (si los colmillos no van ya en la cabeza), `tail_lizard` (parte `hips`), `crest_1`…`crest_4`, los 8 peinados, las 5 barbas y las capas de rasgos `mark_scar_eye`, `mark_scar_cheek`, `mark_warpaint`, `mark_runes` y `mark_freckles`;
  - `data/characters/pieces.json` / `pieces_v2.json` (regenerados), `appearance.json`, `races.json`, `data/texts/textos.csv` y `tests/helpers/render_characters.gd` (sets `races` y `races_back`).
- Tests: `tools/art/tests/`.

**Pasos:**
- [ ] Tests de Node:
  - las cabezas nuevas tienen el cuello en el mismo pivote (y=0) que `headV2`;
  - `ears_elf` lleva la etiqueta `ears`;
  - la cola va en `hips`;
  - cada pieza nueva cabe en 126³;
  - las crestas usan el tinte de pelo (250).
- [ ] Ejecutar `node --test tools/art/tests/`: debe **fallar**.
- [ ] Esculpirlo todo. Los rasgos son vóxeles teñidos a 1 vóxel por delante de la cara.
- [ ] Regenerar las cabezas y las piezas, y ejecutar los tests: deben **pasar**.
- [ ] Datos de `appearance.json`:
  - pieles del ogro: `#7d8c6a` (verde gris), `#6f7a45` (oliva), `#a08445` (ocre), `#5f6b72` (pizarra), `#6e7f93` (azul ceniza) y `#5a5a3c` (marrón musgo), con `races: ["ogre"]`;
  - pieles del lagarto: `#4f8a3c` (verde), `#2f8f7a` (jade), `#c2a36b` (arena), `#9a4f2c` (óxido), `#25303f` (negro azulado) y `#e8e2d0` (albino), con `races: ["lizard"]`;
  - dos pieles más para el elfo: `#f3eef6` (pálido lunar) y `#b8b4b8` (ceniza);
  - ojos nuevos: `#d6b42a` (amarillo reptil) y `#8a4fc0` (violeta);
  - pelos nuevos: `#e8e0c8` (platino), `#f4f4f0` (blanco), `#8a3b22` (castaño rojizo), `#1e2a4a` (azul noche) y `#4a6b3a` (verde musgo);
  - las listas `races` de peinados y barbas, según la tabla de la spec.
- [ ] Textos nuevos en `textos.csv`: `APPEAR_RACE`, `APPEAR_MARKS`, `RACE_*`, `RACE_*_DESC` (una línea de lore provisional), `HAIR_*`, `BEARD_*` y `MARK_*`.
- [ ] Capturas de `--set=races` (las 5 razas con el mismo peinado y ropa) y `--set=variety`, para que las revise el usuario.
- [ ] Commit: `art: race heads, ears, tail, crests, new hair, beards and face marks`.

### T5 · El equipo en las cabezas de ogro y lagarto
**Archivos:**
- Modificar `races.json` (los `head_fit` definitivos) y `character_catalog.gd` (ajuste opcional por pieza: `"fit": {"ogre": {"scale": 1.1, "offset": [0, 2, 1]}}` en `pieces_v2.json`).
- Tests: `test_character_catalog.gd` y `test_human_rig.gd`.

**Pasos:**
- [ ] Tests:
  - `test_every_head_piece_attaches_to_every_race`: todas las piezas `part == "head"` del equipo v2 sobre las 5 razas, sin errores;
  - `test_closed_helmet_hides_elf_ears`;
  - `test_snout_and_tusks_never_hidden`;
  - `test_piece_fit_overrides_head_fit`.
- [ ] Ejecutar: deben **fallar**.
- [ ] Implementar `fit` en `piece_entry(id, race)`.
- [ ] Ajustar los `head_fit` mirando `--set=gear --tier=1..3` con cada raza (parámetro nuevo `--race=`).
- [ ] Ejecutar los tests: deben **pasar**. Hacer capturas por tramo para el usuario.
- [ ] Commit: `fix: fit headgear to ogre and lizard heads`.

### T6 · Tema de piedra y oro
**Archivos:**
- Crear `ui/stone_theme.gd`.
- Tests: `tests/unit/ui/test_stone_theme.gd`.

**Interfaces:**
- `class_name StoneTheme`.
- Constantes: `STONE := Color("#2a2522")`, `STONE_DARK := Color("#17130f")`, `GOLD := Color("#e3b45a")`, `GOLD_DIM := Color("#9c7a3c")`, `BLOOD := Color("#8e1b1b")` y `TEXT := Color("#f1e4c8")`.
- `static func apply(theme: Theme) -> void`: botones con borde dorado de 2 px y bisel; el pulsado, en rojo.
- `static func panel() -> StyleBoxFlat`.
- `static func primary_button(b: Button) -> void`: el botón grande dorado de Jugar.

**Pasos:**
- [ ] Test: `apply` define los estilos `normal`, `hover`, `pressed` y `disabled` de Button, y `panel` de PanelContainer, con los colores de las constantes. Comprobar que falla.
- [ ] Implementar y comprobar que pasa.
- [ ] Commit: `feat: stone and gold menu theme`.

### T7 · Decorado del altar y pose de oración
**Archivos:**
- Modificar:
  - `tools/art/make_props.mjs`: `altar_sun` (un altar de piedra con el Sol Negro en vóxel brillante 253 con tono rojo), `column_broken`, `brazier`, `candles` y `flagstones`, a 5 cm/vóxel como la antorcha;
  - `game/characters/human_rig.gd`: acción en bucle `pray` (brazos alzados a unos 120°, cabeza alta y balanceo leve, con un ciclo de 4 s), en `LOOPING`.
- Tests: `tools/art/tests/` y `test_human_rig.gd`.

**Pasos:**
- [ ] Tests: los props nuevos existen y caben en su tamaño; `play_action("pray")` deja `current_action() == "pray"` pasados 10 s y levanta los brazos por encima de los hombros. Comprobar que fallan.
- [ ] Implementar, generar `assets/props/` y comprobar que pasan.
- [ ] Commit: `art: black sun altar props and a praying loop`.

### T8 · Escena del menú
**Archivos:**
- Crear `game/menu_scene.gd` y `data/scenes/title_altar.json`.
- Tests: `tests/unit/game/test_menu_scene.gd`.

**Interfaces:**
- Formato de `title_altar.json`:
  ```json
  {"ambience":"mazmorra_noche","props":[{"id":"altar_sun","pos":[0,0,0],"rot":0}, ...],
   "cultists":[{"type":"cultist","pos":[2.2,0,0],"face":[0,0,0]}, ...6],
   "lights":[{"pos":[0,1.2,0],"color":"#ff5a2a","energy":2.0,"flicker":true}],
   "shots":{"title":{"orbit":{"center":[0,1,0],"radius":7,"height":3.2,"period_s":60}},
            "select":{"pos":[0,1.4,-6.5],"look":[0,1.0,-3.6]},
            "create":{"pos":[0.8,1.4,-6.2],"look":[0,1.0,-3.6]}},
   "hero_spot":[0,0,-3.6]}
  ```
- `class_name MenuScene extends Node3D`.
- `func build(path: String = DEFAULT_PATH) -> void`.
- `func set_shot(id: String, instant: bool = false) -> void`: transición de 1 s entre planos.
- `func show_character(look: Dictionary) -> HumanRig` (devuelve `null` si `look` está vacío).
- `func set_quality(q: int) -> void`.
- `var hero: HumanRig`.
- Los cultistas son `HumanRig.build(MonsterAvatar.look_of(type))` en `pray`, con un desfase aleatorio de fase.
- Brasas y niebla con `AmbienceBuilder`. Las luces con `flicker` reutilizan el parpadeo de `Torch`.

**Pasos:**
- [ ] Tests:
  - `test_builds_from_data`: 6 cultistas, el altar y al menos una luz;
  - `test_shots_exist`: `set_shot` con `title`, `select` y `create` mueve la cámara;
  - `test_show_character_replaces_hero`: dos llamadas dejan un solo héroe;
  - `test_frees_cleanly`: se construye, se libera y no quedan recursos (GUT sin fugas).
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: black sun altar menu scene driven by data`.

### T9 · Pantalla de inicio y créditos
**Archivos:**
- Modificar `ui/title_screen.gd`.
- Crear `ui/credits_window.gd`.
- Añadir los textos `MENU_CREDITS`, `CREDITS_TITLE` y `CREDITS_BODY` (Kenney CC0, Teko OFL, Godot MIT, GUT MIT).
- Tests: `tests/unit/ui/test_title_screen.gd`.

**Interfaces:**
- `TitleScreen`:
  - mantiene `play_requested`, `quit_requested` y `options_requested`, y añade `credits_requested`;
  - tiene `play_button`, `options_button`, `credits_button`, `quit_button`, `logo` y `version_label`;
  - **sin fondo opaco**: deja ver la `MenuScene`.
- `CreditsWindow extends PanelContainer` con un `close_requested`.

**Disposición:**
- logo centrado arriba (480×160);
- `play_button` abajo a la izquierda (margen de 40 px, al menos 260×64, `StoneTheme.primary_button`);
- versión abajo a la derecha;
- iconos de 48 px arriba a la derecha, en este orden: ajustes, créditos y salir (iconos vóxel de `make_icons.mjs`: `ui_gear`, `ui_star`, `ui_exit`), con `tooltip_text`.

**Pasos:**
- [ ] Tests:
  - `test_play_bottom_left`: el centro del botón cae en el cuadrante inferior izquierdo;
  - `test_icons_top_right_in_order`;
  - un test por cada icono, comprobando su señal;
  - `test_no_opaque_background`;
  - los de logo, versión y `test_all_ui_fits_1280x720`, que se mantienen.
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: final title screen with corner play button, icons and credits`.

### T10 · Selección y creación sobre la escena
**Archivos:**
- Modificar `ui/character_select_screen.gd` y `ui/character_create_screen.gd`.
- Tests: `tests/unit/ui/test_character_screens.gd`.

**Interfaces:**
- Ambas pantallas quitan su `CharacterPreview` y su fondo, y emiten `look_changed(look: Dictionary)` cuando cambia el personaje que se ve. `main` lo pasa a `MenuScene.show_character`.
- Selección: mantiene todas sus señales; la fila de cada personaje muestra nombre, clase, nivel y raza; el panel `StoneTheme.panel()` va a la izquierda (≤ 460 px de ancho).
- Creación: la fila `race` va primero, con la etiqueta `RACE_*_DESC` debajo. `_step(kind)` usa `options_for(kind, race)`, y al cambiar de raza llama a `sanitize_appearance` y refresca todas las filas. El arrastre sobre la zona vacía de la derecha gira `MenuScene.hero` con `func turn_hero(deg: float)`. Si las filas no caben en 720 px de alto, se reparten en un `TabContainer` (Raza y cuerpo · Cabeza · Rasgos).

**Pasos:**
- [ ] Tests:
  - `test_race_row_first_with_description`;
  - `test_changing_race_fixes_invalid_options`: un humano con barba larga pasa a lagarto, sin barba y con una cresta válida;
  - `test_random_respects_race`;
  - `test_create_emits_race`;
  - `test_select_row_shows_race`;
  - `test_look_changed_emitted`;
  - `test_both_fit_1280x720` (sin ScrollContainer).
- [ ] Comprobar que fallan.
- [ ] Implementar y comprobar que pasan.
- [ ] Commit: `feat: stone-themed character select and create over the altar scene`.

### T11 · Integración en `main`
**Archivos:**
- Modificar `game/main.gd`.
- Tests: `tests/unit/ui/test_main_flow.gd`.

**Reglas:**
- El tema de los tres menús es `StoneTheme`, y el resto mantiene `HoloTheme`.
- `MenuScene` se crea en `_ready`. `_show_title`, `_show_select` y `_show_create` llaman a `set_shot`.
- `look_changed` → `show_character`.
- Al entrar en partida, la escena se **libera**. Al volver al menú, se reconstruye.
- La calidad gráfica de las opciones se aplica también a `MenuScene`.
- `credits_requested` abre `CreditsWindow`.

**Pasos:**
- [ ] Tests:
  - `test_menu_scene_follows_screens`;
  - `test_menu_scene_freed_in_game_and_back`;
  - `test_credits_open_and_close`;
  - `test_menus_use_stone_theme`.
- [ ] Comprobar que fallan.
- [ ] Implementar, y comprobar que pasan los tests y la suite completa sin fugas.
- [ ] Commit: `feat: wire the altar scene and stone theme into the menu flow`.

### T12 · Documentación y versión
**Archivos:**
- `project.godot` → `config/version="0.10.0"`.
- `docs/Decisiones/D-016 Razas solo de aspecto con cabeza propia.md` y el índice de decisiones.
- En el GDD:
  - `04 Personajes y progresión.md` §4.10 ([Implementado], con las razas);
  - `09 Interfaz.md` §9.1;
  - `11 Arte y audio.md`;
  - `15 Decisiones abiertas.md` (cerrar «Razas»);
  - `Registro de cambios.md`.
- `docs/Planes/Planes.md` (fila 7) y el estado de la spec y del plan.
- Notas de la versión y `docs/Sesiones/`.
- `tools/art/README.md`, con los sets y los comandos nuevos.

**Pasos:**
- [ ] Actualizar los documentos y la versión.
- [ ] Ejecutar la suite completa y `node --test tools/art/tests/`: deben **pasar**.
- [ ] Commit: `docs: Plan 7 identity and character creation (0.10.0)`.
- [ ] Prueba de juego del usuario. Las correcciones van a 7.x antes de publicar.

---
← [[Planes]]
