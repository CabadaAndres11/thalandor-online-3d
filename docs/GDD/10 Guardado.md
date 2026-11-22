---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-22
---

# 10. Guardado **[En curso]** (personajes, versiones y exportación hechos en la 0.2.0; falta el autoguardado del progreso)

- **Archivos JSON** por personaje en `user://saves/` (en Windows, la carpeta de datos del usuario).
- **Autoguardado:** la posición cada 30 s, al cambiar de zona y al salir; el progreso y el inventario cada vez que el host los cambia (en cola, sin escrituras simultáneas).
- **Exportación e importación:** cada personaje se puede exportar e importar como archivo, como copia de seguridad o para jugar desde otro PC.
- **Versiones del guardado:** cada guardado lleva un número de versión y se migra automáticamente al actualizar el juego. Ninguna actualización puede borrar personajes ni objetos (lo que no quepa va a casillas extra).

## Plan 4 (0.6.0) **[Implementado]**
Personajes **versión 3**: el nivel suelto pasa a `progress` (nivel, experiencia, atributos, talentos, maestrías y mejora). Los personajes de la 0.5.0 (versión 2) entran a nivel 1 sin perder nada más. El anfitrión sanea cualquier progreso que llegue en el HELLO. Las escrituras se agrupan (como mucho una por personaje y fotograma) y se vuelcan al salir.

## Plan 5 (0.7.0) **[Implementado]**
Personajes **versión 4**: oro, bolsa y equipo. Los de la versión 3 entran con el equipo inicial de su clase (el aldeano, con la espada de madera). El anfitrión sanea el inventario que llega en el `HELLO`: lo que no existe se descarta, lo que no se puede llevar va a la bolsa y lo que no cabe ocupa casillas extra.

## Plan 8.1 (0.11.0) **[Implementado]**
Personajes **versión 5**: `place` (zona y casilla) y `tutorial_done`. Los de la versión 4 aparecen en la aldea, con el tutorial ya hecho. El anfitrión coloca a cada jugador según su `place` si la zona existe, no es una mazmorra y la casilla está libre; si no, en la entrada de la zona o en la aldea. Se guarda al cambiar de zona y cada 30 s.

---
← [[00 Índice del GDD|Índice del GDD]]
