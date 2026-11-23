---
tags: [plan]
plan: 8.1.1
fecha: 2026-11-23
estado: en curso
actualizado: 2026-11-23
---
# Plan 8.1.1 — Correcciones de la prueba 0.11.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (ejecución nativa en el chat, norma 5). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Fix the 13 points from the 0.11.0 playtest. Ships as 0.11.1.

**Architecture:**
- **Performance:**
  - `VoxMesher` merges equal coplanar faces (greedy meshing);
  - `ZoneView` draws pieces and ground in 16×16 chunks, with visibility ranges and shadows per piece read from `pieces.json`;
  - the zone is built in steps across several frames, behind the loading screen.
- **Houses:**
  - drawn at 10 cm per voxel, in four parts (floor, walls, cut walls, roof), with walkable insides;
  - each client opens only the house its own player stands in.
- **Zone edges:** a decorated margin outside the map and markers at each exit come from `ZoneLayout`. The camera clamps to the zone.
- **New UI:** a shared zone image feeds the map window (M) and the minimap; a top-right icon bar opens the windows.
- **Smaller fixes:** inventory sort (host-authoritative), joining from the pause menu, class preview with the starter kit.

**Tech Stack:** Godot 4.7.2, GDScript, GUT (`./run_tests.sh [res://tests/...]`); Node art generators (`node --test tools/art/tests/`).

**Spec:** [[Plan 8.1.1 — Correcciones de la prueba 0.11.0 (spec)]]

## Global Constraints
- Version **0.11.1** in `project.godot`.
- No window needs scroll at 1280×720.
- Game text in `data/texts/textos.csv` (Spanish); code and commits in English; commits with the user's email.
- Content as data: piece shadows and ranges, house interiors and parts live in `data/zones/pieces.json`, not in code.
- `sim/` does not depend on game or UI classes.
- €0; nothing to install.
- After moving main: `Godot --import` (memory: reimport after update).

## Review Focus
1. **Rotated house:** a house at `rot` 90/180/270 must keep its door walkable and its interior cells reachable from the door. Pinned by the BFS test in Task 4, run over all four rotations.
2. **House open in a group:** a partner standing inside a house must not open it on your screen. Pinned in Task 4, only the local player's house opens.
3. **Zone change mid-build:** a ZONE message arriving while the staged build is still running must not leave half of two zones. Pinned in Task 3, a second build cancels the first.
4. **Bag full of stacks:** sorting must never lose items or exceed the stack size when stacks merge. Pinned in Task 8, the item count by base is unchanged and every stack is at most `stack`.
5. **Joining from the pause menu without tutorial or with an empty code:** the join must stay disabled. Pinned in Task 9.

---

### Task 1: Greedy meshing in VoxMesher

**Files:**
- Modify: `game/characters/vox_mesher.gd`
- Test: `tests/test_vox_mesher.gd` (add cases)

**Interfaces:**
- Produces: `VoxMesher.build(vox, tints) -> ArrayMesh` (same signature, fewer triangles); `static func triangle_count(mesh: Mesh) -> int` (sum of index count / 3 over surfaces), used by later tests.

- [ ] **Step 1: Write failing tests**
  - `test_single_colour_cube_is_twelve_triangles`: a 4×4×4 solid cube of one palette index builds to `triangle_count == 12`.
  - `test_merged_mesh_covers_same_area_per_colour`: on `res://assets/world/tree_oak.vox`, the summed face area per (colour, normal) equals that of the unmerged build. Keep the old path as `build_unmerged` for this test only.
  - `test_tree_has_far_fewer_triangles`: tree_oak merged ≤ 50 % of unmerged.
- [ ] **Step 2: Run** `./run_tests.sh res://tests/test_vox_mesher.gd`. Expected: FAIL (`triangle_count` missing, 12 ≠ 384).
- [ ] **Step 3: Implement.**
  - Per side and per slice, build a 2D mask of the visible faces keyed by (final colour after AO, the 4 corner AO values, glow or lit).
  - Merge only faces whose key is equal, with all 4 corners equal. Faces whose corners differ in AO stay single quads, so the shading looks exactly as before.
  - Standard greedy rectangle growth: first along u, then along v.
  - Vertices are emitted with the same winding as today.
- [ ] **Step 4: Run** the file, then the full suite (characters use the mesher too). Expected: PASS.
- [ ] **Step 5: Commit** `perf: greedy meshing merges equal voxel faces`.

### Task 2: Chunked pieces and ground, ranges and shadows by quality

**Files:**
- Modify: `game/zone_view.gd`, `tools/art/make_world.mjs` (writes `shadow`, `range` per piece), `data/zones/pieces.json` (regenerated), `tests/data/zones/pieces.json`
- Test: `tests/test_zone_view.gd`

**Interfaces:**
- Produces:
  - `ZoneView.CHUNK := 16`;
  - nodes `Pieces/<piece_id>@<cx>,<cz>` (MultiMeshInstance3D) and `Ground_<kind>@<cx>,<cz>`;
  - `ZoneView.shadow_for(piece_id: String, quality: int) -> bool`.
  - `pieces.json` fields:
    - `"shadow": "never" | "medium"` (medium = on at MEDIUM and HIGH);
    - `"range": 35 | 70` (metres).
  - Values:
    - bush, rock_small, stump and torch: `never`, range 35;
    - everything else: `medium`, range 70.
  - At LOW quality, no piece casts shadow.

- [ ] **Step 1: Failing tests**
  - `test_pieces_are_split_by_chunk`: a 40×40 test zone with trees at (2,2) and (30,30) gives two tree nodes, `tree_oak@0,0` and `tree_oak@1,1`.
  - `test_visibility_range_from_data`: `visibility_range_end` is 35 on bush nodes and 70 on trees.
  - `test_shadows_by_quality`: a bush is `SHADOW_CASTING_SETTING_OFF` at HIGH. A tree is ON at HIGH and MEDIUM and OFF at LOW, also after `set_quality`.
  - `test_ground_split_by_chunk`: a 40×40 zone has `Ground_grass@2,2`.
  - Keep the existing `piece_transform` tests.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
  - `_build_pieces` and `_build_ground` group by `Vector2i(at / CHUNK)`.
  - `set_quality` updates the shadows of the piece nodes.
  - Add `shadow` and `range` to the `make_world.mjs` table and regenerate.
  - Update the art test in `tools/art/tests/` that checks the table keys.
- [ ] **Step 4: Run** the zone view tests, `node --test tools/art/tests/` and the full suite. PASS.
- [ ] **Step 5: Commit** `perf: zone pieces and ground in 16x16 chunks with draw ranges and shadows by quality`.

### Task 3: Staged zone build behind the loading screen

**Files:**
- Modify: `game/zone_view.gd`, `game/game_session.gd`, `ui/loading_overlay.gd`, `game/main.gd`
- Test: `tests/test_zone_view.gd`, `tests/test_loading_overlay.gd`, `tests/test_main_flow.gd`

**Interfaces:**
- Produces:
  - `ZoneView.build_steps(layout: ZoneLayout, quality: int) -> Array[Callable]`: ground, then one step per piece kind, then blocks, torches and lighting. `build()` runs them all at once.
  - `GameSession.zone_building: bool`; signal `GameSession.zone_built()`. The game builds through the steps, one per `process_frame`, and `map` is set before the first step, from `layout.collision()`.
  - `LoadingOverlay.MIN_SHOW_S := 0.6`: `hide_overlay()` waits until 0.6 s have passed since `show_zone`, then fades out over 0.2 s.
  - `main.gd`: Play shows `loading.show_zone(zone name)` before creating the game; the overlay hides on `zone_built` and the client's `zone_ready`, whichever comes last.

- [ ] **Step 1: Failing tests**
  - `test_steps_build_same_scene_as_build`: the node names and the piece instance counts are equal for `build()` and for running `build_steps` one by one.
  - `test_new_zone_cancels_unfinished_build`: start a staged build of zone_a, run 1 step, then start zone_b. When it finishes there is one `Zone` node with zone_b's ground and no zone_a node.
  - `test_overlay_stays_min_time`: `show_zone` then `hide_overlay()` at once leaves it visible until 0.6 s have been simulated (step `_process` manually).
  - `test_play_shows_loading`: after `_on_play`, `game.loading.visible` is true.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement** in the files above. `_on_zone_changed` uses the same staged path. A generation counter cancels stale steps.
- [ ] **Step 4: Run** these files and the full suite. PASS.
- [ ] **Step 5: Commit** `fix: zones build over several frames behind a loading screen that shows at least 0.6 s`.

### Task 4: Walkable houses at 10 cm voxels

**Files:**
- Modify:
  - `tools/art/make_world.mjs`: `house()` returns parts; scale 1.0, 10 voxels per cell for houses;
  - `data/zones/pieces.json` and `assets/world/house_*_{floor,walls,walls_cut,roof}.vox` (regenerated; the old `house_*.vox` are removed);
  - `sim/zone_layout.gd`;
  - `game/zone_view.gd`;
  - `game/game_session.gd`;
  - `data/zones/aldea.json`.
- Create: `game/house_view.gd`
- Test: `tests/test_zone_layout.gd`, `tests/test_zone_view.gd`, `tests/test_zones_data.gd`, `tools/art/tests/world.test.mjs`

**Interfaces:**
- Produces:
  - **`pieces.json` house entries** (all footprints, interiors and doors are relative cells, rotated like footprints):
    - `"parts": {"floor": vox, "walls": vox, "walls_cut": vox, "roof": vox}`;
    - `"scale": 1.0`;
    - `"interior": [[x, z], ...]`;
    - `"door": [[x, z], [x, z]]`;
    - `"footprint"`: the wall ring minus the door, plus the cells of large furniture.
  - **House sizes** (bigger, so the inside is walkable):
    - `house_small`: 6×6;
    - `house_large`: 8×7;
    - `house_forge`: 7×7.
  - Walls are 1 cell thick, 3 m high. The door is 2 cells in the middle of the +Z side. `walls_cut` keeps the walls up to 1 m.
  - **Furniture** (per the spec): small house: bed, table, chest. Large house: 2 beds, long table, hearth, shelf. Forge: anvil, lit forge with `GLOW` and a light, barrel.
  - **`ZoneLayout`:**
    - `houses: Array` of `{index: int, cells: Array[Vector2i]}` (world interior cells per placed house);
    - `func house_at(cell: Vector2i) -> int` (−1 if none).
  - **`HouseView` (`extends Node3D`):**
    - children `Floor`, `Walls`, `WallsCut`, `Roof` (MeshInstance3D);
    - `func set_open(open: bool) -> void`: the roof fades over 0.25 s (alpha on a duplicated transparent material); Walls and WallsCut visibility swap;
    - `var open: bool`.
  - **`ZoneView`:** houses are `HouseView` nodes under `Houses/house_<index>` (not MultiMesh); `func open_house(index: int) -> void` (−1 closes all).
  - **`GameSession._process`** calls `zone_view.open_house(layout.house_at(own cell))` for the local player only.
  - **`aldea.json`:** re-lay the houses at their new sizes. Brann and the forge exterior stay reachable. Default entry beside the forge, outside.

- [ ] **Step 1: Failing tests**
  - Node: `house parts and interior`: every house has 4 parts and its interior is not in the footprint. The door cells are free. The interior is ≥ 12 cells for the small house.
  - GUT `test_house_interior_reachable_from_door_all_rotations`: for each house and rot in [0, 90, 180, 270], placed in a 30×30 zone, BFS over `collision()` from the cell outside the door reaches every interior cell.
  - `test_house_at`: interior cells map to the house index; the outside maps to −1.
  - `test_open_house_hides_roof_and_cuts_walls`: after `open_house(0)` and 0.3 s, house_0's Roof is invisible (or alpha 0), WallsCut is visible and Walls is not. The other houses stay closed. `open_house(-1)` closes it.
  - `test_only_local_player_opens_house`: a GameSession with a partner avatar inside house 0 and the own player outside has no house open.
  - `test_aldea_brann_and_merchant_reachable`: update the zones data test.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
  - House shapes in `make_world.mjs` at 10 voxels per cell. Larger planks, stones and thatch tiles, 2–3 voxels each, with less per-voxel noise.
  - `ZoneLayout` reads `parts`, `interior` and `door`.
  - Then `HouseView` and the `ZoneView` and `GameSession` hooks.
  - Regenerate the assets; re-lay `aldea.json`.
- [ ] **Step 4: Run** the node tests, these GUT files and the full suite. Render the village with `tests/helpers/render_zone.gd` and look at it (Read the PNG). PASS.
- [ ] **Step 5: Commit** `feat: walkable houses at 10 cm voxels that open when you step inside`.

### Task 5: Decorated zone margin, exit markers and camera bounds

**Files:**
- Modify: `sim/zone_layout.gd`, `game/zone_view.gd`, `game/iso_camera.gd`, `game/game_session.gd`, `tools/art/make_world.mjs` (new `signpost` piece), `data/zones/*.json` (`"margin": "forest" | "rock"`)
- Test: `tests/test_zone_layout.gd`, `tests/test_zone_view.gd`, `tests/test_iso_camera.gd` (new if missing)

**Interfaces:**
- Produces:
  - **`ZoneLayout.MARGIN := 14`.**
  - **`ZoneLayout.margin_pieces: Array`:** same shape as `pieces`, at cells outside `[0, size)`. It is seeded from the zone id: tree_oak/tree_pine/rock_large at density 0.55 for `forest`, crypt_wall/rock_large for `rock`. It is never in `collision()`.
  - **`ZoneLayout.exit_markers: Array`** of `{at: Vector2i, to: String, rot: int}`, one per exit:
    - a `signpost` on the exit's inner edge;
    - two `torch` pieces beside it, added to `torches`;
    - in front of the exit, a 3-cell gap kept free of margin pieces.
  - **ZoneView:**
    - draws the margin pieces under `Margin`, and a darker ground band under them;
    - a `Label3D` with `tr("ZONE_" + to)` on each signpost (billboard, visible within 10 m);
    - an emissive soft quad over each exit area (`ExitGlow_<i>`).
  - **IsoCamera:**
    - `var bounds: Rect2` (empty = no limit);
    - `follow()` clamps the target to `bounds.grow(-6)`.
  - GameSession sets `bounds = Rect2(Vector2.ZERO, layout.size)` on every zone change.
  - Instanced zones (crypt) use `margin: rock`. Every zone file gets a `margin` value.

- [ ] **Step 1: Failing tests**
  - `test_margin_surrounds_zone_except_exits`: every cell on the 1-cell ring outside the map, except those in front of an exit, has a margin piece within 2 cells.
  - `test_margin_not_walkable`: `collision()` blocks every cell outside the map (assert the existing behaviour holds).
  - `test_exit_markers`: each exit has one signpost and two extra torches.
  - `test_camera_clamped`: with bounds 96×96, `follow(Vector3(-50, 0, 200))` puts the target at (6, y, 90).
  - `test_signpost_label_text`: the Label3D text is `tr("ZONE_bosque")` for the village's east exit.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.** Regenerate pieces with `signpost` (wooden post and board, `shadow: medium`, range 70, footprint `[[0,0]]`).
- [ ] **Step 4: Run** and render village and forest; look at the edge and the exit. PASS.
- [ ] **Step 5: Commit** `feat: zones end in a thick tree line, exits show a signpost and torches, the camera stays inside`.

### Task 6: Crypt clearing and path

**Files:**
- Modify: `sim/zone_layout.gd`, `data/zones/bosque.json`
- Test: `tests/test_zones_data.gd`

**Interfaces:**
- Produces:
  - Scatter keeps free every cell within `ZoneLayout.EXIT_CLEAR := 6` of any exit area, generic for all zones.
  - `bosque.json`:
    - a dirt path, width 2, from the main road to the crypt door at (139, 100);
    - two `torch` entries beside the crypt arch.

- [ ] **Step 1: Failing tests**
  - `test_crypt_has_clearing`: no scattered piece within 6 cells of the crypt exit.
  - `test_path_reaches_crypt`: `ZoneView.ground_cells()` path cells form a 4-connected chain from the village exit (0, 64) to the crypt exit.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** PASS.
- [ ] **Step 5: Commit** `content: clearing, path and torches lead to the forest crypt`.

### Task 7: Class preview with the starter kit; assassin mask fits the lizard snout

**Files:**
- Modify: `ui/class_choice_window.gd`, `tools/art/clothes_v2.mjs` (`maskAssassin` uses the race head fit) and/or the lizard `head_fit` data, regenerated assets
- Test: `tests/test_class_choice_window.gd`, `tools/art/tests/` (mask test)

**Interfaces:**
- Consumes: `Inventory.starter(class_id, ItemDB.load_default()).visible_bases() -> Array`.
- Produces: `ClassChoiceWindow.preview_gear(class_id: String) -> Array`.

- [ ] **Step 1: Failing tests**
  - `test_preview_shows_starter_kit`: for each class, `preview_gear(id)` equals `Inventory.starter(id, db).visible_bases()`, and `select(id)` builds the rig with that gear (the rig's gear list).
  - Art test `assassin mask hugs lizard head`: for the lizard, the mask voxels are within 1 voxel of the fitted head's surface. None is more than 2 voxels away.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.** Render the lizard assassin with `tests/helpers/render_menu.gd` and look at it.
- [ ] **Step 4: Run.** PASS.
- [ ] **Step 5: Commit** `fix: class choice shows the starter kit; assassin mask fits the lizard snout`.

### Task 8: Sort the bag

**Files:**
- Modify: `sim/items/inventory.gd`, `net/host_session.gd` (`"sort"` action), `ui/inventory_window.gd` (button `BTN_SORT`), `data/texts/textos.csv`
- Test: `tests/test_inventory.gd`, `tests/test_inventory_window.gd`, `tests/test_host_items.gd` (or the existing host item test file)

**Interfaces:**
- Produces: `Inventory.sort_bag(db: ItemDB) -> void`.
  - **Order:** first the equipment slot index in `SLOTS` (consumables and unknown last). Then rarity, from highest to lowest (by index in `loot.rarities`). Then level, highest first. Then `base_id`.
  - **Stacks:** equal consumables merge up to `stack`.
  - **Empty slots:** they go to the end, and the bag size does not change.
  - Equipment is untouched.
  - The host handles the `"sort"` item action and marks the inventory dirty.
  - Text: `BTN_SORT,Ordenar`.

- [ ] **Step 1: Failing tests**
  - `test_sort_order`: the expected order holds for a mixed bag.
  - `test_sort_merges_stacks_without_loss`: 3 potion stacks of 15/15/15 with stack 20 become 20/20/5; the item count per base is unchanged.
  - `test_sort_keeps_equipment`.
  - `test_host_sort_action`.
  - `test_sort_button_requests_sort`.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** PASS.
- [ ] **Step 5: Commit** `feat: sort button orders the bag and merges stacks`.

### Task 9: Join a group from the pause menu

**Files:**
- Modify: `ui/character_select_screen.gd` (remove `join_button`, `code_edit`, `join_requested`), `ui/pause_menu.gd`, `game/main.gd`, `data/texts/textos.csv`
- Test: `tests/test_character_select_screen.gd`, `tests/test_pause_menu.gd`, `tests/test_main_flow.gd`

**Interfaces:**
- Produces:
  - `PauseMenu.join_code_edit: LineEdit`, `PauseMenu.join_button: Button`, signal `join_requested(code: String)`.
  - The join is disabled while the code is empty, while the group is locked (`set_group_locked`), and while a group is open.
  - `main.gd` `_on_pause_join(code)`:
    1. save the character;
    2. `game.leave()`;
    3. show the loading screen;
    4. `_on_join(...)` with the current character and `progress`.
  - `settings.last_code` pre-fills the field.
  - Texts:
    - `BTN_JOIN_GROUP,Unirse a un grupo`;
    - `JOIN_CODE_HINT,Código del grupo`.

- [ ] **Step 1: Failing tests**
  - `test_select_screen_has_no_join`.
  - `test_pause_join_disabled_empty_or_locked`.
  - `test_pause_join_saves_and_connects`: a fake signaling joins with the same character id and progress.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.** Remove the tests of the old select-screen join that no longer apply; move the ones still valid.
- [ ] **Step 4: Run** and the full suite. PASS.
- [ ] **Step 5: Commit** `feat: join a friend's group from the pause menu; the select screen only plays`.

### Task 10: Zone map (M) and minimap

**Files:**
- Create: `game/zone_map_image.gd`, `ui/map_window.gd`, `ui/minimap.gd`
- Modify: `game/game_session.gd`, `game/main.gd`, `game/input_setup.gd` (`"window_map": [KEY_M]`), `save/settings_store.gd` (`var minimap: bool = true`, VERSION 4 with migration), `ui/options_window.gd` (checkbox), `data/texts/textos.csv`
- Test: `tests/test_zone_map_image.gd`, `tests/test_map_window.gd`, `tests/test_minimap.gd`, `tests/test_settings_store.gd`

**Interfaces:**
- Produces:
  - **`ZoneMapImage.make(layout: ZoneLayout, px_per_cell: int = 4) -> Image`**, a static function, size `layout.size * px_per_cell`:
    - ground colours from `ZoneView.GROUND`;
    - houses and rocks drawn darker;
    - trees as dark-green blobs.
  - **`ZoneMapImage.markers(layout, client) -> Array`** of `{kind, cell: Vector2, label: String, yaw: float}`:
    - kinds: `self`, `partner`, `npc`, `exit`, `dungeon`;
    - an exit whose target zone is instanced is a `dungeon`.
  - **`GameSession.map_texture: ImageTexture`**: rebuilt on every zone change.
  - **`MapWindow` (HoloTheme):**
    - `func refresh(texture, markers, zone_name)`;
    - fits in 1280×720 (≤ 1000×640) with a legend;
    - toggled by M via `main._toggle_window`.
  - **`Minimap` (Control, 180×180):**
    - top-right under the icon bar;
    - `func refresh(texture, markers, center: Vector2, cam_yaw: float)`;
    - rotates so the camera's forward is up, with an "N" at the edge;
    - hidden when `settings.minimap` is false.
  - **Texts:**
    - `WINDOW_MAP,Mapa`;
    - `OPT_MINIMAP,Minimapa`;
    - `MAP_LEGEND_YOU,Tú`;
    - `MAP_LEGEND_PARTY,Grupo`;
    - `MAP_LEGEND_NPC,Personajes`;
    - `MAP_LEGEND_EXIT,Salida`;
    - `MAP_LEGEND_DUNGEON,Mazmorra`.

- [ ] **Step 1: Failing tests**
  - `test_image_size_and_ground_colours`: a road cell's pixel is near `GROUND.road`.
  - `test_markers`: the crypt exit is a `dungeon` at its cell; Brann is an `npc` with his name; self has the player's yaw.
  - `test_map_window_fits_720p`.
  - `test_m_toggles_map`.
  - `test_minimap_hidden_by_setting`.
  - `test_settings_v3_migrates_minimap_true`.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** and render the HUD with the minimap (`tests/helpers/render_main.gd`); look at it. PASS.
- [ ] **Step 5: Commit** `feat: zone map on M and a minimap that turns with the camera`.

### Task 11: Top-right icon bar

**Files:**
- Create: `ui/icon_bar.gd`
- Modify: `game/main.gd`, `game/input_setup.gd` (`"window_quests": [KEY_J]`), `data/texts/textos.csv`
- Test: `tests/test_icon_bar.gd`, `tests/test_main_flow.gd`

**Interfaces:**
- Produces:
  - **`IconBar` (HBoxContainer, HoloTheme):**
    - `const ENTRIES := ["character", "inventory", "abilities", "talents", "quests", "map", "menu"]`;
    - each button: a vector icon drawn in `_draw` (like `KeyIcon`/`LockIcon`) and a small key label from InputMap;
    - signal `pressed_entry(id: String)`;
    - `func set_open(id: String, open: bool)`: a lit border while that window is open, a glow on hover;
    - `quests` is disabled, with tooltip `tr("QUESTS_SOON")`.
  - `main.gd` maps the entries to the existing toggles (`_toggle_window`, `_toggle_inventory`, the map, the pause menu) and keeps `set_open` in sync.
  - Texts:
    - `QUESTS_SOON,Llega con las misiones`;
    - `ICON_CHARACTER,Personaje`;
    - `ICON_INVENTORY,Bolsa`;
    - `ICON_ABILITIES,Habilidades`;
    - `ICON_TALENTS,Talentos`;
    - `ICON_QUESTS,Misiones`;
    - `ICON_MAP,Mapa`;
    - `ICON_MENU,Menú`.

- [ ] **Step 1: Failing tests**
  - `test_entries_order_and_keys` (C, I, K, T, J, M, Esc).
  - `test_click_opens_window_and_marks_it`.
  - `test_quests_disabled`.
  - `test_bar_inside_top_right_at_720p` (its rect within the top-right quarter, no overlap with the minimap or party frames).
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**, render the HUD and look at it. PASS.
- [ ] **Step 5: Commit** `feat: icon bar in the top-right corner opens the game windows`.

### Task 12: Version, docs, review

**Files:** `project.godot` (0.11.1), `docs/Planes/Planes.md`, the spec and plan (estado: implementado), GDD 06/09/10/14 as affected, `docs/GDD/Registro de cambios.md`, `docs/Sesiones/Sesión 2026-11-23.md`

- [ ] **Step 1:** Full suite plus node tests are green, and the import is clean.
- [ ] **Step 2:** Update the docs and the version, then commit `docs: Plan 8.1.1 playtest fixes (0.11.1)`.
- [ ] **Step 3:** Final review by a fresh reviewer on the most capable model over `main..HEAD`. Fix the findings with RED→GREEN tests, then commit.
- [ ] **Step 4:** Report to the user with the playtest steps. Do not publish without their go-ahead.

---
← [[Planes]]
