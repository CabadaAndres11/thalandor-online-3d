---
tags: [plan]
plan: 3
fecha: 2026-11-15
estado: borrador
actualizado: 2026-11-15
---
# Plan 3 — Combate y clases: plan de implementación

> **Ejecución:** nativa en el chat (norma 5), tarea a tarea y con TDD; pasos con casillas `- [ ]`. **Paradas obligatorias:**
> - punto de control de arte en las Tasks 7 y 12;
> - publicación de la 0.3.0 en la Task 8, con permiso del usuario;
> - publicación de la 0.4.0 en la Task 15, con permiso del usuario.

**Objetivo:** combate en tiempo real resuelto por el anfitrión en `sim/`, con:
- habilidades como datos;
- los kits completos de las 5 clases y sus pasivas;
- esquiva y recarga global;
- monstruos con IA, amenaza, élites y un jefe;
- derribo y reaparición;
- HUD y ventana K.

**Arquitectura:**
- `sim/combat/`: estadísticas, daño, estados, efectos, sistema de combate, reglas de clase y pasivas.
- `sim/ai/`: monstruos, caminos con `AStarGrid2D`, IA y aparición.
- `SimWorld`: guarda jugadores y monstruos como `CombatEntity` y produce una lista de **eventos** por tick, que el anfitrión envía.
- `net/`: transporta los botones, la barra y los eventos.
- `game/`: dibuja monstruos, efectos y números.
- `ui/`: el HUD y la ventana K.

**Tecnología:** Godot 4.7.2, GDScript tipado, GUT, `AStarGrid2D` y `RandomNumberGenerator` con semilla, `GPUParticles3D` y `CPUParticles3D` (efectos) y scripts de Node (arte).

**Spec:** [[Plan 3 — Combate y clases (spec)]]

## Restricciones globales
- Siguen en vigor todas las de los Planes 1 y 2:
  - tipos;
  - código y commits en inglés;
  - textos en `textos.csv`;
  - contenido en `data/`;
  - sin scroll a 1280×720;
  - señales conectadas a métodos, no a lambdas que capturan `self`;
  - `Co-Authored-By` en cada commit.
- **Determinismo:** `sim/` no usa nodos, `randf()` global ni el reloj. El azar sale solo de `SimWorld.rng` (`RandomNumberGenerator` con semilla) y el tiempo se cuenta en **ticks** (30 por segundo). Los datos se escriben en segundos y se convierten a ticks al cargar.
- **Ids:** los jugadores usan 1, 2…; los monstruos empiezan en **1000**.
- **Constantes nuevas en `data/balance.json`:**

  | Constante | Valor |
  |---|---|
  | `armor_k` | 60 |
  | `mitigation_cap` | 0.75 |
  | `crit_multiplier` | 1.5 |
  | `damage_variance` | 0.1 |
  | `gcd_s` | 0.5 |
  | `dodge_distance` | 3.0 |
  | `dodge_s` | 0.2 |
  | `dodge_invuln_s` | 0.3 |
  | `dodge_cooldown_s` | 3.0 |
  | `in_combat_s` | 5.0 |
  | `revive_hold_s` | 3.0 |
  | `revive_range` | 2.0 |
  | `revive_hp_pct` | 0.3 |
  | `respawn_s` | 3.0 |
  | `group_hp_scale` | 0.75 |
  | `threat_switch_margin` | 0.1 |
  | `boss_respawn_s` | 180 |
  | `max_monsters_per_snapshot` | 32 |

- **Botones de entrada (bits):** `BTN_BASIC = 1` (pulsado este tick), `BTN_BASIC_HELD = 2`, `BTN_SECONDARY = 4`, `BTN_SLOT1..4 = 8, 16, 32, 64`, `BTN_DODGE = 128`, `BTN_INTERACT_HELD = 256`. Los bits de "pulsado" son **flancos**: el anfitrión nunca los repite cuando reutiliza la última entrada porque falta una.
- **Protocolo 3.** **Versión del juego:** 0.3.0 en la Task 8 y 0.4.0 en la Task 15.
- **Equipos:** `TEAM_PLAYERS` y `TEAM_MONSTERS`. No hay fuego amigo: los efectos dañinos solo alcanzan al equipo contrario y las curaciones y escudos solo al propio.

## Puntos de atención en la revisión
1. **Pulsaciones con pérdida o duplicados:** una pulsación de habilidad llega en varias entradas (redundancia 3), un paquete se pierde o llega dos veces, o al anfitrión le falta una entrada y repite la anterior. La habilidad se lanza **exactamente una vez** → tests en la Task 4.
2. **Usar una habilidad sin poder:** aturdido, congelado, derribado, muerto, sin recurso, en recarga o en recarga global. No pasa nada y **no se gasta recurso** → tests en las Tasks 3 y 9.
3. **El dueño o el objetivo desaparece a mitad de acción:** el objetivo de un proyectil o un aviso muere o se va del grupo, o el lanzador sale del grupo con proyectiles en el aire. Sin errores y sin quedar nada colgado → tests en las Tasks 3 y 14.
4. **Muchas entidades:** 4 jugadores con estados y 30 monstruos. La instantánea cabe en `Protocol.MAX_PACKET_BYTES`, o se limita a los 32 monstruos más cercanos de cada jugador → tests en las Tasks 4 y 12.
5. **Objetivo inalcanzable:** el jugador está rodeado de bloques o fuera del mapa de caminos. El monstruo no se queda girando ni bloquea la simulación: abandona por correa y vuelve a su sitio → test en la Task 5.

---

### Task 0: Preparación
- [ ] Rama `plan-3-combat` y espacio de trabajo y registro (`sdd-workspace`).
- [ ] Copiar a `assets/monsters/pets/` solo `animal-dog.glb`, `animal-fox.glb`, `animal-hog.glb` y `Textures/colormap.png` del zip de Cube Pets que el usuario dejó en Descargas. Añadir su entrada en `CREDITS.md` (Kenney, CC0).
- [ ] Commit `chore: Cube Pets models used by Plan 3 (CC0)`.

### Task 1: Entidades, estadísticas y daño
**Archivos:**
- Crear: `sim/combat/combat_entity.gd`, `sim/combat/combat_stats.gd` y `sim/combat/damage.gd`.
- Modificar: `sim/player_state.gd` (ahora `extends CombatEntity`), `sim/sim_world.gd` (`rng`, `entities()`, `entity(id)`) y `data/balance.json`.
- Test: `tests/unit/sim/test_damage.gd` y `tests/unit/sim/test_combat_entity.gd`.

**Interfaces:**
- `class_name CombatStats extends RefCounted`, con los campos `max_hp`, `max_resource`, `attack_power`, `spell_power`, `armor`, `crit_chance`, `dodge_chance` y `move_speed_mult`, y `static func from_dict(d: Dictionary) -> CombatStats`.
- `class_name CombatEntity extends RefCounted`:
  - `id: int`, `team: int`, `position: Vector3`, `facing: float`, `radius: float` (0.4 jugador), `stats: CombatStats`;
  - `hp: float`, `resource: float`, `resource_kind: String` (`"rage" | "mana" | "focus" | "energy" | ""`), `shield: float`;
  - `life: int` (`ALIVE`, `DOWNED`, `DEAD`), `statuses: Array` (de `StatusEffect`, Task 2);
  - `cooldowns: Dictionary` (id → tick de fin), `gcd_end: int`, `last_combat_tick: int`;
  - `func is_alive() -> bool` y `func can_act(tick: int) -> bool` (vivo, sin aturdir ni congelar).
- `PlayerState` conserva `aim` y `copy_from()` y `clone()`, **que copian solo lo que se predice**: posición, mirada, `facing` y los campos de esquiva de la Task 4.
- `class_name Damage extends RefCounted`:
  - `static func roll(attacker: CombatEntity, target: CombatEntity, spec: Dictionary, world: SimWorld) -> Dictionary`, con `spec = {base, coef, kind: "physical"|"magic", can_crit := true}` y salida `{amount: float, crit: bool, dodged: bool, absorbed: float}`;
  - `static func apply(target: CombatEntity, result: Dictionary, world: SimWorld) -> void` (primero escudo, después vida; vida 0 → `Combat.on_zero_hp`, Task 3).

- [ ] **Paso 1: tests que fallan.**
  - `test_mitigation_formula_and_cap`: con armadura 60 y K 60 → 50 %; con armadura 10 000 → 75 %.
  - `test_crit_multiplies_by_1_5`.
  - `test_variance_within_10_percent_and_seeded`: dos mundos con la misma semilla dan la misma secuencia.
  - `test_magic_ignores_armor`: _decisión del plan:_ la armadura solo reduce el daño físico.
  - `test_shield_absorbs_before_hp`.
  - `test_dodge_chance_avoids_hit`.
  - `test_player_state_clone_copies_only_predicted_fields`.
- [ ] **Paso 2:** ejecutar → FALLA. Implementar. Ejecutar → PASA. La suite completa PASA (el refactor de `PlayerState` no rompe nada).
- [ ] **Paso 3:** commit `feat(sim): combat entities, stats and damage`.

### Task 2: Estados y recursos
**Archivos:** crear `sim/combat/status_effect.gd` y `sim/combat/resources.gd`. Test: `tests/unit/sim/test_status_and_resources.gd`.

**Interfaces:**
- `class_name StatusEffect extends RefCounted`:
  - `kind: String`, uno de `stun`, `root`, `freeze`, `slow`, `poison`, `burn`, `mark`, `damage_buff`, `damage_reduction`, `evasion`, `taunted`, `stealth`, `invulnerable`, `hot`, `shield_tag`;
  - `end_tick: int`, `stacks: int`, `magnitude: float`, `source_id: int`, `tick_every: int`, `next_tick: int`.
- `CombatEntity`:
  - `func add_status(s: StatusEffect, max_stacks: int) -> void` (renueva la duración y suma acumulaciones hasta el máximo);
  - `func has_status(kind: String) -> bool`;
  - `func status_mult(kind: String) -> float`.
- `class_name Resources extends RefCounted`:
  - `static func tick(e: CombatEntity, world: SimWorld) -> void` (regeneración y decaimiento según `resource_kind`, en combate o no);
  - `static func on_damage_dealt(e, amount)` y `static func on_damage_taken(e, amount)`, que generan ira.
- **Valores** en `data/characters/classes.json`, bloque `resource` por clase: `max`, `regen_per_s`, `regen_in_combat_mult`, `decay_per_s`, `gain_per_hit`, `gain_per_damage_taken_pct`.

- [ ] **Paso 1: tests que fallan.**
  - `test_rage_gains_on_hit_and_decays_out_of_combat`.
  - `test_mana_no_regen_in_combat_without_meditation`.
  - `test_focus_regen_slower_while_dodging`.
  - `test_energy_fixed_regen`.
  - `test_status_expires_on_tick`.
  - `test_poison_stacks_to_five_and_ticks_damage`.
  - `test_slow_reduces_move_speed_mult`.
  - `test_stun_and_freeze_block_actions`.
  - `test_root_blocks_movement_not_actions`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(sim): status effects and class resources`.

### Task 3: Habilidades como datos y efectos básicos
**Archivos:**
- Crear: `sim/combat/ability_db.gd`, `sim/combat/combat.gd` (sistema por tick), `sim/combat/effects.gd`, `sim/combat/projectile.gd` y `sim/combat/pending_area.gd`.
- Crear: `data/abilities/_test.json`, con habilidades de prueba que solo cargan los tests.
- Test: `tests/unit/sim/test_effects.gd` y `tests/unit/sim/test_combat_actions.gd`.

**Interfaces:**
- **Formato de habilidad** (JSON):
  - `id`, `class` (o `monster`), `name`, `desc`, `icon`;
  - `kind` (`basic | secondary | active | passive`), `level`;
  - `cost`, `cooldown_s`, `gcd: bool`, `range`, `anim` (`melee | shoot | cast | dash`), `threat_mult` (por defecto 1);
  - `effects: [ {type, ...} ]`.
- **Efectos de esta tarea:**
  - `melee_arc {angle_deg, range, damage}`;
  - `projectile {speed, radius, range, pierce: bool, damage, on_hit: [effects], explode: {radius, damage}?}`;
  - `area {at: "cursor"|"self", radius, delay_s, telegraph: bool, damage?, heal?, statuses?}`;
  - `dash {to: "cursor"|"back"|"behind_target", distance, speed}`;
  - `blink {to: ..., distance}`.

  Los efectos con `damage` aceptan `statuses: [{kind, duration_s, magnitude, stacks}]`.
- `class_name AbilityDB extends RefCounted`:
  - `static func load_default() -> AbilityDB`, que carga `data/abilities/*.json` sin `_test`;
  - `static func load_files(paths: Array) -> AbilityDB`;
  - `func get_ability(id: String) -> Dictionary` y `func class_abilities(class_id: String) -> Array`;
  - `func validate() -> Array[String]`, que devuelve errores legibles (tipo de efecto desconocido, campo que falta, texto sin traducir).
- `class_name Combat extends RefCounted`:
  - `static func try_cast(world: SimWorld, caster: CombatEntity, ability_id: String, aim: Vector3) -> bool` (comprueba vida, `can_act`, recarga, recarga global y coste; gasta y aplica);
  - `static func tick(world: SimWorld) -> void` (proyectiles, áreas pendientes, estados, recursos y muertes);
  - `static func on_zero_hp(world, e)`.
- `SimWorld`:
  - `projectiles: Array`, `pending_areas: Array` y `events: Array` (se vacía al empezar cada tick);
  - `func emit(ev: Array) -> void`.
- **Eventos**, en arrays: `["cast", caster_id, ability_id, aim]`, `["hit", target_id, amount, crit, source_id]`, `["dodge", target_id]`, `["heal", target_id, amount]`, `["status", target_id, kind, end_tick]`, `["projectile", pid, owner_id, ability_id, from, dir, speed, range]`, `["projectile_end", pid, pos]`, `["telegraph", aid, pos, radius, end_tick]`, `["died", id]`, `["downed", id]`, `["revived", id]`, `["respawned", id, pos]` y `["spawned", id, type_id, pos]`.

- [ ] **Paso 1: tests que fallan.**
  - `test_melee_arc_hits_inside_angle_and_range_only`.
  - `test_no_friendly_fire`.
  - `test_projectile_travels_and_hits_first_enemy`.
  - `test_piercing_projectile_hits_all_in_line`.
  - `test_projectile_stops_at_solid_cell`.
  - `test_area_waits_delay_and_emits_telegraph`.
  - `test_dash_moves_toward_cursor_and_stops_at_wall`.
  - `test_blink_behind_target`.
  - **Punto de atención 2:**
    - `test_cast_rejected_on_cooldown_gcd_no_resource_stunned_dead_without_cost`;
    - `test_gcd_does_not_block_basic_secondary_dodge`.
  - **Punto de atención 3:**
    - `test_projectile_whose_owner_left_still_resolves_without_error`;
    - `test_area_target_dead_before_delay_is_fine`.
  - `test_ability_db_validate_reports_unknown_effect`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(sim): data-driven abilities with core effects`.

### Task 4: Botones, esquiva predicha y red de combate
**Archivos:**
- Modificar: `sim/player_input.gd` (`buttons: int`), `sim/movement.gd` (esquiva), `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/input_reader.gd`, `game/input_setup.gd` y `game/game_session.gd`.
- Test: `tests/unit/sim/test_dodge.gd`, más los tests de `protocol`, `host_session` y `client_session`.

**Interfaces:**
- `PlayerInput.buttons: int` (bits de las restricciones globales). `InputReader.read_buttons() -> int` (clic izquierdo y derecho, 1–4, Espacio, E).
- **Esquiva en `Movement.apply`:**
  - si `BTN_DODGE` y la esquiva está lista, empieza un salto de `dodge_distance` en `dodge_s` en la dirección de movimiento (o hacia la mira si estás quieto);
  - da `invulnerable` durante `dodge_invuln_s`;
  - campos en `PlayerState` (predichos): `dash_ticks: int`, `dash_dir: Vector2` y `dodge_ready_tick: int`;
  - el contador de ticks lo da la entrada: `PlayerInput.seq` sirve como reloj local para la recarga.
- **Protocolo 3:**
  - INPUT, filas `[seq, move, aim, buttons]`;
  - fila de jugador en SNAPSHOT: `[id, pos, aim, facing, last_seq, hp, max_hp, resource, max_resource, life, status_bits, dash_ticks, dash_dir, dodge_ready_seq]`;
  - nuevo campo SNAPSHOT `monsters: [[id, type_index, pos, facing, hp, max_hp, flags, target_id]]`;
  - mensaje nuevo `EVENTS [tick, events]` (fiable);
  - HELLO lleva `bar: Array` (4 ids) y hay un mensaje nuevo `SET_BAR [bar]` (fiable).
- **Anfitrión:**
  - por cada entrada **nueva**, traduce sus flancos a `Combat.try_cast` (básico, secundario y casillas según la barra del jugador);
  - al **repetir** la última entrada por falta de una, **borra los flancos** y solo mantiene los botones sostenidos;
  - envía los eventos del tick.
- **Cliente:** guarda la vida, el recurso y los estados propios de la instantánea, interpola los monstruos y emite la señal `combat_event(ev: Array)`.

- [ ] **Paso 1: tests que fallan.**
  - `test_dodge_dash_distance_and_invulnerability`.
  - `test_dodge_cooldown`.
  - `test_dodge_prediction_matches_host`: cliente en memoria con 100 ms.
  - **Punto de atención 1:**
    - `test_press_with_redundancy_casts_once`;
    - `test_lost_packet_press_still_casts_once`;
    - `test_repeated_last_input_does_not_recast`.
  - `test_set_bar_validates_ability_ids_of_class`.
  - `test_events_reach_all_clients_in_order`.
  - **Punto de atención 4:** `test_snapshot_fits_with_4_players_30_monsters`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. La suite completa PASA, incluido `test_two_processes`. Commit `feat(net): combat input, predicted dodge, events and protocol 3`.

### Task 5: Monstruos, caminos e IA básica
**Archivos:**
- Crear: `sim/ai/monster_state.gd`, `sim/ai/monster_db.gd`, `sim/ai/pathfinder.gd`, `sim/ai/monster_ai.gd` y `sim/ai/spawner.gd`.
- Crear: `data/monsters/wolf.json` y `data/monsters/slime.json`.
- Modificar: `data/maps/test_arena.json` (`spawns` y `respawn_point`; escenario de 48×48) y `sim/sim_world.gd`.
- Test: `tests/unit/sim/test_monster_ai.gd`, `test_pathfinder.gd` y `test_spawner.gd`.

**Interfaces:**
- **Formato de monstruo** (JSON):
  - `id`, `name`, `model` (`pets:dog | kenney | vox:slime`);
  - `tint`, `scale`, `radius`, `stats`, `speed`;
  - `aggro_range`, `leash_range`, `attack_range`;
  - `behavior` (`melee | ranged_kite | charger | boss`);
  - `abilities` (ids de `data/abilities/monsters.json`).
- `class_name MonsterState extends CombatEntity`:
  - `type_id: String`, `home: Vector3`, `ai: int` (`IDLE | CHASE | ATTACK | RETURN`), `target_id: int`;
  - `threat: Dictionary`, `path: PackedVector2Array`, `repath_tick: int`, `elite: bool`, `phase: int`.
- `class_name Pathfinder extends RefCounted`:
  - `func _init(map: CollisionMap)` (`AStarGrid2D` con diagonal solo si no corta esquinas);
  - `func path(from: Vector3, to: Vector3) -> PackedVector2Array` (vacío si no hay camino).
- `class_name MonsterAI extends RefCounted`: `static func tick(world: SimWorld, m: MonsterState) -> void`.
  - **Reposo:** si un jugador vivo, no derribado y sin sigilo entra en `aggro_range`, se le suma amenaza y pasa a perseguir.
  - **Persecución:** recalcula el camino cada 0,5 s; el movimiento usa `Movement` con su radio.
  - **Ataque:** dentro de `attack_range`, `Combat.try_cast` de su primera habilidad lista.
  - **Correa:** si se aleja más de `leash_range` de casa, vuelve, se cura del todo y vacía la amenaza.
- `class_name Spawner extends RefCounted`: puntos `{type, count, radius, respawn_s, elite_chance}`.
  - `func tick(world)` crea los monstruos que faltan cuando vence su temporizador.
  - Vida escalada: `1 + group_hp_scale × (jugadores − 1)`.
  - Con `world.on_player_count_changed()` reescala la vida de forma proporcional.

- [ ] **Paso 1: tests que fallan.**
  - `test_path_around_blocks`.
  - `test_no_path_returns_empty`.
  - `test_idle_until_player_in_range`.
  - `test_ignores_stealthed_and_downed_players`.
  - `test_chases_and_attacks_in_range`.
  - **Punto de atención 5:**
    - `test_unreachable_target_leashes_home_and_heals`;
    - `test_sim_tick_time_bounded_with_30_monsters` (menos de 5 ms por tick en el PC de desarrollo; se apunta, no es un requisito estricto).
  - `test_spawner_respawns_after_timer`.
  - `test_group_scaling_at_spawn_and_rescale_on_join_leave`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(sim): monsters with pathfinding, AI and spawner`.

### Task 6: Kits de nivel 1 y reglas de clase básicas
**Archivos:**
- Crear: `data/abilities/warrior.json`, `cleric.json`, `mage.json`, `archer.json`, `assassin.json` y `monsters.json`, con lo de nivel 1 y los ataques del lobo y el limo.
- Crear: `sim/combat/class_rules.gd`.
- Modificar: `data/characters/classes.json` (`stats` y `resource`) y `data/texts/textos.csv`.
- Test: `tests/unit/sim/test_class_kits_level1.gd`.

**Valores iniciales** (se ajustan tras jugar):

| Clase | CI | CD | Nivel 1 |
|---|---|---|---|
| Guerrero (vida 200, ira 100, armadura 40) | **Tajo**: arco de 120° y 2,5 m, 10 + 0,6 AP, +8 ira | **Golpe brutal**: 30 ira, objetivo a 2,5 m, 28 + 1,2 AP, recarga 4 s | **Carga**: dash de 8 m hacia el cursor, aturde 1 s al chocar; recarga 12 s |
| Clérigo (vida 150, maná 150) | **Destello sagrado**: proyectil de 20 m, 9 + 0,6 SP | **Sanar**: 20 maná, cura 25 + 1,0 SP al aliado bajo el cursor o a sí mismo; recarga 1,5 s | **Palabra de escudo**: 30 maná, escudo de 40 + 1,0 SP durante 8 s sobre el aliado bajo el cursor o sí mismo; recarga 10 s |
| Mago (vida 130, maná 160) | **Proyectil arcano**: proyectil de 22 m, 10 + 0,7 SP | **Explosión arcana**: 25 maná, área de 2,5 m en el cursor con 0,6 s de retardo, 26 + 1,1 SP; recarga 5 s | **Parpadeo**: 15 maná, blink de 8 m hacia el cursor; recarga 10 s |
| Arquero (vida 150, concentración 100) | **Disparo**: sin cargar, proyectil de 20 m con 9 + 0,6 AP y gratis; cargado hasta 1,5 s, ×2,2 de daño y ×1,5 de alcance, gasta 15 de concentración | **Disparo perforante**: 25 de concentración, atraviesa, 18 + 0,9 AP; recarga 6 s | **Voltereta**: dash de 5 m hacia atrás y flecha al cursor; recarga 8 s |
| Asesino (vida 160, energía 100) | **Cuchillada**: arco de 90° y 2 m, 9 + 0,5 AP, +1 combo | **Eviscerar**: 35 energía, objetivo a 2 m, (12 + 0,4 AP) × combos; los gasta | **Paso sombrío**: 20 energía, blink a la espalda del objetivo bajo el cursor (12 m); recarga 12 s |

Valores comunes:
- `attack_power` y `spell_power` son 20 en todas las clases.
- El crítico es del 5 %.
- La esquiva es del 5 % para el arquero y el asesino y del 0 % para el resto.

**Reglas de clase en esta tarea:**
- `ClassRules.on_hit(world, caster, target, ability)`: ira y combos.
- `ClassRules.charge_shot(...)`: carga del arquero con `BTN_BASIC_HELD`. El anfitrión cuenta los ticks que se mantiene el botón y dispara al soltarlo.
- `ClassRules.ally_under_cursor(world, caster, aim, radius := 1.0) -> CombatEntity`: clérigo.
- **Monstruos:** lobo (mordisco: arco de 60° y 1,6 m, 8 de daño, recarga 1,2 s) y limo (golpe en área propia de 1,8 m, 14 de daño, recarga 2 s; lento).

- [ ] **Paso 1: tests que fallan.**
  - Por cada clase, `test_<clase>_basic_secondary_level1`, con daño, coste, recurso generado o gastado, recarga y objetivo correctos.
  - `test_archer_charged_shot_costs_focus_and_scales`.
  - `test_eviscerate_scales_with_combo_and_resets`.
  - `test_heal_targets_ally_under_cursor_else_self`.
  - `test_all_ability_files_validate`: `AbilityDB.validate()` vacío y textos traducidos.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(combat): level 1 kits of the five classes`.

### Task 7: Monstruos y efectos en pantalla (punto de control de arte)
**Archivos:**
- Crear: `game/monster_avatar.gd`, `game/combat_fx.gd`, `game/floating_numbers.gd` y `game/overhead_bar.gd`.
- Crear con `tools/art/`: `assets/monsters/` (lobo recoloreado, limo `.vox`).
- Modificar: `game/player_avatar.gd` (animaciones de acción: `play_action(anim)`) y `game/game_session.gd` (monstruos y efectos a partir de `client.combat_event`).
- Test: `tests/unit/game/test_monster_avatar.gd` y `test_combat_fx.gd`.

**Interfaces:**
- `MonsterAvatar.setup(type: Dictionary)` y `apply_state(row: Dictionary, delta: float)`.
- `play_attack()`: Cube Pets hace una embestida por código (`Tween`, 0,25 s); el modelo de Kenney usa `attack-melee-right`.
- `play_death()`: vuelco y desaparición en 1 s.
- `CombatFX.handle(ev: Array)`: proyectil visual (se mueve solo a partir de `from`, `dir`, `speed` y `range`; se borra con `projectile_end`), destello de arco, aviso en el suelo (disco que se llena hasta `end_tick`), burbuja de escudo y número flotante.
- `OverheadBar`: nombre y vida encima de cada uno. En los monstruos solo se ve si están heridos o en combate.

- [ ] **Paso 1: tests que fallan.**
  - `test_monster_avatar_builds_each_model`.
  - `test_fx_projectile_removed_on_end`.
  - `test_telegraph_fills_and_frees`.
  - `test_damage_number_colors` (normal, crítico, curación, esquiva).
  - `test_overhead_bar_hidden_when_full_out_of_combat`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA.
- [ ] **Paso 3: PUNTO DE CONTROL DE ARTE.**
  - Capturas con `tests/helpers/render_characters.gd`, set nuevo `monsters_a`: lobo, limo, el lobo atacando y un aviso en el suelo.
  - Se envían al usuario y **se espera su visto bueno**.
- [ ] **Paso 4:** commit `feat(game): monster avatars, combat effects and overhead bars`.

### Task 8: HUD básico, muerte en solitario y 0.3.0
**Archivos:**
- Crear: `ui/combat_hud.gd` (vida y recurso, barra de habilidades, combos y carga).
- Modificar: `sim/combat/combat.gd` (muerte en solitario: reaparece a los `respawn_s` en `respawn_point` con vida completa; los monstruos que lo perseguían vuelven a casa), `game/main.gd`, `data/texts/textos.csv` y `project.godot` (0.3.0).
- Crear: `tools/art/make_icons.mjs` → `assets/icons/<ability>.png` (64 px, forma y color de la clase y símbolo).
- Test: `tests/unit/ui/test_combat_hud.gd` y `tests/unit/sim/test_death.gd`. Se amplía la prueba de 1280×720.

**Interfaces:** `CombatHud.bind(client: ClientSession, bar: Array, abilities: AbilityDB)`. En cada fotograma:
- vida y recurso, con número;
- las casillas CI, CD, 1–4 y Espacio con su icono, tecla, barrido de recarga (a partir de los eventos `cast`), recarga global y casilla atenuada si no llega el recurso;
- combos del asesino y carga del arquero.

- [ ] **Paso 1: tests que fallan.**
  - `test_hud_shows_hp_resource`.
  - `test_slot_dims_without_resource`.
  - `test_cooldown_sweep_from_cast_event`.
  - `test_solo_death_respawns_after_3s_full_hp`.
  - `test_monsters_return_home_after_target_died`.
  - `test_all_ui_fits_1280x720`, ahora con el HUD.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Se arranca el juego con `run_project`, sin errores en la consola.
- [ ] **Paso 3:** revisión intermedia de la rama con `requesting-code-review`. Se corrige lo crítico y lo importante.
- [ ] **Paso 4: PUBLICACIÓN 0.3.0,** con permiso del usuario. Se junta la rama con `main`, se sube y se etiqueta `v0.3.0`. Notas: "combate básico: kit de nivel 1, lobos y limos". Se resume al usuario qué probar. El trabajo continúa en la rama `plan-3-combat-b`.

### Task 9: Resto de efectos y ganchos de pasivas
**Archivos:**
- Modificar: `sim/combat/effects.gd`, con los efectos `heal` (directa y `hot`), `shield`, `status` (todos los tipos), `trap {radius, arm_s, lifetime_s, damage, statuses}`, `stealth`, `cleanse`, `revive {range}` y `taunt`.
- Crear: `sim/combat/passives.gd`.
- Modificar: `game/combat_fx.gd` y `game/player_avatar.gd`, para el icono de estado encima de la cabeza (aturdido, congelado, envenenado, inmovilizado, marcado…) y el personaje translúcido mientras está en sigilo.
- Test: `tests/unit/sim/test_effects_more.gd`, `test_passives.gd` y `tests/unit/game/test_status_visuals.gd` (`test_status_icon_shown_and_cleared` y `test_stealth_makes_avatar_translucent`).

**Interfaces:**
- **Formato de pasiva:** `{"type": "stat", "stat": "armor_pct", "value": 0.10}` o `{"type": "hook", "hook": "<nombre>", ...params}`.
- **Ganchos:**
  - `rage_decay_mult`, `block_generates_rage`, `on_crit_heal_pct`;
  - `mana_regen_in_combat`, `healing_received_pct`, `healing_done_pct`, `heal_leaves_hot`;
  - `spell_power_after_no_damage_s`, `fire_crit_burn`, `bonus_vs_status`;
  - `range_pct`, `bonus_vs_far`, `every_nth_basic_crits`;
  - `back_damage_pct`, `stealth_opener_crit_bonus`, `after_dodge_combo`.
- `Passives.stat_mods(e) -> Dictionary` y `Passives.has_hook(e, name) -> Dictionary` (parámetros, o `{}`).

- [ ] **Paso 1: tests que fallan.**
  - Un test por efecto nuevo:
    - `test_trap_arms_and_triggers_once`;
    - `test_stealth_breaks_on_attack_and_damage`;
    - `test_cleanse_removes_only_negative`;
    - `test_hot_ticks`;
    - `test_taunt_forces_target`;
    - `test_revive_far_ally`.
  - Un test por gancho, por ejemplo `test_hook_on_crit_heal_pct`.
  - **Punto de atención 2:** `test_stealth_cast_rejected_when_in_combat_unless_vanish`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(sim): remaining effects and passive hooks`.

### Task 10: Kits completos
**Archivos:** completar `data/abilities/<clase>.json` con las activas de los niveles 3–20 y las 4 pasivas de cada clase (GDD), y `textos.csv`. Test: `tests/unit/sim/test_class_kits_full.gd`.

**Valores iniciales:**
- Recargas de 8 a 20 s para las activas de nivel 3–10 y de 25 a 60 s para las de nivel 20 (*Resurrección*: 60 s).
- Duraciones de los estados según el GDD (Red 3 s, Nova de escarcha 2 s, Muro de escudo 6 s, Veneno 30 s, Evasión 5 s, Grito de guerra 8 s).
- Costes entre el 15 % y el 35 % del recurso máximo.

Cada habilidad del GDD es una combinación de efectos. Por ejemplo:
- *Lluvia de flechas* = `area` en el cursor de 3 m, 0,4 s de retardo y 3 pulsos;
- *Torbellino* = `area` en uno mismo de 3 m;
- *Bola de fuego* = `projectile` con `explode` de 2,5 m.

- [ ] **Paso 1: tests que fallan.**
  - `test_every_class_has_7_actives_4_passives`.
  - Para cada habilidad nueva, un test de su efecto principal, agrupados por clase:
    - `test_warrior_full_kit`;
    - `test_cleric_full_kit`;
    - `test_mage_full_kit`;
    - `test_archer_full_kit`;
    - `test_assassin_full_kit`.
  - `test_all_ability_files_validate`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(combat): full class kits and passives`.

### Task 11: Ventana K y barra guardada
**Archivos:**
- Crear: `ui/abilities_window.gd`.
- Modificar: `save/character_data.gd` (VERSION 2: `bar: Array`; migración v1 → v2 con la barra por defecto), `game/main.gd` (K abre y cierra; `SET_BAR` al cambiar), `game/input_setup.gd` (`abilities_window`: K) y `textos.csv`.
- Test: `tests/unit/ui/test_abilities_window.gd`, más los tests de `character_data` y `main_flow`.

**Interfaces:**
- `AbilitiesWindow.show_for(class_id: String, bar: Array, abilities: AbilityDB)`, con la señal `bar_changed(bar: Array)`.
- Se hace clic en una activa y luego en una casilla 1–4. Si la habilidad ya estaba en otra casilla, se intercambian.

- [ ] **Paso 1: tests que fallan.**
  - `test_migrates_v1_to_v2_with_default_bar`.
  - `test_bar_sanitized_to_class_abilities`.
  - `test_assign_and_swap_slots`.
  - `test_window_fits_1280x720`.
  - `test_bar_change_sends_set_bar_and_saves`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Commit `feat(ui): abilities window and saved ability bar`.

### Task 12: Resto de monstruos y élites (punto de control de arte)
**Archivos:**
- Crear: `data/monsters/boar.json`, `goblin.json` y `skeleton_archer.json`, y sus habilidades en `monsters.json`.
- Modificar: `sim/ai/monster_ai.gd`, con los comportamientos `charger` (avisa en línea y carga 8 m) y `ranged_kite` (se aleja si estás a menos de 5 m).
- Arte: pieles de goblin y esqueleto, y piezas de orejas, cuchillo y arco (`tools/art/`); jabalí recoloreado; aura de élite.
- Test: `tests/unit/sim/test_monster_behaviors.gd`.

**Élite:** ×1,3 de tamaño, ×2,5 de vida, ×1,4 de daño y un aura. `elite_chance` va en cada punto de aparición.

- [ ] **Paso 1: tests que fallan.**
  - `test_boar_telegraphs_then_charges_line`.
  - `test_skeleton_keeps_distance_and_shoots`.
  - `test_goblins_pack_share_aggro`.
  - `test_elite_modifiers`.
  - **Punto de atención 4:** `test_snapshot_limits_to_nearest_32_monsters`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA.
- [ ] **Paso 3: PUNTO DE CONTROL DE ARTE.** Set `monsters_b` (jabalí, goblin, esqueleto y un élite). **Se espera el visto bueno.**
- [ ] **Paso 4:** commit `feat(combat): boar, goblin, skeleton archer and elites`.

### Task 13: El jefe, Rey orco
**Archivos:**
- Crear: `data/monsters/orc_king.json` y sus habilidades.
- Modificar: `sim/ai/monster_ai.gd` (comportamiento `boss`: fases al 66 % y al 33 %).
- Modificar: `ui/combat_hud.gd` (barra de jefe con su fase) y `textos.csv` (aviso en el chat "¡El Rey orco ha caído!").
- Test: `tests/unit/sim/test_boss.gd`.

**Fases:**
1. Golpe en arco.
2. Además, salto a un jugador con área de 4 m avisada 1,2 s.
3. Además, cada 20 s llama a 3 goblins.

Reaparece a los `boss_respawn_s`.

- [ ] **Paso 1: tests que fallan.**
  - `test_boss_phases_by_hp`.
  - `test_boss_jump_telegraph_then_damage`.
  - `test_boss_summons_goblins`.
  - `test_boss_death_announced_and_respawns`.
  - `test_boss_bar_shows_name_and_phase`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. Arte del jefe (piel de orco, armadura y hacha vóxel) en la misma captura. Commit `feat(combat): orc king boss`.

### Task 14: Amenaza completa, derribo y grupo
**Archivos:**
- Modificar: `sim/ai/monster_ai.gd` y `sim/combat/combat.gd`.
- Crear: `ui/party_frames.gd` y `ui/downed_overlay.gd`.
- Modificar: `game/game_session.gd` (E sostenida y barra de levantar).
- Test: `tests/unit/sim/test_threat.gd` y `test_downed.gd`, y `tests/integration/test_combat_group.gd` (tres clientes en memoria).

**Reglas:**
- **Amenaza:**
  - el daño suma su valor × `threat_mult`;
  - la curación suma la mitad del valor en todos los monstruos que persiguen al curado;
  - provocar fuerza el objetivo y le da la amenaza máxima + 10 %;
  - el monstruo cambia de objetivo solo si otro supera al actual en más de `threat_switch_margin`.
- **Derribo:** en grupo, si queda algún aliado en pie, vida 0 → `DOWNED`. Mantener E a menos de `revive_range` durante `revive_hold_s` lo levanta con `revive_hp_pct`; si el que levanta se mueve, recibe daño o suelta, se cancela. Si todos están derribados o muertos, reaparecen todos.
- **Al irse un jugador:** se quita de las tablas de amenaza, sus proyectiles se resuelven sin dueño y se reescala la vida de los monstruos.

- [ ] **Paso 1: tests que fallan.**
  - `test_highest_threat_targeted_with_margin`.
  - `test_heal_threat_split`.
  - `test_taunt_overrides`.
  - `test_downed_in_group_revived_with_e`.
  - `test_revive_cancels_on_move_or_damage`.
  - `test_all_down_respawn_all`.
  - **Punto de atención 3:** `test_player_leaving_mid_fight_cleans_threat_and_projectiles`.
  - `test_party_frames_show_downed`.
  - `test_combat_group_three_clients_see_same_hp`.
- [ ] **Paso 2:** ejecutar → FALLA, implementar y ejecutar → PASA. La suite completa PASA. Commit `feat(combat): threat, downed and revive, party frames`.

### Task 15: Cierre y 0.4.0
- [ ] `project.godot` pasa a 0.4.0 y se actualizan las notas de la versión: clases completas, ventana K, monstruos y jefe, derribo, y la tabla de controles.
- [ ] `CREDITS.md` completo.
- [ ] Suite en local y en CI → PASA. Se arranca el juego con `run_project`, sin errores. Capturas del HUD en combate.
- [ ] Revisión final de la rama (`requesting-code-review`, revisor en el modelo más capaz) y corrección de lo crítico y lo importante, con su test.
- [ ] Documentación:
  - GDD §3.2, §4.1–4.3, §5 y §9.2 → [Implementado];
  - notas de cada clase con sus valores iniciales;
  - `Registro de cambios`, `Planes.md` y este plan → hecho;
  - nota de sesión.
- [ ] **Con permiso del usuario:** juntar con `main`, subir, etiqueta `v0.4.0` y comprobar la Release.
- [ ] Resumen al usuario: qué se hizo, qué falta y qué probar.

---
← [[Planes]]
