---
tags: [plan]
plan: 3.2
fecha: 2026-11-16
estado: borrador
actualizado: 2026-11-16
---
# Plan 3.2 — Vóxel propio, bestiario del prólogo y clase con Brann: plan de implementación

Spec: [[Plan 3.2 — Vóxel propio, bestiario del prólogo y clase con Brann (spec)]]. Ejecución nativa en el chat, rama `plan-3-2-story`. Versión de salida **0.5.0**, protocolo **5**.

**Objetivo:** personajes y enemigos 100 % vóxel por código, bestiario del asalto a la aldea, y personajes que nacen aldeanos y eligen clase con Brann.

**Arquitectura:**
- `HumanRig` (nuevo, por huesos, como `BeastRig`) sustituye a `CharacterRig`/Kenney. `CharacterCatalog.resolve` sigue dando el *look*, ahora con piezas vóxel en lugar de capas.
- La clase se elige con un mensaje nuevo cliente → anfitrión. El NPC es un dato del mapa, no una entidad de la simulación.

## Restricciones globales
- Ningún archivo bajo `assets/` puede derivar de terceros; `CREDITS.md` sin la fila de Kenney.
- Textos del juego en `data/texts/textos.csv`, marcados `[provisional]` en una columna de notas si vienen del guion sin fijar.
- Sin scroll a 1280×720 (ventana de clases y ventana K).
- Contenido en `data/`: monstruos, NPC y clases sin tocar las reglas de `sim/`, salvo lo que pide el aldeano (recurso `none`).
- Los ids de `appearance.json` no cambian.

## Lo que más puede fallar (cubierto en las tareas indicadas)
1. Un personaje guardado con peinado o barba de capa se ve calvo o sin barba tras el cambio → test de que cada id resuelve a pieza vóxel (Task 2).
2. Un invitado con la 0.4.x entra en una partida 0.5.0 → rechazo por versión, como hoy (Task 7).
3. Pulsar E junto a Brann y a un aliado caído a la vez → reanima y no abre la ventana (Task 8).
4. Elegir clase estando caído o durante el combate → el anfitrión lo rechaza si está caído o muerto; en combate se permite (Task 7).
5. Un aldeano con la barra guardada de una versión antigua → `sanitize_bar` la deja vacía (Task 6).

---

### Task 1: `HumanRig` — cuerpo, cara y animaciones
**Archivos:** crear `tools/art/make_humans.mjs`, `assets/characters/vox/human*.vox` + `human.json`, `game/characters/human_rig.gd`; modificar `tools/art/vox.mjs` y `game/characters/vox_mesher.gd` (canales `TINT_SKIN = 248`, `TINT_EYES = 249`); test `tests/unit/characters/test_human_rig.gd`.

**Produce:**
- `HumanRig.build(look: Dictionary) -> HumanRig`, con el mismo *look* que `CharacterRig.build`, pero `hair_layer`/`beard_layer`/`outfit_layer` dejan de existir y `outfit` pasa a ser `{primary, secondary}` en el torso y las piernas.
- `set_moving_speed(speed_mps: float, move_speed: float)`.
- `play_action(kind: String) -> float`: devuelve los segundos que dura; `kind` ∈ `melee`, `shoot`, `cast`, `dash`, `downed`, `die`, `idle`.
- `current_action() -> String`.
- `part(name) -> Node3D`, `piece_node(id) -> MeshInstance3D`, `pieces() -> Array[String]`.
- Partes: `hips`, `torso`, `head`, `arm_left`, `arm_right`, `hand_left`, `hand_right`, `leg_left`, `leg_right`, con altura total ≈ la de Kenney × `MODEL_SCALE`.

Pasos:
- [ ] Tests fallidos:
  - `test_builds_all_parts` (las 9 partes existen);
  - `test_tints_skin_and_eyes`;
  - `test_body_scale_widens_torso`;
  - `test_each_action_ends` (cada acción devuelve > 0 s y vuelve a `idle` al avanzar el tiempo, salvo `downed` y `die`, que se mantienen);
  - `test_no_external_paths` (ningún recurso cargado contiene `characters/base` ni `layers`).
- [ ] Ejecutar GUT → fallan.
- [ ] `make_humans.mjs` (cuerpo con cara pintada: ojos `TINT_EYES` y cejas en el tono del pelo) y `human_rig.gd`, con las animaciones por tween/fase al estilo de `BeastRig` (reposo con respiración; andar con brazos contrarios; golpe con giro de torso; tensar arco; hechizo con brazos alzados; esquiva agachada; caído tumbado; muerte cayendo hacia atrás).
- [ ] GUT verde.
- [ ] Commit `feat(art): own voxel humanoid rig`.

### Task 2: Peinados, barbas, armas y ropa en vóxel
**Archivos:** modificar `tools/art/make_pieces.mjs`, `data/characters/appearance.json` (cada `hair_style` y `beard` con `piece`, sin `layer`), `data/characters/pieces.json` (`part` con los nombres de `HumanRig`), `data/characters/classes.json` (sin `outfit`; añade `weapon`), `game/characters/character_catalog.gd` (`resolve`); test `tests/unit/characters/test_character_catalog.gd`.

**Produce:** piezas nuevas:
- peinados `hair_short`, `hair_bob`, `hair_swept`;
- barbas `beard_full`, `beard_mustache`, `beard_short`, `beard_goatee`;
- armas `weapon_sword`, `weapon_mace`, `weapon_staff`, `weapon_bow`, `weapon_daggers`, `weapon_wood_sword`.

`resolve()` devuelve `pieces` con el pelo, la barba (tinte de pelo), el tocado, las piezas de la clase y el arma (`part: hand_right`, o `hand_left` para el arco).

Pasos:
- [ ] Tests fallidos:
  - `test_every_appearance_id_resolves` (cada combinación de `hair_style` × `beard` da sus piezas y ningún valor `*_layer`);
  - `test_class_weapon_attached`;
  - `test_bald_has_no_hair_piece`;
  - `test_headgear_hides_hair` (como hoy).
- [ ] Implementar y regenerar con `node tools/art/make_pieces.mjs assets/characters/pieces`.
- [ ] GUT verde.
- [ ] Commit `feat(art): voxel hair, beards and class weapons`.

### Task 3: Punto de revisión del usuario
- [ ] `tests/helpers/render_characters.gd`, set `human_review`: las 5 clases en Kenney y en `HumanRig` lado a lado, los 2 tipos de cuerpo, 4 peinados con barba, y una tira con cada acción a mitad de su duración. Guardar las capturas en `user://render/`.
- [ ] Enseñárselas al usuario. **No seguir sin su visto bueno**; aplicar los cambios que pida y repetir.

### Task 4: Cambio a `HumanRig` y borrado de Kenney
**Archivos:**
- modificar `game/player_avatar.gd` (usa `HumanRig`; `ACTION_ANIMS` desaparece; `play_action(kind)` delega en el rig; el caído usa `downed` y no gira con el ratón), `game/monster_avatar.gd` (`humanoid:` usa `HumanRig`), `ui/character_preview.gd`, `tests/helpers/render_characters.gd`;
- borrar `game/characters/character_rig.gd`, `assets/characters/base/`, `assets/characters/layers/`, `assets/characters/character.gdshader`, `tools/art/extract_layers.mjs`, `tools/art/paint_outfits.mjs`;
- actualizar `CREDITS.md` y `tools/art/README.md`;
- adaptar los tests que usen `CharacterRig` (`test_character_rig.gd` → se borra; lo cubre `test_human_rig.gd`).

Pasos:
- [ ] Test fallido `test_no_kenney_left` en `tests/unit/test_assets.gd`: recorre `res://` y falla si existe algún `.glb` o algún archivo bajo `assets/characters/base|layers`.
- [ ] Cambiar, borrar y adaptar.
- [ ] GUT verde y el juego arranca sin errores (`--headless --quit-after 120`, sin `ERROR` en la salida).
- [ ] Commit `refactor(art): switch to HumanRig and drop Kenney assets`.

### Task 5: Bestiario del prólogo
**Archivos:**
- crear `data/monsters/cultist.json`, `cult_archer.json`, `marked_hound.json`, `marked_boar.json`, `guard_beast.json`;
- borrar `goblin.json`, `skeleton_archer.json`, `wolf.json`, `boar.json`, `slime.json`, `orc_king.json`;
- `data/abilities/monsters.json`: renombrar `goblin_stab` → `cultist_stab`, `skeleton_arrow` → `cult_arrow`, `wolf_bite` → `hound_bite`, `boar_gore`/`boar_charge` → `marked_boar_gore`/`marked_boar_charge`, `orc_king_cleave`/`orc_king_jump` → `guard_beast_cleave`/`guard_beast_jump`, con los mismos valores; quitar `slime_slam`;
- `tools/art/make_monsters.mjs`: rigs `marked_hound` (lobo más fiero con collar), `marked_boar` (jabalí con collar y placas) y `guard_beast` (bípedo grande con cuernos, cadenas y collar). Quitar slime y skeleton;
- `make_pieces.mjs`: `cult_mask` (hueso con sol negro de cinco rayos partido), `cult_hood`, `cult_robe_*`;
- `game/beast_rig.gd`: animaciones de tajo y salto para `guard_beast` (las que hoy hace el rey orco en `MonsterAvatar`);
- `data/maps/test_arena.json`: mismos puntos de aparición, nuevos tipos; el sitio del limo pasa a sabuesos;
- `textos.csv`: `MON_CULTIST` «Cultista enmascarado», `MON_CULT_ARCHER` «Arquero del culto», `MON_MARKED_HOUND` «Sabueso marcado», `MON_MARKED_BOAR` «Jabalí marcado», `MON_GUARD_BEAST` «Bestia de guardia». Quitar las claves retiradas;
- tests que nombren monstruos retirados.

Pasos:
- [ ] Tests fallidos en `tests/unit/data/test_monster_data.gd`:
  - `test_every_monster_loads` (modelo existente y habilidades presentes en `monsters.json`);
  - `test_map_spawns_exist`;
  - `test_prologue_roster` (exactamente los 5 ids nuevos).
- [ ] Implementar y regenerar el arte.
- [ ] GUT verde.
- [ ] Captura `render_characters --set=prologue` para la revisión final.
- [ ] Commit `feat(content): prologue bestiary`.

### Task 6: Aldeano y creación sin clase
**Archivos:**
- `data/characters/classes.json`: añadir `villager` primero, con `"selectable": false`, ropa `primary #8a7a5c` / `secondary #5a4632`, `weapon: weapon_wood_sword`, stats `max_hp 120, attack_power 10, spell_power 0, armor 10, crit_chance 0.05, dodge_chance 0`, `resource {"kind": "none", "max": 0, "start": 0}`;
- `data/abilities/villager.json`: básica `villager_strike` (cuerpo a cuerpo, como la básica del guerrero al 70 %);
- `CharacterCatalog`: `DEFAULT_CLASS := "villager"`, `selectable_classes() -> Array`;
- `ClassRules.setup_player` acepta el recurso `none`;
- `AbilityDB.sanitize_bar` devuelve `[]` para el aldeano;
- `ui/character_create_screen.gd`: sin fila de clase; la señal pasa a `create_requested(char_name, appearance)`;
- `save/character_data.gd`: `VERSION` +1; un personaje sin `class_id` nace `villager`;
- `ui/abilities_window.gd`: con el aldeano, muestra solo su básica y el texto `ABILITIES_VILLAGER_HINT`;
- `ui/combat_hud.gd`: sin barra de recurso si el tipo es `none`;
- `textos.csv`: `CLASS_VILLAGER`, `CLASS_VILLAGER_DESC`, `ABILITIES_VILLAGER_HINT` «Habla con Brann para elegir tu clase» [provisional].

Pasos:
- [ ] Tests fallidos:
  - `test_new_character_is_villager` (`test_character_data.gd`);
  - `test_old_save_keeps_class`;
  - `test_villager_not_selectable` (catálogo);
  - `test_villager_setup` (`test_class_rules`: 120 de vida y recurso 0 sin regeneración);
  - `test_villager_bar_empty` (`sanitize_bar` con una barra antigua devuelve `[]`);
  - `test_create_screen_has_no_class_row`;
  - `test_abilities_window_villager_fits_1280x720`.
- [ ] Implementar.
- [ ] GUT verde.
- [ ] Commit `feat(classes): characters start as villagers`.

### Task 7: Elegir clase en red
**Archivos:** `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/game_session.gd`, `data/npcs/brann.json`, `data/maps/test_arena.json` (`"npcs": [{"id": "brann", "at": [22, 18], "facing": 180}]`), `sim/npc_db.gd` (nuevo); tests `test_protocol.gd`, `test_host_session.gd`, `test_client_session.gd`.

**Produce:**
- `Protocol.VERSION := 5`.
- Mensajes nuevos: `Msg.CHOOSE_CLASS [["class_id", TYPE_STRING]]` y `Msg.PLAYER_CLASS [["id", TYPE_INT], ["class_id", TYPE_STRING], ["bar", TYPE_ARRAY]]`.
- `NpcDB.load_default() -> NpcDB`, con `npc(id) -> Dictionary` y `positions(map: Dictionary) -> Array` (`[{id, position: Vector3, facing}]`).
- Constante `NpcDB.TALK_RANGE := 2.5`.
- `ClientSession.choose_class(class_id: String)` y la señal `class_changed(id: int, class_id: String)`.
- El roster guarda la `class_id` nueva.

Pasos:
- [ ] Tests fallidos:
  - `test_choose_class_roundtrip` (empaquetar y validar);
  - `test_host_accepts_valid_choice` (aldeano a 2 m de Brann → `class_id`, stats, recurso lleno, barra por defecto, y `PLAYER_CLASS` llega a todos);
  - `test_host_rejects` (ya tiene clase, a 3 m, caído, muerto, `villager`, id desconocido: no cambia nada y no hay mensaje);
  - `test_client_updates_roster_and_emits`;
  - `test_hello_v4_rejected`.
- [ ] Implementar. El anfitrión, local o remoto, pasa por la misma validación.
- [ ] GUT verde.
- [ ] Commit `feat(net): choose class with an NPC`.

### Task 8: Brann en el mundo y ventana de clases
**Archivos:**
- crear `game/npc_avatar.gd` (`HumanRig` + nombre encima; *look* de `brann.json`: robusto, pelo y barba grises, delantal `primary #6b4a2b` / `secondary #9a9a9a`, espada) y `ui/class_choice_window.gd`;
- modificar `game/game_session.gd` (crea los NPC del mapa; al pulsar E: si hay un aliado caído en el rango de reanimación, no hace nada nuevo; si no y Brann está a ≤ 2,5 m, abre la ventana si eres aldeano o muestra su línea; al recibir `class_changed` rehace el avatar y guarda el personaje con `CharacterStore`), `ui/party_frames.gd` (icono y recurso de la clase nueva);
- `textos.csv`: `NPC_BRANN`, `BRANN_HAS_CLASS` «Ya has elegido tu camino. Ahora recórrelo.» y `CLASS_CHOICE_TITLE`, `CLASS_CHOICE_CONFIRM`, `CLASS_CHOICE_WARNING` «La elección es definitiva», todos [provisional];
- test `tests/unit/ui/test_class_choice_window.gd`, `tests/unit/game/test_npc_interaction.gd`.

**Ventana de clases:** 5 botones de clase (las de `selectable_classes()`), y para la elegida: nombre, descripción, recurso, vista previa con `CharacterPreview` (el personaje con esa clase), aviso y botón Confirmar. Esc cierra. Señal `class_confirmed(class_id)` → `client.choose_class`.

Pasos:
- [ ] Tests fallidos:
  - `test_window_lists_five_classes`;
  - `test_window_fits_1280x720`;
  - `test_confirm_emits`;
  - `test_e_opens_for_villager_near_brann`;
  - `test_e_prefers_revive` (aliado caído en rango → la ventana no se abre);
  - `test_e_far_does_nothing`;
  - `test_e_with_class_shows_line`.
- [ ] Implementar.
- [ ] GUT verde.
- [ ] Commit `feat(ui): Brann and the class choice window`.

### Task 9: Documentación, versión y revisión final
- [ ] `project.godot` → versión 0.5.0.
- [ ] GDD:
  - el apartado de personajes y clases (la creación sin clase, Brann);
  - el bestiario;
  - `Registro de cambios.md`;
  - `15 Decisiones abiertas.md`.
- [ ] Decisión en `docs/Decisiones/` («Clase elegida dentro de la partida» y «Arte 100 % propio»), enlazada en el índice.
- [ ] `Planes.md`: fila 3.2.
- [ ] Notas de la versión.
- [ ] Nota de sesión.
- [ ] GUT completo verde, más una revisión final de toda la rama por un revisor nuevo.
- [ ] Commit `docs: version 0.5.0`. La publicación queda para cuando el usuario pruebe.

---
← [[Planes]]
