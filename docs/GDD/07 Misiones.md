---
tags: [gdd]
estado: en curso
actualizado: 2026-11-26
---

# 7. Misiones **[En curso]** (motor implementado en la 0.12.0, [[Plan 8.2 — Misiones, diálogos y escenas (spec)|Plan 8.2]]; las misiones del guion llegan en la 8.3)

- **Tipos:** matar X, recoger objetos que sueltan los monstruos, hablar con alguien o entregarle un objeto, explorar una ubicación, derrotar a un jefe.
- **Cadenas:** se encadenan mediante requisitos (misión previa completada, nivel mínimo, clase).
- **Progreso por personaje.** En grupo, una muerte cuenta para todos los miembros cercanos que tengan la misión activa.
- **Recompensas:** experiencia, oro y, opcionalmente, un objeto a elegir entre varios.
- **Misiones especiales:** prueba de rango de clase (nivel 50) y misiones de cambio de clase ([[04 Personajes y progresión|§4.9]]).

## Motor de misiones (0.12.0) **[Implementado]** ([[D-018 Misiones en el anfitrión con objetivos fijos y marcas]])
- **Misiones como datos** en `data/quests/<id>.json`: pasos en orden; dentro de un paso, objetivos en cualquier orden. Requisitos (misiones previas, nivel, clase, marcas que hacen falta o que lo impiden), `auto` (empieza sola), quién la da y a quién se entrega, diálogos de oferta, progreso y entrega, objetos que entrega al empezar (`give`).
- **Tipos de objetivo:** `talk`, `deliver`, `kill`, `collect`, `reach`, `interact`, `scene` y `choice`. Matar, recoger y llegar cuentan para todos los del grupo que estén a 30 m y tengan ese objetivo; hablar, examinar, escenas y decisiones son de cada uno. Un mismo monstruo cuenta para todos los objetivos del paso a la vez.
- **Al terminar un paso o la misión** (`on_done`): marcas de historia, marcas del personaje (`tutorial_done` abre el juego en grupo), una escena, un momento a solas, objetos y la misión siguiente.
- **Recompensas:** `levels` da la experiencia que piden los siguientes niveles (se conserva la que ya llevabas), además de oro, objetos y uno a elegir. Sin sitio en la bolsa, la entrega se rechaza sin perder nada.
- **Objetos de misión** (`slot: "quest"`): van a la bolsa apilados hasta 99, con borde dorado y la etiqueta *Objeto de misión*. No se venden, no se equipan, no se usan ni salen de la bolsa; solo la misión los quita al entregarlos, terminarla o abandonarla.
- **Lo lleva el anfitrión**, como el nivel y la bolsa; las peticiones del cliente (`QUEST_ACTION`) se comprueban: distancia al PNJ o al punto, que el paso lo pida, que la marca la ofrezca el diálogo.
- **Comandos de prueba** del anfitrión: `/mision <id>`, `/mision paso`, `/mision fin`, `/mision borrar <id>`, `/marca <nombre>`, `/marca quitar <nombre>`.
- **Cadena de ejemplo** (provisional, se borra en la 8.3): *Un encargo de Brann*, *Lobos en el camino* y *Lo que vio la noche*.

## Diálogos (0.12.0) **[Implementado]**
- `data/dialogues/<id>.json`: nodos de líneas y opciones solo donde importan. Una opción puede pedir o impedir marcas, desaparecer tras usarse, poner marcas o lanzar una acción (aceptar, entregar, comerciar, entrenar o una escena). Al volver a un nodo ya visto se salta a sus opciones.
- **Qué dice cada PNJ** a cada jugador: primero la entrega, luego un objetivo con él, luego una misión que ofrecer, el progreso, sus propias entradas `talk` y, si no hay nada, lo de siempre (tienda, menú de Brann o un saludo).
- Los textos usan `{nombre}` y `{apodo}` (*Thal An Dor* desde la marca `apodo`).

## Escenas (0.12.0) **[Implementado]**
- `data/cutscenes/<id>.json`: actores (PNJ, monstruos, el propio jugador o un aspecto suelto) y pistas en paralelo con pasos de cámara, mover, pose, línea, espera, fundido, ambiente, mostrar, ocultar, temblor y efectos. `stage` es la zona del jugador o una zona y variante aparte, para las escenas [ANIMACIÓN].
- Mientras la ve, el jugador está **a salvo** (estado `in_scene`, 120 s como mucho): no se mueve, los monstruos no lo eligen ni le dañan. Una escena espera a que acabe el combate.

## Momentos a solas (0.12.0) **[Implementado]**
- Un paso con `moment` manda al jugador a **su propia copia** de una variante de zona (`aldea~noche#p<id>`); nadie más entra y se cierra cuando se queda vacía. Si sale dentro, vuelve a ella; si muere, reaparece dentro. Con `moment: null` vuelve a la zona compartida.

---
← [[00 Índice del GDD|Índice del GDD]]
