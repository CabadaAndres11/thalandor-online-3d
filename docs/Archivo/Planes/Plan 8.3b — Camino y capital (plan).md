---
tags: [plan]
plan: 8.3b
fecha: 2026-11-26
estado: hecho
actualizado: 2026-11-26
---
# Plan 8.3b — Camino y capital: plan de implementación

> Ejecución nativa en el chat (norma 5). Pasos con casillas `- [x]`. Cada tarea: test que falla → código → tests en verde → commit.

**Objetivo:** la misión 4 («La capital») sobre tres zonas nuevas (Camino de Sumerhold, capital y palacio), con bandidos, el PNJ de reinicios, la vuelta del mercader y la reja de la cripta que abre la historia. Sale como **0.14.0**.

**Arquitectura:** casi todo son datos (`data/zones/`, `data/quests/prologo_4.json`, `data/dialogues/`, `data/cutscenes/`, `data/npcs/`, `data/monsters/`). El motor gana salidas con marcas (`sim/zone_layout.gd`, `net/host_session.gd`, `game/game_session.gd`) y reinicios con precio (`sim/progression/requests.gd`, ventana nueva). El arte sale de `tools/art/make_world.mjs`.

**Técnica:** Godot 4.7.2, GDScript, GUT (`./run_tests.sh [res://tests/...]`). Arte en Node (`node --test tools/art/tests/`).

**Spec:** [[Plan 8.3b — Camino y capital (spec)]]

## Restricciones globales
- Camino de Sumerhold: nivel **4–8**. Capital y palacio: `"safe": true`, sin hordas.
- Reinicio: **20 de oro × nivel** por reinicio (`balance.progression.reset_gold_per_level = 20`). La mejora del nivel 50 no se reinicia.
- La reja de la cripta pide la marca **`cripta_abierta`**.
- `prologo_4`: `auto` tras `prologo_3`, mundo compartido, recompensa **1 nivel** y oro; marca `prologo_hecho`.
- Guardado: sigue la **versión 7**. Protocolo: sube a **10** solo si cambia un mensaje (el aviso de salida cerrada va como evento, así que se queda en 9).
- Textos en `data/texts/textos.csv`. Arte propio por código. Ninguna ventana con scroll a 1280×720.

## Puntos de revisión
1. **Un personaje guardado dentro de la cripta o junto a la antigua entrada del bosque:** carga y, al salir de la cripta, aparece en el palacio. → T5.
2. **En grupo, un amigo sin `cripta_abierta` en la reja** cuando el anfitrión ya la tiene: a él no le deja pasar y le avisa; al anfitrión sí. → T1.
3. **Reinicio con el oro justo, sin oro, en combate o sin nada que reiniciar:** con el justo se hace y deja 0; en los demás casos no cambia nada. → T2.
4. **Un personaje de la 0.13.0 que ya terminó `prologo_3`:** al entrar, `prologo_4` empieza sola. → T6.
5. **Bandidos de la emboscada:** su punto de aparición está a más de su `aggro_range` + 3 m del punto `emboscada`, para que la escena salte antes de que ataquen. → T5.

---

### T1. Salidas que abre la historia
**Archivos:** `sim/zone_layout.gd` (salidas con `requires` y `gate`), `net/host_session.gd` (`_check_exits`), `game/game_session.gd` (pinta la reja), `game/main.gd` (aviso en el chat); test `tests/unit/sim/test_locked_exits.gd`.

**Produce:**
- Una salida admite `"requires": {"flags": [...]}` y `"gate": {"closed": "<pieza>", "open": "<pieza>", "at": [x, z], "rot": 0}`. `ZoneLayout` guarda `requires` y `gate` en cada diccionario de `exits`.
- `ZoneLayout.exit_open(exit: Dictionary, log: QuestLog) -> bool`: cierto sin `requires` o si el log tiene todas sus marcas.
- `HostSession._check_exits`: antes de la rama de mazmorras, si `exit_open` es falso, envía `["exit_locked", id]` cada `EXIT_WARN_S` y no mueve al jugador.
- El cliente (`GameSession`) coloca la pieza `gate.closed` o `gate.open` según `client.quests`, y la cambia al llegar una actualización de misiones. Main escribe `UI_EXIT_LOCKED` (*La reja está cerrada.*) en el chat con `exit_locked`.

- [x] Tests:
  - `test_exit_open_needs_flags`: sin la marca es falso; con ella, cierto; sin `requires`, siempre cierto.
  - `test_host_refuses_locked_exit`: en una zona de prueba (`tests/data/zones/zone_gate.json`), el jugador en la salida no cambia de zona y recibe `exit_locked`; con la marca, cambia.
  - `test_guest_without_flag_stays` (punto de revisión 2): dos jugadores, solo uno con la marca; pasa solo ese.
  - `test_gate_piece_follows_flags`: `GameSession` muestra la pieza cerrada y, tras poner la marca, la abierta.
- [x] Implementar → verde → suite → commit `feat: exits the story opens`.

### T2. Reinicios por oro
**Archivos:** `data/balance.json` y `sim/balance.gd` (`reset_gold_per_level`), `sim/progression/requests.gd`, `net/host_session.gd` (rol `class_trainer`, ya existe), crear `ui/reset_window.gd`, `game/main.gd` (el PNJ con rol `class_trainer` abre la ventana si no tiene misión que decir); test `tests/unit/sim/test_paid_resets.gd`, `tests/unit/ui/test_reset_window.gd`.

**Produce:**
- `ProgressRequests.reset_cost(level: int, b: Balance) -> int` = `reset_gold_per_level × level`.
- `ProgressRequests.reset(...)` cobra ese precio de `p.inventory.gold` y marca `inventory_dirty`. Si no llega el oro, devuelve falso sin cambiar nada. La comprobación de "nada que reiniciar" va antes de cobrar.
- `ResetWindow`: dos botones, *Reiniciar atributos* y *Reiniciar talentos*, con el precio, y apagados con el motivo (`UI_RESET_NO_GOLD`, `UI_RESET_NOTHING`). Señal `reset_requested(what: String)` → `client.request_reset(what)` (el mensaje `RESET` ya existe). Se cierra con Esc.

- [x] Tests:
  - `test_reset_cost`: nivel 10 → 200.
  - `test_reset_charges_gold` (punto de revisión 3): con el oro justo reinicia y deja 0; con 1 menos no hace nada; en combate o sin nada que reiniciar, no cobra.
  - `test_reset_needs_trainer`: lejos del PNJ, nada.
  - `test_reset_window_states`: con el oro, los botones activos y el precio en el texto; sin oro, apagados con el motivo; sin puntos repartidos, *Reiniciar atributos* apagado.
- [x] Implementar → verde → suite → commit `feat: resets for gold at the capital's trainer`.

### T3. Bandidos
**Archivos:** `data/monsters/bandit.json`, `bandit_archer.json`, `bandit_chief.json`; habilidades en `data/abilities/` si hacen falta (reusar las del culto donde valgan); textos; test `tests/unit/data/test_monster_data.gd` (`ROSTER`).

**Produce:**
- `model: "humanoid:<id>"` con un `look` de ropa del catálogo (cuero y tela en tonos tierra, capuchas; sin máscaras): `bandit` cuerpo a cuerpo con espada, `bandit_archer` a distancia y se aleja (comportamiento del arquero del culto), `bandit_chief` con hacha a dos manos, más vida (×3 del bandido) y un golpe pesado avisado.
- Nombres `MON_BANDIT` (*Bandido*), `MON_BANDIT_ARCHER` (*Arquero bandido*), `MON_BANDIT_CHIEF` (*Cabecilla bandido*). Botín normal; el cabecilla, como élite.

- [x] Tests:
  - `ROSTER` incluye los tres; sus datos validan; el avatar de cada uno se construye.
  - `test_bandits_are_not_cult`: su `look` no lleva piezas de máscara ni marca del culto.
- [x] Implementar → verde → suite → commit `content: bandits`.

### T4. Arte de ciudad, palacio y camino, y PNJ
**Archivos:** `tools/art/make_world.mjs` y `tools/art/tests/world.test.mjs`, `data/zones/pieces.json`, `assets/world/*.vox`, `data/ambiences/palacio.json`, `data/npcs/` nuevos; test `tests/unit/data/test_capital_art.gd`.

**Produce:**
- Piezas:
  - ciudad: `city_wall`, `city_gate` (con torreones; paso libre de 3 casillas), `house_city` (piedra, dos plantas, visitable con las cuatro partes de las casas), `market_stall`, `fountain`, `city_lamp`;
  - palacio: `palace_column`, `palace_carpet` (sin huella), `throne`, `brazier`, `crypt_gate_closed` y `crypt_gate_open` (misma huella; la abierta deja libre el paso);
  - camino: `caravan_wagon` (con lona), `horse` (quieto), `bandit_palisade`.
- Ambiente `palacio`: interior cálido con luz de braseros.
- PNJ con nombre: `rey` (*el rey Aldren*, provisional), `oriel`, `lord_maren`, `caravanero`, `maese_corwin` (rol `class_trainer`), `guardia_palacio`, `guardia_ciudad`. Genéricos: `ciudadano_1…4`, `ciudadana_1…4`. Cada uno con `look` válido y `lines.greet`.

- [x] Tests:
  - Node: cada pieza nueva se genera, cabe en 126 vóxeles por lado y en su huella; `house_city` tiene puerta e interior libres; las dos rejas tienen la misma huella menos el paso.
  - GUT: cada pieza está en `pieces.json` y su `.vox` existe; cada PNJ tiene nombre traducido y un aspecto que el catálogo acepta sin cambiarlo; `maese_corwin` tiene rol `class_trainer`; el ambiente `palacio` carga.
- [x] Implementar → verde → commit `art: city, palace and road pieces; capital NPCs`.

### T5. Tres zonas nuevas y el bosque
**Archivos:** `data/zones/camino.json`, `capital.json`, `palacio.json`; `data/zones/bosque.json` (salida al este, sin salida a la cripta), `data/zones/cripta_prueba.json` (vuelve al palacio, `from_cripta`); `data/loading.json` y capturas con `tests/helpers/render_loading.gd`; textos `ZONE_CAMINO` (*Camino de Sumerhold*), `ZONE_CAPITAL` (*Sumerhold, Capital del Reino*, si no existe ya), `ZONE_PALACIO` (*Palacio de Sumerhold*); test `tests/unit/data/test_zones_data.gd`.

**Produce:**
- **`camino`:** unos 160 × 64, nivel 4–8, linde de bosque y calzada de oeste a este.
  - Puntos `caravana` (entrada oeste, con `caravan_wagon`, `horse` y el `caravanero`) y `emboscada` (mitad de camino).
  - `spawns` de bandidos (4 `bandit`, 2 `bandit_archer`, 1 `bandit_chief`) junto a la emboscada, que reaparecen a los 30 s.
  - Hordas suaves (`marked_hound`, `marked_boar`, nivel 4–8) apartadas de la calzada, y un campamento de bandidos con `bandit_palisade` y su horda.
  - Salidas: `bosque` (`from_camino`) y `capital` (`from_camino`).
- **`capital`:** unos 96 × 80, `safe`, muralla con `city_gate` al sur, plaza con `fountain` y `market_stall`, varias `house_city` y el acceso al palacio al norte.
  - Punto `puerta_capital`.
  - PNJ: `merchant`, `maese_corwin` y `guardia_ciudad`; ciudadanos que pasean (`walkers`).
  - Salidas: `camino` (sur) y `palacio` (norte).
- **`palacio`:** interior, `safe`, `margin: "none"`, ambiente `palacio`; pasillo y salón del trono con `palace_column`, `palace_carpet`, `brazier`, `throne` y `kingdom_banner`.
  - Punto `salon_trono`.
  - PNJ: `rey`, `oriel`, `lord_maren` y `guardia_palacio`.
  - Salidas: `capital` (sur) y la reja `cripta_prueba` con `"requires": {"flags": ["cripta_abierta"]}` y su `gate`.
- **Bosque:** salida al este al final del camino real. Sin la salida a la cripta (el `crypt_arch` queda como ruina). Su camino llega a la nueva salida.

- [x] Tests:
  - Las tres zonas cargan sin errores, se alcanzan sus entradas y salidas, y tienen nombre traducido; `capital` y `palacio` son `safe` y sin hordas.
  - `test_road_level_band`: `camino` es de nivel 4–8 y sus hordas también.
  - `test_ambush_is_out_of_reach` (punto de revisión 5): cada punto de aparición de bandidos está a más de `aggro_range` + 3 m de `emboscada`.
  - `test_crypt_leads_to_palace` (punto de revisión 1): la salida de `cripta_prueba` va a `palacio:from_cripta`, y el bosque ya no tiene salida a la cripta.
  - `test_capital_walkers_valid`.
  - Se actualizan los tests del bosque que buscaban la cripta (`test_crypt_has_clearing`, `test_path_reaches_crypt`, `test_zone_map_image.test_markers`): ahora la calzada llega a la salida del este.
- [x] Commit `content: the road, the capital and the palace`.

### T6. La misión 4
**Archivos:** `data/quests/prologo_4.json`; diálogos `data/dialogues/prologo4_*`; escenas `data/cutscenes/prologo_emboscada`, `prologo_llegada`, `prologo_audiencia`, `prologo_descenso`; textos; test `tests/integration/test_prologue_4.gd`.

**Produce:** la misión de la spec §2, paso a paso, con sus textos de recuadro.
- Diálogos del caravanero (antes y después), de Oriel al recibir la máscara y del rey con el encargo.
- Escenas con las frases clave del guion:
  - Oriel: *Con cada sello que renueves, tu poder crecerá. Es la respuesta del mundo a la llamada, no un regalo.*
  - Maren: *El héroe pertenece al reino.*
  - Protagonista: *Mi hermana pertenece a mí. Y voy a ir a buscarla.*
  - Con frases nuevas en el mismo tono para los sellos y la intercesión de Oriel.
- La multitud de la llegada sale con actores de los ciudadanos genéricos.
- El paso del encargo pone `cripta_abierta` y lanza el descenso, en el que la reja se abre.
- Al terminar: 1 nivel, oro y la marca `prologo_hecho`. La máscara se entrega a Oriel con `deliver`.

- [x] Tests:
  - `test_prologue_4`: de principio a fin en el anfitrión con las peticiones de un cliente; tras la emboscada (los bandidos del punto muertos), la llegada y la audiencia, la máscara ya no está en la bolsa, el jugador tiene `cripta_abierta`, cruza la reja y, al salir de la cripta, vuelve al palacio.
  - `test_prologue_4_starts_for_013_characters` (punto de revisión 4): un log con `prologo_3` hecho empieza `prologo_4` al entrar.
  - Datos válidos: misiones, diálogos y escenas sin errores.
- [x] Commit `content: mission 4, the capital`.

### T7. Versión, documentación y revisión
**Archivos:** `project.godot` (`config/version="0.14.0"`), `.github/release-notes.md`, GDD (06 Mundo, 07 Misiones, 04 Personajes y progresión, 09 Interfaz, Registro de cambios), `docs/Planes/Planes.md`, nota de sesión.

- [x] Suite completa en verde.
- [x] Versión 0.14.0 y notas de la versión (camino, capital, palacio, bandidos, reinicios por oro, el mercader en la capital y la cripta bajo el palacio).
- [x] GDD y registro; `Planes.md` → *Hecho (0.14.0, sin publicar)*; nota de sesión.
- [x] Revisión final del conjunto; decir al usuario qué probar.
- [x] Commit `chore: 0.14.0 — road and capital`.

---
← [[Planes]]
