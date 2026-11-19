---
tags: [plan, spec]
plan: 6.2
fecha: 2026-11-20
estado: aprobado
actualizado: 2026-11-20
---
# Plan 6.2 — Humanoide y piezas a vóxel 2×: diseño

## Objetivo
Segunda parte de la [[14 Hoja de ruta|renovación gráfica]]: un **humanoide nuevo** con vóxel de 1,8 cm ([[D-015 Vóxel 2× y renovación gráfica en cuatro partes]]) y proporciones adultas, con cara, más volumen y materiales con textura; y las **piezas de apariencia** rehechas a esa escala. Referencias: [[Estilo gráfico objetivo (Plan 6)]] (sobre todo la 3, proporciones; y la 4, textura por vóxel).

**Por qué:** el humanoide de 49 vóxeles y colores casi planos da el aspecto infantil que queremos dejar atrás. Todo el arte posterior (equipo, razas, PNJ) se apoya en este cuerpo.

**Publicación:** **no se publica sola**. Sale con la [[14 Hoja de ruta|6.3 (equipo)]] en la **0.9.0** (decisión del usuario), para que no haya una versión con el equipo mal ajustado.

## Fuera de alcance
- **Equipo** (`make_gear.mjs`, 141 objetos): 6.3. Hasta entonces, el equipo viejo se acopla al cuerpo nuevo **ampliado al doble** (ver §4), solo como transición interna.
- **Cultistas, jefes y piezas de monstruo:** siguen con el cuerpo viejo hasta la 6.4.
- **Peinados, barbas o rasgos nuevos y razas:** Plan 7. Aquí se rehacen los que hay.
- **Ropa que sigue al cuerpo** (capas y túnicas con física): 6.4.
- **Animaciones nuevas:** las de hoy se conservan; solo se ajustan los pivotes y los ángulos que no encajen.

## Antifines
- Que el cuerpo nuevo se vea «de bloques»: los volúmenes (cráneo, hombros, pantorrillas) deben ser redondeados.
- Colores planos: cada material muestra dos o tres tonos mezclados.
- Romper los personajes guardados, la red o las reglas: el aspecto sigue saliendo de los mismos ids de apariencia y equipo.
- Que el arte deje de ser propio y hecho por código (D-010).

## Enfoques
- **A (elegido): librería de esculpido** en `tools/art/sculpt.mjs`.
  - Formas redondeadas (elipsoide, cápsula entre dos puntos con radios distintos, cilindro, caja redondeada) que se rasterizan a vóxeles.
  - Operaciones: añadir, tallar y reflejar en X.
  - Reglas de pintura: ruido de tonos, sombreado por orientación de la cara y bordes y costuras.
  - Los detalles finos (ojos, cejas, hebillas) se ponen a mano con la `Shape` de siempre.
  - La reutilizan la 6.3 y la 6.4.
- **B: duplicar los `.vox` actuales y retocarlos.** Descartado: hereda las formas de bloque.
- **C: caja a caja a 2×.** Descartado: unas cuatro veces más trabajo, y el resultado tiende a verse cuadrado.

## Diseño

### 1. Librería de esculpido (`tools/art/sculpt.mjs`)
- **Formas:**
  - `ellipsoid(c, r, idx)`
  - `capsule(a, b, ra, rb, idx)`: tronco de cono con extremos redondeados
  - `cylinder(a, b, r, idx)`
  - `roundBox(min, max, radius, idx)`
  - `carve(…)`: las mismas formas, pero quitando vóxeles
  - `mirrorX(shape, axisX)`
- **Pintura:**
  - `tone(shape, idx, tones, seed)`: reparte base, sombra y luz con ruido determinista. En los canales teñibles se usan los índices `SHADE`/`LIGHT` de `vox.mjs`.
  - `shadeByFacing(shape)`: los vóxeles de superficie que miran hacia abajo o hacia atrás pasan a su tono de sombra, y los de arriba a su tono de luz.
  - `seam(...)`: líneas de costura o borde de un tono.
- **Determinista:** misma entrada, mismos vóxeles, para que los `.vox` no cambien sin motivo en git.
- **Tests:** con `node --test` (sin dependencias), en `tools/art/tests/`.

### 2. Cuerpo nuevo `human_v2`
- **Generador:** `make_humans.mjs` genera también `human_v2` en `assets/characters/vox_v2/` + `human_v2.json`, con las **mismas partes y jerarquía** que hoy:
  - cadera, torso y cabeza;
  - brazo, antebrazo y mano por lado;
  - muslo y pierna con bota por lado.
- **Medidas:**
  - **98 vóxeles de alto** a 1,8 cm (≈1,76 m);
  - cabeza de unos 17 vóxeles (unas 5,8 cabezas de alto), algo grande como en la referencia 3;
  - hombros a unos 76, cadera a unos 46 y rodilla a unos 26.
  - Las medidas finas las fija el plan y se revisan por capturas.
- **Cara:**
  - cejas, ojos con blanco e iris (canal de ojos);
  - nariz con volumen, pómulos y boca;
  - orejas y mandíbula marcada.
  - Varias filas de vóxeles por rasgo, no un solo vóxel.
- **Cuerpo:**
  - torso con pecho, hombros redondeados y cintura;
  - brazos y piernas con volumen de músculo (cápsulas);
  - manos con dedos insinuados en el puño;
  - botas con caña, pliegues y suela.
- **Canales teñibles:** los mismos (piel, ojos, pelo, principal, secundario, pantalón) con sus tres tonos.
- **Cuerpos delgado y robusto:** siguen siendo `body_scale` por grupo, sin cambios en los datos.

### 3. Piezas de apariencia v2
- **Generador:** `make_pieces.mjs` genera también la versión v2 de las piezas de jugador y PNJ, en `assets/characters/pieces_v2/`, con su tabla `data/characters/pieces_v2.json` (mismo formato y mismos ids):
  - **pelo:** 7 piezas (`hair_short`, `hair_bob`, `hair_swept`, `hair_mohawk`, `hair_long`, `hair_ponytail`, `hair_bun`), con mechones y volumen;
  - **barbas:** 4;
  - **ropa de clase:** 6 conjuntos, con pliegues, costuras y caída;
  - **tocados:** 5;
  - **otras:** hombreras y carcaj;
  - **armas en la mano:** 8 (todas menos la del Inquisidor).
- **Piezas de monstruo:** no se tocan (6.4).

### 4. Convivencia de los dos cuerpos
- **Aspecto (`look`):** lleva `"body": "v1"` o `"v2"`. Sin la clave, se usa `v1`, así que los cultistas y jefes no cambian.
- **`HumanRig`:** carga el rig y la escala de cada cuerpo (v1: `human.json` a 0,36; v2: `human_v2.json` a 0,18).
- **`CharacterCatalog.resolve`:** devuelve `"body": "v2"` para jugadores y PNJ, y toma cada pieza de `pieces_v2.json`.
  - Si una pieza no tiene versión v2 (todo el equipo hasta la 6.3), usa la v1 con `"voxel_scale": 2`.
  - `HumanRig` aplica esa escala a la pieza para que encaje de forma aproximada en el cuerpo nuevo.
- **Agarres y efectos:** los agarres de arma (`staff`, `bow`, `blade_down`…) y los efectos que dependen de posiciones (aura, arco a la espalda) siguen funcionando con el cuerpo nuevo.

### 5. Revisión del arte
- Capturas con `tests/helpers/render_characters.gd`, añadiendo el set `classes_v2` y el set `compare`, que pone el viejo y el nuevo lado a lado.
- El usuario revisa las capturas, y si quiere los `.vox` en MagicaVoxel, antes de seguir con la 6.3.

## Pruebas
- **Librería (`node --test`):**
  - cada forma produce los vóxeles esperados (simetría, radios, extremos);
  - `carve` quita;
  - `tone` es determinista y usa solo los tonos dados;
  - `shadeByFacing` oscurece las caras de abajo.
- **GUT:**
  - el cuerpo v2 mide 1,7–1,85 m;
  - tiene todas las partes y la jerarquía de siempre;
  - un look sin `body` usa v1;
  - `resolve` da v2 y piezas v2;
  - una pieza sin v2 lleva `voxel_scale` 2;
  - existen todos los `.vox` de `pieces_v2.json`;
  - las pruebas actuales de `HumanRig` (acciones, agarres, arco, bastón, combo y aura) pasan con los dos cuerpos.
- **Prueba de juego:** con la 6.3, en la 0.9.0.

## Decisiones tomadas
- Vóxel 2× y Plan 6 en cuatro partes: [[D-015 Vóxel 2× y renovación gráfica en cuatro partes]].
- 6.2 y 6.3 se publican juntas en la 0.9.0 (usuario).
- Librería de esculpido (usuario, a propuesta de Claude).
- Proporciones de la referencia 3, de unas 5,8 cabezas; cuerpo viejo conviviendo hasta la 6.4; equipo viejo ampliado al doble como transición *(decisiones de Claude)*.

---
← [[Planes]]
