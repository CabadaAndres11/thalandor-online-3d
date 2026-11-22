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

## Vóxel 2× (Plan 6.2)
```bash
# Cuerpo v2 (lo escribe make_humans.mjs junto al v1, en assets/characters/vox_v2)
node tools/art/make_humans.mjs assets/characters/vox
# Piezas v2 (pelo y barbas; después ropa, tocados y armas)
node tools/art/make_pieces_v2.mjs assets/characters/pieces_v2 data/characters/pieces_v2.json
# Tests de la librería de esculpido y de los generadores
node --test tools/art/tests/
```
- `sculpt.mjs`: formas redondeadas (elipsoide, cápsula, cilindro, caja redondeada), `carve`, `mirrorX`, `shellAround`, `tone` y `shadeByFacing`.
- Tonos de textura de cada canal teñible: `TEX_D(t)` (t − 40) y `TEX_L(t)` (t − 50); `SHADE` y `LIGHT` quedan para la forma.
- Capturas: sets `bodies`, `faces`, `heads` y `heads_back` de `render_characters.gd`.

## Razas y menú (Plan 7)
- `races_v2.mjs`: cabezas del ogro y del lagarto. `make_humans.mjs` las escribe junto al cuerpo v2 (`human_v2_head_<raza>.vox`, apartado `heads` de `human_v2.json`).
- `make_pieces_v2.mjs` añade las orejas élficas, la nariz enana, la cola, las crestas, 8 peinados, 5 barbas y los rasgos de la cara.
- `make_props.mjs` hace el decorado del menú: `altar_sun`, `column_broken`, `brazier`, `candles` y `flagstones`.
- `make_icons.mjs` hace también los iconos del menú (`assets/icons/ui/`).
- Capturas de las razas: `--set=races`, `races_back`, `races_side`, `hair_new`, `faces_new` y `crests`; cualquier set con `_close` acerca la cámara a las cabezas. El equipo en otra raza: `--set=gear --race=ogre --tier=3`.
- Capturas del menú: `-s tests/helpers/render_menu.gd -- --shot=title|select|create` (solo la escena) y `-s tests/helpers/render_main.gd -- --screen=title|select|create` (con la interfaz).

## Mundo (Plan 8.1)
```bash
# Piezas del mundo (casas, bosque, rocas, cripta) y su tabla con las casillas que bloquean
node tools/art/make_world.mjs assets/world data/zones/pieces.json
```
- Capturas de una zona: `-s tests/helpers/render_zone.gd -- --zone=aldea --view=top|iso`.
