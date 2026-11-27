---
tags: [plan]
plan: 2
fecha: 2026-11-14
estado: hecho
actualizado: 2026-11-14
---
# Plan 2 — Personajes vóxel: plan de implementación

> **Ejecución:** nativa en el chat (norma 5), tarea a tarea y con TDD. Los pasos llevan casillas `- [ ]` para el seguimiento. Las tareas 3 y 4 **se paran** en un punto de control de arte hasta que el usuario dé su visto bueno a las capturas.

**Objetivo:** personajes vóxel propios basados en Kenney Blocky Characters:
- capas de textura teñidas y piezas `.vox` enganchadas;
- animaciones de reposo y andar;
- hasta 8 personajes guardados por jugador, con exportación e importación;
- pantallas de selección y creación;
- personaje enviado al grupo y saneado por el anfitrión.

Se publica como versión 0.2.0.

**Arquitectura:**
- `game/characters/`: lector `.vox`, mallas, catálogo y `CharacterRig`. El rig es un nodo que monta el modelo de Kenney con su shader de capas y sus piezas.
- `save/`: `CharacterData` y `CharacterStore`.
- `net/`: transporta la clase y la apariencia como diccionarios saneados.
- `ui/`: las pantallas nuevas.
- `sim/` no cambia.
- El arte se genera con scripts de Node en `tools/art/`, cuyo resultado se guarda en `assets/characters/`.

**Tecnología:** Godot 4.7.2, GDScript tipado, GUT 9.6.1, Node (scripts de arte, sin dependencias) y MagicaVoxel `.vox` (formato de archivo).

**Spec:** [[Plan 2 — Personajes vóxel (spec)]]

## Restricciones globales
- Todas las del Plan 1 siguen en vigor: Godot 4.7.2, tipos, código y commits en inglés, textos en `data/texts/textos.csv`, sin scroll a 1280×720 y `Co-Authored-By` en cada commit.
- **Contenido como datos:** opciones de apariencia, clases y piezas en `data/characters/*.json`. Añadir una opción no toca código.
- **Modelo base:** `assets/characters/base/character-a.glb` (Kenney Blocky Characters 2.0, CC0). Rejilla vóxel de **0,1** unidades del modelo y escala en el mundo `MODEL_SCALE = 0.667` (≈1,8 m).
- **Índices de paleta teñibles** en `.vox`: **250** = color de pelo, **251** = color principal de la clase, **252** = color secundario de la clase.
- **Coordenadas `.vox` → Godot:** vóxel `(x, y, z)` de MagicaVoxel (Z hacia arriba) → `(x, z, y)` en Godot (Y hacia arriba). El origen de la pieza es la esquina del vóxel (0,0,0).
- **Personajes:**
  - máximo **8**;
  - nombre de 2–16 caracteres, con la regla de `HostSession.is_valid_name`;
  - sin nombres repetidos entre tus personajes, sin distinguir mayúsculas (`to_lower()`);
  - nivel 1;
  - formato `CharacterData.VERSION = 1`.
- **Archivos:** `user://saves/characters/<id>.json`. Ajustes `SettingsStore.VERSION = 2`, con `last_character_id`.
- **Protocolo:** `Protocol.VERSION = 2`. **Versión del juego:** `0.2.0` (en la tarea 9).
- **Clases** (ids): `warrior`, `cleric`, `mage`, `archer`, `assassin`. Por defecto: `warrior`.
- **Opciones de apariencia** (kinds): `body` (2), `skin` (8), `eyes` (6), `hair_style` (8), `hair_color` (10), `beard` (5, incluida `none`).
- **Animaciones** del glb que se usan: `idle` y `walk`. Transición de 0,15 s. A partir de **0,2 m/s** cuenta como "andando"; la velocidad de reproducción es la velocidad real dividida entre `balance.move_speed`.

## Puntos de atención en la revisión
1. **Archivo de personaje dañado, editado a mano o un JSON que no es un personaje** (al cargar o al importar): se ignora con un aviso, nunca da error de script y nunca borra el archivo → tests en la tarea 6.
2. **Un invitado envía una apariencia inventada**: ids desconocidos, valores que no son texto, cientos de claves, clase vacía. El anfitrión la sanea y el jugador entra con valores por defecto → tests en la tarea 7.
3. **Nombres con tildes y mayúsculas:** "Ána" y "ána" se consideran repetidos, y "Ñoño" y "O'Brien" se aceptan → tests en la tarea 6.
4. **Exportar o importar cancelado, o un error de escritura** (carpeta sin permiso): un aviso, sin error y sin personajes a medias → tests en la tarea 6 (almacén) y en la tarea 8 (cancelar no hace nada).
5. **Avatar de otro jugador sin datos todavía, o que aparece de golpe** (primer estado, salto al aparecer): no se queda "andando" para siempre. Con el estado vacío o con un salto mayor de 2 m en un fotograma queda en `idle` → test en la tarea 5.

---

### Task 0: Cierre del Plan 1
- [ ] La suite completa PASA en local y en CI.
- [ ] Revisión final del Plan 1 (`requesting-code-review` sobre los commits desde `95deff0`). Se corrige lo que salga, incluidos los avisos de GDScript que daba `run_project` y el ping de ~100 ms de ENet en local: hay que explicarlo o corregirlo.
- [ ] Documentación:
  - en [[15 Decisiones abiertas]] y [[02 Arquitectura técnica|§2.5]], "Prueba entre casas aplazada hasta tener más contenido; se mantienen WebRTC (por defecto) y ENet";
  - plan del Plan 1 → `estado: hecho, salvo la prueba entre casas`;
  - `Planes.md`;
  - nota de sesión.
- [ ] Commit `docs: close Plan 1 (home-to-home test postponed)` y push.

### Task 1: Lector de `.vox`
**Archivos:**
- Crear: `game/characters/vox_file.gd`
- Crear: `tests/helpers/vox_writer.gd` (solo para tests)
- Test: `tests/unit/characters/test_vox_file.gd`

**Interfaces:**
- Produce:
  - `class_name VoxFile extends RefCounted`, con `size: Vector3i`, `voxels: Array` (cada elemento `[x, y, z, index]` en coordenadas de Godot, ya convertidas) y `palette: PackedColorArray` (256 colores; índice 0 = vacío);
  - `static func parse(bytes: PackedByteArray) -> VoxFile`, que devuelve `null` si el archivo no es válido;
  - `static func load_file(path: String) -> VoxFile`.
- Helper de tests: `VoxWriter.build(size: Vector3i, voxels: Array, palette: PackedColorArray = []) -> PackedByteArray`. Recibe los vóxeles en coordenadas de MagicaVoxel y escribe `VOX `, versión 150, `MAIN`, `SIZE`, `XYZI` y, si hay paleta, `RGBA`.

- [ ] **Paso 1: tests que fallan.**
  - `test_parses_size_voxels_and_palette`: escribe 2×3×4 con el vóxel MagicaVoxel `[1,2,3, 5]` y la paleta con el índice 5 = rojo. Comprueba `size == Vector3i(2,4,3)`, `voxels == [[1,3,2,5]]` y `palette[5] == Color.RED`.
  - `test_default_palette_when_no_rgba`: `palette.size() == 256`.
  - `test_rejects_bad_magic`, `test_rejects_truncated_chunk` y `test_rejects_voxel_outside_size`: `parse()` devuelve `null`.
  - `test_empty_bytes_is_null`.
- [ ] **Paso 2:** ejecutar `./run_tests.sh tests/unit/characters/test_vox_file.gd` → FALLA.
- [ ] **Paso 3:** implementar `VoxFile.parse`.
  - Recorre los bloques de `MAIN` y lee `SIZE`, `XYZI` y `RGBA`. Ignora los demás.
  - `RGBA[i]` corresponde al índice `i+1`.
  - Si no hay `RGBA`, usa la paleta por defecto de MagicaVoxel, aunque basta con gris.
  - Comprueba los límites antes de leer. Nunca escribe errores del motor con datos truncados.
- [ ] **Paso 4:** ejecutar el test → PASA.
- [ ] **Paso 5:** commit `feat(characters): MagicaVoxel .vox reader`.

### Task 2: Mallas de vóxeles con colores teñibles
**Archivos:**
- Crear: `game/characters/vox_mesher.gd`
- Test: `tests/unit/characters/test_vox_mesher.gd`

**Interfaces:**
- Consume: `VoxFile`.
- Produce:
  - `class_name VoxMesher extends RefCounted`;
  - `const VOXEL_SIZE := 0.1`, `const TINT_HAIR := 250`, `const TINT_PRIMARY := 251`, `const TINT_SECONDARY := 252`;
  - `static func build(vox: VoxFile, tints: Dictionary) -> ArrayMesh` (`tints`: índice → `Color`);
  - `static func cached(path: String, tints: Dictionary) -> ArrayMesh`, con caché por ruta y tintes.

- [ ] **Paso 1: tests que fallan.**
  - `test_single_voxel_has_6_faces`: 24 vértices y 36 índices.
  - `test_two_adjacent_voxels_have_10_faces`.
  - `test_tint_index_uses_given_color`: el color de los vértices del índice 250 es el `Color` pasado.
  - `test_untinted_uses_palette_color`.
  - `test_voxel_size_scales_positions`: un vóxel en `(2,0,0)` va de x = 0.2 a 0.3.
  - `test_cached_returns_same_mesh_for_same_tints`.
- [ ] **Paso 2:** ejecutar → FALLA.
- [ ] **Paso 3:** implementar.
  - Una cara por lado de vóxel cuyo vecino está vacío, con colores por vértice y normales planas.
  - El material es un `StandardMaterial3D` con `vertex_color_use_as_albedo`.
  - La clave de caché es `path + str(tints)`.
- [ ] **Paso 4:** ejecutar → PASA.
- [ ] **Paso 5:** commit `feat(characters): voxel meshing with tintable palette indices`.

### Task 3: Prueba de viabilidad del arte (punto de control 1)
**Archivos:**
- Crear: `tools/art/png.mjs`, que lee PNG con paleta o RGBA (filtros 0–4) y escribe PNG RGBA. Usa solo `zlib` de Node.
- Crear: `tools/art/vox.mjs`, que escribe `.vox` con la paleta y los índices teñibles de las restricciones globales.
- Crear: `tools/art/extract_layers.mjs <carpeta de texturas de Kenney> <salida>`.
- Crear: `tools/art/paint_outfits.mjs` y `tools/art/make_pieces.mjs`.
- Crear: `tools/art/README.md`, con cómo se ejecutan y de dónde sale el pack (`~/Downloads/kenney_blocky-characters_20.zip`).
- Crear:
  - `assets/characters/base/character-a.glb`;
  - `assets/characters/layers/*.png`: piel, cara, ojos, un peinado, una barba y la ropa del mago;
  - `assets/characters/pieces/hair_long.vox` y `hat_mage.vox`.
- Crear: `assets/characters/character.gdshader`.
- Crear: `game/characters/character_rig.gd` (mínimo) y `tools/render_characters.gd`.
- Crear: `CREDITS.md`.

**Interfaces:**
- Produce:
  - `class_name CharacterRig extends Node3D`;
  - `const MODEL_SCALE := 0.667`;
  - `const PARTS := ["torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]`;
  - `static func create(class_id: String, appearance: Dictionary, catalog: CharacterCatalog = null) -> CharacterRig`. En esta tarea acepta un diccionario ya resuelto con rutas y colores. El catálogo llega en la tarea 4.
  - `func part(name: String) -> Node3D`;
  - el shader con los uniforms `skin_tex`, `face_tex`, `eyes_tex`, `hair_tex`, `beard_tex`, `outfit_tex` (`sampler2D`, transparente si no hay) y `skin_color`, `eyes_color`, `hair_color` (`vec3`).
  - **Orden de las capas:** piel × skin_color → cara → ojos × eyes_color → ropa → barba × hair_color → pelo × hair_color.
- `tools/render_characters.gd` (SceneTree, con ventana): monta una fila de personajes, los ilumina como en el escenario y guarda `user://render/characters.png`.

- [ ] **Paso 1:** extraer capas de las 18 texturas.
  - Por regiones de la plantilla UV: cabeza, torso, brazos y piernas.
  - Piel = píxeles cercanos al tono de piel de muestra de cada textura, pasados a gris con el sombreado normalizado.
  - Pelo y barba = píxeles de la cabeza que no son piel ni cara, en gris.
  - Ojos y cara = recortes fijos de la cara.
  - Se elige el mejor resultado para cada capa.
- [ ] **Paso 2:** pintar con el script la ropa del mago (túnica larga) en el estilo de Kenney: formas planas, sombreado suave y bordes oscuros.
- [ ] **Paso 3:** generar `hair_long.vox` (enganchado a `head`) y `hat_mage.vox`, con índices teñibles.
- [ ] **Paso 4:** `CharacterRig` mínimo y `tools/render_characters.gd`.
  - El rig carga el glb, pone el shader en las 6 mallas, aplica `MODEL_SCALE` y engancha las piezas a `part("head")`.
  - Se comprueba que las mallas de Kenney se ven con sombreado normal; si no, se prueba *unlit*.
  - Captura: 3 versiones del mago con piel, pelo y ojos distintos, más 1 sin sombrero y con melena.
- [ ] **Paso 5: test** `tests/unit/characters/test_character_rig.gd::test_rig_has_six_parts_and_attached_pieces`: crea el rig de la prueba y comprueba que las 6 partes existen y que `hat_mage` es hijo de `head`.
- [ ] **Paso 6: PUNTO DE CONTROL 1.**
  - Se envía la captura al usuario (SendUserFile) junto con lo que ha salido bien y mal de los recortes.
  - **Se espera su visto bueno.** Según lo que diga: seguir, repintar las capas a mano con scripts, o pasar a Blender o Claude Design.
- [ ] **Paso 7:** commit `feat(characters): art pipeline spike (layers, mage outfit, first voxel pieces)`.

### Task 4: Todo el arte y el catálogo en datos (punto de control 2)
**Archivos:**
- Crear: `data/characters/appearance.json`, `classes.json` y `pieces.json`.
- Crear: `game/characters/character_catalog.gd`.
- Crear: el resto de capas y piezas en `assets/characters/`.
- Modificar: `data/texts/textos.csv`, con los nombres de clases, descripciones y opciones.
- Test: `tests/unit/characters/test_character_catalog.gd`.

**Interfaces:**
- Formato de los JSON:
  - **`appearance.json`**: `{ "<kind>": [ {"id", "name" (clave de texto), ...}, ... ] }`.
    - `body` lleva `"scale": {"torso": [x,y,z], "arm": [x,y,z], "leg": [x,y,z]}`.
    - `skin`, `eyes` y `hair_color` llevan `"color": "#rrggbb"`.
    - `hair_style` lleva `"layer": "res://…png"` y `"piece": "<id>"` o `""`.
    - `beard` lleva `"layer"`, con `""` para `none`.
  - **`classes.json`**: `[ {"id", "name", "desc", "outfit": "res://…png", "headgear": "<piece id>" | "", "primary": "#…", "secondary": "#…"} ]`.
  - **`pieces.json`**: `{ "<id>": {"file": "res://…vox", "part": "<parte>", "offset": [x,y,z] (vóxeles), "tag": "hair" | "headgear", "hides": ["hair"]} }`.
- Produce: `class_name CharacterCatalog extends RefCounted`, con:
  - `const KINDS := ["body", "skin", "eyes", "hair_style", "hair_color", "beard"]` y `const DEFAULT_CLASS := "warrior"`;
  - `static func load_default() -> CharacterCatalog` (en caché);
  - `func options(kind: String) -> Array`, `func option(kind: String, id: String) -> Dictionary` (`{}` si no existe), `func classes() -> Array`, `func class_def(id: String) -> Dictionary` y `func piece(id: String) -> Dictionary`;
  - `func default_appearance() -> Dictionary` (la primera opción de cada kind);
  - `func sanitize_class(id: Variant) -> String` y `func sanitize_appearance(app: Variant) -> Dictionary`, que devuelve exactamente las 6 claves con ids válidos;
  - `func random_appearance(rng: RandomNumberGenerator) -> Dictionary`.
- `CharacterRig.create(class_id, appearance, catalog)` pasa a resolver todo con el catálogo.
  - **Escala del cuerpo:** `torso`, los dos brazos y las dos piernas se multiplican por `scale`.
  - **Piezas:**
    1. el tocado de la clase;
    2. la pieza del peinado, salvo que alguna pieza con `hides` contenga su `tag`.
  - `func pieces() -> Array[String]` devuelve los ids enganchados.

- [ ] **Paso 1: tests que fallan.**
  - `test_all_kinds_have_expected_counts`: body 2, skin 8, eyes 6, hair_style 8, hair_color 10 y beard 5.
  - `test_five_classes_with_ids`.
  - `test_every_referenced_file_exists`: capas, piezas y `.vox`. Los `.vox` además se leen con `VoxFile.load_file` sin devolver `null`.
  - `test_every_name_key_is_translated`: `TranslationServer.translate(key) != key`.
  - `test_sanitize_unknown_ids_fall_back_to_defaults`.
  - `test_sanitize_non_dictionary_returns_default`.
  - `test_sanitize_drops_extra_keys_and_non_strings`.
  - `test_random_appearance_is_valid`.
- [ ] **Paso 2: tests del rig** en `test_character_rig.gd`.
  - `test_builds_every_class_body_and_hair_style_without_errors`: las 5 × 2 × 8 combinaciones, con `free()` de cada una.
  - `test_hood_hides_long_hair`: el arquero con `hair_long` no tiene la pieza `hair_long`.
  - `test_robust_body_scales_torso`.
- [ ] **Paso 3:** ejecutar → FALLA. Implementar el catálogo, los JSON y el rig completo.
- [ ] **Paso 4:** producir el resto del arte con los scripts de la tarea 3:
  - 8 peinados, de ellos 4 con pieza (`hair_long`, `hair_ponytail`, `hair_bun` y `hair_mohawk`);
  - 5 barbas;
  - la ropa de las 5 clases;
  - los tocados `hood_cleric` (sin `hides`), `hat_mage` (`hides: ["hair"]`), `hood_archer` (`hides: ["hair"]`) y `mask_assassin` (sin `hides`).
- [ ] **Paso 5:** ejecutar → PASA.
- [ ] **Paso 6: PUNTO DE CONTROL 2.**
  - Captura con las 5 clases y una fila de variaciones de apariencia.
  - Se envía al usuario y **se espera su visto bueno** antes de seguir.
- [ ] **Paso 7:** commit `feat(characters): appearance catalog, class outfits and voxel pieces`.

### Task 5: Avatar animado en el juego
**Archivos:**
- Modificar: `game/player_avatar.gd` y `game/game_session.gd:236-250` (`_sync_avatars`).
- Modificar: `game/characters/character_rig.gd`.
- Test: `tests/unit/game/test_player_avatar.gd`.

**Interfaces:**
- Consume: `CharacterRig.create`.
- Produce:
  - `CharacterRig.set_moving_speed(speed_mps: float, move_speed: float) -> void` y `CharacterRig.current_animation() -> String` (`"idle"` o `"walk"`);
  - `PlayerAvatar.setup(player_name: String, slot: int, class_id: String, appearance: Dictionary) -> void`, que sustituye a la cápsula por el rig y mantiene el nombre y la flecha de apuntar;
  - `PlayerAvatar.apply_state(state: Dictionary, delta: float) -> void`, que calcula la velocidad a partir del cambio de posición.
- `GameSession._sync_avatars` pasa `client.roster[id].class_id` y `.appearance` (tarea 7). Hasta la tarea 7 usa `CharacterCatalog.DEFAULT_CLASS` y `{}` si no existen.

- [ ] **Paso 1: tests que fallan.**
  - `test_idle_when_still`.
  - `test_walk_when_moving_at_move_speed`: posiciones que avanzan 5 m/s × delta.
  - `test_walk_speed_scale_matches_velocity`: a 2,5 m/s, `speed_scale` ≈ 0.5.
  - `test_empty_state_keeps_idle`.
  - `test_teleport_jump_is_not_walking` (punto de atención 5): un salto de 3 m en un fotograma da `idle`.
  - `test_faces_state_facing`: `rotation.y == state.facing`.
- [ ] **Paso 2:** ejecutar → FALLA. Implementar: `AnimationPlayer.play(name, 0.15)` y `speed_scale`.
- [ ] **Paso 3:** ejecutar el test y la suite completa → PASA.
- [ ] **Paso 4:** commit `feat(game): animated voxel character avatars`.

### Task 6: Personajes guardados
**Archivos:**
- Crear: `save/character_data.gd` y `save/character_store.gd`.
- Modificar: `save/settings_store.gd` (VERSION 2, `last_character_id`; `player_name` solo se lee, para rellenar el nombre del primer personaje).
- Test: `tests/unit/save/test_character_data.gd`, `test_character_store.gd` y `test_settings_store.gd`.

**Interfaces:**
- Produce `class_name CharacterData extends RefCounted`:
  - `const VERSION := 1`;
  - `id: String`, `name: String`, `class_id: String`, `appearance: Dictionary`, `level: int` y `created_at: int` (unix);
  - `func to_dict() -> Dictionary` (incluye `version`);
  - `static func from_dict(d: Variant, catalog: CharacterCatalog) -> CharacterData`: devuelve `null` si `d` no es un `Dictionary`, si falta `id` o si el nombre no es válido. Sanea la clase y la apariencia y migra con `static func migrate(d: Dictionary) -> Dictionary`.
- Produce `class_name CharacterStore extends RefCounted`:
  - `const MAX_CHARACTERS := 8` y `const DEFAULT_DIR := "user://saves/characters"`;
  - `func _init(dir: String = DEFAULT_DIR, catalog: CharacterCatalog = null)`;
  - `var last_error: String` (clave de texto) y `var skipped_files: Array[String]`;
  - `func load_all() -> Array[CharacterData]`, ordenado por `created_at`;
  - `func create(name: String, class_id: String, appearance: Dictionary) -> CharacterData` (`null` con `last_error` en `ERR_CHAR_FULL`, `ERR_NAME` o `ERR_NAME_TAKEN`);
  - `func delete(id: String) -> bool` y `func name_taken(name: String, except_id: String = "") -> bool`;
  - `func export_to(id: String, path: String) -> Error`;
  - `func import_from(path: String, new_name: String = "") -> CharacterData` (`null` con `ERR_IMPORT_INVALID`, `ERR_NAME_TAKEN` o `ERR_CHAR_FULL`). Al importar se genera un **id nuevo**.
- El id es de 16 caracteres hexadecimales de `Crypto.generate_random_bytes(8)`.

- [ ] **Paso 1: tests que fallan.** `test_character_data.gd`:
  - `test_round_trip`;
  - `test_sanitizes_unknown_class_and_appearance`;
  - `test_rejects_non_dictionary_and_missing_id`;
  - `test_migrates_version_0_example`: un diccionario sin `version` y con `class` en vez de `class_id` se migra.
- [ ] **Paso 2: tests que fallan.** `test_character_store.gd` (en un directorio temporal en `user://test_chars/` que se borra en `after_each`):
  - `test_create_and_load`;
  - `test_max_eight`;
  - `test_duplicate_name_case_insensitive`: "Ána" frente a "ána" (punto de atención 3);
  - `test_accepts_accented_and_apostrophe_names`;
  - `test_damaged_file_is_skipped_not_deleted` (punto de atención 1);
  - `test_import_non_character_json_fails_cleanly`;
  - `test_export_import_round_trip_gets_new_id`;
  - `test_import_with_taken_name_needs_new_name`;
  - `test_export_to_unwritable_path_returns_error` (punto de atención 4);
  - `test_delete`.
- [ ] **Paso 3:** ejecutar → FALLA. Implementar.
- [ ] **Paso 4:** `test_settings_store.gd`: añadir `test_saves_last_character_id` y `test_reads_v1_player_name`.
- [ ] **Paso 5:** ejecutar → PASA. Commit `feat(save): characters with versioned files, export and import`.

### Task 7: Personaje en la red
**Archivos:**
- Modificar: `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd` y `game/game_session.gd`.
- Modificar: `tests/helpers/guest_process.gd`, para que envíe una clase y una apariencia.
- Test: `tests/unit/net/test_protocol.gd`, `test_host_session.gd` y `test_client_session.gd`, más `tests/integration/test_webrtc_session.gd` y `test_two_processes.gd`.

**Interfaces:**
- `Protocol.VERSION := 2`.
  - HELLO: `[game_version, protocol, name, class_id: String, appearance: Dictionary]`.
  - Fila `roster`: `[id, name, slot, class_id, appearance]`.
  - PLAYER_JOINED: `[id, name, slot, class_id, appearance]`.
  - `decode` valida `TYPE_DICTIONARY`.
- `Protocol.hello(game_version: String, protocol: int, name: String, class_id: String, appearance: Dictionary)` y `Protocol.player_joined(id: int, name: String, slot: int, class_id: String, appearance: Dictionary)`.
- `HostSession` tiene `var catalog: CharacterCatalog` (`load_default()`) y sanea en `_on_hello`. `roster()` devuelve las filas nuevas.
- `ClientSession._init(p_balance, p_map, p_game_version, p_name, p_class_id: String = CharacterCatalog.DEFAULT_CLASS, p_appearance: Dictionary = {})`. `roster[id]` es `{"name", "slot", "class_id", "appearance"}`.
- `GameSession.start_host(player_name: String, class_id: String = CharacterCatalog.DEFAULT_CLASS, appearance: Dictionary = {})`, y lo mismo para `join(code, name, class_id, appearance)` y `join_with(signaling, name, class_id, appearance)`.

- [ ] **Paso 1: tests que fallan.**
  - `test_protocol.gd`:
    - `test_hello_carries_class_and_appearance`;
    - `test_hello_with_wrong_types_is_rejected`: `appearance` como `Array` da `{}`.
  - `test_host_session.gd`:
    - `test_host_sanitizes_invented_appearance` (punto de atención 2): ids inventados, valores enteros, 300 claves y clase `""`. El jugador entra con la clase por defecto y una apariencia válida de 6 claves;
    - `test_roster_carries_class_and_appearance`.
  - `test_client_session.gd`: `test_player_joined_updates_roster_with_appearance`.
  - `test_webrtc_session.gd`: `test_guest_class_reaches_host_avatar`.
- [ ] **Paso 2:** ejecutar → FALLA. Implementar. Los tests que ya existen siguen pasando gracias a los valores por defecto.
- [ ] **Paso 3:** suite completa → PASA, incluido `test_two_processes.gd`. Opcionalmente, también con `THALANDOR_SIGNALING` apuntando al servidor desplegado.
- [ ] **Paso 4:** commit `feat(net): players bring their character class and appearance`.

### Task 8: Pantallas de personajes
**Archivos:**
- Crear: `ui/character_preview.gd`, `ui/character_select_screen.gd` y `ui/character_create_screen.gd`.
- Modificar:
  - `ui/title_screen.gd`: título, versión, **Jugar** (que abre "Tus personajes") y **Salir**; sin nombre ni código;
  - `ui/message_dialog.gd`: `func ask(text: String) -> void` con los botones Sí y No y la señal `answered(yes: bool)`;
  - `game/main.gd`: flujo título → selección → crear o jugar o unirse; recuerda `last_character_id` y `last_code`.
- Modificar: `data/texts/textos.csv`.
- Test: `tests/unit/ui/test_character_screens.gd`, `test_title_screen.gd::test_all_ui_fits_1280x720` y `test_main_flow.gd`.

**Interfaces:**
- `CharacterPreview extends SubViewportContainer`: `func show_character(class_id: String, appearance: Dictionary) -> void`. Gira 20°/s; al arrastrar con el ratón, gira con el arrastre.
- `CharacterSelectScreen extends Control`:
  - señales `play_requested(id: String)`, `join_requested(id: String, code: String)`, `create_requested()`, `delete_requested(id: String)`, `export_requested(id: String)`, `import_requested()` y `back_requested()`;
  - `func set_characters(list: Array[CharacterData], selected_id: String) -> void`, `func selected_id() -> String` y `func set_code(code: String) -> void`.
  - **Crear** está desactivado con 8 personajes. **Jugar**, **Unirse**, **Borrar** y **Exportar** están desactivados sin selección.
- `CharacterCreateScreen extends Control`:
  - señales `create_requested(name: String, class_id: String, appearance: Dictionary)` y `back_requested()`;
  - `func reset(default_name: String) -> void` y `func current_appearance() -> Dictionary`.
  - **Crear** está desactivado mientras el nombre no es válido.
- `Main` abre `FileDialog` con `use_native_dialog = true` y el filtro `*.json`. Si se cancela, no pasa nada. Borrar pasa por `dialog.ask`.
- `MessageDialog.ask_text(text: String, default_text: String) -> void`, con la señal `text_answered(text: String)` (`""` = cancelado). Si al importar sale `ERR_NAME_TAKEN`, `Main` pide otro nombre con este diálogo y reintenta `import_from(path, nuevo)`.
- Al entrar en la selección, si `store.skipped_files` no está vacío, `Main` muestra `ERR_CHAR_SKIPPED` con el número de archivos.

- [ ] **Paso 1: tests que fallan.**
  - `test_select_disables_buttons_without_selection`.
  - `test_create_disabled_at_eight`.
  - `test_create_screen_invalid_name_disables_create`.
  - `test_create_screen_arrows_cycle_options`: la flecha ▶ en `hair_style` 8 veces vuelve al inicio.
  - `test_random_gives_valid_appearance`.
  - `test_main_flow.gd`:
    - `test_create_then_play_enters_game_with_that_class`: el roster del cliente tiene la clase elegida;
    - `test_join_from_select_uses_selected_character`;
    - `test_last_character_is_preselected`;
    - `test_delete_asks_confirmation`;
    - `test_cancelled_export_does_nothing`: se llama directamente al manejador de cancelación (punto de atención 4);
    - `test_import_taken_name_asks_for_another`;
    - `test_damaged_files_are_reported`.
  - `test_all_ui_fits_1280x720`: añadir las pantallas de selección (8 personajes con nombres de 16 caracteres) y de creación.
- [ ] **Paso 2:** ejecutar → FALLA. Implementar. Ninguna pantalla necesita scroll.
- [ ] **Paso 3:** suite completa → PASA. Se ejecuta el juego con `run_project` para ver que arranca sin errores en la consola.
- [ ] **Paso 4:** commit `feat(ui): character select and create screens`.

### Task 9: Cierre del plan y versión 0.2.0
- [ ] `project.godot` pasa a `config/version="0.2.0"`. `.github/release-notes.md` explica:
  - los personajes nuevos;
  - que los personajes se guardan en `%APPDATA%\Godot\app_userdata\Thalandor Online\saves\characters`;
  - que hay que jugar todos con la 0.2.0.
- [ ] `CREDITS.md` completo: Kenney y lo que se haya usado.
- [ ] Suite completa en local y en CI → PASA.
- [ ] Revisión final de la rama del Plan 2 (`requesting-code-review`) y corrección de lo que salga.
- [ ] Documentación:
  - GDD §4.10, §9.1, §10 y §11 → [Implementado], con lo que se haya concretado;
  - `Registro de cambios`;
  - `Planes.md` → Plan 2 hecho;
  - este plan → `estado: hecho`;
  - nota de sesión.
- [ ] **Con permiso del usuario:** push, etiqueta `v0.2.0` y comprobación de la Release y del zip.
- [ ] Resumen al usuario: qué se hizo, qué falta y qué probar (crear varios personajes, jugar solo y en grupo, exportar e importar).

---
← [[Planes]]
