---
tags: [plan]
plan: 3.1
fecha: 2026-11-16
estado: hecho
actualizado: 2026-11-16
---
# Plan 3.1 — Ajustes tras la 0.4.0: plan de implementación

Spec: [[Plan 3.1 — Ajustes tras la 0.4.0 (spec)]]. Ejecución nativa en el chat, rama `plan-3-tweaks`.

### Task 1: Detalle calculado
- Crear `ui/ability_details.gd`: `AbilityDetails.lines(ability: Dictionary, stats: CombatStats, resource_kind: String) -> PackedStringArray`.
- Textos `DETAIL_*` en `textos.csv`.
- Test `tests/unit/ui/test_ability_details.gd`: fórmula y resultado del daño; las 55 habilidades de clase generan detalle sin `%` sueltos ni claves sin traducir; pasivas con su número.

### Task 2: Ventana K con CI y CD
- `ui/abilities_window.gd`: fila "Ataques" (CI, CD); `show_for` recibe también las estadísticas y el recurso para el detalle; los ataques no van a la barra.
- Tests en `test_abilities_window.gd`: ids de ataques, no asignables, el detalle aparece, cabe a 1280×720.

### Task 3: Esqueleto vóxel propio
- `make_monsters.mjs`: rig bípedo `skeleton`; `BeastRig` con forma bípeda (andar, reposo, disparar, morir desmoronándose).
- `data/monsters/skeleton_archer.json` → `rig:skeleton`; se retiran `outfit_skeleton.png` y la pieza `skeleton_bow`.
- Tests en `test_monster_avatar.gd`. Punto de control de arte con captura.

### Task 4: Cierre
- Suite completa, 0.4.1, notas de la versión, registro de cambios, nota de sesión. Publicar solo con permiso.

---
← [[Planes]]
