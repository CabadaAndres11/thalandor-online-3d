# Scripts de arte

Generan todo el arte del juego como datos: vóxeles y paletas escritos por código, sin recursos de terceros. Usan solo Node, sin dependencias. El resultado se guarda en el repositorio, así que solo hace falta volver a ejecutarlos al cambiar el arte.

## Comandos
```bash
# Humanoide (jugadores, cultistas, PNJ): una .vox por parte y human.json con los pivotes
node tools/art/make_humans.mjs assets/characters/vox
# Piezas: peinados, barbas, ropa de clase, tocados y armas, y su tabla
node tools/art/make_pieces.mjs assets/characters/pieces data/characters/pieces.json
# Monstruos vóxel (rigs por partes)
node tools/art/make_monsters.mjs assets/monsters/vox
# Props del mundo (antorcha), a vóxel de 5 cm
node tools/art/make_props.mjs assets/props
# Iconos de habilidades y estados
node tools/art/make_icons.mjs assets/icons
```

## Capturas para revisar el arte
Con ventana (no `--headless`):
```bash
"$GODOT" --path . -s tests/helpers/render_characters.gd -- --set=classes
```
Guarda la imagen en `user://render/<set>.png`. Otros sets: `variety`, `actions`, `grip`, `boss`, `acolyte`, `vaelthar`, `nhazar` e `inquisitor` (el enemigo de frente, de lado y de espaldas).

## Archivos
- `vox.mjs`: escribe `.vox`. Recibe los ejes de Godot (Y hacia arriba) y los convierte a los de MagicaVoxel (Z hacia arriba).
  - Índices teñibles: 247 pantalón, 248 piel, 249 ojos, 250 pelo, 251 color principal, 252 secundario.
  - `SHADE(t)` y `LIGHT(t)` dan el tono oscuro y el claro de cada tinte.
  - 253 brilla sin sombreado.
- `png.mjs`: lee y escribe PNG (iconos).
