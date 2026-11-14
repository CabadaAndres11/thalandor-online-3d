---
tags: [sesion]
fecha: 2026-11-14
tipo: desarrollo
---
# Sesión 2026-11-14 — Plan 2: personajes vóxel

## Objetivo
Cerrar el Plan 1 y hacer el Plan 2: personajes vóxel propios, guardados y visibles en grupo (versión 0.2.0).

## Qué se hizo
- **Cierre del Plan 1** con revisión independiente:
  - con WebRTC, el tercer jugador no podía entrar, porque el servidor de enlace repetía ids;
  - un invitado podía meter valores NaN en la simulación;
  - los dos fallos están corregidos y con tests;
  - la prueba entre casas queda aplazada.
- **Diseño:** [[Plan 2 — Personajes vóxel (spec)]] y [[Plan 2 — Personajes vóxel (plan)]].
  - El usuario eligió packs gratuitos y el enfoque de capas de textura más piezas vóxel.
  - La base es **Kenney Blocky Characters 2.0** (CC0).
- **Arte**, generado con scripts de `tools/art/`:
  - capas recortadas de las texturas de Kenney (piel, ojos, cejas, peinados y barbas) y ropa pintada para las 5 clases;
  - piezas `.vox`: 4 peinados con volumen, sombrero, capuchas, pañuelo y hombreras;
  - **dos puntos de control** con capturas. El usuario pidió una armadura medieval para el Guerrero, con peto, malla, faldón y hombreras vóxel.
- **Código:**
  - lector de `.vox` y generador de mallas teñibles;
  - catálogo en `data/characters/` que sanea apariencias;
  - `CharacterRig` (modelo, shader de capas y piezas) y avatar animado (reposo y andar);
  - `CharacterData` y `CharacterStore` (hasta 8 personajes, archivos con versión, exportar e importar);
  - pantallas "Tus personajes" y "Crear personaje";
  - protocolo 2, con la clase y la apariencia, saneadas por el anfitrión.

## Qué se probó
- **Automático:** 262 tests de GUT en verde, incluida la prueba con dos procesos reales. En ella el invitado entra como arquero con coleta y el anfitrión lo ve así.
- **Juego real:** se ejecutó con `run_project`, sin errores. Las pantallas se revisaron con capturas a 1280×720.
- **Pruebas de juego:** pendientes del usuario.

## Problemas encontrados
- En la plantilla de Kenney la cabeza tiene escala 0,1 y el torso es padre de los brazos y la cabeza. Las piezas compensan la escala de toda la cadena, y el cuerpo robusto no agranda la cabeza.
- La posición del jugador propio solo cambia en los ticks de física, así que la velocidad para animar se suaviza para que no parpadee entre reposo y andar.
- Al aclarar colores muy claros el script de arte se pasaba de 255 y salían líneas cian en la ropa. Ya se limita el valor.
- Con ENet, en el mismo PC, el ping sale de ~100 ms frente a ~34 ms de WebRTC. Medido aparte, ENet tarda un solo tick, así que la causa sigue sin localizar.

## Siguiente paso
- Con permiso del usuario: volver a desplegar el servidor de enlace (ids que no se repiten), juntar la rama `plan-2-characters` con `main`, subir y publicar la 0.2.0.
- Pruebas de juego del usuario: crear varios personajes, jugar solo y en grupo, exportar e importar.
- Plan 3 (combate y clases).

---
← [[Sesiones]]
