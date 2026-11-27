---
tags: [gdd]
estado: en curso
actualizado: 2026-11-26
---

# 7. Misiones **[En curso]** (motor implementado en la 0.12.0, Plan 8.2; prólogo en la 0.13.0 y la 0.14.0, Plan 8.3a y Plan 8.3b; el arco 1 en la 8.4–8.5)

- **Tipos:** matar X, recoger objetos que sueltan los monstruos, hablar con alguien o entregarle un objeto, explorar una ubicación, derrotar a un jefe.
- **Cadenas:** se encadenan mediante requisitos (misión previa completada, nivel mínimo, clase).
- **Progreso por personaje.** En grupo, una muerte cuenta para todos los miembros cercanos que tengan la misión activa.
- **Recompensas:** experiencia, oro y, opcionalmente, un objeto a elegir entre varios.
- **Misiones especiales:** prueba de rango de clase (nivel 50) y misiones de cambio de clase ([[04 Personajes y progresión|§4.9]]).

## Motor de misiones (0.12.0) **[Implementado]** ([[D-018 Misiones en el anfitrión con objetivos fijos y marcas]])
- **Misiones como datos** en `data/quests/<id>.json`: pasos en orden; dentro de un paso, objetivos en cualquier orden. Requisitos (misiones previas, nivel, clase, marcas que hacen falta o que lo impiden), `auto` (empieza sola), quién la da y a quién se entrega, diálogos de oferta, progreso y entrega, objetos que entrega al empezar (`give`).
- **Tipos de objetivo:** `talk`, `deliver`, `kill`, `collect`, `reach`, `interact`, `scene`, `choice` y, desde la 0.13.0, `hit` y `hit_secondary` (golpes a un tipo de monstruo, con el ataque básico o el secundario), `dodge` (esquivas) y `class` (tener clase). Cualquier objetivo puede llevar `label`: el texto que muestra el recuadro, con su cuenta. Desde la 0.14.1 lo que se recoge cae al suelo junto al monstruo, como botín personal, y cuenta al recogerlo. Matar, recoger y llegar cuentan para todos los del grupo que estén a 30 m y tengan ese objetivo; hablar, examinar, escenas y decisiones son de cada uno. Un mismo monstruo cuenta para todos los objetivos del paso a la vez.
- **Al terminar un paso o la misión** (`on_done`): marcas de historia, marcas del personaje (`tutorial_done` abre el juego en grupo), una escena, un momento a solas, objetos y la misión siguiente.
- **Recompensas:** `levels` da la experiencia que piden los siguientes niveles (se conserva la que ya llevabas), además de oro, objetos y uno a elegir. Sin sitio en la bolsa, la entrega se rechaza sin perder nada.
- **Objetos de misión** (`slot: "quest"`): van a la bolsa apilados hasta 99, con borde dorado y la etiqueta *Objeto de misión*. No se venden, no se equipan, no se usan ni salen de la bolsa; solo la misión los quita al entregarlos, terminarla o abandonarla.
- **Lo lleva el anfitrión**, como el nivel y la bolsa; las peticiones del cliente (`QUEST_ACTION`) se comprueban: distancia al PNJ o al punto, que el paso lo pida, que la marca la ofrezca el diálogo.
- **Comandos de prueba** del anfitrión: `/mision <id>`, `/mision paso`, `/mision fin`, `/mision borrar <id>`, `/marca <nombre>`, `/marca quitar <nombre>`.
- Una misión puede llevar su propio `moment` (vale desde el primer paso) y su propio `give`, que acepta también objetos normales (pociones).
- La cadena de ejemplo de la 0.12.0 se ha borrado.

## El prólogo (0.13.0) **[Implementado]** (Plan 8.3a, [[D-019 Prólogo como tutorial y clase en el asalto]])
- Es el **tutorial**: cada paso enseña algo con una frase en el recuadro bajo el minimapa (*Muévete con WASD hasta Mira*, *Golpes al muñeco 3/10*).
- **La víspera** (`prologo_1`, empieza sola al crear el personaje, a solas en `aldea/vispera`): llegar a Mira y hablar con ella, los tres recados de Brann (al panadero, al cazador y a la anciana), el muñeco de práctica (10 golpes y 3 esquivas; desde la 0.14.1 sin clic derecho, porque el aldeano no lo tiene; Brann da 2 pociones), la colina al atardecer y la fiesta con el cuerno.
- **El asalto** (`prologo_2`, a solas en `aldea/asalto`; desde la 0.15.0 las peleas y el secuestro pasan en la escena y los enemigos aparecen al elegir clase, con la marca `despertar`): seguir a Mira, la plaza y el secuestro, perseguir a Mira y **elegir la clase** cuando despierta el poder (la ventana sale sola y no se cierra sin elegir), el alba, 4 sabuesos y **el Heraldo**, que huye al 10 %, y Brann caído en la puerta. Al terminar: 2 niveles, la marca `tutorial_done` y la vuelta a la aldea en ruinas.
- **Llegan tarde** (`prologo_3`, en el mundo compartido): ayudar a los supervivientes, la llegada de Verrin, el rastro en el bosque (campamento, máscara, huellas de carro y el río), la anciana llama al héroe *Thal An Dor* (marca `apodo`) y Verrin habla de la capital. 1 nivel y la marca `prologo_3_hecho`. La **máscara del culto** se queda en la bolsa para la 8.3b.
- **La capital** (`prologo_4`, 0.14.0, Plan 8.3b): en el mundo compartido, tras *Llegan tarde*. La caravana del Camino de Sumerhold y la emboscada (4 bandidos, 2 arqueros y el cabecilla), la llegada a Sumerhold, la audiencia con el rey, Oriel y lord Maren, la máscara para Oriel y el encargo del rey, que pone la marca `cripta_abierta` y abre la reja de la cripta. 1 nivel, 100 de oro y la marca `prologo_hecho`.
- Si el Heraldo huye antes de su paso, vuelve a su sitio; los sabuesos del alba reaparecen y la defensa tiene 8 cultistas para los 6 que pide: ninguna misión se queda sin enemigos.

## Diálogos (0.12.0) **[Implementado]**
- `data/dialogues/<id>.json`: nodos de líneas y opciones solo donde importan. Una opción puede pedir o impedir marcas, desaparecer tras usarse, poner marcas o lanzar una acción (aceptar, entregar, comerciar, entrenar o una escena). Al volver a un nodo ya visto se salta a sus opciones.
- **Qué dice cada PNJ** a cada jugador: primero la entrega, luego un objetivo con él, luego una misión que ofrecer, el progreso, sus propias entradas `talk` y, si no hay nada, lo de siempre (tienda, menú de Brann o un saludo).
- Los textos usan `{nombre}` y `{apodo}` (*Thal An Dor* desde la marca `apodo`).
- Brann ya no enseña clases ni reinicia (0.13.0): la acción de entrenar se ha quitado.

## Escenas (0.12.0) **[Implementado]**
- `data/cutscenes/<id>.json`: actores (PNJ, monstruos, el propio jugador o un aspecto suelto) y pistas en paralelo con pasos de cámara, mover, pose, línea, espera, fundido, ambiente, mostrar, ocultar, temblor y efectos. `stage` es la zona del jugador, `player` (las casillas cuentan desde donde está el jugador, 0.13.0) o una zona y variante aparte, para las escenas [ANIMACIÓN]. Poses `kneel`, `point` y `lie`; efectos `fire`, `smoke` y `flash`; una línea de `""` es narración y un monstruo habla con su nombre. Los PNJ colocados que salen como actores se esconden mientras dura.
- Mientras la ve, el jugador está **a salvo** (estado `in_scene`, 120 s como mucho): no se mueve, los monstruos no lo eligen ni le dañan. Una escena espera a que acabe el combate.

## Momentos a solas (0.12.0) **[Implementado]**
- Un paso con `moment` manda al jugador a **su propia copia** de una variante de zona (`aldea~asalto#p<id>`); nadie más entra y se cierra cuando se queda vacía. Si sale dentro, vuelve a ella; si muere, reaparece dentro. Con `moment: null` vuelve a la zona compartida.

---
← [[00 Índice del GDD|Índice del GDD]]
