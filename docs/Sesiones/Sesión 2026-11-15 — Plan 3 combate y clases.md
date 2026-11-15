---
tags: [sesion]
fecha: 2026-11-15
tipo: desarrollo
---
# Sesión 2026-11-15 — Plan 3 combate y clases

## Objetivo
Terminar el [[Plan 3 — Combate y clases (plan)|Plan 3]]: la 0.3.0 (Tasks 0–8, combate básico) y la 0.4.0 (Tasks 9–15).

## Qué se hizo
- **0.3.0, combate básico:** simulación de combate en el anfitrión, kits de nivel 1, lobos y limos con IA, HUD de combate. Publicada.
- **Task 9:** efectos restantes (escudos, curación en el tiempo, provocar, trampas, sigilo, resurrección…) y los ganchos de las pasivas.
- **Task 10:** kit completo de las 5 clases (7 habilidades usables y 4 pasivas cada una) con sus iconos provisionales.
- **Task 11:** ventana de Habilidades (K) y barra guardada con el personaje (personajes versión 2).
- **Task 12:** jabalí (carga avisada en línea), goblins en manada, esqueleto arquero que se aleja y élites. Arte aprobado (`monsters_b`). Instantánea por jugador con los 32 monstruos más cercanos.
- **Task 13:** jefe Rey orco con 3 fases, barra de jefe, aviso en el chat y arte (piel, corona, colmillos, hacha).
- **Task 14:** amenaza completa, derribo y levantar con E, desangrado, caída de todo el grupo y marcos de aliados.
- **Task 15:** revisión final de la rama (Opus): 7 correcciones con su test; versión 0.4.0, notas, créditos, GDD y valores iniciales en las notas de clase.

## Qué se probó
- Tests automáticos: 504 de 504.
- Capturas: monstruos (`monsters_b`), jefe (`boss`), HUD en combate (`ui_combat`) y ventana K (`ui_abilities`).
- El juego arranca sin errores.
- **Falta la prueba de juego del usuario** de la 0.4.0 (clases, monstruos, jefe y derribo en grupo).

## Problemas encontrados
- La instantánea de red superaba el tamaño de un paquete ENet con los monstruos nuevos: ahora las filas de jugadores y monstruos viajan en binario (protocolo 4).
- Correcciones de la revisión: barra de levantar colgada si te matan levantando; recarga de Sigilo en combate mal mostrada; salto del jefe muerto que aún dañaba; salto sobre muros; goblins del jefe acumulándose; importar un personaje le borraba la barra.

## Siguiente paso
- Prueba de juego de la 0.4.0 con amigos.
- Pendientes menores anotados en el registro del plan (carga del arquero derribado, deslizarse al caer en mitad de la esquiva).
- Plan 4: progresión (niveles, experiencia, pasivas activas).

---
← [[Sesiones]]
