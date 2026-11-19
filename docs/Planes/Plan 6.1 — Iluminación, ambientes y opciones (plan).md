---
tags: [plan]
plan: 6.1
fecha: 2026-11-19
estado: hecho
---
# Plan 6.1 — Iluminación, ambientes y opciones: implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (ejecución nativa en el chat, norma 5 del proyecto). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ambientes de iluminación como datos, tres calidades de vídeo, antorchas y una ventana de Opciones (vídeo y sonido) guardada en `settings.json` v3.

**Architecture:** `Ambience` lee un JSON de `data/ambiences/`; `AmbienceBuilder` cruza ambiente × calidad y produce `Environment`, sol y partículas; `Arena` los monta y los reconstruye al cambiar ambiente o calidad. `SettingsStore` guarda vídeo y sonido; `SettingsApplier` los aplica a la ventana, al viewport, a `RenderingServer` y a los buses. `OptionsWindow` edita un `SettingsStore` en vivo; `main.gd` cablea todo.

**Tech Stack:** Godot 4.7.2 (Forward+), GDScript, GUT; Node para el arte (`tools/art/`).

**Spec:** [[Plan 6.1 — Iluminación, ambientes y opciones (spec)]]

## Global Constraints
- Nada de esto toca `sim/` ni la red; sin cambio de protocolo ni de versión de personaje.
- Versión del juego **0.8.0** (`project.godot` `config/version`).
- Textos del juego en `data/texts/textos.csv` (español); código y commits en inglés.
- Ninguna ventana con scroll a 1280×720.
- Sin autoloads: `main.gd` crea y cablea.
- Arte propio por código (`tools/art/`), sin assets de terceros.
- Tests: `"D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=<archivo>`; toda la batería sin `-gtest`. Tras tocar `textos.csv`: `... --headless --path . --import`.

## Review Focus
1. **`settings.json` de la 0.7.0 (v2) sin claves de vídeo** → arranca con Media, 100 %, ventana, VSync, sin límite y volúmenes al 100 %, y conserva último personaje y código (test en Tarea 5).
2. **Valores fuera de rango o de tipo erróneo en el JSON de ajustes** (calidad 7, escala 0,1, FPS 75, volumen −3) → se recortan al valor válido más cercano o al defecto (Tarea 5).
3. **Ambiente con secciones ausentes o mal escritas** (sin `glow`, color no válido) → defectos, sin error (Tarea 1).
4. **Cambiar de calidad varias veces en partida** → no se duplican sol, partículas ni luces de antorcha (Tarea 4).
5. **`/ambiente` con mayúsculas o espacios extra** (`/Ambiente  mazmorra_noche `) → funciona; cualquier otro texto que empiece por `/` sigue yendo al anfitrión (Tarea 7).

---

### Task 1: Ambientes como datos

**Files:**
- Create: `game/visual/ambience.gd`, `data/ambiences/exterior_dia.json`, `data/ambiences/mazmorra_noche.json`
- Test: `tests/unit/game/test_ambience.gd`

**Interfaces:**
- Produces: `class_name Ambience extends RefCounted` con `const DEFAULT_ID := "exterior_dia"`, `const DIR := "res://data/ambiences/"`, `static func from_dict(id: String, d: Dictionary) -> Ambience`, `static func load_id(id: String) -> Ambience` (id inexistente → `DEFAULT_ID` + `push_warning`), `static func ids() -> PackedStringArray` (ordenados). Campos:
  - `id: String`
  - `sun_color: Color`, `sun_energy: float`, `sun_elevation: float` (grados), `sun_azimuth: float`, `sun_shadows: bool`
  - `sky_top: Color`, `sky_horizon: Color` (cielo liso = mismos colores)
  - `ambient_color: Color`, `ambient_energy: float`
  - `fog_color: Color`, `fog_density: float`, `fog_height: float`, `fog_height_density: float`, `volumetric_density: float` (0 = sin volumétrica), `volumetric_albedo: Color`
  - `tonemap: String` (`"aces"` | `"filmic"`), `exposure: float`
  - `glow: bool`, `glow_intensity: float`, `glow_threshold: float`, `glow_bloom: float`
  - `ssao: bool`, `ssao_radius: float`, `ssao_intensity: float`
  - `brightness: float`, `contrast: float`, `saturation: float`
  - `ssr: bool`
  - `dof: bool`, `dof_distance: float`, `dof_amount: float`
  - `particles: String` (`"embers"` | `"dust"` | `"none"`), `particle_amount: int`, `particle_color: Color`

Formato JSON (secciones `sun`, `sky`, `ambient`, `fog`, `tonemap`, `color` con defectos si faltan; `glow`, `ssao`, `dof`, `particles` **ausentes = apagados**; `"ssr": true|false`):
```json
{"sun": {"color": "#ffd9a8", "energy": 1.3, "elevation": 32, "azimuth": -35, "shadows": true},
 "sky": {"top": "#5d8fc8", "horizon": "#f0cfa0"},
 "ambient": {"color": "#a3b6cf", "energy": 0.45},
 "fog": {"color": "#b4c6dc", "density": 0.008, "height": 0.0, "height_density": 0.0, "volumetric_density": 0.01, "volumetric_albedo": "#ffe8cc"},
 "tonemap": {"mode": "aces", "exposure": 1.0},
 "glow": {"intensity": 0.5, "threshold": 1.0, "bloom": 0.03},
 "ssao": {"radius": 1.2, "intensity": 1.6},
 "color": {"brightness": 1.0, "contrast": 1.08, "saturation": 1.05},
 "ssr": false,
 "dof": {"distance": 28, "amount": 0.08},
 "particles": {"type": "dust", "amount": 80, "color": "#fff1d0"}}
```
`mazmorra_noche`: sol frío tenue (`#7f93c9`, 0.25, elevación 50, con sombras), cielo liso `#07080d`, ambiente `#2a2438` 0.25, niebla cálida densa cerca del suelo (`#3a2418`, 0.02, altura 1.5, height_density 0.6, volumétrica 0.03 albedo `#ff9a5a`), glow fuerte (1.0, umbral 0.8, bloom 0.1), ssao fuerte, contraste 1.15, saturación 1.1, `ssr: true`, dof, partículas `embers` 160 `#ff8a3a`. Valores finos ajustables en la revisión por capturas (Tarea 8).

- [ ] **Step 1: Tests que fallan** — `test_load_both_ambiences` (`ids() == ["exterior_dia", "mazmorra_noche"]`; `load_id("mazmorra_noche").particles == "embers"`), `test_missing_sections_use_defaults` (`from_dict("x", {})`: `glow == false`, `ssao == false`, `dof == false`, `particles == "none"`, `sun_energy > 0`, `tonemap == "aces"`), `test_bad_values_fall_back` (`{"sun": {"color": "notacolor", "energy": "x"}}` → color y energía por defecto), `test_unknown_id_falls_back` (`load_id("nope").id == "exterior_dia"`).
- [ ] **Step 2:** Ejecutar `-gtest=res://tests/unit/game/test_ambience.gd` → FAIL (`Ambience` no existe).
- [ ] **Step 3:** Implementar `ambience.gd` y los dos JSON. Colores con `Color.html_is_valid`; números con `is float or is int`.
- [ ] **Step 4:** Ejecutar el test → PASS.
- [ ] **Step 5:** Commit `feat: ambiences as data`.

### Task 2: Calidad y constructor de ambientes

**Files:**
- Create: `game/visual/graphics_quality.gd`, `game/visual/ambience_builder.gd`
- Test: `tests/unit/game/test_ambience_builder.gd`

**Interfaces:**
- Consumes: `Ambience` (Tarea 1).
- Produces:
  - `class_name GraphicsQuality` con `enum { LOW, MEDIUM, HIGH }`, `const PARTICLE_SCALE := [0.25, 0.6, 1.0]`, `static func clamp_level(q: int) -> int`.
  - `class_name AmbienceBuilder` (estático):
    - `make_environment(a: Ambience, q: int) -> Environment`
    - `configure_sun(sun: DirectionalLight3D, a: Ambience, q: int) -> void`
    - `make_particles(a: Ambience, q: int) -> GPUParticles3D` (`null` si `particles == "none"`; `amount = max(1, round(particle_amount × PARTICLE_SCALE[q]))`; caja de emisión de 40 × 6 × 40 m que sigue a la cámara la pone `Arena`)

Reglas (tabla §3 de la spec; la calidad solo **quita**):

| | LOW | MEDIUM | HIGH |
|---|---|---|---|
| `ssao_enabled` | false | `a.ssao` | `a.ssao` |
| `fog_enabled` | true | true | true |
| `fog_height_density` | 0 | `a.fog_height_density` | `a.fog_height_density` |
| `volumetric_fog_enabled` | false | false | `a.volumetric_density > 0` |
| `glow_enabled` | `a.glow` | `a.glow` | `a.glow` |
| `ssr_enabled` | false | false | `a.ssr` |
| DOF lejano (en `CameraAttributesPractical`, devuelto en `env.set_meta("camera_attributes", …)`) | off | off | `a.dof` |
| Sol: `directional_shadow_mode` / `max_distance` | ORTHOGONAL / 40 | PARALLEL_2_SPLITS / 60 | PARALLEL_4_SPLITS / 80 |

Fondo: `BG_SKY` con `ProceduralSkyMaterial` (`sky_top_color`, `sky_horizon_color`, suelo = horizonte oscurecido). Tonemap `TONE_MAPPER_ACES` o `FILMIC`. Corrección con `adjustment_enabled = true`.

- [ ] **Step 1: Tests que fallan** — con `mazmorra_noche`:
  - `test_low_strips_expensive_effects` (LOW: `ssao_enabled`, `ssr_enabled`, `volumetric_fog_enabled` false, `fog_height_density == 0`, `glow_enabled` true);
  - `test_medium_adds_ssao_only` (`ssao_enabled` true, `ssr_enabled` false, volumétrica false);
  - `test_high_has_everything_the_ambience_asks` (ssao, ssr, volumétrica, DOF true);
  - `test_quality_never_adds_what_ambience_lacks` (`from_dict("x", {})` en HIGH: glow, ssao, ssr false; `make_particles` null);
  - `test_sun_shadows_per_quality` (los tres modos y distancias de la tabla);
  - `test_particles_scale_with_quality` (embers 160: 40 / 96 / 160).
- [ ] **Step 2:** Ejecutar → FAIL.
- [ ] **Step 3:** Implementar ambos archivos.
- [ ] **Step 4:** Ejecutar → PASS.
- [ ] **Step 5:** Commit `feat: ambience builder with quality levels`.

### Task 3: Antorcha

**Files:**
- Create: `tools/art/make_props.mjs` → `assets/props/torch.vox`; `game/visual/torch.gd`
- Modify: `tools/art/README.md` (comando nuevo)
- Test: `tests/unit/game/test_torch.gd`

**Interfaces:**
- Produces: `class_name Torch extends Node3D` con:
  - `const VOX_PATH := "res://assets/props/torch.vox"`
  - `var light: OmniLight3D`, `var flame: GPUParticles3D`
  - `func set_quality(q: int) -> void`
  - `static func flicker(t: float, phase: float) -> float`: suma de dos o tres senos de frecuencias no múltiplos (≈ 7, 11 y 17 rad/s), resultado en [0.85, 1.15].
  - Cada antorcha toma una fase aleatoria al crearse; en `_process` aplica `light_energy = 2.2 × flicker` y `omni_range = 7 × (0.97 + 0.03 × flicker)`.

Detalles:
- **Modelo:** poste de madera oscura de 2 × 14 vóxeles, cuenco de hierro de 5 × 3 × 5 arriba y brasas `GLOW` dentro. Escala 0,1 m/vóxel como los monstruos; mallado con `VoxMesher.cached(VOX_PATH, {})`.
- **Luz:** color `#ff9548`, a 1,55 m de altura.
- **Calidad:** `shadow_enabled = (q == HIGH)`. En LOW, `distance_fade_enabled = true`, `distance_fade_begin = 18`.
- **Llama:** partículas pequeñas naranja-amarillas, sin sombra y con material sin sombreado para que la recoja el glow.

- [ ] **Step 1: Tests que fallan** — `test_flicker_stays_in_range` (1000 muestras de t en [0, 60] con 3 fases ∈ [0.85, 1.15]), `test_flicker_varies` (desviación entre muestras > 0,02), `test_shadows_only_on_high` (LOW/MEDIUM false, HIGH true), `test_low_fades_with_distance`, `test_torch_vox_exists` (`FileAccess.file_exists(Torch.VOX_PATH)`).
- [ ] **Step 2:** Ejecutar → FAIL.
- [ ] **Step 3:** Escribir `make_props.mjs` (mismo estilo que `make_monsters.mjs`, `write`/`Shape` de `vox.mjs`); ejecutar `node tools/art/make_props.mjs assets/props`; importar (`--import`); implementar `torch.gd`.
- [ ] **Step 4:** Ejecutar → PASS.
- [ ] **Step 5:** Commit `feat: torch prop with flickering light`.

### Task 4: La arena usa ambientes, calidad y antorchas

**Files:**
- Modify: `game/arena.gd` (sustituye `_add_lighting`), `data/maps/test_arena.json`, `game/game_session.gd`
- Test: `tests/unit/game/test_arena.gd`

**Interfaces:**
- Consumes: Tareas 1–3.
- Produces:
  - `Arena.build(layout: Dictionary, quality: int = GraphicsQuality.MEDIUM) -> CollisionMap` (firma compatible).
  - `Arena.ambience_id: String`, `Arena.quality: int`, `Arena.torches: Array[Torch]`.
  - `Arena.set_ambience(id: String) -> bool` (false si el id no existe; no cambia nada).
  - `Arena.set_quality(q: int) -> void`.
  - `GameSession.set_graphics_quality(q: int) -> void` (delega en `arena`).
  - Nodos fijos bajo la arena: `Sun`, `Environment` (`WorldEnvironment`), `AmbientParticles` (puede faltar) y `Torches/`.
  - Reconstruir **reutiliza** `Sun` y `Environment`, y sustituye las partículas: nunca duplica nodos.
  - `WorldEnvironment.camera_attributes` sale del meta del Environment.

Mapa:
- `"ambience": "exterior_dia"` y `"torches": [[x, z], …]` en `test_arena.json`, con unas 8 antorchas repartidas junto a los bloques y a Brann y el mercader.
- La antorcha se coloca en el centro de la celda, `(x + 0.5, 0, z + 0.5)`.
- Las celdas de antorcha **no** cuentan como sólidas (son decorado; no tocan `CollisionMap`).
- Las partículas de ambiente siguen a la cámara: `Arena.follow(pos: Vector3)`, que `GameSession` llama donde ya mueve la cámara.

- [ ] **Step 1: Tests que fallan:**
  - `test_layout_ambience_is_used`: layout con `"ambience": "mazmorra_noche"` → `ambience_id`.
  - `test_missing_ambience_defaults`: sin `"ambience"` → `"exterior_dia"`.
  - `test_torches_from_layout`: dos antorchas en las posiciones esperadas y celdas no sólidas.
  - `test_set_ambience_rejects_unknown`.
  - `test_switching_quality_and_ambience_does_not_duplicate_nodes`: 3 cambios de calidad y 2 de ambiente → exactamente un `DirectionalLight3D` y un `WorldEnvironment`, y como mucho un `GPUParticles3D` de ambiente.
  - `test_quality_reaches_torches`.
  - Los tests actuales de la arena siguen en verde.
- [ ] **Step 2:** Ejecutar → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Ejecutar `test_arena.gd` y `test_main_flow.gd` → PASS.
- [ ] **Step 5:** Commit `feat: arena lit by data ambiences with torches`.

### Task 5: Ajustes de vídeo y sonido (guardado y aplicación)

**Files:**
- Modify: `save/settings_store.gd` (VERSION 3)
- Create: `game/visual/settings_applier.gd`
- Test: `tests/unit/save/test_settings_store.gd`, `tests/unit/game/test_settings_applier.gd`

**Interfaces:**
- Produces:
  - **`SettingsStore`, campos nuevos con su defecto:**
    - `quality: int = GraphicsQuality.MEDIUM`
    - `render_scale: float = 1.0`, en [0.5, 1.0] y redondeado a 0.05
    - `fullscreen: bool = false`
    - `vsync: bool = true`
    - `max_fps: int = 0`, uno de `SettingsStore.FPS_CHOICES := [0, 30, 60, 120, 144]`; otro valor → el más cercano
    - `volumes: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0, "UI": 1.0}`, cada uno en [0, 1]
    - `muted: bool = false`
  - **Métodos de `SettingsStore`:** `func reset_video_audio() -> void` y `func duplicate_store() -> SettingsStore`. `save_to` escribe todo (v3); `load_from` lee v1, v2 y v3.
  - **`SettingsApplier`** (estático):
    - `const BUSES := ["Master", "Music", "SFX", "UI"]`
    - `ensure_buses() -> void` crea los que falten, con Music, SFX y UI enviando a Master
    - `apply_audio(s: SettingsStore) -> void` usa `linear_to_db`, con 0 → silenciado, y `muted` silencia Master
    - `apply_viewport(s: SettingsStore, vp: Viewport) -> void`:
      - si la escala es menor que 1: `scaling_3d_mode = FSR` y `scaling_3d_scale`; si no, BILINEAR a 1.0
      - `msaa_3d` = 2X en HIGH, si no, DISABLED
      - `screen_space_aa = FXAA`
    - `apply_quality_globals(q: int) -> void`:
      - atlas de sombras del sol 2048 / 4096 / 4096
      - calidad de SSAO: LOW = VERY_LOW, MEDIUM = LOW, HIGH = HIGH
      - filtro de sombras suaves: LOW HARD, MEDIUM LOW, HIGH MEDIUM
    - `apply_window(s: SettingsStore) -> void`: modo de ventana, VSync y `Engine.max_fps`. No toca la ventana si `DisplayServer.get_name() == "headless"`, pero `max_fps` sí.
    - `apply_all(s: SettingsStore, vp: Viewport) -> void`

- [ ] **Step 1: Tests que fallan**
  - **`test_settings_store.gd`:**
    - `test_v3_round_trip`: todos los campos.
    - `test_v2_file_gets_video_defaults`: v2 → Media, 1.0, VSync, `last_character_id` conservado.
    - `test_out_of_range_values_are_clamped`: calidad 7 → HIGH, escala 0.1 → 0.5, FPS 75 → 60, volumen −3 → 0, `"Music": "x"` → 1.0.
    - `test_reset_video_audio_keeps_last_character`.
  - **`test_settings_applier.gd`:**
    - `test_buses_created_and_routed`.
    - `test_volume_zero_mutes_bus`.
    - `test_master_mute`.
    - `test_scale_below_one_uses_fsr`: sobre un `SubViewport`.
    - `test_msaa_only_on_high`.
    - `test_max_fps_applied`: restaurar `Engine.max_fps` en `after_each`.
- [ ] **Step 2:** Ejecutar ambos → FAIL.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Ejecutar → PASS, y `test_main_flow.gd` sigue en verde.
- [ ] **Step 5:** Commit `feat: video and audio settings`.

### Task 6: Ventana de Opciones

**Files:**
- Create: `ui/options_window.gd`
- Modify: `ui/pause_menu.gd` (botón y `signal options_requested()`), `ui/title_screen.gd` (botón y `signal options_requested()`), `game/main.gd`, `data/texts/textos.csv`
- Test: `tests/unit/ui/test_options_window.gd`, `tests/unit/ui/test_title_screen.gd`, `tests/unit/ui/test_main_flow.gd`

**Interfaces:**
- Consumes: `SettingsStore`, `SettingsApplier`, `GraphicsQuality`, `GameSession.set_graphics_quality`.
- Produces:
  - `class_name OptionsWindow extends Control`.
  - Señales: `signal settings_changed()` y `signal closed()`.
  - Métodos:
    - `func open(s: SettingsStore) -> void` edita `s` en vivo.
    - `func show_tab(i: int) -> void`, con 0 = Vídeo y 1 = Sonido.
    - `func panel_rect() -> Rect2`.
    - `func set_quality(q: int) -> void`, `func set_volume(bus: String, v: float) -> void` y `func press_reset() -> void`, que también usan los tests.

Ventana y botones:
- **Layout:**
  - panel centrado con `HoloTheme.panel_style()` y título;
  - `TabContainer` con dos pestañas;
  - Vídeo: calidad (`OptionButton`), escala (`HSlider` del 50 al 100 en pasos de 5, con etiqueta en %), pantalla completa y VSync (`CheckButton`) y límite de FPS (`OptionButton`);
  - Sonido: cuatro `HSlider` del 0 al 100 con % y una casilla de silenciar;
  - abajo, Restablecer y Cerrar.
  - Esc cierra.
- **Menú de pausa:** botón «Opciones» entre «Abrir grupo» y «Salir».
- **Título:** botón «Opciones» entre Jugar y Salir.
- **Al arrancar, `main.gd`:** `SettingsApplier.ensure_buses()` y `apply_all(settings, get_viewport())` después de cargar los ajustes.
- **Al recibir `settings_changed`:** `apply_all` y, si hay partida, `game.set_graphics_quality(settings.quality)`.
- **Al recibir `closed`:** `settings.save_to(settings_path)` y vuelve a la pantalla o menú de origen.
- **Partida nueva:** `_start_game` llama a `game.set_graphics_quality(settings.quality)` nada más crearla.
- **Entrada:** la ventana visible bloquea la entrada (`_update_input_block`).

Textos nuevos:

| Clave | Texto |
|---|---|
| `MENU_OPTIONS` | Opciones |
| `OPTIONS_TITLE` | Opciones |
| `OPTIONS_TAB_VIDEO` | Vídeo |
| `OPTIONS_TAB_SOUND` | Sonido |
| `OPTIONS_QUALITY` | Calidad |
| `QUALITY_LOW` | Baja |
| `QUALITY_MEDIUM` | Media |
| `QUALITY_HIGH` | Alta |
| `OPTIONS_RENDER_SCALE` | Escala de resolución |
| `OPTIONS_FULLSCREEN` | Pantalla completa |
| `OPTIONS_VSYNC` | Sincronización vertical (VSync) |
| `OPTIONS_MAX_FPS` | Límite de FPS |
| `OPTIONS_FPS_UNLIMITED` | Sin límite |
| `OPTIONS_VOL_MASTER` | General |
| `OPTIONS_VOL_MUSIC` | Música |
| `OPTIONS_VOL_SFX` | Efectos |
| `OPTIONS_VOL_UI` | Interfaz |
| `OPTIONS_MUTE` | Silenciar todo |
| `BTN_RESET` | Restablecer |
| `BTN_CLOSE` | Cerrar |

`BTN_CLOSE` solo si no existe ya.

- [ ] **Step 1: Tests que fallan:**
  - `test_window_fits_1280x720_both_tabs`
  - `test_quality_change_edits_store_and_emits`
  - `test_volume_slider_edits_store`
  - `test_reset_restores_defaults_and_emits`
  - `test_escape_closes` (emite `closed`)
  - `test_title_has_options_button`, que emite `options_requested`
  - en `test_main_flow.gd`: `test_options_from_title_saves_on_close`, con ajustes en un archivo temporal: abrir, cambiar a Baja, cerrar, recargar y comprobar `quality == LOW`.
- [ ] **Step 2:** Ejecutar → FAIL.
- [ ] **Step 3:** Implementar y reimportar textos.
- [ ] **Step 4:** Ejecutar los tres archivos → PASS.
- [ ] **Step 5:** Commit `feat: options window (video and sound)`.

### Task 7: Comando local `/ambiente`

**Files:**
- Create: `game/visual/ambience_command.gd`
- Modify: `game/main.gd` (`_on_chat_submitted`), `data/texts/textos.csv`
- Test: `tests/unit/game/test_ambience_command.gd`

**Interfaces:**
- Produces: `class_name AmbienceCommand` con `static func handle(text: String, current: String, ids: PackedStringArray) -> Dictionary` que devuelve `{"handled": bool, "switch_to": String, "message": String}`:
  - El primer token, sin distinguir mayúsculas y quitando espacios, debe ser `/ambiente`; si no, `handled` es false.
  - Sin argumento: el mensaje es `tr("AMBIENCE_LIST") % [current, ", ".join(ids)]`.
  - Con un id válido: `switch_to` es ese id y el mensaje es `tr("AMBIENCE_SET") % id`.
  - Con un id desconocido: `switch_to` queda vacío y el mensaje es `tr("AMBIENCE_UNKNOWN") % [arg, ", ".join(ids)]`.
- `main._on_chat_submitted`:
  - si `handled`: llama a `game.arena.set_ambience(switch_to)` cuando no está vacío, enseña `chat.add_message("", message, true)` y **no** envía nada;
  - si no, se comporta como hoy.

Textos:

| Clave | Texto |
|---|---|
| `AMBIENCE_LIST` | Ambiente: %s. Disponibles: %s |
| `AMBIENCE_SET` | Ambiente cambiado a %s (solo en tu pantalla) |
| `AMBIENCE_UNKNOWN` | No existe el ambiente «%s». Disponibles: %s |

- [ ] **Step 1: Tests que fallan:**
  - `test_lists_without_argument`
  - `test_switches_to_valid_id`
  - `test_case_and_spaces` (`"/Ambiente  mazmorra_noche "`)
  - `test_unknown_id`
  - `test_other_commands_not_handled` (`"/oro 5"`, `"hola"`, `"/ambientex"`)
- [ ] **Step 2:** Ejecutar → FAIL.
- [ ] **Step 3:** Implementar y cablear en `main.gd`.
- [ ] **Step 4:** Ejecutar → PASS.
- [ ] **Step 5:** Commit `feat: local /ambiente command`.

### Task 8: Revisión por capturas, versión y documentación

**Files:**
- Create: `tests/helpers/render_ambiences.gd`, que guarda en `user://render/ambience_<id>_<calidad>.png` la arena con la cámara de juego, un personaje y Brann, para los 2 ambientes × 3 calidades. Se ejecuta con ventana, como `render_characters.gd`.
- Modify:
  - `project.godot` (`config/version="0.8.0"`)
  - `tools/art/README.md`
  - GDD: `docs/GDD/11 Arte y audio.md` (ambientes y calidad **[Implementado 0.8.0]**), `docs/GDD/09 Interfaz.md` (ventana de Opciones), `docs/GDD/06 Mundo.md` (ambiente por zona como dato), `docs/GDD/Registro de cambios.md` (fila nueva)
  - `docs/Planes/Planes.md` (estado de la 6.1) y la spec (`estado: implementado`)
  - una nota de sesión nueva en `docs/Sesiones/`

- [ ] **Step 1:** Ejecutar el render y revisar las 6 capturas. Ajustar los valores de los JSON de ambiente hasta que:
  - el exterior se vea cálido y con profundidad, sin colores de juguete;
  - la mazmorra se vea oscura, con las antorchas y las brasas como luz principal;
  - en Baja se siga viendo bien.
- [ ] **Step 2:** Batería completa de GUT → todo en verde (hoy 1208 tests, más los nuevos).
- [ ] **Step 3:** Documentación y versión.
- [ ] **Step 4:** Commit `chore: 0.8.0 lighting overhaul docs and version`.
- [ ] **Step 5:** Entregar las capturas al usuario para su prueba de juego. La publicación (etiqueta `v0.8.0`) solo se hace después de su visto bueno.

---
← [[Planes]]
