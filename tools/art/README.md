# Scripts de arte de los personajes

Generan el arte de `assets/characters/`. Usan solo Node (sin dependencias). El resultado se guarda en el repositorio, así que solo hace falta volver a ejecutarlos al cambiar el arte.

## Origen
Pack **Kenney Blocky Characters 2.0** (CC0), de [kenney.nl/assets/blocky-characters](https://kenney.nl/assets/blocky-characters). Se descarga el zip y se descomprime fuera del repositorio. Del pack solo se copian `character-a.glb` y su textura a `assets/characters/base/`.

## Comandos
```bash
# Capas de la cabeza recortadas de las texturas de Kenney (piel, ojos, cejas, cara, peinados, barbas)
node tools/art/extract_layers.mjs "<pack>/Models/GLB format/Textures" assets/characters/layers
# Ropa inicial de las clases
node tools/art/paint_outfits.mjs assets/characters/layers
# Piezas vóxel (.vox): pelos con volumen y tocados. Imprime el desplazamiento de cada una sobre la cabeza.
node tools/art/make_pieces.mjs assets/characters/pieces
```

## Capturas para revisar el arte
Con ventana (no `--headless`):
```bash
"$GODOT" --path . -s tests/helpers/render_characters.gd -- --set=spike
```
Guarda la imagen en `user://render/<set>.png`.

## Archivos
- `png.mjs`: lee y escribe PNG.
- `layout.mjs`: zonas de la plantilla UV de Kenney (16 px por vóxel).
- `vox.mjs`: escribe `.vox`. Recibe los ejes de Godot (Y hacia arriba) y los convierte a los de MagicaVoxel (Z hacia arriba). Índices teñibles: 250 pelo, 251 color principal de la clase, 252 secundario.
