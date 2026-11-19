---
tags: [sesion]
fecha: 2026-11-19
tipo: desarrollo
---
# Sesión 2026-11-19

## Objetivo
Diseñar e implementar el [[Plan 5 — Objetos (spec)|Plan 5 · Objetos]] hasta la versión 0.7.0.

## Qué se hizo
- Spec y plan del Plan 5; decisiones en [[D-014 Objetos por clase, armas a dos manos y tramos épicos]].
- Reglas en `sim/items/`: datos de objetos, tiradas de botín y rarezas, inventario de 30 casillas y 11 ranuras, estadísticas del equipo y bloqueo solo con escudo, pociones con recarga compartida, durabilidad al morir, botín personal en el suelo y mercader.
- Personajes versión 4 con equipo inicial por clase; protocolo de red 7 (inventario, aspecto del equipo y botín solo para su dueño).
- Familias de arma (mandoble, alabarda, varita, ballesta…) y combo visual de tres golpes.
- Aspecto desde el equipo, animaciones a dos manos, iconos renderizados, haz de luz del botín, ventanas I, C (11 huecos) y del mercader, HUD de pociones y aviso de reparar, comandos `/oro` y `/objeto`.
- Arte por código (`tools/art/make_gear.mjs`): 141 objetos en 3 tramos, un juego por clase, capas, halos, coronas y auras en el tramo 3, y los únicos de los tres jefes.

## Qué se probó
- 1208 tests automáticos (GUT) en verde.
- Revisión del arte por capturas: el usuario pidió juegos por clase, tramos más épicos, túnica larga con mangas y sombrero bajo para el mago, y hachas con la hoja al frente.

## Problemas encontrados
- La ventana C no cabía junto al inventario a 1280×720: inventario de 5 × 6 y ventana C más estrecha.

## Publicación y hoja de ruta
- **0.7.0 publicada** (etiqueta `v0.7.0`, la CI genera el zip de Windows).
- [[14 Hoja de ruta]] revisada con las peticiones del usuario: renovación gráfica primero, identidad y razas, mundo con diálogos nuevos, secretos y clases ocultas, oficios, interfaz y audio, y contenido de la demo con el bestiario ampliado.

## Siguiente paso
- Plan 6 · Renovación gráfica: vóxel más fino y aspecto menos infantil.

---
← [[Sesiones]]
