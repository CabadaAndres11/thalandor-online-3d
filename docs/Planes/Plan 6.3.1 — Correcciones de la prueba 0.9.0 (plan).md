---
tags: [plan]
plan: 6.3.1
fecha: 2026-11-20
estado: en curso
actualizado: 2026-11-20
---
# Plan 6.3.1 — Correcciones de la prueba 0.9.0: plan

Spec: [[Plan 6.3.1 — Correcciones de la prueba 0.9.0 (spec)]]. Cada tarea sigue el ciclo test que falla, código, test que pasa y commit.

| # | Tarea | Ficheros | Tests |
|---|---|---|---|
| 1 | Venta: precio mínimo 1, margen de 0,5 m y aviso de rechazo | `sim/items/merchant.gd`, `net/host_session.gd`, `textos.csv` | `test_merchant.gd` |
| 2 | Regeneración fuera de combate (`out_of_combat_hp_pct` = 0,02) | `data/balance.json`, `sim/balance.gd`, `sim/combat/resources.gd` | `test_resources.gd` |
| 3 | Animación con la habilidad evolucionada | `game/game_session.gd` | test del cliente: el templario usa `melee` |
| 4 | Fondo rojo si no se puede equipar | `ui/item_slot.gd` | `test_item_slot.gd` |
| 5 | Joyas v2 y campo `model` | `tools/art/gear_jewelry_v2.mjs`, `make_gear_v2.mjs`, `bases.json`, `item_icons.gd` | `node --test` y GUT de `icon_pieces` |
| 6 | Modelo del objeto en el suelo | `game/loot_view.gd` | `test_loot_view.gd` |
| 7 | Combo: lateral a la izquierda, lateral a la derecha y descendente (`melee` y `heavy`) | `game/characters/human_rig.gd` | `test_human_rig.gd` |
| 8 | Mano izquierda en el mango (cinemática inversa) | `game/characters/human_rig.gd` | `test_human_rig.gd` |
| 9 | Efectos vóxel del clérigo | `game/voxel_fx.gd`, `game/combat_fx.gd` | `test_combat_fx.gd` y capturas |
| 10 | Versión 0.9.1, documentación y revisión final | `project.godot` y bóveda | suite completa |

---
← [[Planes]]
