---
tags: [plan]
plan: 6.2
fecha: 2026-11-20
estado: aprobado
---
# Plan 6.2 — Humanoide y piezas a vóxel 2×: implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (ejecución nativa). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Cuerpo humanoide v2 (98 vóxeles, 1,8 cm) y sus piezas de apariencia, conviviendo con el cuerpo v1 de los monstruos.

**Architecture:**
- `tools/art/sculpt.mjs` rasteriza formas redondeadas sobre la `Shape` de `vox.mjs` y pinta tonos.
- `make_humans.mjs` y `make_pieces.mjs` escriben v2 en carpetas y tablas propias.
- `HumanRig` elige el rig por `look.body`.
- `CharacterCatalog` resuelve a v2 con respaldo v1 ampliado ×2.

**Tech Stack:** Node (sin dependencias, `node --test`), Godot 4.7.2, GDScript, GUT.

**Spec:** [[Plan 6.2 — Humanoide y piezas a vóxel 2× (spec)]]

## Global Constraints
- Sin publicar: sale con la 6.3 en la 0.9.0. No se toca `config/version` aquí.
- Mismos ids de partes, piezas y apariencia; los personajes guardados y el protocolo de red no cambian.
- Monstruos (`data/monsters/*.json`) siguen en v1 sin tocar sus datos.
- Arte determinista: volver a ejecutar un generador no cambia los `.vox`.
- Tests GUT: `"D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd` (importar antes). Tests de arte: `node --test tools/art/tests/`.

## Review Focus
1. **Un monstruo humanoide** (cultista, Acólito, Vaelthar, Nhazar, Inquisidor) se ve exactamente como antes: v1, escala 0,36, sus piezas v1 (Tarea 3).
2. **Equipo sin versión v2** puesto en un jugador: aparece a escala ×2, en su hueso y sin error (Tarea 3).
3. **Cuerpo robusto con v2:** los brazos se separan con los hombros y las piezas no se despegan (Tarea 3, test de `body_scale`).
4. **Agarres en v2:** el arco a la espalda y en la mano, el bastón inclinado y `blade_down` siguen las pruebas actuales (Tarea 6).
5. **Vista previa del personaje e iconos de objetos:** usan v2 sin salirse del encuadre (Tarea 7, captura).

---

### Task 1: Librería de esculpido

**Files:** Create `tools/art/sculpt.mjs`, `tools/art/tests/sculpt.test.mjs`

**Interfaces — Produces** (all mutate and return the given `Shape`; coordinates are voxel centres, Godot axes):
- `ellipsoid(s, [cx,cy,cz], [rx,ry,rz], idx)`
- `capsule(s, a, b, ra, rb, idx)`
- `cylinder(s, a, b, r, idx)`
- `roundBox(s, [x0,y0,z0], [x1,y1,z1], radius, idx)`
- `carve(s, fn)`: runs a shape function on a temporary `Shape` and deletes those cells from `s`
- `mirrorX(s, axis = -0.5)`: copies every cell to its reflection, since bodies are symmetric about x = −0.5
- `tone(s, idx, [base, shade, light], seed, mix = [0.6, 0.25, 0.15])`: recolours only cells of `idx`
- `shadeByFacing(s, idxs, {shade, light})`: a surface cell with empty below or behind (−Z) takes the shade tone; one with empty above takes the light tone
- `noise3(x, y, z, seed) -> [0,1)`

- [ ] **Step 1: Tests que fallan:**
  - `ellipsoid is symmetric and has the right extent` (r = [3,2,3] → x from −3 to 3);
  - `capsule spans both ends with each radius`;
  - `carve removes cells`;
  - `mirrorX reflects about -0.5` (x = 2 → x = −3);
  - `tone is deterministic and only uses given tones`;
  - `shadeByFacing darkens bottom faces and lights top faces`.
- [ ] **Step 2:** `node --test tools/art/tests/` → FAIL (no module).
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** `node --test tools/art/tests/` → PASS.
- [ ] **Step 5:** Commit `feat(art): voxel sculpting library`.

### Task 2: Cuerpo v2

**Files:**
- Modify: `tools/art/make_humans.mjs`. Same CLI; it also writes `assets/characters/vox_v2/human_v2_*.vox` and `human_v2.json`, with a `file` path under `res://assets/characters/vox_v2/`.
- Create: `tools/art/tests/human_v2.test.mjs`.

**Interfaces — Produces:** `export function humanV2() -> {parts, palette}`, with the same part names, parents and JSON shape as `human()`. Guard the CLI with `import.meta.url` so tests can import it.

Target joints, in voxels from the ground at x = −0.5 symmetry:

| Joint | Height |
|---|---|
| Hip pivot | 46 |
| Waist (torso pivot) | 53 |
| Head pivot | 81 |
| Top of the skull | 97–98 |
| Shoulders | 76, x = ±16 |
| Elbows | 56 |
| Wrists | 38 |
| Knees | 26 |

Feet: soles at 0.

- [ ] **Step 1: Tests que fallan (`node --test`):**
  - `v2 has the same parts and parents as v1`
  - `v2 is 96-99 voxels tall` (the highest cell of the head plus its pivot)
  - `head is 15-19 voxels tall`
  - `v2 is symmetric` (left/right limb shapes mirror)
  - `skin uses three tones`
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Escribir `humanV2()` con `sculpt.mjs`:
  - **Cráneo y mandíbula:** elipsoides, con la cara pintada a mano a varias filas por rasgo.
  - **Torso:** elipsoide de pecho más cápsula de cintura, con cuello.
  - **Extremidades:** cápsulas.
  - **Manos:** puño con nudillos.
  - **Botas:** caña con pliegue y suela.
  - **Acabado:** `tone` y `shadeByFacing` en cada material.
- [ ] **Step 4:** Ejecutar el generador y `node --test` → PASS.
- [ ] **Step 5:** Commit `feat(art): v2 humanoid body`.

### Task 3: Dos cuerpos en el rig y el catálogo

**Files:**
- Modify: `game/characters/human_rig.gd`, `game/characters/character_catalog.gd`.
- Test: `tests/unit/characters/test_human_rig.gd`, `tests/unit/characters/test_character_catalog.gd`.

**Interfaces — Produces:**
- **`HumanRig.BODIES`:** `{"v1": {"rig": "res://assets/characters/vox/human.json", "scale": 0.36}, "v2": {"rig": "res://assets/characters/vox_v2/human_v2.json", "scale": 0.18}}`.
- **`HumanRig.body: String`**, read from `look.get("body", "v1")`; an unknown value falls back to v1. The rig data is cached per body.
- **Piece entries:** may carry `"voxel_scale": float`. The node scale is `Vector3.ONE * voxel_scale` and its offset is multiplied by `voxel_scale`.
- **`CharacterCatalog`:**
  - `const PIECES_V2 := "res://data/characters/pieces_v2.json"`;
  - `func piece_v2(id) -> Dictionary`;
  - `resolve()` adds `"body": "v2"`, and each `_piece_entry(id)` uses `piece_v2(id)` when it exists, otherwise the v1 piece with `"voxel_scale": 2.0`.
- **Hiding:** `hides` and `tag` come from whichever entry is used.

- [ ] **Step 1: Tests que fallan:**
  - `test_look_without_body_is_v1`: scale 0.36.
  - `test_v2_body_is_a_person_tall`: the AABB of all meshes is 1.70–1.85 m.
  - `test_v2_has_all_parts`.
  - `test_piece_voxel_scale`: a look with a v1 piece at `voxel_scale` 2 gives node scale 2 and the offset doubled.
  - `test_resolve_gives_v2_and_v2_pieces`: hair from `pieces_v2/`.
  - `test_piece_without_v2_is_scaled`: a gear base from the item DB carries `voxel_scale` 2.
  - `test_monster_look_stays_v1`: `MonsterAvatar.look_of(cultist)` has no `body`, and the rig scale is 0.36.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implementar. Create `data/characters/pieces_v2.json` as `{}` for now, so `resolve` falls back for everything until Tasks 4–6.
- [ ] **Step 4:** GUT suite completa → PASS. Las pruebas actuales de `HumanRig` corren con el look por defecto; añadir una vuelta v2 a `test_about_as_tall_as_a_person`.
- [ ] **Step 5:** Commit `feat: v2 body alongside v1 in HumanRig and catalog`.

### Task 4: Pelo y barbas v2

**Files:**
- Modify: `tools/art/make_pieces.mjs`.
  - New export `piecesV2()`, built with `sculpt.mjs` on the v2 head.
  - Writes `assets/characters/pieces_v2/*.vox` and merges entries into `data/characters/pieces_v2.json`, with the same `part`, `tag` and `hides` as v1.
  - The CLI takes an optional third and fourth argument for the v2 dir and table.
- Update: `tools/art/README.md`.
- Test: `tools/art/tests/pieces_v2.test.mjs`, `tests/unit/data/test_assets.gd`.

- [ ] **Step 1: Tests que fallan:**
  - **node:**
    - `every v2 hair and beard id matches v1 tags and hides`;
    - `hair covers the v2 skull` (no head cell above the ear line is left uncovered for `hair_cap` styles).
  - **GUT:** `test_every_v2_piece_file_exists`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Esculpir los 7 peinados (mechones con `tone` sobre el canal pelo, volumen sobre el cráneo) y las 4 barbas (sobre mandíbula y labio).
- [ ] **Step 4:** Generar, importar y ejecutar los tests → PASS.
- [ ] **Step 5:** Commit `feat(art): v2 hair and beards`.

### Task 5: Ropa, tocados, hombreras y carcaj v2

**Files:** `tools/art/make_pieces.mjs` (`piecesV2` grows); tests as Task 4.

Pieces:
- outfits: `outfit_warrior`, `outfit_cleric`, `outfit_mage`, `outfit_archer`, `outfit_assassin`, `outfit_villager`;
- headgear: `hat_mage`, `hood_archer`, `helm_templar`, `mask_assassin`, `hood_cleric`;
- `pauldron_left`, `pauldron_right`;
- `quiver_back`.

Clothes:
- They sit on the v2 torso, arms and hips with 1–2 voxels of clearance.
- They show folds (`shadeByFacing` + seams), hems and belts.
- The mage robe reaches the shins.

- [ ] **Step 1: Test que falla (node):** `outfits do not leave body cells poking out` (for each torso outfit, every v2 torso surface cell is covered or inside); `every v2 id in the class data exists`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Esculpir.
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5:** Commit `feat(art): v2 outfits, headgear, pauldrons, quiver`.

### Task 6: Armas en la mano v2

**Files:** `tools/art/make_pieces.mjs`; `tests/unit/characters/test_human_rig.gd`.

Pieces: `weapon_sword`, `weapon_wood_sword`, `weapon_mace`, `weapon_staff`, `weapon_bow`, `weapon_crossbow`, `weapon_dagger_right`, `weapon_dagger_left`. They are the same length in metres as v1 (twice the voxels), with filos, remaches and grips in two or three tones.

- [ ] **Step 1: Tests que fallan:** the current grip tests run on a v2 look too:
  - `test_bow_stays_upright_while_aiming_v2`
  - `test_staff_points_up_while_casting_v2`
  - `test_the_bow_rides_on_the_back_v2`
  - `test_staff_rests_tilted_v2`

  Use a shared helper that builds both bodies.
- [ ] **Step 2:** Run → FAIL. Without v2 weapons the pieces are scaled v1; the test asserts that the piece file is under `pieces_v2/`.
- [ ] **Step 3:** Esculpir las armas. Si algún agarre falla, ajustar el pivote o la constante en `human_rig.gd` por cuerpo, en `BODIES`.
- [ ] **Step 4:** Suite GUT completa → PASS.
- [ ] **Step 5:** Commit `feat(art): v2 hand weapons`.

### Task 7: Capturas, revisión y documentación

**Files:**
- Modify `tests/helpers/render_characters.gd`: sets `classes_v2` (the five classes on v2) and `compare` (v1 and v2 of each class, side by side). The existing sets stay as they are.
- Docs:
  - `docs/GDD/11 Arte y audio.md`: v2 body **[Implementado, se publica en 0.9.0]**;
  - `docs/GDD/Registro de cambios.md`;
  - `docs/Planes/Planes.md`;
  - the spec state;
  - the session note.

- [ ] **Step 1:** Render `classes_v2`, `compare`, `variety` and `actions`. Review the art against the antifines and fix it (several rounds if needed).
- [ ] **Step 2:** Check the character preview and the item icons with a capture (`render_ui.gd`, if it covers them).
- [ ] **Step 3:** Full GUT suite and `node --test` → green.
- [ ] **Step 4:** Docs and commit `docs: Plan 6.2 done`.
- [ ] **Step 5:** Send the captures to the user for review before starting the 6.3.

---
← [[Planes]]
