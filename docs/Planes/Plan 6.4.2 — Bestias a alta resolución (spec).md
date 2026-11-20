---
tags: [plan, spec]
plan: 6.4.2
fecha: 2026-11-20
estado: implementado
actualizado: 2026-11-20
---
# Plan 6.4.2 — Bestias a alta resolución: diseño

## Objetivo
Segunda parte del Plan 6.4: rehacer las tres bestias (sabueso marcado, jabalí marcado y lobo del cazador) con los mismos diseños, a la resolución del nuevo estilo. Sale como **0.9.5**. El usuario lo probará todo junto.

**Por qué:** hoy son cajas de vóxeles de 10 cm (el sabueso mide 12 vóxeles de alto) junto a un jugador y unos cultistas de vóxel fino.

## Fuera de alcance
- Ropa que sigue al cuerpo (siguiente parte del 6.4).
- Reglas, tamaños en el mundo, ataques y animación: el `BeastRig` y sus partes no cambian.

## Diseño
1. **Densidad:**
   - las bestias se esculpen a vóxel de **2,5 cm** (4× más denso);
   - el JSON del rig lleva `"voxel_scale": 0.25`;
   - `BeastRig` escala pivotes, desplazamientos y mallas por él.

   Mismas partes (`body`, `head`, cuatro patas y cola) y pivotes en el mismo sitio en metros.
2. **Generador `tools/art/beasts_v2.mjs`:** esculpe con `sculpt.mjs`. La piel usa el tinte del monstruo con textura y forma (sombra abajo, luz arriba).
   - **Sabueso:**
     - pecho, costillar, cintura y ancas con volumen;
     - cresta de púas por el lomo;
     - cabeza con hocico, mandíbula, colmillos, orejas en punta y ojos rojos que brillan;
     - collar de hierro con púas y la marca del sol negro ardiendo en la garganta;
     - patas con muslo, caña y garras.
   - **Lobo:** el mismo cuerpo sin el collar del culto, teñido de gris en sus datos.
   - **Jabalí:**
     - cuerpo de tonel con joroba y cresta de cerdas;
     - placas de hierro con remaches en los flancos;
     - cabeza baja con disco del hocico y colmillos largos curvados hacia arriba;
     - collar con la marca;
     - patas cortas con pezuñas partidas;
     - cola rizada.
3. **Revisión:** capturas de las tres bestias junto a un cultista.

## Pruebas
- **`node --test`:**
  - cada bestia tiene sus 7 partes;
  - las patas llegan al suelo;
  - los ojos y la marca brillan (el lobo no lleva marca);
  - las piezas caben en un `.vox`;
  - la generación es determinista.
- **GUT:**
  - `BeastRig` aplica `voxel_scale` (las bestias miden lo mismo en metros que antes);
  - las tres bestias se montan;
  - la suite completa pasa.

## Decisiones tomadas
- Seguir el 6.4 sin parar; el usuario lo prueba todo junto.
- Decisiones de Claude:
  - mismos diseños;
  - vóxel de 2,5 cm;
  - las bestias antes que la ropa, para cerrar los monstruos.

## Durante la implementación
- Tamaños medidos antes del cambio y conservados: el sabueso y el lobo miden 1,7 m de alto y 2,9 m de largo, y el jabalí 1,7 por 2,6.
- `make_monsters.mjs` escribe las bestias desde `beasts_v2.mjs`. El código v1 de las bestias desaparece.
- Captura: `docs/Adjuntos/Plan 6.4.2/bestias.png` (conjunto `beasts` de `render_characters.gd`).

---
← [[Planes]]
