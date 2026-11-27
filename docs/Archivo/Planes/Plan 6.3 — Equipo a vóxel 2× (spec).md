---
tags: [plan, spec]
plan: 6.3
fecha: 2026-11-20
estado: implementado
actualizado: 2026-11-20
---
# Plan 6.3 — Equipo a vóxel 2×: diseño

## Objetivo
Tercera parte de la [[14 Hoja de ruta|renovación gráfica]]: rehacer **todo el equipo visible** (armaduras de las 5 clases en 3 tramos, armas por familia, únicos de los jefes) sobre el cuerpo v2 de la [[Plan 6.2 — Humanoide y piezas a vóxel 2× (spec)|6.2]], con el mismo diseño y más épico. Cierra la **0.9.0**, que sale junto con la 6.2.

**Por qué:** desde la 6.2 el equipo viejo se ve al doble de tamaño sobre el cuerpo nuevo, sin ajustarse a él. El jugador debe reconocer su equipo, pero con el aspecto de las referencias ([[Estilo gráfico objetivo (Plan 6)]]).

## Fuera de alcance
- Objetos nuevos, cambios de estadísticas o de `bases.json`: los ids y los datos no cambian.
- Cultistas y jefes (6.4).
- Física de capas, túnicas y auras (6.4): siguen rígidas.

## Antifines
- Que el jugador no reconozca su juego: cada clase conserva su tipo de armadura, sus emblemas, sus colores por tramo y sus extras (capas, halos, coronas…).
- Que los tramos se parezcan entre sí: cada tramo debe verse claramente más rico que el anterior.
- Que una pieza atraviese el cuerpo o tape los ojos (salvo los yelmos cerrados con visera).
- Que cambie algo de la red, los guardados o las reglas.

## Enfoques
- **A (elegido por el usuario): mismos diseños, rehechos y más épicos por tramo.** Cada pieza conserva su idea y se esculpe a 2× sobre el cuerpo v2 con la librería `sculpt.mjs`, con textura, molduras, remaches y grabados. El tramo 3 gana silueta: hombreras con forma de ala, capas más largas, escudos y armas sobredimensionados y gemas con brillo.
- **B: rediseño completo hacia las referencias.** Descartado: mucho más trabajo y cambia la identidad de los juegos revisados en el Plan 5.
- **C: rehacer tal cual a 2×.** Descartado: el tramo 3 seguiría lejos de las referencias.

## Diseño
1. **Generador `tools/art/make_gear_v2.mjs`.**
   - Escribe `assets/items/vox_v2/*.vox` y `data/items/gear_pieces_v2.json`, con los **mismos ids, partes, `tag` y `hides`** que `gear_pieces.json`.
   - Los colores por clase y tramo (`TIER_COLORS`, materiales por tipo de armadura) se sacan a un módulo compartido con el generador v1, para que no diverjan. Los `.vox` v1 deben salir idénticos.
2. **Armaduras:** se dibujan como cáscaras (`shellAround`) sobre las partes del cuerpo v2. Mismas piezas que hoy:
   - cabeza (con sus extras), hombros, pecho con emblema y su faldón o túnica;
   - mangas y campanas del mago;
   - guantes con puños, perneras y botas.

   Cada tramo añade riqueza:
   - **tramo 1:** sencillo, con material y costuras;
   - **tramo 2:** ribetes, remaches y molduras;
   - **tramo 3:** dorado, runas que brillan, gemas con un vóxel de reflejo y silueta mayor.
3. **Armas:** las 17 familias de cada tramo y los 3 únicos, en el marco del puño v2. Miden lo mismo en metros que en v1, con filos, vaceos, empuñaduras con tiras y guardas trabajadas. El tramo 3 es más grande y adornado.
4. **Uso en el juego:**
   - `CharacterCatalog` carga también `gear_pieces_v2.json` en la tabla v2, así que el equipo deja de verse ampliado.
   - Los **iconos de objeto** (`ItemIcons`) usan la versión v2 cuando existe.
5. **Revisión del arte:** capturas por clase y tramo (`render_characters.gd`, sets `gear` y `weapons` sobre v2), revisadas antes de cerrar.
6. **Publicación 0.9.0:** la versión sube a 0.9.0 y se publica solo tras la prueba de juego del usuario (6.2 + 6.3).

## Pruebas
- **`node --test`:**
  - cada id de `gear_pieces.json` tiene versión v2 con la misma parte, `tag` y `hides`;
  - ninguna armadura está dentro de su parte del cuerpo v2;
  - los tocados no tapan los ojos (salvo los yelmos con visera);
  - el tamaño de la silueta crece con el tramo en cabeza, hombros y armas;
  - la generación es determinista;
  - los `.vox` v1 no cambian.
- **GUT:**
  - el equipo puesto usa la pieza v2 sin `voxel_scale`;
  - un juego completo de tramo 3 de cada clase se monta sin errores;
  - los iconos usan la v2;
  - existen todos los ficheros v2;
  - la suite completa pasa.

## Decisiones tomadas
- Mismos diseños, más épicos por tramo (usuario).
- Módulo compartido de colores con el generador v1 e iconos con la versión v2 *(decisiones de Claude)*.

---
← [[Planes]]
