---
tags: [plan]
plan: 5
fecha: 2026-11-19
estado: borrador
actualizado: 2026-11-19
---
# Plan 5 — Objetos: plan de implementación

Spec: [[Plan 5 — Objetos (spec)]]. Rama `claude/plan-desarrollo-d1cd1b`. Versión de salida **0.7.0**, protocolo **7**, personajes versión **4**.

**Objetivo:** botín personal, inventario, 11 ranuras de equipo visibles, familias de arma, pociones, durabilidad y mercader provisional, todo guardado con el personaje.

**Arquitectura:**
- Reglas nuevas en `sim/items/` (portadas de `D:\RPG\src\sim\items`), sin nodos ni red. El inventario de un jugador es un objeto `Inventory` colgado de `PlayerState`, como `PlayerProgress`.
- `Progression.rebuild` suma el equipo (atributos y modificadores) a las estadísticas; nada más calcula estadísticas.
- El anfitrión valida cada petición (`ItemRequests`) y devuelve `INVENTORY` al dueño, que lo guarda en su `CharacterData`. El aspecto (ids de base de las 8 ranuras visibles) viaja a todos con `PLAYER_GEAR`.
- Contenido en `data/items/`: `bases.json`, `affixes.json`, `loot.json`, `weapons.json`. Modelos en `tools/art/make_gear.mjs` → `assets/items/vox/` y `data/items/gear_pieces.json`.

**Tests:** `"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json` (un archivo: `-gtest=res://tests/...`). Pasa = `---- All tests passed! ----` y código 0. `$GODOT` = build de consola 4.7.2.

## Restricciones globales
- Todo número de botín, precio, poción y durabilidad vive en `data/items/loot.json`; todo objeto, propiedad y familia en `data/items/`. Añadir un objeto no toca `sim/`.
- Textos del juego en `data/texts/textos.csv` (español); código, ids y commits en inglés.
- Ninguna ventana con scroll a 1280×720: cada ventana nueva lleva su test `panel_rect()` dentro de 1280×720.
- El anfitrión nunca aplica un cambio de inventario sin validarlo; un cliente nunca recibe el `INVENTORY` ni el botín de otro.
- Ninguna migración borra ni rebaja un personaje u objeto.
- Aleatoriedad de juego solo con `world.rng`. **Excepción:** los ids de objeto (`ItemRoll.new_uid`) usan un `RandomNumberGenerator` aleatorizado propio, para que no se repitan entre sesiones.
- Tiempos en segundos en los datos y en ticks en la simulación.
- Un commit por tarea, con el mensaje indicado.

## Lo que más puede fallar (cubierto en las tareas indicadas)
1. **Un `HELLO` con inventario imposible** (bases que no existen, nivel o rareza inválidos, uid repetido, más de 30 casillas, un arma a dos manos con secundaria, equipo de otra clase, oro negativo) → se sanea (lo inválido se descarta, lo que no se puede llevar va al inventario, lo que no cabe se conserva en casillas extra) y el jugador entra (Tasks 3 y 9).
2. **Equipar un arma a dos manos con la secundaria ocupada e inventario lleno** → se rechaza sin perder nada (Task 3).
3. **Morir varias veces seguidas** → la durabilidad baja hasta 0 y no pasa a negativo; a 0 la pieza no da estadísticas ni bloqueo (Tasks 4 y 6).
4. **Recoger botín con el inventario lleno, o que se acabe el tiempo** → el objeto sigue en el suelo hasta los 2 min y luego desaparece solo para su dueño; nunca se duplica (Task 7).
5. **Un personaje de la 0.6** (versión 3) con clase → entra con el equipo inicial de su clase; un aldeano, con la espada de madera (Task 9).

---

> **Cambio durante la ejecución (2026-11-19):** la armadura pasa a ser **un juego por clase y tramo, exclusivo de su clase** (`<clase>_<ranura>_t<n>`, con `class` en la base); `ItemDB.can_use` ya no usa el orden de armaduras. Por tramo hay 30 piezas de armadura y 17 armas o secundarias.

## Fase A — Reglas de objetos (`sim/items/`)

### Task 1: Datos y `ItemDB`
**Archivos:** crear `sim/items/item_db.gd`, `data/items/{bases,affixes,loot,weapons}.json`; tests `tests/unit/sim/test_item_db.gd`, `tests/unit/data/test_items_data.gd`.

**Datos:**
- `loot.json` (copia del prototipo con estos valores): `gold {chance 0.9, base 2, exponent 1.3, variance 0.2, elite_mult 4}`; `items {normal_chance 0.12, elite_guaranteed 1, elite_extra_chance 0.4, boss_guaranteed 2, usable_share 0.75, unique_chance 0.25}`; `rarity.normal {common 0.55, uncommon 0.3, rare 0.12, epic 0.03}`, `rarity.elite` (también jefes) `{0.25, 0.45, 0.22, 0.08}`; `affix_count {common 0, uncommon 1, rare 2, epic 3, legendary 4, unique 0}`; `affix_roll {min 0.6, max 1.0}`; `potion_chance 0.06`; `value {base 3, exponent 1.4, rarity_mult {common 1, uncommon 2, rare 4, epic 8, legendary 16, unique 16}}`; `sell_factor 0.25`; `repair_factor 0.2`; `inventory_size 30`; `durability_loss_on_death 10`; `durability_warn 25`; `potion {heal_pct 0.35, resource_pct 0.35, cooldown_s 30, stack 20, price_base 5, price_per_level 2}`; `pickup_radius 1.0`; `loot_ttl_s 120`; `loot_scatter 1.5`; `merchant {stock_commons 4, restock_s 600}`; `two_hand_mult 1.8`.
- `affixes.json`: las del prototipo con los nombres del 3D (`strength`, `agility`, `intellect`, `stamina`, `spirit`, `armor_add`, `attack_power_add`, `spell_power_add`, `crit_add`, `crit_damage_add`, `dodge_add`, `block_add` (solo `offhand`, `chest`, `shoulders`), `cooldown_reduction_add` (`neck`, `ring`, `hands`, `head`), `lifesteal_add` (`main`, `neck`, `ring`), `move_speed_pct` (`feet`), `max_hp_pct`, …), cada una `{stat, mode, base, per_level, slots?, name}`.
- `weapons.json`: `families` (ver Task 11), `weapon_types` (tipo → `{family, hands: 1|2, slots: ["main"]|["offhand"]|["main","offhand"]}`), `classes` (clase → `{armor: [...], weapons: [...], offhand: [...]}` según la tabla del spec §4; `villager → {armor: [], weapons: ["wood_sword"], offhand: []}`), `starter` (clase → lista de ids de base, nivel 1 común).
- `bases.json`: `{"<id>": {slot, kind, tier, min_level, max_level, look: [piece ids], name, stats: [{stat, base?, per_level}], unique_of?: "<monster id>"}}`. Ranuras: `main, offhand, head, shoulders, chest, hands, legs, feet, neck, ring`. Los tramos: `t1 1–19, t2 20–39, t3 40–9999`. Esta tarea mete las bases del **tramo 1** (24 armaduras, 18 armas/secundarias, collares y anillos, la espada de madera del aldeano, las dos pociones con `slot: "consumable"`) con `look: []`; Task 13 les pone modelo.

**Produce** `class_name ItemDB`:
- `static load_default() -> ItemDB`; `base(id) -> Dictionary`; `affix(id) -> Dictionary`; `loot() -> Dictionary`; `family_of(base_id) -> Dictionary` (vacío si no es arma); `hands(base_id) -> int`.
- `can_use(class_id, base_id) -> bool` — armadura: su tipo o uno inferior en `["cloth","leather","mail","plate"]` hasta el máximo de la clase; armas y secundaria según `classes`; cuello, anillo y consumibles: todos.
- `bases_for(level, class_id := "", slot := "") -> Array[String]` — tramo que contiene `level`, sin consumibles, únicos ni `villager`.
- `validate() -> Array[String]` — errores: ranura o tipo desconocido, estadística desconocida, texto sin traducir, tipo de arma sin familia, base que ninguna clase puede usar.

Pasos:
- [ ] Tests fallidos: `test_can_use` (guerrero → placas y tela sí; mago → placas no; arquero → malla sí, placas no; asesino → malla no; clérigo → varita, cetro, tomo sí; mago → cetro no), `test_bases_for_tier` (nivel 19 → solo t1; 20 → solo t2 cuando existan; 500 → t3), `test_two_hand` (`hands("greatsword_t1") == 2`), `test_items_data` (`validate()` vacío).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): item data and ItemDB`.

### Task 2: Objetos y tiradas
**Archivos:** crear `sim/items/item.gd`, `sim/items/item_roll.gd`; test `tests/unit/sim/test_item_roll.gd`.

**Produce:**
- `class_name Item`: `uid: String`, `base_id: String`, `level: int`, `rarity: String`, `affixes: Array` (`{id, value}`), `durability: int = 100`, `count: int = 1`. `to_dict()`; `static from_dict(v: Variant, db: ItemDB) -> Item` (null si la base no existe; nivel a `1..65535`, rareza desconocida → `common`, propiedades desconocidas o repetidas fuera, durabilidad a `0..100`, `count` a `1..stack`).
- `ItemRoll` (static): `new_uid() -> String`; `roll_rarity(tier: String, rng) -> String` (`tier` = `"normal"` o `"elite"`); `roll_gear(base_id, level, rarity, rng, db) -> Item`; `stat_value(stat_def, level, two_hand: bool) -> float` (`(base + per_level × nivel) × (two_hand_mult si dos manos)`); `value(item, db) -> int` (`round(3 × nivel^1,4 × rarity_mult)`, consumibles 0); `roll_loot(class_id, monster_level, kind: String, rng, db) -> Dictionary` (`kind` `normal|elite|boss`; devuelve `{gold: int, items: Array[Item]}` con las reglas del spec §2; el Guerrero solo recibe pociones de vida); `unique_for(monster_id, db) -> String`.

Pasos:
- [ ] Tests fallidos: `test_affixes_unique_and_in_range` (épico de nivel 30: 3 propiedades de estadísticas distintas, cada valor entre 60 % y 100 % del máximo), `test_rarity_table` (10 000 tiradas normales: común 55 % ± 2), `test_loot_counts` (élite: siempre ≥ 1 objeto; jefe: ≥ 2), `test_usable_share` (10 000 objetos para el mago: 75 % ± 2 usables), `test_rage_no_resource_potion`, `test_gold_formula` (nivel 10 normal, sin varianza: `round(2 × 10^1,3)` = 40), `test_value` (común nivel 1 = 3; raro nivel 10 = `round(3 × 10^1,4 × 4)`), `test_from_dict_garbage` (base inexistente → null; `durability: -5` → 0; propiedad repetida → fuera), `test_uid_unique` (1000 uids distintos).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): items, loot and affix rolls`.

### Task 3: Inventario y equipo
**Archivos:** crear `sim/items/inventory.gd`; modificar `sim/player_state.gd` (`var inventory := Inventory.new()`, `var inventory_dirty := false`, `var potion_ready_tick := 0`); test `tests/unit/sim/test_inventory.gd`.

**Produce** `class_name Inventory`:
- `const SLOTS := ["main","offhand","head","shoulders","chest","hands","legs","feet","neck","ring_1","ring_2"]`; `const VISIBLE := ["main","offhand","head","shoulders","chest","hands","legs","feet"]`.
- `gold: int`, `bag: Array` (30 entradas `Item` o `null`, más casillas extra al final si hace falta al sanear), `equipment: Dictionary` (ranura → `Item`).
- `add(item: Item, db) -> bool` — apila consumibles iguales hasta `stack`, si no, primera casilla libre; `false` si no cabe.
- `equip(index: int, class_id: String, level: int, db, ring_slot := "") -> bool` — comprueba clase y nivel; dos manos libera `offhand` (falla si no cabe en el inventario); una secundaria con un arma a dos manos puesta la quita; anillos a `ring_1` o el libre o el indicado.
- `unequip(slot: String, db) -> bool`; `take(index: int) -> Item`; `visible_bases() -> Array` (8 ids o `""`).
- `to_dict()`; `static from_dict(v, class_id, level, db) -> Inventory` — saneado del spec y del punto 1 de *Lo que más puede fallar*; uid repetido → se le da uno nuevo.

Pasos:
- [ ] Tests fallidos: `test_stack_potions` (25 → 20 + 5), `test_full_bag`, `test_equip_rules` (clase, nivel), `test_two_hand_frees_offhand`, `test_two_hand_full_bag_refused` (nada cambia), `test_offhand_removes_two_hand`, `test_rings`, `test_sanitize` (los casos del punto 1).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): inventory and equipment`.

### Task 4: Estadísticas del equipo y bloqueo con escudo
**Archivos:** crear `sim/items/gear_stats.gd`; modificar `sim/progression/progression.gd`, `sim/progression/attributes.gd` (`totals` suma los atributos del equipo), `FLAT` (+ `attack_power_add`, `spell_power_add`, `max_resource_add`); tests `tests/unit/sim/test_gear_stats.gd`, ajustar tests de bloqueo del Guerrero (`test_passives.gd`, `test_upgrades_warrior.gd`) equipándole un escudo.

**Produce** `GearStats` (static): `attributes(inv, db) -> Dictionary`; `mods(inv, db) -> Array` (entradas `{type: "stat", stat, value}` de estadísticas fijas y propiedades; los `mode: "pct"` como `<stat>`); `has_shield(inv, db) -> bool`; `family(inv, db) -> String` (familia del arma principal; `""` sin arma). Las piezas con `durability == 0` no cuentan para nada.

`Progression.rebuild`: suma `GearStats.attributes` a los totales y añade `GearStats.mods` a `modifiers()`. Tras los topes: si `p.class_id != ""` y no `has_shield` → `block_chance = 0`.

Pasos:
- [ ] Tests fallidos: `test_gear_adds_stats` (pecho de placas sube armadura; +12 fuerza sube poder de ataque), `test_broken_gear_ignored`, `test_block_needs_shield`, `test_rebuild_keeps_ratio` (equipar en combate conserva el % de vida).
- [ ] GUT → fallan. Implementar. GUT verde (toda la batería).
- [ ] Commit `feat(items): gear stats and shield-only block`.

### Task 5: Peticiones de objetos y pociones
**Archivos:** crear `sim/items/item_requests.gd`; test `tests/unit/sim/test_item_requests.gd`.

**Produce** `ItemRequests` (static; cada uno devuelve `bool`; si acepta: `Progression.rebuild` cuando cambia el equipo y `p.inventory_dirty = true`):
- `equip(world, p, index, ring_slot := "")`, `unequip(world, p, slot)` — vivo (no derribado ni muerto).
- `use(world, p, index)` — consumible: vida o recurso según la base; recarga compartida `potion_ready_tick`; el Guerrero no bebe de recurso; no se usa a vida o recurso llenos. Emite `["potion", p.id, kind]`.
- `use_potion(world, p, kind: String)` — la primera pila de ese tipo (teclas Q y R).
- `on_death(world, p)` — resta `durability_loss_on_death` a cada pieza equipada (mínimo 0), reconstruye, marca sucio.

Pasos:
- [ ] Tests fallidos: `test_potion_heals_35`, `test_potion_shared_cooldown` (vida y luego recurso antes de 30 s → rechazada), `test_rage_no_resource_potion`, `test_dead_cannot_equip`, `test_death_durability` (dos muertes → 80; once muertes → 0, no negativo).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): equip, potions and durability requests`.

### Task 6: Durabilidad al morir (no derribado)
**Archivos:** modificar `sim/combat/combat.gd` (`_die` llama a `ItemRequests.on_death`); test en `tests/unit/sim/test_death.gd` y `test_downed.gd`.

Pasos:
- [ ] Tests fallidos: `test_death_costs_durability` (muerto en solitario → 90), `test_downed_keeps_durability` (derribado y revivido → 100; derribado que se desangra y muere → 90).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): durability loss on death`.

### Task 7: Botín en el mundo
**Archivos:** crear `sim/items/loot.gd`; modificar `sim/sim_world.gd` (`var loot: Dictionary`, `var items: ItemDB`; `step` llama a `Loot.step`), `sim/combat/combat.gd` (tras `Xp.share`, `Loot.drop`); test `tests/unit/sim/test_loot.gd`.

**Produce** `Loot` (static):
- `drop(world, m: MonsterState)` — sin botín de invocados; por cada jugador no muerto a `share_range`: `ItemRoll.roll_loot` (`kind` `boss` si `def.boss`, `elite` si élite) y, en jefes con único, `unique_chance`. Oro directo (`inventory.gold`, sucio) y evento `["gold", owner, amount, pos]`. Cada objeto: `world.loot[drop_id] = {owner, item, pos, expire_tick}` (posición esparcida hasta `loot_scatter` con `world.rng`) y evento `["loot", owner, drop_id, item.to_dict(), pos]`.
- `step(world)` — cada jugador vivo recoge lo suyo a `pickup_radius` si cabe (evento `["loot_gone", owner, drop_id, true]`); si no cabe, una vez por objeto `["bag_full", owner]`; caducados → `["loot_gone", owner, drop_id, false]`.

Pasos:
- [ ] Tests fallidos: `test_each_player_own_roll` (dos jugadores cerca de un élite → cada uno ≥ 1 entrada con su `owner`), `test_far_player_no_loot`, `test_pickup_only_owner`, `test_full_bag_stays`, `test_expire_120s`, `test_summons_no_loot`, `test_boss_unique_chance` (semilla fija; 1000 muertes de Vaelthar → 25 % ± 4 con su único).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): personal loot drops and pickup`.

### Task 8: Mercader (reglas)
**Archivos:** crear `sim/items/merchant.gd`, `data/npcs/merchant.json` (`role: "merchant"`), modificar `data/maps/test_arena.json` (`{"id": "merchant", "at": [25, 19], "facing": 250}`); test `tests/unit/sim/test_merchant.gd`.

**Produce** `Merchant` (static), todas exigen `near` (a `TALK_RANGE` de un PNJ con rol `merchant`) y jugador vivo fuera de combate:
- `stock(world, p) -> Array[Item]` — 4 comunes usables de nivel `p.level`; se rehace si han pasado `restock_s` desde la última vez (guardado en `p.merchant_stock`, `p.merchant_tick`).
- `potion_price(level) -> int` = `5 + 2 × nivel`; `sell_price(item, db) = floor(value × 0.25)`; `repair_cost(item, db) = ceil(value × 0.2 × (100 − durabilidad) / 100)`.
- `buy(world, p, index) -> bool` (índice del stock; `-1` vida, `-2` recurso), `sell(world, p, bag_index) -> bool`, `repair_all(world, p) -> bool`.

Pasos:
- [ ] Tests fallidos: `test_buy_potion` (oro baja, poción en la bolsa), `test_buy_not_enough_gold`, `test_sell_25pct`, `test_repair_cost` (raro nivel 10 a 50 % → `ceil(valor × 0.1)`), `test_restock_after_10min`, `test_far_from_merchant_refused`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): merchant rules`.

## Fase B — Guardado y red

### Task 9: Personaje versión 4 y equipo inicial
**Archivos:** modificar `save/character_data.gd` (`VERSION := 4`, `var inventory := Inventory.new()`), `net/host_session.gd` (`_on_choose_class`: equipo inicial de la clase, adiós a la espada de madera); tests `tests/unit/save/test_character_data.gd`, `tests/unit/net/test_choose_class.gd`.

- Migración `version < 4`: `inventory` = `starter[class_id]` equipado, nivel 1, común, sin oro.
- `Inventory.starter(class_id, db) -> Inventory` (estático, en `inventory.gd`).

Pasos:
- [ ] Tests fallidos: `test_v3_gets_starter` (guerrero v3 → espada, escudo y placas t1 equipados; nivel y talentos intactos), `test_v3_villager_wood_sword`, `test_roundtrip_v4`, `test_choose_class_gives_kit`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(save): character version 4 with inventory and starter kits`.

### Task 10: Protocolo 7
**Archivos:** modificar `net/protocol.gd`, `net/host_session.gd`, `net/client_session.gd`, `game/main.gd` (guarda el inventario recibido como hoy el progreso); tests `tests/unit/net/test_protocol.gd`, nuevo `tests/unit/net/test_items_net.gd`.

**Mensajes:**
- `HELLO` + `["inventory", TYPE_DICTIONARY]` (`PROTOCOL6_HELLO_SIZE := 7` para responder *otra versión*).
- `PLAYER_JOINED` y filas de `roster` + `["gear", TYPE_ARRAY]` (8 ids de `Inventory.VISIBLE`).
- `ITEM_ACTION [action: String, args: Array]` — `equip [index, ring_slot]`, `unequip [slot]`, `use [index]`, `potion [kind]`, `merchant_open []`, `buy [index]`, `sell [index]`, `repair []`.
- `INVENTORY [inventory: Dictionary, potion_cd_s: float]` — solo al dueño, al cambiar (`inventory_dirty`), como `_flush_progress`.
- `PLAYER_GEAR [id, gear: Array]` — a todos cuando cambian las visibles.
- `MERCHANT_STOCK [items: Array]` — solo al que lo abre.
- Los eventos `gold`, `loot`, `loot_gone` y `bag_full` se envían **solo a su dueño** (`HostSession._events_for(id, events) -> Array`).
- `ClientSession`: señales `inventory_changed()`, `gear_changed(id: int)`, `merchant_stock(items: Array)`; `request_item(action: String, args: Array)`; `inventory: Inventory`, `gear_of(id) -> Array`.

Pasos:
- [ ] Tests fallidos: `test_hello_inventory_sanitized`, `test_inventory_only_owner`, `test_loot_events_only_owner`, `test_gear_broadcast`, `test_old_protocol_rejected`, `test_equip_roundtrip` (cliente pide equipar → recibe `INVENTORY` y los demás `PLAYER_GEAR`).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(net): protocol 7 with inventory, gear and loot`.

## Fase C — Manejo, aspecto e interfaz

### Task 11: Familias de arma en la simulación
**Archivos:** crear `sim/items/weapon_family.gd`; modificar `data/items/weapons.json` (`families`), el punto donde `Combat` resuelve la habilidad que lanza un jugador; test `tests/unit/sim/test_weapon_family.gd`.

**Datos** (`families`, propuesta ajustable): `one_hand {}`; `heavy {grip "two_hand", melee_anim "heavy", cooldown_mult 1.4, damage_mult 1.5, range_add 0.5, angle_deg 150}`; `polearm {grip "polearm", melee_anim "thrust", cooldown_mult 1.2, damage_mult 1.25, range_add 1.5, angle_deg 50}`; `staff {grip "staff"}`; `wand {projectile {speed 30, range 14}, cooldown_mult 0.75, damage_mult 0.8}`; `bow {grip "bow"}`; `crossbow {grip "crossbow", auto_charge true, cooldown_mult 2.0}`; `daggers {}`.

**Produce** `WeaponFamily.adjust(ability: Dictionary, family: Dictionary) -> Dictionary` — solo al `kind: "basic"`: multiplica `cooldown_s` y el `damage` de sus efectos, suma `range_add` a `range` y al de sus `melee_arc`, fija `angle_deg`, cambia `anim: "melee"` por `melee_anim`, sobrescribe `speed`/`range` de sus `projectile`, y con `auto_charge` lanza siempre con carga completa (la tensión no se espera). Copia, nunca muta el original.

Pasos:
- [ ] Tests fallidos: `test_heavy_basic` (golpe del guerrero: recarga 0,84, rango 3, arco 150, daño ×1,5), `test_wand_projectile`, `test_crossbow_full_charge` (disparo sin tensar = daño del cargado), `test_other_abilities_untouched`, `test_original_not_mutated`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(items): weapon families change the basic attack`.

### Task 12: Aspecto desde el equipo y animaciones nuevas
**Archivos:** modificar `game/characters/character_catalog.gd` (carga también `data/items/gear_pieces.json`; `resolve(class_id, appearance, upgrade := "", gear: Array = [])`), `game/characters/human_rig.gd` (grips `two_hand`, `polearm`, `crossbow`; acciones `heavy` y `thrust`), `data/characters/classes.json` (`fixed_pieces: ["quiver_back"]` del Arquero; pieza `outfit_base` para el pecho y piernas vacíos), `game/player_avatar.gd` y `game/game_session.gd` (rehacer el rig al recibir `gear_changed`); tests `tests/unit/characters/test_character_catalog.gd`, `test_human_rig.gd`.

- Con `gear` no vacío: piezas = `look` de cada base visible (+ `hides` del casco) + `fixed_pieces` de la clase + pelo y barba; ranura de pecho o piernas vacía → `outfit_base`; `grip` = el de la familia del arma principal; el `look` de la mejora de clase **ya no se aplica** a jugadores (el equipo manda). Sin `gear` (PNJ, monstruos, pantallas antiguas) → como hoy.
- **Combo visual de tres golpes** (solo cliente, nada cambia en `sim/`): `HumanRig.play_action` cuenta los básicos cuerpo a cuerpo seguidos (`melee`, `heavy`, `thrust`, `stab`) y reproduce la variante `combo_step` 0, 1, 2 y vuelve a 0; si pasa más de `COMBO_RESET_S := 1.2` s desde el último, empieza en 0. Variantes: una mano → tajo derecha-izquierda, revés izquierda-derecha, golpe vertical; pesada → tajo amplio, revés amplio, mazazo vertical; asta → estocada, barrido, estocada a fondo; dagas → puñalada derecha, izquierda, cruzada con las dos. El rastro de `slash_fx.gd` sigue la hoja en las tres. `HumanRig.combo_step() -> int` para los tests.
- Arreglo previo: `render_characters.gd` gana el set `gear` (los 5 personajes con el equipo de un tramo: `--tier=1|2|3`, de frente, de lado y de espaldas, y una fila con las 18 armas).

Pasos:
- [ ] Tests fallidos: `test_resolve_from_gear` (casco que oculta pelo; pecho vacío → `outfit_base`; grip de mandoble = `two_hand`), `test_quiver_always`, `test_rig_heavy_and_thrust` (las acciones existen y terminan), `test_melee_combo_cycles` (tres básicos seguidos → pasos 0, 1, 2 y el cuarto 0), `test_melee_combo_resets` (pausa de 1,3 s → vuelve a 0), `test_combo_same_duration` (los tres pasos duran lo mismo).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(characters): look from equipped gear, two-handed animations and 3-hit melee combo`.

### Task 13: Arte del tramo 1
**Archivos:** crear `tools/art/make_gear.mjs` (escribe `assets/items/vox/*.vox` y `data/items/gear_pieces.json`; mismos marcos y paleta que `make_pieces.mjs`, importando sus constantes); modificar `data/items/bases.json` (`look` del t1), `tools/art/README.md`; test en `tests/unit/data/test_items_data.gd` (`test_every_base_has_model`: cada base no consumible tiene `look` con piezas existentes).

- Piezas por ranura: cabeza → `head`; hombros → `arm_left`/`arm_right`; pecho → `torso` (+ faldón en `hips`); manos → `hand_*` (+ brazal en `forearm_*`); piernas → `leg_*` (+ `hips`); pies → `shin_*` (bota). Armas en el marco del puño, como `WEAPONS`.
- Los 4 juegos del t1 se parecen a la ropa de clase actual (el guerrero de placas, el clérigo y el mago de tela, el arquero y el asesino de cuero), para que el aspecto inicial apenas cambie.
- [ ] Generar, importar (`--headless --import`), `render_characters.gd -- --set=gear --tier=1`.
- [ ] **Revisión del usuario** con la captura; ajustar hasta aprobar.
- [ ] GUT verde. Commit `feat(art): tier 1 gear models`.

### Task 14: Iconos y botín en el suelo
**Archivos:** crear `game/items/item_icons.gd` (renderiza cada base en un `SubViewport` 64×64 y lo cachea en memoria y en `user://cache/icons/<base>.png`; consumibles con icono dibujado), `game/loot_view.gd` (haz de luz del color de la rareza, nombre flotante con tamaño de mundo, desaparece al recogerse o caducar; oro como número flotante dorado); modificar `game/game_session.gd` (eventos `loot`, `loot_gone`, `gold`, `bag_full` → chat `ITEM_BAG_FULL`); tests `tests/unit/game/test_loot_view.gd`, `test_item_icons.gd`.

- Colores de rareza (`loot.json`, `rarity_color`): común `#ffffff`, poco común `#3fd15a`, raro `#3f8cff`, épico `#b04fe8`, legendario `#ff8a1f`, único `#e8c547`.

Pasos:
- [ ] Tests fallidos: `test_loot_beam_spawn_and_free`, `test_icon_cached` (segunda petición = misma textura).
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(game): item icons and loot on the ground`.

### Task 15: Inventario, tooltip y ventana C
**Archivos:** crear `ui/item_slot.gd`, `ui/item_tooltip.gd`, `ui/inventory_window.gd`; modificar `ui/character_window.gd` (11 huecos alrededor del modelo, con el equipo), `game/input_setup.gd` (`window_inventory: KEY_I`, `potion_health: KEY_Q`, `potion_resource: KEY_R`), `game/main.gd` (I abre y cierra; puede convivir con C y con el mercader; Q/R piden `potion`); textos en `textos.csv`; tests `tests/unit/ui/test_inventory_window.gd`, `test_item_tooltip.gd`, ajustar `test_character_window.gd`.

- Inventario 6×5 + oro. Clic derecho: equipar o usar (petición `ITEM_ACTION`). Clic derecho en un hueco de C: desequipar.
- Tooltip: nombre en color de rareza, ranura y tipo, nivel (rojo si supera el del personaje), estadísticas fijas y propiedades, durabilidad (rojo a 0), valor de venta, y bajo una línea la **comparación** con lo equipado en esa ranura (diferencias `+` en verde y `−` en rojo). Rojo *No puede usarlo tu clase*.

Pasos:
- [ ] Tests fallidos: `test_windows_fit_720` (I y C abiertas a la vez dentro de 1280×720), `test_tooltip_compare` (cambiar un pecho de 10 de armadura por uno de 14 → `+4`), `test_right_click_equips` (emite la petición), `test_eleven_slots`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(ui): inventory window, item tooltips and equipment slots`.

### Task 16: HUD de pociones y durabilidad
**Archivos:** modificar `ui/combat_hud.gd` (dos huecos Q y R con icono, cantidad y recarga compartida; icono de yunque rojo y aviso cuando alguna pieza baja del 25 %); test `tests/unit/ui/test_combat_hud.gd`.

Pasos:
- [ ] Tests fallidos: `test_potion_counts_and_cooldown`, `test_durability_warning`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(ui): potion slots and durability warning`.

### Task 17: Mercader (PNJ y ventana)
**Archivos:** modificar `data/npcs/merchant.json` (aspecto propio: delantal, bolsa, gorro), `game/npc_interaction.gd` (rol `merchant` → abrir mercader), `game/main.gd`; crear `ui/merchant_window.gd`; textos; test `tests/unit/ui/test_merchant_window.gd`, `tests/unit/game/test_npc_interaction.gd`.

- Ventana junto al inventario: pestaña *Comprar* (2 pociones y 4 objetos con precio, clic derecho compra), pestaña *Vender y reparar* (clic derecho en el inventario vende; raro o mejor pide confirmación con `message_dialog`; botón *Reparar todo* con su precio, desactivado si no hay nada que reparar). Se cierra al alejarse.

Pasos:
- [ ] Tests fallidos: `test_fits_with_inventory_720`, `test_sell_confirms_rare`, `test_repair_button_price`, `test_interact_opens_merchant`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(ui): provisional merchant next to Brann`.

### Task 18: Comandos de pruebas
**Archivos:** modificar `net/host_session.gd` (`/oro <n> [nombre]`, `/objeto <base> [nivel] [rareza] [nombre]`); test `tests/unit/net/test_test_commands.gd`.

Pasos:
- [ ] Tests fallidos: `test_gold_command`, `test_item_command` (base inexistente → `CMD_BAD`; bolsa llena → `ITEM_BAG_FULL`), `test_guest_refused`.
- [ ] GUT → fallan. Implementar. GUT verde.
- [ ] Commit `feat(net): /oro and /objeto test commands`.

## Fase D — Arte de los tramos 2 y 3 y únicos

### Task 19: Tramo 2
- [ ] Añadir las 42 bases t2 a `bases.json` (nivel 20–39) con sus nombres y modelos en `make_gear.mjs`: más ornamentados que el t1 (ribetes, remaches, gemas).
- [ ] `render_characters.gd -- --set=gear --tier=2`; **revisión del usuario**; ajustar.
- [ ] GUT verde. Commit `feat(art): tier 2 gear`.

### Task 20: Tramo 3
- [ ] Igual con las 42 bases t3 (nivel 40+): el aspecto más épico (oro, brillo `GLOW`, siluetas grandes).
- [ ] Revisión del usuario. GUT verde. Commit `feat(art): tier 3 gear`.

### Task 21: Únicos de jefe
- [ ] Tres bases `unique` con `unique_of` (Acólito Cultista → arma a una mano; Vaelthar → bastón; Nhazar → mandoble) *(propuesta de Claude)*, nombre propio, estadísticas fijas altas y modelo inspirado en su jefe.
- [ ] Revisión del usuario. GUT verde (`test_boss_unique_chance` con datos reales). Commit `feat(items): boss uniques`.

## Fase E — Cierre

### Task 22: Documentación y versión
- [ ] GDD: §8 a **[Implementado]** con lo que cambió (carcaj adorno, armas nuevas, tres tramos, legendarios aplazados), §4.2 (tabla de armas), §9 (ventanas I, mercader, HUD), §10 (versión 4), *Registro de cambios*; decisión `D-014 Objetos: armas a dos manos, familias y tramos` en `docs/Decisiones/` y su índice; `Planes.md`; sesión en `docs/Sesiones/`.
- [ ] `project.godot` → `0.7.0`. Batería completa verde.
- [ ] Commit `docs: plan 5 items` y `chore(release): 0.7.0` (publicación tras la prueba de juego del usuario).

---
← [[Planes]]
