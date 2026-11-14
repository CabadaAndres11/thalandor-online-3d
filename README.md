# Thalandor Online

RPG de acción en **3D vóxel** con cámara isométrica, hecho en **Godot 4**, para jugar online con hasta 4 amigos.

- **Diseño (GDD):** bóveda de Obsidian en [`docs/`](docs/00%20Inicio.md), empezando por `docs/GDD/00 Índice del GDD.md`.
- **Descargas:** en [Releases](../../releases).

## Desarrollo
- Godot **4.7.2** estable, GDScript con tipado estático.
- Tests con [GUT](https://github.com/bitwes/Gut): `./run_tests.sh` (variable `GODOT` con la ruta del ejecutable de consola de Godot).
- Estructura: `sim/` reglas puras · `net/` red · `game/` escenas · `ui/` interfaz · `save/` guardado · `data/` contenido · `tests/` tests.

Licencia del código: por decidir. Créditos de assets en `CREDITS.md` cuando los haya.
