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

## Tercera tanda
Casco del ogro, sin barbas para ogros, bosque (sin cripta antigua ni franja de agua), fuente y Corwin en la capital, palacio rediseñado (nobles, estatuas, archivo, escalera y portón de la cripta con guardias, sin cartel), capturas de carga y carga sin congelación previa. Suite GUT: 1835 pruebas, todas pasan.

## Cuarta tanda
Capuchas según la referencia (`hood_v2.mjs`), casco del ogro más pequeño, palacio rehecho (estrado con escalones, estatuas gigantes de granito, reja enrasada con escalera detrás, archivo, armería, sala del consejo, nobles en parejas), Oriel en el archivo y sin Archivista real, saludos de PNJ en la ventana de diálogo, escenas de audiencia y descenso reajustadas. Se trabajó en el worktree `acolito-cultista-enemy-3966a7` (el de la rama original no se podía escribir desde la sesión).

## Entorno
Tests en dos niveles (`tests/slow`, `--all`), JSON de datos compactos y planes terminados archivados en `docs/Archivo`, para gastar menos tiempo y tokens. CLAUDE.md recoge el flujo nuevo.

## Quinta tanda
Pociones en su botón con iconos nuevos; mercader con varias rarezas; palacio (antorchas de pared, escalera a la cripta, armería con modelos reales y lanza, ropa de corte, nobles que hablan), capital (torres, sin pozo, interiores alternos, vecinos, niños y otras razas, PNJ menores sin nombre ni punto en el mapa) y textos de misiones más grandes. Pendiente: plan del árbol de talentos estilo PoE.

## Plan 8.3g — Árbol de talentos en anillos
Spec y plan acordados con el usuario (anillos conectados, todo disponible, ruta marcada, holograma con iconos de estadística). 19 iconos pintados por el usuario con IA. Implementado: generador con rutas, reglas sin anillos, guardado v8 y ventana con zoom y arrastre.

## Sexta tanda
Capuchas sin frontal ni sombra en la cara, escalera de la cripta entrando desde el norte y sin parpadeo, nuevos aspectos de Verrin y del rey (piezas `verrin_*` y `king_*` en `gear_armor_v2.mjs`).
