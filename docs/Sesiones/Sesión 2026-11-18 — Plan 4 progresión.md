---
tags: [sesion]
fecha: 2026-11-18
tipo: desarrollo
---
# Sesión 2026-11-18 — Plan 4: progresión

## Objetivo
Implementar el [[Plan 4 — Progresión (spec)|Plan 4]]: experiencia y niveles sin tope, desbloqueos, atributos, talentos, arena que escala y mejoras de clase del nivel 50, todo guardado con el personaje.

## Qué se hizo
- **Fase A (Tasks 1–10):** curva de experiencia y reparto por cercanía, monstruos con nivel y arena de 1 a 60, atributos y `Progression.rebuild` (un único sitio que calcula las estadísticas), desbloqueos por nivel, árbol de talentos de 66 nodos con maestrías, peticiones validadas por el anfitrión, protocolo 6, personajes versión 3 y la interfaz (barra de experiencia, ventanas C y T, menú de Brann, nivel en nombres). Parada para la prueba del usuario.
- **Task 11:** kit nuevo del Asesino y habilidades que se repiten o se canalizan.
- **Task 12:** armazón de mejoras (datos, elegir con Brann, evolución, ventana, red).
- **Task 13:** efectos genéricos (rayo, abanico, escudo que refleja, rebote…), estados nuevos, 18 ganchos y aliados invocados.
- **Tasks 14–18:** las 12 mejoras de las 5 clases ([[D-013 Mejoras del nivel 50 revisadas]]).
- **Task 19:** revisión final del diff por un revisor nuevo, documentación y versión 0.6.0 ([[D-012 Brann como instructor provisional y arena que escala]]).

## Qué se probó
- Suite GUT completa en verde. La prueba jugando de la Fase B está pendiente.

## Problemas encontrados
- La clave `type` del efecto `summon` chocaba con el efecto: el monstruo se indica con `monster`.
- La evolución del Templario apuntaba a `cleric_holy_flash`, que no existe: es `cleric_smite`.
- El proyectil «virote» no tiene dibujo propio.

## Ajustes tras la prueba
- Mejora de nivel 50 obligatoria (ventana automática, Esc no la cierra, sin Brann para la primera elección).
- Monstruos y aliados invocados exigen línea de visión para atacar.
- Nombre del jugador en tamaño de mundo.
- Tema holográfico azul, ventana C con modelo y huecos de objetos, ventana K en lista.

## Siguiente paso
- Prueba del usuario, revisión de arte (casco templario, ballesta, lobo, iconos) y publicación de la 0.6.0.

---
← [[Sesiones]]
