---
tags: [sesion]
fecha: 2026-11-27
tipo: desarrollo
---
# Sesión 2026-11-27 — Mazmorra y correcciones del mundo

## Objetivo
Lista de fallos del usuario: mazmorra (misión, cierre, reaparición), sala del trono, capital, marcadores, río, cámaras de escenas, aldea, barbas y relieve.

## Qué se hizo
- Cripta: misión `cripta_1`, sin reaparición (`respawn: false`), cierre a los 12 s tras el jefe (`HostSession._close_cleared_dungeons`).
- Palacio y capital rehechos (piezas `palace_*`, `hedge`, `palace_facade`; casas, puestos, adoquín, gente).
- `ZoneMapImage.quest_target` busca la zona del PNJ y recorre el grafo de zonas.
- Textos "Ayudar"/"Investigar", charco de sangre vóxel, agua texturada, relieve en terrazas.
- Cámaras de río, ejército y despertar recolocadas; herrería movida; barbas del ogro con `piece_fit`.

## Qué se probó
- Suite GUT completa: 1823 pruebas, todas pasan (antes de los últimos ajustes de cámara y barbas).
- Capturas con `tests/helpers/render_shot.gd`.

## Problemas encontrados
- Las cámaras de escena quedaban dentro de casas; las del despertar son relativas al jugador.

## Siguiente paso
- Prueba de juego del usuario: cripta completa, capital, palacio, escenas del prólogo.

---
← [[Sesiones]]

## Segunda tanda
Jefe de cripta con nivel de instancia, mármol, mercado y casas de la capital, carteles, agua y puente del bosque, cámara con el relieve y capturas de carga. Suite GUT: 1829 pruebas, todas pasan.
