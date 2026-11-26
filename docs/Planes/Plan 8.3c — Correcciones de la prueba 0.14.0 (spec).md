---
tags: [plan, spec]
plan: 8.3c
fecha: 2026-11-26
estado: hecho
actualizado: 2026-11-26
---
# Plan 8.3c — Correcciones de la prueba 0.14.0: diseño

## Objetivo
Corregir lo que el usuario encontró al probar la 0.14.0. Sale como **0.14.1**.

## Errores y arreglos
| # | Error del usuario | Causa | Arreglo |
|---|---|---|---|
| 1 | Antes de tener clase, el clic derecho y el izquierdo tienen el mismo icono; solo debe haber clic izquierdo | La 8.3a dio al aldeano un ataque secundario (`villager_shove`) para practicar el clic derecho | Se quita `villager_shove`. **La práctica del muñeco ya no pide golpes con el clic derecho**: queda golpear (clic izquierdo) y esquivar. |
| 2 | Otros PNJ dicen «Hablar con Brann» | El aviso sobre la cabeza de los PNJ usaba el texto de la 0.5.0 (`CLASS_CHOICE_TALK`) | Aviso nuevo `[E] Hablar` (`UI_TALK_PROMPT`). Se actualizan también los textos que aún mandaban a Brann (descripción del aldeano, pista de la ventana K, aviso de la mejora). |
| 3 | El clic y los números en los diálogos lanzan habilidades | El clic o el número que cierra el diálogo (o elige una opción) se leía en el mismo fotograma como ataque o habilidad | Al cerrarse un diálogo, una escena o una ventana que bloquea, el juego sigue sin atacar **0,25 s** más. |
| 4 | Hablar no hace zoom | La cámara isométrica es ortográfica: acercarla no cambia su tamaño | El acercamiento (`focus`) también reduce el tamaño de la vista. |
| 5 | La ventana de misiones no está pegada a la derecha | Medía 240 px y empezaba en el borde izquierdo del minimapa (180 px), así que se salía 48 px por la derecha | Pegada al margen derecho y creciendo hacia la izquierda. |
| 6 | El jugador se ve dos veces en las escenas | El avatar propio se volvía a mostrar en cada fotograma al sincronizar a los jugadores | Mientras dura una escena, el avatar propio sigue oculto. |
| 7 | Los objetos de misión deben caer al suelo (cazas, botín de enemigos…) | Iban directos a la bolsa | Caen junto al monstruo como el resto del botín personal y se recogen al pasar por encima; al recogerlos cuentan para la misión. Nunca caen más de los que faltan, contando los que ya están en el suelo. **(Decisión del usuario.)** |
| 8 | PNJ duplicados en las escenas | Solo se ocultaban los PNJ colocados; los aldeanos y ciudadanos que pasean (`walkers`) seguían ahí | También se ocultan los paseantes que salen como actores, y se vuelven a mostrar al acabar. |
| 9 | (encontrado al arreglar el 8) Los aldeanos que pasean no salían en la zona inicial hasta cambiar de zona | `place_walkers` solo se llamaba al cambiar de zona | También al crear la partida. |

## Pruebas (GUT)
- (1) El aldeano no tiene ataque secundario y `prologo_1` no tiene objetivo `hit_secondary`.
- (2) El aviso de un PNJ cualquiera es `[E] Hablar`; ningún texto en uso menciona a Brann como instructor.
- (3) Tras cerrar el diálogo, durante 0,25 s, `input_blocked` sigue activo.
- (4) Con `focus(true)` el tamaño de la vista ortográfica baja.
- (5) El borde derecho del recuadro coincide con el del minimapa.
- (6) Durante una escena, el avatar propio está oculto aunque se sincronice.
- (7) Un objetivo `collect` deja el objeto en el suelo para su dueño, no en la bolsa; al recogerlo, el contador sube; no cae uno de más si ya hay uno en el suelo.
- (8) Un paseante que sale como actor se oculta durante la escena y vuelve después.

## Tareas
- [x] Arreglos 1–8 con sus tests.
- [x] Suite completa en verde.
- [x] Versión 0.14.1, notas de la versión, GDD y registro, `Planes.md`.
- [x] Commit y subida a main.

---
← [[Planes]]
