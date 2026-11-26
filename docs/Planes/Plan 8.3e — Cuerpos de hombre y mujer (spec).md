---
tags: [plan, spec]
plan: 8.3e
fecha: 2026-11-27
estado: borrador
actualizado: 2026-11-27
---
# Plan 8.3e — Cuerpos de hombre y mujer: diseño

## Objetivo
El tipo de cuerpo pasa a ser **Hombre** o **Mujer**, en lugar de *Esbelto* o *Robusto*. Cada uno tiene su cara y sus proporciones. Mira lleva el de mujer, con el aspecto nuevo de la 0.15.1 (su atuendo vóxel propio). Sale como **0.16.0**.

## Decisiones del usuario
- **Cara propia y proporciones, con las armaduras como están** (opción 1):
  - una cabeza de mujer para humanos, elfos y enanos;
  - proporciones propias (hombros, cintura, caderas y brazos);
  - el pecho como pieza del cuerpo que se oculta bajo las armaduras de pecho;
  - no se rehacen las ~300 piezas de equipo.
- **Personajes guardados:** *esbelto* pasa a **mujer** y *robusto* a **hombre**, solo.
- **PNJ:** los asigna Claude según quién es cada uno.

## Enfoques considerados
| Enfoque | Qué supone | Elegido |
|---|---|---|
| **1. Cara y proporciones; pecho que se oculta bajo armadura** | Cabeza nueva, escalas por parte y una pieza de pecho con su etiqueta. | **Sí**: nada se atraviesa y las armaduras no cambian. |
| 2. Cuerpo de mujer completo | Torso y caderas propios, y todo el equipo rehecho para él. | No: un plan entero de arte. |

## Fuera de alcance
- Cara de mujer para ogros y lagartos (cabeza propia de su raza): solo cambian de proporciones.
- Rehacer armaduras o ropa por cuerpo.
- Cambiar el aspecto de un personaje ya creado.

## Antifines
- Que una armadura de pecho deje asomar el pecho del cuerpo.
- Que un personaje guardado pierda su aspecto o no cargue.
- Que la ventana de creación necesite scroll.

## Diseño
1. **Datos (`data/characters/appearance.json`):** la lista `body` pasa a tener `male` (*Hombre*) y `female` (*Mujer*), cada uno con:
   - `scale`:
     - hombre: torso `[1.08, 1, 1.06]`, brazo `[1.06, 1, 1.06]`, pierna `[1.04, 1, 1.04]`;
     - mujer: torso `[0.9, 1, 0.94]`, brazo `[0.86, 1, 0.88]`, pierna `[0.96, 1, 0.98]`;
   - `head`: `""` para el hombre y `"female"` para la mujer (si la raza tiene cabeza propia, manda la de la raza);
   - `pieces`: la mujer lleva `bust_female`.
   - Los nombres de texto son `BODY_MALE` y `BODY_FEMALE`.
2. **Cabeza de mujer** (`tools/art/human_v2.mjs`, `headFemaleV2()`; `make_humans.mjs` la escribe en `heads.female` de `human_v2.json`):
   - mandíbula y barbilla más estrechas, pómulos más altos;
   - cejas de una fila, más finas;
   - pestañas oscuras sobre cada ojo;
   - labios más llenos (dos filas de color de labio);
   - nariz más corta.
3. **Pieza `bust_female`** (pieza v2 del cuerpo, parte `torso`, en `tools/art/clothes_v2.mjs` o `make_pieces_v2.mjs`):
   - dos volúmenes suaves en el pecho, del color de la ropa (tinte primario), para que se vea con la ropa básica de cada clase;
   - etiqueta `bust`;
   - `CharacterCatalog.resolve` la oculta si lleva una pieza de pecho de equipo (el hueco `chest` de su equipo tiene `look`) o una pieza de pecho propia (`pieces` de un PNJ con parte `torso`).
4. **Paso de los viejos:** `CharacterCatalog.sanitize_appearance` traduce `slim` a `female` y `robust` a `male` antes de comprobar. Así los guardados, los PNJ que falten y los datos de red viejos cargan sin cambiar de versión de guardado.
5. **PNJ:**
   - **mujer:** Mira, Verrin, la anciana cantora, las aldeanas ancianas, las ciudadanas, Oriel y la herida;
   - **hombre:** el resto.
6. **Creación de personaje:** el selector de cuerpo muestra *Hombre* y *Mujer*; la vista previa cambia de cara y de proporciones.

## Pruebas (GUT)
- `sanitize_appearance` cambia `slim` por `female` y `robust` por `male`, y un personaje guardado con `slim` carga como mujer.
- `resolve` con cuerpo de mujer:
  - usa la cabeza `female` para un humano y la de la raza para un ogro;
  - lleva `bust_female`;
  - con un pecho de equipo, no la lleva.
- Las dos opciones de cuerpo tienen nombre traducido. Ningún PNJ usa `slim` ni `robust`.
- Mira es mujer y no lleva `bust_female`, porque su atuendo lleva pecho propio.
- Arte (Node): la cabeza de mujer y la pieza de pecho caben y son distintas de las del hombre.

## Tareas
- [ ] Cabeza `female` y pieza `bust_female` (arte y datos).
- [ ] Opciones de cuerpo nuevas, paso de los viejos, `resolve` (cabeza, pecho y ocultarlo) y PNJ.
- [ ] Creación de personaje y capturas de comprobación.
- [ ] Suite, versión 0.16.0, notas, GDD (04 Personajes), registro y `Planes.md`.

---
← [[Planes]]
