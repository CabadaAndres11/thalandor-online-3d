---
tags: [decision]
id: D-010
fecha: 2026-11-16
estado: aceptada
---
# D-010 · Arte propio hecho por código

## Contexto
Desde la 0.2.0 los personajes usaban el modelo y las animaciones de Kenney Blocky Characters (CC0). El usuario quiere un juego con identidad propia y que el contenido siga al guion.

## Decisión
- **Sin assets de terceros:** todo el arte (personajes, piezas, monstruos e iconos) lo generan los scripts de `tools/art/` como datos.
- **Humanoide propio** (`HumanRig`): un rig vóxel por huesos con animaciones por código.
  - Vóxel fino, proporciones de adulto, y codos y rodillas.
  - Cada color tiene un tono oscuro y otro claro, y el mallador añade oclusión ambiental en los vértices.
- **Estilo:** menos «bloque» que Kenney. Se fijó con una imagen de referencia del usuario y se aprobó con capturas antes de borrar Kenney.

## Por qué
- Da una identidad visual propia, épica, coherente en todo el juego.
- Permite cambiar cualquier pieza sin depender de un pack.
- Un sistema por piezas sirve también para el equipo visible.

## Alternativas consideradas
- **Malla con esqueleto exportada a `.glb` desde código:** animaciones más suaves, pero exige escribir un exportador glTF con skinning y no encaja con los monstruos.
- **Seguir con el esqueleto de Kenney cambiando solo la malla:** descartada porque sigue dependiendo de un paquete externo.

## Afecta a
- [[11 Arte y audio]]
- [[Plan 3.2 — Vóxel propio, bestiario del prólogo y clase con Brann (spec)]]

---
← [[Índice de decisiones]]
