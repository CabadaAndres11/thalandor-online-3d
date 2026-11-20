---
tags: [plan]
plan: 6.3
fecha: 2026-11-20
estado: aprobado
---
# Plan 6.3 — Equipo a vóxel 2×: implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (ejecución nativa). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Todo el equipo visible a vóxel 2× sobre el cuerpo v2, mismos ids y diseños, más épico por tramo; versión 0.9.0 lista para la prueba de juego.

**Architecture:**
- `tools/art/gear_style.mjs` (shared) holds the materials and tier colours used by `make_gear.mjs` (v1) and `make_gear_v2.mjs`.
- v2 armour lives in `gear_armor_v2.mjs`: shells over `human_v2` parts.
- v2 weapons live in `gear_weapons_v2.mjs`: drawn in the v2 fist frame.
- The catalog merges `gear_pieces_v2.json` into its v2 table.
- `ItemIcons` prefers v2.

**Tech Stack:** Node (`node --test`), Godot 4.7.2, GDScript, GUT.

**Spec:** [[Plan 6.3 — Equipo a vóxel 2× (spec)]]

## Global Constraints
- Mismos ids que `data/items/gear_pieces.json`; `bases.json` no cambia.
- Los `.vox` y la tabla v1 del equipo salen idénticos tras extraer `gear_style.mjs` (comprobar con `git status`).
- Arte determinista, sin `Math.random`.
- Versión `0.9.0` en la última tarea; no se publica sin la prueba del usuario.
- Tests: `node --test tools/art/tests/` y GUT completo.

## Review Focus
1. **Equipo mixto:** un jugador con piezas de varias clases y tramos (p. ej., hombreras de guerrero T3 sobre túnica de mago T1) → nada se atraviesa de forma llamativa y no hay errores (Tarea 4, test de montaje).
2. **Arma secundaria** (escudo, orbe, tomo, daga y espada corta a la izquierda) → mano izquierda y orientación correctas (Tarea 3).
3. **Arco y ballesta de equipo** con su agarre → se sostienen como hoy (Tarea 4).
4. **Cuerpo robusto con armadura** → las piezas siguen a sus partes (Tarea 4).
5. **Iconos de las 141 bases + únicos** → todos se generan sin error con v2 (Tarea 4).

---

### Task 1: Módulo de estilo compartido
**Files:** Create `tools/art/gear_style.mjs`. Modify `tools/art/make_gear.mjs` so it imports from it.

**Exports:** `C`, `PALETTE`, `mats`, `TIER_COLORS`, `tierPalette`, `CLASS_SETS`, `cmats`, `wmats`.

- [ ] Mover el código sin cambiarlo.
- [ ] Regenerar el v1 y comprobar que `git status assets/items data/items` no muestra cambios.
- [ ] Commit `refactor(art): shared gear style module`.

### Task 2: Armaduras v2
**Files:**
- Create `tools/art/gear_armor_v2.mjs`, exporting `armorV2(): {id: {shape, part, palette}}` for every class × tier piece and its extras.
- Create `tools/art/make_gear_v2.mjs` (CLI: `<out dir> <gear_pieces_v2.json>`, which copies `tag` and `hides` from v1).
- Create `tools/art/tests/gear_v2.test.mjs`.

- [ ] **Tests que fallan:**
  - `every v1 armour id has a v2 piece on the same part`;
  - `armour never sits inside its v2 body part`;
  - `tier silhouettes grow` (cell count and bounding box of head, shoulders and chest: t3 > t2 > t1 per class);
  - `head pieces keep the eyes visible unless the v1 piece hides the face` (warrior helms are exempt);
  - `generation is deterministic`.
- [ ] Run → FAIL.
- [ ] Esculpir:
  - las piezas de cada tipo (`plate`, `cloth`, `mail`, `leather`) como cáscaras sobre las partes v2;
  - los tocados por clase y sus emblemas;
  - los extras del tramo 3: capa, halo, coronas, fragmentos y rayos;
  - las hombreras con forma de ala del guerrero T3.
- [ ] Generate and run the tests → PASS.
- [ ] Commit `feat(art): v2 armour sets`.

### Task 3: Armas v2
**Files:** Create `tools/art/gear_weapons_v2.mjs`, exporting `gearWeaponsV2()` (17 families × 3 tiers, the left-hand variants and the 3 uniques). Hook it into `make_gear_v2.mjs`.

- [ ] **Tests que fallan:**
  - `every v1 weapon id has a v2 piece on the same hand`;
  - `off-hand items are on hand_left`;
  - `weapons keep their v1 length in metres (±15 %)`;
  - `tier 3 weapons are larger than tier 1`.
- [ ] Run → FAIL. Then sculpt, generate and run → PASS.
- [ ] Commit `feat(art): v2 weapons and uniques`.

### Task 4: Uso en el juego e iconos
**Files:** Modify `game/characters/character_catalog.gd` (it merges `GEAR_PIECES_V2 := "res://data/items/gear_pieces_v2.json"` into `_pieces_v2`) and `game/items/item_icons.gd` (it uses `piece_v2` when present). Tests in `tests/unit/characters/test_human_rig.gd`, `tests/unit/game/test_item_icons.gd` and `tests/unit/data/test_assets.gd`.

- [ ] **Tests que fallan:**
  - `test_gear_is_worn_as_v2`: a T3 chest gives a node at scale 1 and a file under `vox_v2`;
  - `test_full_tier3_kit_builds_for_every_class`: no errors and every piece is attached;
  - `test_mixed_kit_builds`;
  - `test_robust_body_with_armour`;
  - `test_icons_use_v2_pieces`;
  - `test_every_v2_gear_file_exists`.
- [ ] Run → FAIL. Then implement and run the full suite → PASS.
- [ ] Commit `feat: v2 gear in game and icons`.

### Task 5: Capturas, versión y documentación
- [ ] Render `gear` (the three tiers, front and back), `weapons` (pages 0–3) and `classes` on v2. Review against the antifines and adjust (several rounds if needed).
- [ ] Set `config/version="0.9.0"`.
- [ ] Update the docs: GDD 11 and its changelog, `Planes.md`, the spec state and the session note.
- [ ] Run the full GUT suite and `node --test`.
- [ ] Commit `chore: 0.9.0 graphics overhaul docs and version`.
- [ ] Send the captures to the user and wait for their playtest before publishing.

---
← [[Planes]]
