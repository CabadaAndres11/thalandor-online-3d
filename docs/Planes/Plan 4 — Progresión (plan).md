---
tags: [plan]
plan: 4
fecha: 2026-11-16
estado: en curso
actualizado: 2026-11-16
---
# Plan 4 — Progresión: plan de implementación

Spec: [[Plan 4 — Progresión (spec)]]. Rama `plan-4-progression`. Versión de salida **0.6.0**, protocolo **6**, personajes versión **3**.

**Objetivo:** experiencia y niveles sin tope, desbloqueos, atributos, árbol de talentos, arena que escala y mejoras de clase del nivel 50, todo guardado con el personaje.

**Arquitectura:**
- Reglas nuevas en `sim/progression/` (portadas de `D:\RPG\src\sim\progression`), sin nodos ni red. El progreso de un jugador es un objeto `PlayerProgress` colgado de `PlayerState`.
- Una sola función, `Progression.rebuild`, calcula las estadísticas finales a partir de clase, nivel, atributos, talentos, maestrías, pasivas y mejora.
- El anfitrión valida cada petición y devuelve `PROGRESS` al dueño, que lo guarda en su `CharacterData`.
- Las mejoras del nivel 50 son datos (`data/upgrades/`); `sim/` solo gana efectos y ganchos genéricos.

**Tests:** `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` (un archivo: `-gtest=res://tests/...`). Pasa = `---- All tests passed! ----` y código 0.

## Restricciones globales
- Todo número de equilibrio vive en `data/balance.json`; todo contenido (nodos, mejoras, habilidades) en `data/`. Añadir contenido no toca `sim/`.
- Textos del juego en `data/texts/textos.csv` (español); código, ids y commits en inglés.
- Ninguna ventana con scroll a 1280×720: cada ventana nueva lleva su test `panel_rect()` dentro de 1280×720, como `test_class_choice_window.gd`.
- El anfitrión nunca aplica un cambio de progreso sin validarlo; un cliente nunca recibe el `PROGRESS` de otro.
- Ninguna migración borra ni rebaja un personaje.
- Aleatoriedad solo con `world.rng`; tiempos en segundos en los datos y en ticks en la simulación.
- Un commit por tarea, con el mensaje indicado.

## Lo que más puede fallar (cubierto en las tareas indicadas)
1. **Un `HELLO` con progreso imposible** (más puntos que nivel, nodos sueltos, mejora de otra clase, números negativos o enormes) → se sanea y el jugador entra; nunca se rechaza ni rompe la partida (Task 7).
2. **Ganar de golpe experiencia para muchos niveles** (`/xp 99999999`) → sube todos los niveles en un tick sin bucle infinito ni desbordar; el nivel viaja como u16 (Tasks 1 y 8).
3. **Reconstruir estadísticas en mitad del combate** (subir de nivel, gastar punto) → se conserva el % de vida y de recurso, los estados y las recargas; nunca cura ni mata (Task 4).
4. **Cambiar o reiniciar la mejora con sus habilidades en la barra, canalizando o con el lobo fuera** → la barra se sanea, el canalizado se corta y el lobo desaparece (Tasks 12 y 17).
5. **Un personaje guardado en la 0.5.0** (versión 2, con Evasión en la barra o sin campos de progreso) → entra a nivel 1 con la ranura vacía, sin perder nada más (Tasks 9 y 11).

---

## Fase A — Progresión base

### Task 1: Experiencia y curva
**Archivos:** crear `sim/progression/xp.gd`, `sim/progression/player_progress.gd`; modificar `sim/balance.gd`, `data/balance.json`; tests `tests/unit/sim/test_xp.gd`, `test_player_progress.gd`.

**Datos** (`balance.json`, bloque `xp`, cargado en `Balance.xp: Dictionary`):
`{"base": 100, "exponent": 1.6, "linear_from": 50, "linear_step": 2500, "monster_base": 8, "monster_exponent": 1.2, "elite_mult": 4, "boss_mult": 10, "level_grace": 2, "level_penalty": 0.2, "min_factor": 0.1, "share_range": 30.0, "group_bonus": 0.1}`

**Produce:**
- `class_name PlayerProgress`: `level: int = 1`, `xp: int = 0`, `attributes: Dictionary` (`strength`, `agility`, `intellect`, `stamina`, `spirit` → int, puntos repartidos a mano), `talents: Array` (ids), `masteries: Dictionary` (dirección → rango), `upgrade: String = ""`.
  - `const ATTRIBUTES := ["strength", "agility", "intellect", "stamina", "spirit"]`.
  - `to_dict() -> Dictionary`; `static from_dict(v: Variant) -> PlayerProgress` (nunca null; cualquier tipo o valor raro cae al valor por defecto).
  - Test `test_from_dict_garbage`: `from_dict("x")`, `{level: -5}`, `{attributes: [1]}`, `{talents: "a"}` → valores por defecto; `test_roundtrip`.

`class_name Xp`, todo `static`:
- `to_next(level: int, b: Balance) -> int` — `round(100 × L^1.6)` hasta 50; desde 50, `to_next(50) + 2500 × (L − 50)`.
- `monster_xp(level: int, elite: bool, boss: bool, b: Balance) -> int`
- `level_factor(player_level: int, monster_level: int, b: Balance) -> float`
- `group_share(total: int, n: int, b: Balance) -> int`
- `add(progress: PlayerProgress, amount: int, b: Balance) -> int` — suma, sube los niveles que toque y devuelve cuántos. `amount` se limita a `0..2_000_000_000`; el nivel, a 65535.

Pasos:
- [ ] Tests fallidos:
  - `test_curve`: `to_next(1) == 100`, `to_next(2) == 303`, `to_next(10) == 3981`, `to_next(50) == roundi(100 × 50^1.6)`, `to_next(51) == to_next(50) + 2500`, `to_next(60) == to_next(50) + 25000`;
  - `test_monster_xp`: nivel 1 → 8; nivel 10 → 127; élite ×4; jefe ×10;
  - `test_level_factor`: diferencia ≤ 2 → 1.0; 3 → 0.8; 10 → 0.1;
  - `test_group_share`: `group_share(100, 1) == 100`, `group_share(100, 4) == 33`;
  - `test_add_many_levels`: `add` con 500 desde nivel 1 deja nivel 3 y 97 de experiencia (100 + 303 gastados), y devuelve 2;
  - `test_add_huge_amount_ends`: `add(p, 2_000_000_000)` termina y deja `level <= 65535`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(sim): experience curve and level-ups`.

### Task 2: Monstruos con nivel y arena que escala
**Archivos:** modificar `sim/combat/combat_entity.gd` (`var level: int = 1`), `sim/player_state.gd` (quitar su `level`), `sim/ai/monster_db.gd`, `sim/ai/spawner.gd`, `sim/sim_world.gd`, `sim/combat/damage.gd`, `sim/combat/combat.gd` (`snapshot_of` copia `level`), `sim/balance.gd`, `data/balance.json`; tests `tests/unit/sim/test_monster_levels.gd`, ajustar `test_damage.gd`.

**Datos:** `"monster_scaling": {"hp": 0.12, "damage": 0.08, "armor": 0.06, "boss_level_bonus": 2, "arena_min": 1, "arena_max": 60}`, `"armor_k_per_level": 6.0`.

**Produce:**
- `MonsterDB.make(type_id, id, pos, world, level: int = 1) -> MonsterState` — aplica `× (1 + factor × (L − 1))` a vida y armadura base y a `damage_done_mult`; `base_max_hp` ya escalado.
- `SimWorld.arena_level: int = 1`; `SimWorld.set_arena_level(level: int) -> void` — limita a 1..60, emite `["arena_level", level]`, y rehace al nivel nuevo los monstruos vivos **sin objetivo y sin amenaza** (mismo sitio, élite conservado, vida llena). Los demás lo toman al reaparecer.
- `SimWorld.monster_level(spawn: Dictionary, def: Dictionary) -> int` — `arena_level + spawn.level_offset (0) + 2 si def.boss`.
- `Damage.mitigation(armor: float, balance: Balance, attacker_level: int = 1) -> float` — `K = armor_k + armor_k_per_level × (L − 1)`.

Pasos:
- [ ] Tests fallidos:
  - `test_level_scales_stats`: cultista nivel 11 → vida `55 × 2.2`, armadura `5 × 1.6`, `damage_done_mult == 1.8`;
  - `test_boss_is_two_above`;
  - `test_set_arena_level_respawns_idle_only`: uno en reposo cambia de nivel; uno con objetivo no;
  - `test_arena_level_clamped`: 0 → 1, 999 → 60;
  - `test_elite_keeps_elite_on_rescale`;
  - `test_mitigation_grows_k`: armadura 60, nivel 1 → 0.5; nivel 11 → `60 / 180`;
  - `test_group_rescale_keeps_level` (añadir jugador no devuelve al nivel 1).
- [ ] Implementar. GUT verde. Commit `feat(sim): monster levels and a scaling arena`.

### Task 3: Reparto de experiencia al matar
**Archivos:** modificar `sim/player_state.gd` (`var progress := PlayerProgress.new()`, `var progress_dirty: bool = false`), `sim/ai/monster_state.gd` (`var summoned_by: int = 0` si no existe ya un campo equivalente para los esbirros del jefe), `sim/combat/combat.gd` (`on_zero_hp`), `sim/progression/xp.gd`; test `tests/unit/sim/test_xp_share.gd`.

**Produce:**
- `Xp.share(world: SimWorld, m: MonsterState) -> void` — jugadores con `life != DEAD` a ≤ 30 m; a cada uno `round(group_share × level_factor)`; llama a `Xp.award`.
- `Xp.award(world: SimWorld, p: PlayerState, amount: int) -> void` — `Xp.add`; marca `p.progress_dirty = true`; si sube: `Progression.rebuild` (Task 4; hasta entonces solo `p.level`), vida al máximo, recurso al máximo salvo `rage`, y evento `["level_up", p.id, level]`.
- Los monstruos con `summoned_by != 0` (esbirros del jefe e invocaciones) no dan experiencia.

Pasos:
- [ ] Tests fallidos: `test_kill_gives_xp_to_near_players`, `test_far_player_gets_none` (a 31 m), `test_downed_player_gets_share`, `test_dead_player_gets_none`, `test_level_up_refills_hp_not_rage`, `test_level_up_event`, `test_boss_minions_give_none`.
- [ ] Implementar. GUT verde. Commit `feat(sim): players earn experience from kills`.

### Task 4: Atributos y cálculo de estadísticas
**Archivos:** crear `sim/progression/attributes.gd`, `sim/progression/progression.gd`; modificar `sim/combat/combat_stats.gd`, `sim/combat/class_rules.gd` (`setup_player` delega en `rebuild`), `sim/combat/passives.gd`, `sim/combat/damage.gd`, `sim/combat/combat.gd`, `sim/combat/resources.gd`, `data/characters/classes.json`, `data/balance.json`; tests `tests/unit/sim/test_attributes.gd`, `test_progression_rebuild.gd`; ajustar `test_passives.gd`.

**Datos:**
- `classes.json`: `"main_attributes"` — warrior `["strength","stamina"]`, cleric y mage `["intellect","spirit"]`, archer `["agility","stamina"]`, assassin `["agility","strength"]`, villager `["strength","stamina"]`; `"attack_attribute"`: `"agility"` para archer, `"strength"` para el resto.
- `balance.json`, bloque `attributes`: `{"points_per_level": 5, "auto_per_level": 1, "attack_power": 0.5, "spell_power": 0.5, "max_hp": 5.0, "max_mana": 2.0, "crit": 0.0005, "dodge": 0.0003, "block": 0.002, "hp_regen": 0.05, "mana_regen": 0.03, "soft_caps": [[200, 0.5], [500, 0.25]], "crit_cap": 0.4, "dodge_cap": 0.25, "block_cap": 0.3, "cooldown_cap": 0.4, "block_reduction": 0.5}`.

**Produce:**
- `CombatStats`: campos nuevos `block_chance`, `crit_damage` (se suma a `crit_multiplier`), `cooldown_reduction`, `lifesteal`, `hp_regen`, `resource_regen_add`; todos en `FIELDS`.
- `Attributes.free_points(pr: PlayerProgress, b: Balance) -> int` — `5 × (level − 1) − suma repartida`.
- `Attributes.totals(pr: PlayerProgress, class_def: Dictionary, b: Balance) -> Dictionary` — repartidos + `auto_per_level × (level − 1)` en cada atributo principal.
- `Attributes.effective(points: int, b: Balance) -> float` — puntos tras los tramos: hasta 200 a ×1, de 200 a 500 a ×0.5, desde 500 a ×0.25.
- `Attributes.spend(pr: PlayerProgress, attr: String, b: Balance) -> bool`.
- `Progression.rebuild(p: PlayerState, world: SimWorld) -> void`:
  1. base de clase → 2. atributos → 3. bonos planos → 4. `× (1 + suma de %)` por estadística, con los modificadores de `Progression.modifiers(p, world) -> Array` (pasivas desbloqueadas; talentos, maestrías y mejora se añaden en las Tasks 6 y 12) → 5. topes;
  - conserva `hp / max_hp` y `resource / max_resource` (personaje recién creado: lleno según `resource.start`);
  - no toca estados, recargas ni posición; fija `p.level = p.progress.level` y `p.passives`.
- Modificadores de estadística admitidos (`{"type":"stat","stat":…,"value":…}`): planos `armor_add`, `max_hp_add`, `hp_regen_add`, `dodge_add`, `crit_add`, `block_add`, `crit_damage_add`, `lifesteal_add`, `cooldown_reduction_add`; porcentuales `armor_pct`, `max_hp_pct`, `max_resource_pct`, `move_speed_pct`, `attack_power_pct`, `spell_power_pct`, `damage_done_pct`, `damage_taken_pct`, `healing_done_pct`, `healing_received_pct`, `threat_pct`, `resource_regen_pct`.
- `Passives.apply_stats` se elimina; `healing_done_pct` y `healing_received_pct` pasan de gancho a modificador `stat` en los JSON de habilidades.
- `Passives.hooks(e, hook) -> Array` (todos los ganchos con ese nombre); `damage_mult` usa todos los `bonus_vs_status`.
- **Bloqueo:** en `Damage.roll`, tras la esquiva, si el daño es físico y `effect.type == "melee_arc"` o el atacante está a ≤ 3 m: tirada de `block_chance`; si bloquea, daño × 0.5, `result.blocked = true`, evento `["block", target.id]` y `Combat._blocked(target)`.
- `Damage.roll` usa `crit_multiplier + attacker.stats.crit_damage`; `Combat.deal` cura `amount × lifesteal`; `Combat.try_cast` multiplica la recarga por `1 − cooldown_reduction`; `Resources.tick` aplica `hp_regen` fuera de combate y `resource_regen_add` al maná.

Pasos:
- [ ] Tests fallidos:
  - `test_free_points`: nivel 1 → 0; nivel 11 → 50; tras gastar 3 → 47;
  - `test_spend_rejects_without_points` y `test_spend_rejects_unknown_attribute`;
  - `test_auto_points_by_class`: guerrero nivel 11 → fuerza 10 y aguante 10 sin gastar;
  - `test_effective_soft_caps`: 200 → 200; 300 → 250; 600 → 375;
  - `test_strength_gives_attack_and_block`: guerrero con 100 de fuerza → `attack_power == 20 + 50`, `block_chance == 0.2`;
  - `test_archer_attack_from_agility`;
  - `test_caps`: crítico ≤ 0.4, esquiva ≤ 0.25, bloqueo ≤ 0.3, recargas ≤ 0.4;
  - `test_percent_bonuses_add_then_multiply`: dos `max_hp_pct` de 0.1 → ×1.2, no ×1.21;
  - `test_rebuild_keeps_hp_ratio`: al 50 % de vida, tras subir aguante sigue al 50 %;
  - `test_rebuild_keeps_statuses_and_cooldowns`;
  - `test_rebuild_at_zero_hp_stays_downed` (no revive);
  - `test_block_halves_melee_physical_only`;
  - `test_villager_keeps_points_on_class_choice`.
- [ ] Implementar. Toda la batería verde (los tests de pasivas existentes deben seguir pasando con los valores de nivel 1). Commit `feat(sim): attributes and a single stat rebuild`.

### Task 5: Desbloqueos por nivel
**Archivos:** modificar `sim/combat/ability_db.gd`, `sim/combat/combat.gd`, `net/host_session.gd`; tests `tests/unit/sim/test_unlocks.gd`, ajustar `test_class_kits_full.gd`.

**Produce:**
- `AbilityDB.unlocked(class_id: String, level: int, upgrade: String = "") -> Array` — ids activas con `level <= level` y (`upgrade` vacío en la habilidad o igual al del jugador).
- `AbilityDB.sanitize_bar(class_id: String, bar: Variant, level: int = 1, upgrade: String = "") -> Array` — vacía las ranuras bloqueadas.
- `AbilityDB.default_bar(class_id: String, level: int = 1, upgrade: String = "") -> Array`.
- `AbilityDB.place_unlocked(bar: Array, class_id: String, old_level: int, new_level: int, upgrade: String) -> Array` — coloca en huecos libres las activas recién desbloqueadas, por nivel ascendente.
- `Combat.try_cast` rechaza una habilidad de jugador con `level > caster.level` o de otra mejora.
- El anfitrión, al subir de nivel un jugador, aplica `place_unlocked` y le reenvía la barra (en `PROGRESS`, Task 8).

Pasos:
- [ ] Tests fallidos: `test_level1_has_three_actives`, `test_sanitize_clears_locked`, `test_cast_locked_refused`, `test_passive_turns_on_at_level` (guerrero nivel 5 tiene `rage_decay_mult`; nivel 4 no), `test_place_unlocked_fills_free_slot`, `test_place_unlocked_keeps_full_bar`.
- [ ] Implementar. GUT verde. Commit `feat(sim): abilities and passives unlock by level`.

### Task 6: Árbol de talentos y maestrías
**Archivos:** crear `tools/data/make_talents.mjs`, `data/talents.json`, `sim/progression/talent_db.gd`, `sim/progression/talents.gd`; modificar `sim/progression/progression.gd`, `data/balance.json`, `docs/GDD/Anexo C — Árbol de talentos.md` (anillo exterior); tests `tests/unit/data/test_talents_data.gd`, `tests/unit/sim/test_talents.gd`.

**Datos:** `talents.json` = `{"start": "start", "directions": ["might","celerity","vitality","bastion","arcane"], "nodes": {id: {"kind": "start"|"minor"|"notable"|"keystone", "dir", "ring": 1|2, "x", "y", "mods": [...], "links": [...]}}}`. Ids `might_1`…`might_4`, `might_key`, híbridos `might_celerity_1`…`_4`; anillo 2: `<radio>_5`, `<radio>_6` (en los puros, `_6` es `kind: keystone`). El script lo genera desde una tabla interna igual a la del anexo C.
- Híbridos: bonus principal de cada dirección al 60 % (100 % en el notable).
- Anillo 2: paso 5 = bonus del paso 1 × 1,5; paso 6 = bonus del notable × 1,5 (híbridos) o del culminante × 1,5 (puros). Los `_5` de radios vecinos se enlazan en anillo.
- `balance.json`: `"masteries": {"might": {"stat": "attack_power_pct", "value": 0.001}, "celerity": {"stat": "move_speed_pct", "value": 0.0005}, "vitality": {"stat": "healing_received_pct", "value": 0.001}, "bastion": {"stat": "max_hp_pct", "value": 0.001}, "arcane": {"stat": "spell_power_pct", "value": 0.001}, "half_at": 100}` — el rango `r` vale `value × r × half_at / (r + half_at)`.

**Produce:**
- `TalentDB.load_default() -> TalentDB`; `node(id) -> Dictionary`; `ids() -> Array`; `count(ring: int) -> int`.
- `Talents.points(level: int) -> int` — `max(0, level − 1)`.
- `Talents.spent(pr: PlayerProgress) -> int` — nodos + rangos de maestría.
- `Talents.can_buy(pr, id: String, db: TalentDB) -> bool` — existe, no es el inicio, no comprado, queda punto, enlazado al inicio o a uno comprado, y si `ring == 2` exige `pr.upgrade != ""`.
- `Talents.buy(pr, id, db) -> bool`; `Talents.can_buy_mastery(pr, dir, db) -> bool` (todo lo disponible comprado y queda punto); `Talents.buy_mastery(pr, dir, db) -> bool`.
- `Talents.valid(pr, db) -> bool` — nodos reales, sin repetir, dentro de los puntos, todos conectados al inicio por nodos comprados, anillo 2 solo con mejora.
- `Talents.mods(pr, db, b: Balance) -> Array` — modificadores `stat` de nodos y maestrías; `Progression.modifiers` los incluye.
- `Talents.reset(pr) -> void` (nodos y maestrías).

Pasos:
- [ ] Tests fallidos:
  - datos: `test_66_nodes` (46 de anillo 1, 20 de anillo 2), `test_links_symmetric`, `test_graph_connected`, `test_five_keystones_per_ring_on_pure_spokes`, `test_every_mod_is_a_known_stat`, `test_positions_inside_unit_circle`;
  - reglas: `test_points_by_level`, `test_buy_needs_link`, `test_buy_needs_point`, `test_cannot_buy_twice`, `test_ring2_needs_upgrade`, `test_mastery_only_when_all_bought`, `test_mastery_diminishing` (rango 100 da la mitad que 100 rangos lineales), `test_valid_rejects_orphan_node`, `test_mods_reach_stats` (comprar `bastion_2` sube la vida un 3 %), `test_reset_returns_points`.
- [ ] Implementar. GUT verde. Commit `feat(sim): circular talent tree with masteries`.

### Task 7: Peticiones de progreso y saneado
**Archivos:** crear `sim/progression/requests.gd`; test `tests/unit/sim/test_progress_requests.gd`.

**Produce** (`class_name ProgressRequests`, `static`; cada una devuelve `bool` y, si acepta, llama a `Progression.rebuild` y pone `p.progress_dirty = true`):
- `spend_attribute(world, p: PlayerState, attr: String) -> bool`
- `buy_talent(world, p, id: String) -> bool`
- `buy_mastery(world, p, dir: String) -> bool`
- `reset(world, p, what: String, near_trainer: bool) -> bool` — `what` ∈ `attributes`, `talents`, `upgrade`; exige `near_trainer`, vivo y fuera de combate.
- `sanitize(pr: PlayerProgress, class_id: String, world: SimWorld) -> PlayerProgress` — copia saneada: nivel 1..65535; experiencia `0..to_next − 1`; atributos enteros ≥ 0 (si suman más que los puntos, todos a 0); talentos (si `Talents.valid` falla, vacíos, y maestrías a 0); mejora que no sea de su clase o con nivel < 50 → `""`.
- Todas rechazan a un jugador muerto. Comprar y gastar se permiten en combate; reiniciar no.

Pasos:
- [ ] Tests fallidos: uno por petición aceptada y por cada motivo de rechazo; y de saneado: `test_sanitize_too_many_attribute_points`, `test_sanitize_orphan_talents`, `test_sanitize_foreign_upgrade`, `test_sanitize_upgrade_below_50`, `test_sanitize_negative_and_huge_numbers`, `test_sanitize_xp_over_level`.
- [ ] Implementar. GUT verde. Commit `feat(sim): validated progress requests and sanitizing`.

### Task 8: Red — protocolo 6
**Archivos:** modificar `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/game_session.gd`; tests `tests/unit/net/test_protocol.gd`, crear `tests/unit/net/test_progress_net.gd`, `tests/unit/net/test_test_commands.gd`.

**Produce:**
- `Protocol.VERSION := 6`. `HELLO` añade `["progress", TYPE_DICTIONARY]`; un `HELLO` de 7 elementos (protocolo 5) se rellena con `{}` para poder responder «versión».
- Mensajes nuevos: `SPEND_ATTRIBUTE [attr: String]`, `BUY_TALENT [id: String]`, `BUY_MASTERY [dir: String]`, `RESET [what: String]`, `SET_ARENA_LEVEL [level: int]`, `PROGRESS [progress: Dictionary, bar: Array]`, `ARENA_LEVEL [level: int]`; cada uno con su función constructora en minúsculas.
- Instantáneas: `PLAYER_RECORD := 82` (añade `level` u16 al final, fila índice 17); `MONSTER_RECORD := 38` (añade `level` u16, fila índice 9).
- `WELCOME` añade `["arena_level", TYPE_INT]`.
- **Anfitrión:**
  - en `_on_hello`: `ProgressRequests.sanitize`, lo asigna al jugador, `rebuild`, barra con `sanitize_bar(…, level, upgrade)` y envía `PROGRESS` al que entra;
  - cada petición llama a su función de `ProgressRequests`; `near_trainer` con `NpcDB.near_with_role(map, pos, "class_trainer")`;
  - tras `world.step`, a cada jugador con `progress_dirty` le envía `PROGRESS` fiable **solo a él**, como mucho una vez por segundo si solo cambió la experiencia y al momento si cambió otra cosa;
  - `SET_ARENA_LEVEL` solo del jugador anfitrión (`host_player_id`, el primero en entrar) y junto al instructor; difunde `ARENA_LEVEL`;
  - chat que empieza por `/`: solo del anfitrión; `/xp <n> [nombre]` → `Xp.award`; `/nivel <n> [nombre]` → experiencia hasta ese nivel (nunca baja); no se difunde como chat; un comando mal escrito o de un invitado se ignora y devuelve al autor un mensaje de sistema.
- **Cliente:** `var progress: PlayerProgress`, `var arena_level: int`; señales `progress_changed()`, `leveled_up(id: int, level: int)`, `arena_level_changed(level: int)`; métodos `spend_attribute(attr)`, `buy_talent(id)`, `buy_mastery(dir)`, `reset_progress(what)`, `set_arena_level(level)`; `render_state` y `monster_render_state` incluyen `level`.
- `GameSession.start_host` y `join` reciben además `progress: Dictionary`.

Pasos:
- [ ] Tests fallidos:
  - protocolo: ida y vuelta de cada mensaje nuevo; tipos erróneos → `{}`; `HELLO` de protocolo 5 → se decodifica y el anfitrión responde `REJECT version`; filas de jugador y monstruo con nivel 65535 intactas;
  - red (sesiones en memoria, anfitrión + 2 clientes): `test_progress_only_to_owner`, `test_hello_progress_sanitized_and_echoed`, `test_spend_attribute_roundtrip`, `test_buy_talent_rejected_keeps_state`, `test_level_up_reaches_everyone`, `test_guest_cannot_set_arena_level`, `test_arena_level_in_welcome`, `test_xp_progress_throttled` (10 muertes en un segundo → ≤ 2 `PROGRESS`), `test_level_up_places_new_ability_in_bar`;
  - comandos: `test_xp_command_host_only`, `test_level_command_never_lowers`, `test_command_with_ally_name`, `test_bad_command_ignored` (`/xp abc`, `/xp -5`, `/nivel 999999` → limitado a 65535), `test_xp_command_many_levels_one_tick`.
- [ ] Implementar. Batería completa verde. Commit `feat(net): protocol 6 carries progress, levels and the arena level`.

### Task 9: Guardado — personajes versión 3
**Archivos:** modificar `save/character_data.gd`, `save/character_store.gd`, `game/main.gd`; tests `tests/unit/save/test_character_data.gd`, `test_character_store.gd`.

**Produce:**
- `CharacterData.VERSION := 3`; `var progress: PlayerProgress` (sustituye a `level`; `to_dict` escribe `"progress": progress.to_dict()`).
- `migrate`: `version < 3` → `progress = {"level": 1}` (el `level` antiguo siempre era 1) y se quita `level`.
- `from_dict` usa `PlayerProgress.from_dict` y sanea la barra con nivel y mejora.
- `CharacterStore.queue_save(c: CharacterData) -> void` y `flush() -> void`: una escritura como mucho por personaje y fotograma; `main.gd` llama a `queue_save` al recibir `progress_changed` y `class_changed`, y a `flush` al salir de la partida y al cerrar el juego.
- La pantalla de selección muestra `Nivel N`.

Pasos:
- [ ] Tests fallidos: `test_v2_migrates_to_level_1`, `test_progress_roundtrip`, `test_garbage_progress_loads_defaults` (el personaje se carga igualmente), `test_newer_version_rejected` (como hoy), `test_queue_save_coalesces` (3 llamadas → 1 escritura), `test_flush_writes_pending`.
- [ ] Implementar. GUT verde. Commit `feat(save): characters keep their progress (version 3)`.

### Task 10: Interfaz de la progresión
**Archivos:** crear `ui/character_window.gd`, `ui/talents_window.gd`, `ui/trainer_menu.gd`, `ui/xp_bar.gd`; modificar `ui/combat_hud.gd`, `ui/abilities_window.gd`, `ui/party_frames.gd`, `game/overhead_bar.gd`, `game/player_avatar.gd`, `game/monster_avatar.gd`, `game/combat_fx.gd`, `game/npc_interaction.gd`, `game/input_setup.gd` (`KEY_C` → `window_character`, `KEY_T` → `window_talents`), `game/main.gd`, `data/texts/textos.csv`, `data/npcs/brann.json`; tests en `tests/unit/ui/` (uno por ventana) y `tests/unit/game/test_npc_interaction.gd`.

**Produce:**
- `XpBar.set_progress(level: int, xp: int, to_next: int)` — barra fina bajo la barra de habilidades.
- Nivel junto al nombre en `OverheadBar` (jugadores y monstruos) y en `PartyFrames`.
- `CombatFX.level_up(avatar)` y mensaje de chat de sistema `%s ha alcanzado el nivel %d`.
- `AbilitiesWindow.show_for(class_id, bar, abilities, level: int, upgrade: String)` — las bloqueadas con candado y `Nivel N`; `locked_ids() -> Array`; no se pueden asignar.
- `CharacterWindow.show_for(name, class_id, progress: PlayerProgress, stats: CombatStats, balance)`; señal `attribute_spent(attr: String)`; `free_points() -> int`; `stat_rows() -> Array`; `panel_rect()`. Las estadísticas las calcula el cliente con `Progression.rebuild` sobre un `PlayerState` local.
- `TalentsWindow.show_for(progress, db: TalentDB, balance)`; señales `talent_bought(id)`, `mastery_bought(dir)`; `node_state(id) -> String` (`owned`, `available`, `locked`, `ring_locked`); `select(id)`; `description_text()`; `masteries_visible() -> bool`; `panel_rect()`. Círculo dibujado con `_draw` a partir de `x`, `y` y `links`.
- `TrainerMenu.show_for(options: Array)`; señal `chosen(option: String)`; opciones `choose_class`, `choose_upgrade`, `reset_attributes`, `reset_talents`, `reset_upgrade`, `arena_level`. Los reinicios piden confirmación con `MessageDialog`; `arena_level` abre un selector 1–60 con − / + y confirmar.
- `NpcInteraction.trainer_options(class_id: String, progress: PlayerProgress, is_host: bool, in_combat: bool) -> Array` — con una sola opción `choose_class`, se abre directa como hoy.
- Las ventanas C, T y K se cierran con Esc y con su tecla; abrir una cierra las otras; bloquean el ataque con el ratón mientras están abiertas, no el movimiento.

Pasos:
- [ ] Tests fallidos, por ventana: cabe en 1280×720 (`panel_rect`), señales al pulsar, estados (`node_state`, `locked_ids`, puntos libres a 0 desactiva los **+**), textos desde `textos.csv` (ninguna clave sin traducir); `test_trainer_options_*` (aldeano; clase sin nivel 50; nivel 50 sin mejora; con mejora; anfitrión; en combate sin reinicios); `test_revive_still_beats_trainer`.
- [ ] Implementar. Capturas con `tests/helpers/render_ui.gd` de C, T y el menú de Brann a 1280×720 para el usuario.
- [ ] Batería completa verde. Commit `feat(ui): experience bar, character and talent windows, Brann as trainer`.

**⏸ Parada:** el usuario prueba la progresión base (salvo «implementa directamente»).

---

## Fase B — Kit del Asesino y mejoras del nivel 50

### Task 11: Kit nuevo del Asesino
**Archivos:** modificar `data/abilities/assassin.json`, `data/texts/textos.csv`, `tools/art/make_icons.mjs` (3 iconos), `sim/combat/effects.gd` y crear `sim/combat/pending_cast.gd` (repetición); tests `tests/unit/sim/test_assassin_kit.gd`, `test_repeat_casts.gd`.

**Mecánica nueva — repetición y canalizado** (bloque de habilidad `"repeat": {"times", "interval_s", "delay_s": 0, "channel": false}`):
- `world.pending_casts: Array` de `PendingCast` (lanzador, habilidad ya moldeada, puntería, veces restantes, tick siguiente, `channel`).
- La primera aplicación ocurre a `delay_s`; coste y recarga se cobran al lanzar.
- Se corta si el lanzador muere, cae o queda aturdido o congelado. Con `channel: true` se corta también si se mueve, esquiva o lanza otra cosa, y mientras dura no puede lanzar nada más; eventos `["channel", id, ability_id, duration_s]` y `["channel_end", id]`.
- Los puntos de combo se cuentan una vez al terminar, con la suma de golpes.

| id | Nivel | Coste | Recarga | Efecto |
|---|---|---|---|---|
| `assassin_throw_knife` | 3 | 20 | 6 s | proyectil 12 m, velocidad 24, daño `10 + 0.8 × PA`, `slow` 0.4 durante 3 s, `combo_gain` 1 |
| `assassin_stealth` | 6 | — | — | sin cambios |
| `assassin_fan` | 10 | — | — | sin cambios |
| `assassin_poison` | 15 | — | — | sin cambios |
| `assassin_rend` | 20 | 30 | 10 s | `melee_arc` 2 m, daño `14 + 1.2 × PA`, estado `bleed` (físico, `0.3 × PA` cada 1 s, 6 s), `combo_gain` 2 |
| `assassin_flurry` | 30 | 40 | 14 s | `repeat` 4 veces cada 0,15 s, cada golpe `6 + 0.5 × PA` a 2 m; `combo_gain` 2 en total |

- Se elimina `assassin_evasion` (datos, textos e icono). `bleed` entra en `StatusEffect.NEGATIVE` y `BIT_KINDS`.

Pasos:
- [ ] Tests fallidos: `test_kit_has_nine_usable_and_levels`, `test_throw_knife_slows_and_gives_combo`, `test_rend_bleeds`, `test_flurry_hits_four_times_two_combo`, `test_repeat_stops_when_stunned`, `test_channel_stops_on_move`, `test_channel_blocks_other_casts`, `test_saved_bar_with_evasion_sanitized`, `test_no_text_keys_left_for_evasion`.
- [ ] Implementar. GUT verde. Actualizar la tabla «Valores» de [[Asesino]]. Commit `feat(classes): assassin kit with more damage and a thrown knife`.

### Task 12: Mejoras de clase — armazón
**Archivos:** crear `sim/progression/upgrade_db.gd`, `data/upgrades/{warrior,cleric,mage,archer,assassin}.json` (vacíos de contenido hasta las Tasks 14–18: solo `id`, `class`, textos), `ui/upgrade_window.gd`; modificar `sim/combat/ability_db.gd`, `sim/progression/progression.gd`, `sim/progression/requests.gd`, `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/main.gd`, `game/game_session.gd`, `data/texts/textos.csv`; tests `tests/unit/sim/test_upgrades.gd`, `tests/unit/data/test_upgrades_data.gd`, `tests/unit/net/test_choose_upgrade.gd`, `tests/unit/ui/test_upgrade_window.gd`.

**Datos:** `data/upgrades/<clase>.json` = lista de `{"id", "class", "name", "desc", "actives": [id, id], "passives": [id, id], "evolves": {"ability": id, "set": {…}, "effects": [...]?, "desc": clave}, "look": {…}?}`. `evolves.set` sustituye campos de la habilidad; `evolves.effects`, si está, sustituye su lista de efectos. Las habilidades de mejora van en `data/abilities/<clase>.json` con `"upgrade": <id>` y `"level": 50`.

**Produce:**
- `UpgradeDB.load_default()`; `for_class(class_id) -> Array`; `upgrade(id) -> Dictionary`; `validate(abilities: AbilityDB) -> Array[String]`.
- `AbilityDB.resolved(id: String, upgrade: String) -> Dictionary` — la habilidad con la evolución aplicada; `Combat.try_cast` y `AbilityDetails` la usan.
- `AbilityDB.class_abilities` sigue devolviendo todo; `actives(class_id, upgrade)` filtra por mejora.
- `Passives.collect(db, class_id, level, upgrade)` incluye las pasivas de la mejora.
- `ProgressRequests.choose_upgrade(world, p, id: String, near_trainer: bool) -> bool` — nivel ≥ 50, sin mejora, de su clase, junto al instructor, vivo.
- `reset(…, "upgrade", …)`: quita la mejora, sanea la barra, corta `pending_casts` del jugador, retira sus invocaciones, y quita los nodos del anillo 2 (devolviendo sus puntos).
- Protocolo: `CHOOSE_UPGRADE [id: String]`, `PLAYER_UPGRADE [id: int, upgrade: String]`; `PLAYER_JOINED` y las filas de `roster` añaden `upgrade: String`. Cliente: `choose_upgrade(id)`, señal `upgrade_changed(id: int, upgrade: String)`.
- `UpgradeWindow.show_for(class_id, abilities, upgrades)`; `select(id)`; `selected()`; `option_ids()`; señal `confirmed(id)`; `panel_rect()`. Tres columnas como máximo (Mago), cada una con sus 2 activas, 2 pasivas y la evolución con `AbilityDetails`.
- Al alcanzar el nivel 50 sin mejora: mensaje de sistema `Habla con Brann para elegir tu mejora de clase`.

Pasos:
- [ ] Tests fallidos: `test_choose_needs_level_50`, `test_choose_needs_trainer`, `test_choose_rejects_other_class`, `test_choose_twice_rejected`, `test_upgrade_actives_appear_in_unlocked`, `test_evolution_changes_resolved_ability`, `test_reset_upgrade_clears_bar_and_ring2`, `test_reset_upgrade_cancels_channel`; datos: `test_every_upgrade_has_2_actives_2_passives_1_evolution` (se activa por clase al llegar su tarea; lista de clases pendientes en el test), `test_mage_has_three`, `test_all_ids_exist`, `test_texts_exist`; red: `test_upgrade_reaches_everyone`, `test_late_joiner_sees_upgrade`; ventana cabe con 3 opciones.
- [ ] Implementar. GUT verde. Commit `feat(classes): class upgrade framework and window`.

### Task 13: Efectos y ganchos genéricos para las mejoras
**Archivos:** modificar `sim/combat/effects.gd`, `combat.gd`, `damage.gd`, `passives.gd`, `status_effect.gd`, `resources.gd`, `sim/ai/monster_ai.gd`, `monster_state.gd`, `net/host_session.gd` (filas de aliados), `game/game_session.gd`, `game/monster_avatar.gd`, `game/combat_fx.gd`, `ui/ability_details.gd`; tests `tests/unit/sim/test_upgrade_effects.gd`, `test_upgrade_hooks.gd`, `test_summons.gd`.

**Efectos** (se documentan en la cabecera de `effects.gd`):
- `area` gana `heal?: {base, coef}` (cura a los aliados dentro en cada pulso) y `follow_caster?: bool`.
- `projectile` gana `count` y `spread_deg` (abanico), y `explode.leave?: {efecto area}` (deja un área al estallar).
- `beam {range, width, damage, statuses?}` — golpe instantáneo en línea a todos (usa `in_line`).
- `shield` gana `reflect_pct` (devuelve ese % del daño absorbido al atacante, sin crítico ni nueva reflexión).
- `heal` gana `bounce?: {count, radius, pct}`.
- `summon {type, duration_s, max: 1}` — crea un `MonsterState` de `data/monsters/<type>.json` en `TEAM_PLAYERS`, con `summoned_by = caster.id`, nivel del lanzador y `despawn_tick`.
- `damage` gana `execute?: {below_pct, mult}`, `lifesteal_pct?`, `school?`.
- Habilidad: `"refund_on_kill": true` (devuelve el coste si mata).

**Estados nuevos:** `haste` (recargas × `1 − magnitud` al lanzar), `vulnerable` (+daño recibido), `attack_slow` (monstruos: recargas × `1 + magnitud`), `weaken` (−daño hecho), `ice_block` (invulnerable y no puede actuar), `bleed`; los negativos, en `NEGATIVE`; los que tienen visual, en `BIT_KINDS` (máximo 32 bits: comprobarlo en un test).

**Ganchos** (`{"type":"hook","hook":…}`):
`damage_per_missing_hp {max_pct}` · `on_kill {reset_cooldown?, heal_pct?}` · `low_hp_guard {below_pct, reduction, duration_s, cooldown_s}` · `cheat_death {hp_pct, cooldown_s}` · `guardian_angel {radius, hp_pct, cooldown_s}` · `melee_hit_restores {amount}` · `stacking_school_damage {school, pct, max, duration_s}` · `school_crit {school, add}` · `slow_adds_attack_slow {pct}` · `freeze_reduces_cooldowns {seconds}` · `stationary_damage {seconds, pct}` · `traps_rearm {times}` · `bonus_vs_low_hp {below_pct, pct}` · `stealth_duration_pct {pct}` · `poison_max_stacks {max}` · `poison_spreads_on_death {radius}` · `poisoned_deal_less {pct}` · `finisher_refund_per_combo {amount}`.
- Las recargas internas de ganchos se guardan en `entity.cooldowns["hook:<nombre>"]`.

**Invocaciones aliadas:**
- `MonsterAI` deja de asumir que el enemigo es un jugador: objetivos = `Effects.enemies_of`. Un aliado invocado sigue a su dueño (a 2–4 m), ataca al último objetivo dañado por el dueño (`owner.last_target_id`, nuevo en `CombatEntity`) o a quien ataque al dueño, y se teletransporta junto a él si queda a más de 25 m.
- Los monstruos enemigos pueden fijarlo como objetivo por amenaza (`add_threat` con su id).
- No da experiencia, no cuenta para el escalado de vida por grupo ni para «alguien en pie», y desaparece al morir el dueño, al cambiar este de mejora o al cumplirse `despawn_tick`.
- En red viaja en las filas de monstruos; `elite` pasa a ser `flags` (bit 0 élite, bit 1 aliado). El cliente lo pinta con barra verde y sin marcador de enemigo.

Pasos:
- [ ] Tests fallidos: uno por efecto, estado y gancho de las listas (nombre `test_<id>`), más `test_reflect_does_not_loop`, `test_cheat_death_has_cooldown`, `test_guardian_angel_only_allies_in_radius`, `test_summon_follows_and_attacks`, `test_summon_gives_no_xp`, `test_summon_does_not_scale_group_health`, `test_summon_gone_when_owner_dies`, `test_only_one_summon`, `test_enemy_can_target_summon`, `test_status_bits_fit_32`.
- [ ] Implementar. Batería completa verde. Commit `feat(sim): generic effects, hooks and allied summons for class upgrades`.

### Tasks 14–18: Contenido de las mejoras (una tarea por clase)
En cada una: rellenar `data/upgrades/<clase>.json`, añadir las habilidades a `data/abilities/<clase>.json` (todas `level: 50`, `gcd: true` salvo indicación), textos en `textos.csv`, iconos en `make_icons.mjs`, test `tests/unit/sim/test_upgrades_<clase>.gd` con **un test por activa, por pasiva y por evolución** que compruebe su efecto con los números de la tabla, y actualizar la nota de la clase en `docs/GDD/Clases/`. Quitar la clase de la lista de pendientes de `test_upgrades_data.gd`. Commit `feat(classes): <class> level 50 upgrades`.

PA = poder de ataque, PH = poder de hechizos.

**Task 14 — Guerrero**
| Mejora | Elemento | Definición |
|---|---|---|
| `protector` | `warrior_mass_taunt` | 20 ira, 20 s; `taunt` radio 10 m, 6 s; `threat_mult` 3 |
| | `warrior_retaliation` | 25 ira, 30 s; `shield` propio `40 + 2 × PA`, 8 s, `reflect_pct` 0.5 |
| | Postura defensiva | `threat_pct` +1.0, `max_hp_pct` +0.15 |
| | Último bastión | `low_hp_guard` 0.2 / 0.4 / 8 s / 60 s |
| | Evolución | `warrior_shield_wall`: además aplica `damage_reduction` 0.5 durante 6 s a los aliados a 8 m |
| `berserker` | `warrior_frenzy` | 0 ira, 45 s, sin GCD; propio 10 s: `damage_buff` 0.25, `haste` 0.3, `vulnerable` 0.15 |
| | `warrior_execute` | 30 ira, 6 s; `melee_arc` 2,5 m 60°, `20 + 1.5 × PA`, `execute` 0.25 → ×2.5; `refund_on_kill` |
| | Furia sangrienta | `damage_per_missing_hp` 0.25 |
| | Masacre | `on_kill` reinicia `warrior_charge`, cura 0.05 |
| | Evolución | `warrior_slash`: `repeat` 2 veces cada 0,15 s, cada golpe al 70 % del daño |

**Task 15 — Clérigo** (además: pieza vóxel `helm_templar` en `make_pieces.mjs` y `pieces.json`; `look` del Templario cambia el tocado; `HumanRig` usa la animación `melee` para su básico)
| Mejora | Elemento | Definición |
|---|---|---|
| `healer` | `cleric_healing_circle` | 40 maná, 20 s; `area` en el cursor radio 5 m, 5 pulsos cada 1 s, `heal` `8 + 0.5 × PH` |
| | `cleric_divine_hymn` | 60 maná, 60 s; `repeat` canalizado 6 veces cada 1 s: `heal` `allies_around` 15 m, `12 + 0.6 × PH` |
| | Ángel guardián | `guardian_angel` 20 m / 0.25 / 120 s |
| | Gracia mayor | `healing_done_pct` +0.2 |
| | Evolución | `cleric_heal`: `bounce` 1 aliado a 10 m al 50 % |
| `templar` | `cleric_crusader_strike` | 15 maná, 4 s; `melee_arc` 2,5 m 90°, mágico `16 + 1.2 × PH`, `lifesteal_pct` 0.3 |
| | `cleric_consecration` | 35 maná, 18 s; `area` propia radio 5 m, 8 pulsos cada 1 s, mágico `6 + 0.4 × PH` y `heal` `3 + 0.2 × PH` |
| | Armadura de fe | `armor_pct` +0.4, `max_hp_pct` +0.15 |
| | Celo | `melee_hit_restores` 4 |
| | Evolución | `cleric_holy_flash`: efectos = `melee_arc` 2,5 m 100°, mágico, mismo daño ×1,15 |

**Task 16 — Mago** (además: campo `school` en el daño de todos sus hechizos — `arcane`: proyectil y explosión arcana; `fire`: bola de fuego; `frost`: nova y descarga)
| Mejora | Elemento | Definición |
|---|---|---|
| `pyromancer` | `mage_flame_pillar` | 35 maná, 14 s; `area` cursor radio 3 m, 6 pulsos cada 1 s, `8 + 0.5 × PH` fuego, `burn` |
| | `mage_meteor` | 60 maná, 30 s; `area` cursor radio 5 m, retardo 1,5 s con aviso, `50 + 2.5 × PH` fuego, `stun` 1 s |
| | Combustión | `bonus_vs_status` `["burn"]` 0.1 |
| | Fénix | `cheat_death` 0.3 / 180 s |
| | Evolución | `mage_fireball`: `explode.leave` área radio 3 m, 4 pulsos cada 1 s, `4 + 0.25 × PH` |
| `cryomancer` | `mage_blizzard` | 45 maná, 20 s; `area` cursor radio 5 m, 8 pulsos cada 1 s, `6 + 0.4 × PH` escarcha, `slow` 0.4 durante 2 s |
| | `mage_ice_block` | 20 maná, 90 s, sin GCD; propio `ice_block` 4 s y `heal` propio del 30 % de la vida en ese tiempo |
| | Escalofrío | `slow_adds_attack_slow` 0.25 |
| | Corazón helado | `freeze_reduces_cooldowns` 1 s por enemigo congelado, máximo 3 s por lanzamiento |
| | Evolución | `mage_frost_nova`: `at: "cursor"`, alcance 12 m |
| `arcanist` | `mage_arcane_missiles` | 40 maná, 10 s; `repeat` canalizado 5 veces cada 0,3 s: proyectil `8 + 0.6 × PH` arcano hacia el cursor |
| | `mage_arcane_lance` | 50 maná, 16 s; `beam` 18 m × 1,2 m, `35 + 1.8 × PH` arcano |
| | Carga arcana | `stacking_school_damage` arcane 0.04 / 5 / 6 s |
| | Poder puro | `school_crit` arcane +0.15 |
| | Evolución | `mage_arcane_blast`: `delay_s` 0 y radio ×1,4 |

**Task 17 — Arquero** (además: pieza `weapon_crossbow` y proyectil «virote»; `look` del Cazador cambia el arma; monstruo de datos `data/monsters/hunter_wolf.json` con el rig del sabueso sin collar, teñido gris, `summon_only: true` para que el mapa y los tests de bestiario lo excluyan)
| Mejora | Elemento | Definición |
|---|---|---|
| `sharpshooter` | `archer_aimed_shot` | 40 foco, 12 s; `repeat` canalizado 1 vez con `delay_s` 1,5: proyectil 30 m, `40 + 2.5 × PA` |
| | `archer_burst` | 30 foco, 8 s; `repeat` 3 veces cada 0,12 s: proyectil `10 + 0.8 × PA` |
| | Punto débil | `crit_damage_add` +0.3 |
| | Paciencia | `stationary_damage` 1,5 s / 0.15 |
| | Evolución | `archer_shot`: el disparo cargado al ≥ 80 % gana `pierce` 3 |
| `hunter` | `archer_multishot` | 35 foco, 8 s; proyectil `count` 5, `spread_deg` 40, `12 + 0.8 × PA` |
| | `archer_companion` | 30 foco, 60 s; `summon` `hunter_wolf` 30 s |
| | Trampero | `traps_rearm` 1 |
| | Superviviente | `max_hp_pct` +0.1, `move_speed_pct` +0.1 |
| | Evolución | `archer_net`: radio de captura 3 m (todos los enemigos dentro) |

`hunter_wolf` a nivel 1: vida 80, armadura 10, PA 10, velocidad 6, mordisco `6 + 0.8 × PA` cada 1,2 s.

Tests añadidos en esta tarea: `test_reset_upgrade_removes_wolf`, `test_second_summon_replaces_first`, `test_crossbow_piece_on_hunter_look`.

**Task 18 — Asesino**
| Mejora | Elemento | Definición |
|---|---|---|
| `shadow` | `assassin_vanish` | 0 energía, 60 s, sin GCD; `stealth` con `vanish`, 8 s, y `move_speed` +0.3 durante 3 s; usable en combate |
| | `assassin_shadow_strike` | 40 energía, 15 s; `blink` tras el objetivo (12 m) + `melee_arc` `20 + 1.6 × PA` con crítico forzado; `combo_gain` 2 |
| | Asesino nato | `bonus_vs_low_hp` 0.3 / 0.2 |
| | Velo | `stealth_duration_pct` +0.5 |
| | Evolución | `assassin_eviscerate`: `finisher_refund_per_combo` 8 |
| `venomancer` | `assassin_toxic_cloud` | 35 energía, 20 s; `area` cursor radio 4 m, 8 pulsos cada 1 s, aplica 1 acumulación de `poison` |
| | `assassin_contagion` | 25 energía, 25 s; al objetivo: estado `contagion` 10 s; si muere con él, su veneno pasa a los enemigos a 6 m |
| | Toxicología | `poison_max_stacks` 10 |
| | Sangre corrupta | `poisoned_deal_less` 0.1 |
| | Evolución | `assassin_slash`: aplica siempre 1 acumulación de `poison` |

`Contagio` es una activa que marca al objetivo con `contagion`; la regla que reparte el veneno al morir un enemigo marcado es `poison_spreads_on_death` (Task 13), leída del estado y no de una pasiva.

### Task 19: Documentación, versión y publicación
**Archivos:** `project.godot` (`0.6.0`), `README.md`, `docs/GDD/04 Personajes y progresión.md` (§4.3–4.8 a **[Implementado]**), `05 Combate.md`, `09 Interfaz.md` (teclas C y T), `10 Guardado.md`, `15 Decisiones abiertas.md`, `Registro de cambios.md`, notas de las 5 clases, `docs/Decisiones/` (D-012 «Brann como instructor provisional y arena que escala», D-013 «Mejoras del nivel 50 revisadas») e índice, `docs/Planes/Planes.md`, `docs/Sesiones/`.

Pasos:
- [ ] Batería completa verde y arranque sin errores (`test_headless_boot`).
- [ ] Revisión final del código de la rama (un revisor nuevo sobre todo el diff) y corrección de lo que encuentre.
- [ ] Documentación y nota de sesión. Commit `docs: version 0.6.0`.
- [ ] Con el visto bueno del usuario: fusionar en `main`, etiqueta `v0.6.0` y publicación (CI de GitHub Releases).

---
← [[Planes]]
