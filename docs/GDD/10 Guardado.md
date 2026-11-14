---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 10. Guardado **[En curso]** (personajes, versiones y exportación hechos en la 0.2.0; falta el autoguardado del progreso)

- **Archivos JSON** por personaje en `user://saves/` (en Windows, la carpeta de datos del usuario).
- **Autoguardado:** la posición cada 30 s, al cambiar de zona y al salir; el progreso y el inventario cada vez que el host los cambia (en cola, sin escrituras simultáneas).
- **Exportación e importación:** cada personaje se puede exportar e importar como archivo, como copia de seguridad o para jugar desde otro PC.
- **Versiones del guardado:** cada guardado lleva un número de versión y se migra automáticamente al actualizar el juego. Ninguna actualización puede borrar personajes ni objetos (lo que no quepa va a casillas extra).

---
← [[00 Índice del GDD|Índice del GDD]]
