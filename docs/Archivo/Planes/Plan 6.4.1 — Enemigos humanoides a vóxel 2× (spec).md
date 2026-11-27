---
tags: [plan, spec]
plan: 6.4.1
fecha: 2026-11-20
estado: implementado
actualizado: 2026-11-20
---
# Plan 6.4.1 — Enemigos humanoides a vóxel 2×: diseño

## Objetivo
Primera parte del Plan 6.4: pasar los 6 enemigos humanoides al cuerpo v2 con **los mismos diseños** (decisión del usuario), rehechos con más detalle.

| Enemigo | Piezas |
|---|---|
| Cultista | túnica, capucha, mangas, puños, daga |
| Cultista arquero | túnica, capucha, mangas, puños, arco |
| Acólito | túnica, capucha, mangas, puños, garras |
| Inquisidor | capucha con corona solar, hombreras, brazales, cinturón, espada |
| Vaelthar | melena, túnica de capas, mangas, tentáculos |
| Nhazar | cabeza de máscaras, cuello, cadenas |

Sale como **0.9.4**.

**Por qué:** junto al jugador con el cuerpo nuevo, los enemigos se ven toscos y de otra época.

## Fuera de alcance
- Ropa que se mueve con el cuerpo (una parte posterior del 6.4).
- Bestias (otra parte del 6.4).
- Reglas, ataques, vida o tamaño en el juego.

## Antifines
- Que un enemigo deje de reconocerse: silueta, colores y rasgos (máscaras, tentáculos, corona solar, ojos dorados) se mantienen.
- Que cambie su tamaño en el mundo: el jefe debe imponer igual que hoy.
- Que las piezas atraviesen el cuerpo v2 en reposo.

## Diseño
1. **Generador `tools/art/monsters_v2.mjs`:**
   - Esculpe con `sculpt.mjs` sobre las partes del cuerpo v2, igual que la ropa y el equipo v2.
   - Usa los **mismos ids** de pieza; los añade a `data/characters/pieces_v2.json` mediante `make_pieces_v2.mjs`.
   - Detalle nuevo:
     - textura de tonos;
     - pliegues en las túnicas;
     - ribetes dorados del culto;
     - ojos que brillan;
     - máscaras con expresión;
     - cadenas con eslabones.
2. **`MonsterAvatar.look_of`:** los humanoides usan `body: v2` y `CharacterCatalog.piece_entry` (v2, o v1 al doble mientras falte). Los datos de los monstruos no cambian.
3. **Tamaño:** el cuerpo v2 mide lo mismo en metros que el v1, así que la escala de cada monstruo en sus datos se mantiene. Si la proporción cambia la altura aparente, se corrige en el render, no en las reglas.
4. **Rasgos especiales:**
   - `hide_parts` (Vaelthar sin antebrazos) y `hover` siguen funcionando con las partes del cuerpo v2;
   - el agarre `blade_down` del inquisidor sigue igual;
   - el arco del arquero usa el arma v2 nueva.
5. **Revisión:** capturas de los 6 enemigos de frente y de espaldas (`render_characters.gd`), comparadas con las de hoy.

## Pruebas
- **`node --test`:**
  - cada pieza de monstruo de `pieces.json` tiene versión v2 en la misma parte;
  - ninguna está dentro de su parte del cuerpo v2;
  - la generación es determinista.
- **GUT:**
  - los 6 enemigos se montan con el cuerpo v2 y sus piezas v2;
  - Vaelthar oculta sus antebrazos;
  - el jefe levita;
  - la suite completa pasa.

## Decisiones tomadas
- Empezar el 6.4 por los enemigos humanoides (usuario).
- Mismos diseños con más detalle (usuario).
- Decisiones de Claude:
  - los mismos ids de pieza;
  - se mantienen las escalas de los datos.

## Durante la implementación
- El usuario pidió usar las hojas de referencia de cada enemigo. Las del acólito, Vaelthar, Nhazar y el inquisidor estaban en conversaciones anteriores; se guardan en `docs/Adjuntos/Referencias enemigos/`. El cultista base no tenía hoja y sigue su diseño con los rasgos comunes del culto.
- Las piezas viven en `tools/art/monsters_v2.mjs` y entran en la tabla v2 por `make_pieces_v2.mjs`. Ya ninguna pieza v1 se dibuja al doble, pero el respaldo sigue existiendo.
- Las máscaras de Nhazar miden el triple de la cuadrícula v1, para que se lean sobre una masa del doble de resolución.
- Capturas en `docs/Adjuntos/Plan 6.4.1/`.

---
← [[Planes]]
