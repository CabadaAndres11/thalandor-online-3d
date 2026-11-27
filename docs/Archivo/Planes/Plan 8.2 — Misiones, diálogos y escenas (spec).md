---
tags: [plan, spec]
plan: 8.2
fecha: 2026-11-23
estado: implementado
actualizado: 2026-11-26
---
# Plan 8.2 — Misiones, diálogos y escenas: diseño

## Objetivo
El **motor de la historia**. Con él, meter el prólogo y el arco 1 del [[Guion]] (8.3–8.5) es escribir datos, no programar:
1. **Misiones como datos** con progreso por personaje, que lleva el anfitrión.
2. **Diálogos** con un PNJ en una ventana nueva, lineales y con opciones solo cuando importan.
3. **Escenas** hechas con los modelos del juego: cámara que se mueve sola, barras negras y subtítulos.
4. **Momentos de la historia** a solas: una zona propia del jugador con otra luz y otro decorado (la víspera y el asalto).
5. **Diario de misiones** (tecla J), objetivo en el HUD y marcas en PNJ, minimapa y mapa.

Sale con una **cadena de misiones de ejemplo** en la aldea y el bosque provisionales que usa todas las piezas, para que el usuario lo pruebe. Las misiones del guion llegan en la 8.3.

## Contexto del guion
- **Misiones 1 y 2 (la víspera y el asalto)** se juegan **a solas**: el juego en grupo se abre al terminar el asalto. Ahí cambian la luz (atardecer, noche, alba), el decorado (fiesta, aldea en llamas) y los PNJ (Brann vivo).
- **Desde la misión 3 el mundo es uno y el mismo para todos:** la aldea en ruinas, Brann muerto. De cada jugador es solo lo suyo: qué misión lleva, qué le dicen los PNJ, sus objetivos y sus decisiones.
- El guion pide objetivos de hablar, entregar, matar, recoger, llegar, examinar pistas, defender por oleadas, jefes por fases, puzles, sigilo, una misión social y una decisión con consecuencias (Maren).

## Fuera de alcance
- Las misiones del guion, sus PNJ, sus decorados y su bestiario: 8.3–8.5.
- **Puzles** (tomos, runas), **sigilo** y la **misión social** del banquete: llegan con la misión que los usa (8.4), como tipos de objetivo nuevos sobre este motor.
- **Defensa por oleadas** y **jefes por fases nuevos**: el motor ya tiene jefes con fases (Plan 4); las oleadas de la misión 10 llegan en la 8.5.
- Voces y música de escena (Plan 11).
- Misiones secundarias y repetibles con contenido propio.
- Pasar del prólogo a los personajes que ya existen: se decide en la 8.3, cuando haya prólogo.

## Antifines
- Que una misión nueva exija tocar `sim/`, `net/` o `ui/`: una misión, un diálogo o una escena son **solo datos**.
- Que la historia de un jugador cambie el mundo de otro: ni PNJ, ni luz, ni monstruos.
- Que una escena le salte encima a un amigo: cada uno ve solo las suyas.
- Que alguien muera viendo una escena.
- Ventanas con scroll a 1280×720.

## Enfoques (decididos con el usuario)
- **Escenas:** con los modelos moviéndose dentro del juego, cámara que se mueve sola, barras negras y subtítulos. *Elección de Claude, delegada por el usuario.* Descartado: vídeos pregrabados (hay que hacerlos aparte, pesan y no llevan el aspecto del personaje).
- **Diálogos:** conversación lineal; opciones solo cuando importan (decisiones, preguntar más). Descartado: respuestas a elegir en todo (el doble de texto y choca con las frases fijas del protagonista) y sin opciones (el banquete pierde gracia).
- **Misiones en grupo:** lo que se hace a golpes (matar, recoger, llegar) cuenta para todos los del grupo que estén cerca y tengan ese objetivo; lo que se habla (diálogos, escenas, decisiones) es de cada uno. Descartado: todo compartido (uno decidiría por todos y las escenas saltarían encima).
- **Dónde viven:** las misiones las lleva el **anfitrión**, como el nivel y la bolsa; diálogos y escenas se ven en el cliente y avisan al anfitrión al terminar. Descartado: que cada cliente cuente lo suyo (un invitado no ve todas las muertes y sería la única regla fuera del anfitrión).
- **Formato:** **tipos de objetivo fijos** y **marcas de historia**, no un lenguaje de scripts. Descartado: scripts genéricos (escribir una misión sería programar).

## Diseño

### 1. Una misión como datos (`data/quests/<id>.json`)
```json
{
  "id": "ej_lobos", "name": "QUEST_EJ_LOBOS", "summary": "QUEST_EJ_LOBOS_SUM",
  "story": true,
  "requires": {"quests": ["ej_encargo"], "level": 1, "flags": [], "not_flags": []},
  "giver": "merchant", "turn_in": "brann",
  "auto": false,
  "steps": [
    {"text": "QUEST_EJ_LOBOS_S1",
     "objectives": [
       {"type": "kill", "monster": "hunter_wolf", "count": 5, "zone": "bosque"},
       {"type": "collect", "item": "q_colmillo", "from": "hunter_wolf", "chance": 0.5, "count": 3}
     ]},
    {"text": "QUEST_EJ_LOBOS_S2",
     "objectives": [{"type": "reach", "zone": "bosque", "point": "claro"}],
     "on_done": {"scene": "ej_huellas"}},
    {"text": "QUEST_EJ_LOBOS_S3",
     "objectives": [{"type": "talk", "npc": "brann", "dialogue": "ej_brann_huellas"}]}
  ],
  "on_done": {"flags": ["ej_lobos_hecho"], "marks": []},
  "rewards": {"levels": 1, "gold": 30, "items": [], "choice": ["weapon_sword", "weapon_bow"]}
}
```
- **Pasos en orden**; dentro de un paso, **todos sus objetivos** a la vez (en cualquier orden). El paso termina cuando se cumplen todos.
- **Tipos de objetivo:**

| Tipo | Se cumple cuando | Quién lo cuenta | En grupo |
|---|---|---|---|
| `talk` | Termina el diálogo indicado con ese PNJ | Cliente avisa; el anfitrión comprueba que está cerca del PNJ | De cada uno |
| `deliver` | Termina el diálogo de entrega y tiene el objeto de misión (`q_…`) | Igual que `talk`; el anfitrión descuenta el objeto | De cada uno |
| `kill` | Mueren `count` monstruos de ese tipo (o etiqueta `tag`), opcionalmente en una zona | Anfitrión, al morir el monstruo | Para todos los cercanos con ese objetivo (mismo radio que la experiencia) |
| `collect` | Junta `count` objetos de misión que caen con probabilidad de ese monstruo | Anfitrión, al morir el monstruo | Cada cercano con el objetivo tira su propia probabilidad y el objeto va a su bolsa |
| `reach` | Pisa el **punto de misión** de la zona | Anfitrión, cada medio segundo | Para todos los del grupo que lo pisen o estén cerca de quien lo pisa |
| `interact` | Pulsa E sobre un punto de misión (huellas, una máscara) | Cliente avisa; el anfitrión comprueba la distancia | De cada uno |
| `scene` | Ve (o salta) la escena | Cliente avisa | De cada uno |
| `choice` | Elige una opción en un diálogo que pone una marca de las indicadas (`any_flag`) | El diálogo pone la marca | De cada uno |

- **Objetos de misión** (`q_…`): **van a la bolsa**, apilados en una casilla, con un borde y una etiqueta *Objeto de misión*. Están **bloqueados**: no se venden, no se equipan, no se tiran ni salen de la bolsa de ninguna forma (el anfitrión rechaza cualquier acción sobre ellos). Solo la misión los quita: al entregarlos (`deliver`) o al terminarla o abandonarla. El contador del objetivo es cuántos lleva en la bolsa. Si la bolsa está llena, el objeto no entra, no cuenta y sale el aviso *Bolsa llena*. **Ordenar** los pone al final. Se definen en `data/items/` como un tipo más (`quest`), con nombre e icono.
- **Puntos de misión:** una zona gana `"quest_points": [{"id": "claro", "at": [x, z], "radius": 3, "look": "sparkle"}]`. `look` es lo que se ve cuando el punto le sirve a alguien: nada, un brillo o una pieza del catálogo (`pieces.json`). Solo lo ve quien tiene ese objetivo activo.
- **`on_done`** de un paso o de la misión: `flags` (marcas de historia que se ponen), `clear_flags`, `marks` (marcas del personaje, p. ej. `tutorial_done`), `scene` (escena que se abre), `moment` (§5) y `next` (misión que empieza sola).
- **Requisitos:** misiones hechas, nivel mínimo, clase (`classes`), marcas que hacen falta o que lo impiden.
- **`auto: true`:** la misión empieza sola en cuanto se cumplen sus requisitos (la historia se encadena sin ir a buscarla). Si no, la da `giver` con un diálogo.
- **`dialogues`** de la misión: `offer` (lo que dice `giver` al ofrecerla; su opción `accept` la empieza), `progress` (si le hablas a medias) y `turn_in` (lo que dice `turn_in` al entregarla; su opción `turn_in` abre la ventana de recompensas). Tienen prioridad sobre los `talk` del PNJ.
- **Recompensas:** `levels` da **la experiencia justa para subir esos niveles desde donde esté** (la regla del Plan 8: 1–2 niveles por misión); `xp` fija si se prefiere; `gold`; `items` fijos; `choice` (uno a elegir en la ventana de entrega).

### 2. El estado de misiones del personaje
- `CharacterData` (versión 6) gana `quests`:
```json
{"active": {"ej_lobos": {"step": 0, "counts": [3, 1]}}, "done": ["ej_encargo"], "flags": ["ej_pregunto_culto"], "tracked": "ej_lobos"}
```
- La migración desde la versión 5 lo deja vacío. Se sanea al cargar: misiones o pasos que ya no existen se quitan; contadores fuera de rango se recortan.
- **Igual que el progreso y la bolsa (Plan 4 y 5):** el invitado lo manda en el saludo (`HELLO` gana `quests`), el anfitrión lo lleva mientras juega y le devuelve cada cambio (`QUESTS`) para guardarlo. El anfitrión lo guarda en su propio personaje del mismo modo.

### 3. Reglas en el anfitrión (`sim/quests/`)
- **`QuestDB`** carga `data/quests/`; **`QuestLog`** es el estado de un jugador (en `PlayerState`); **`QuestRules`** hace avanzar los objetivos.
- **Eventos de la simulación:** al morir un monstruo, `QuestRules` usa la misma lista de jugadores cercanos que `Xp.share` para `kill` y `collect`. `reach` mira posiciones cada medio segundo. Nada de esto cuesta si nadie tiene un objetivo de ese tipo.
- **Peticiones del cliente** (`QUEST_ACTION`, `[action, args]`): `accept`, `talk_done`, `interact`, `scene_done`, `choose_flag`, `turn_in` (con el objeto elegido), `track`, `abandon` (solo misiones que no son de historia). El anfitrión comprueba requisitos, distancia al PNJ o al punto, y que el paso lo pida.
- **Marcas que pone un diálogo:** solo las que la ventana de diálogo ofrecía en ese momento (el anfitrión conoce el diálogo).
- **Cambios** al cliente en `QUESTS` (el estado entero: es pequeño) y un evento `quest_step` / `quest_done` para avisos y sonidos.
- **Comandos de desarrollo:** `/mision <id>` (empieza), `/mision paso`, `/mision fin`, `/mision borrar <id>`, `/marca <nombre>`, `/marca quitar <nombre>`.

### 4. Diálogos (`data/dialogues/<id>.json`)
```json
{
  "id": "ej_brann_encargo",
  "nodes": {
    "start": {"lines": [["brann", "DLG_EJ_B1"], ["player", "DLG_EJ_P1"], ["brann", "DLG_EJ_B2"]],
              "choices": [
                {"text": "DLG_EJ_C_CULTO", "next": "culto", "once": true},
                {"text": "DLG_EJ_C_ACEPTAR", "next": "end", "action": "accept"}
              ]},
    "culto": {"lines": [["brann", "DLG_EJ_B3"]], "flags": ["ej_pregunto_culto"], "next": "start"}
  }
}
```
- **Lineal**: se avanza con E, espacio o clic. Las **opciones** salen solo en los nodos que las tienen (1–4, con número de tecla). Una opción puede pedir o impedir marcas (`if_flags`, `not_flags`), ocultarse tras usarse (`once`), poner marcas (`flags`) o lanzar una acción (`accept`, `turn_in`, `trade`, `train`, `scene:<id>`).
- **Textos** en `textos.csv`, con `{nombre}` (el del personaje) y `{apodo}` (*Thal An Dor*; vacío hasta que la historia lo dé, con una marca).
- **Quién habla:** `player` es el protagonista; cualquier otro es un PNJ por su id (su nombre sale de `data/npcs/`).
- **Qué dice cada PNJ:** el PNJ gana `"talk": [{"when": {"quest": "ej_lobos", "state": "active|done|available|none", "step": 1, "flags": [], "not_flags": []}, "dialogue": "..."}]` (todas las claves de `when` son opcionales). Se usa la primera entrada cuya condición se cumpla (misión activa en tal paso, hecha, no empezada, marcas). Al final, el saludo de siempre. **Brann y el mercader** siguen dando la clase, las mejoras y la tienda como opciones de su diálogo (`train`, `trade`).
- **Ventana:** panel ancho abajo, con el tema de piedra. Lleva el nombre de quien habla y el texto, que aparece letra a letra (un clic lo completa), con las opciones debajo. La cámara se acerca un poco al PNJ y este se gira hacia el jugador. Mientras habla, el personaje no se mueve; si recibe daño o pulsa Esc, la conversación se cierra sin cumplir el objetivo.

### 5. Momentos de la historia (zonas propias y variantes)
- Una zona gana **variantes** en sus datos: `"variants": {"noche": {"ambience": "aldea_noche", "add_pieces": [...], "remove_pieces": ["brann_stall"], "npcs": [...], "hordes": [...], "quest_points": [...]}}`. Una variante solo **añade, quita o cambia** cosas de la zona base.
- **Zona propia:** un paso de misión con `"moment": {"zone": "aldea", "variant": "noche"}` manda al jugador a **su propia copia** de esa variante, como las mazmorras pero solo para él (`aldea~noche#<jugador>`). Nadie más puede entrar. Al terminar la misión o con `"moment": null`, vuelve al mundo compartido.
- **Monstruos de un momento:** las hordas de la variante pueden no reaparecer (`"respawn": false`), para objetivos como *acaba con los cultistas de la plaza*.
- **Guardar a mitad:** si el jugador sale dentro de un momento, al volver el anfitrión lo devuelve a su zona propia (la del paso activo), recreada desde cero. Si el paso ya no tiene momento, va a la zona compartida.
- **Cambio de luz dentro del momento:** un paso o una escena puede cambiar la luz (`"ambience": "aldea_alba"`, con un fundido de unos segundos). En una zona propia no afecta a nadie más.
- En el **mundo compartido** la luz es la de la zona y no cambia con la historia (decisión del usuario: tras el asalto el mundo es siempre el mismo).
- Ambientes nuevos para probar: **atardecer** y **noche con fuego**, en `data/ambiences/`.

### 6. Escenas (`data/cutscenes/<id>.json`)
- **Pistas en paralelo** con pasos en orden; cada paso dura lo que dice o espera a que acabe el anterior:
```json
{
  "id": "ej_huellas", "skippable": true,
  "stage": "here",
  "actors": {"brann": {"npc": "brann", "at": [40, 36], "facing": 90}, "lobo": {"monster": "hunter_wolf", "at": [44, 30]}},
  "tracks": [
    [{"camera": {"at": [42, 8, 40], "look": [42, 0, 33], "fov": 40}, "time": 0},
     {"camera": {"at": [46, 6, 36], "look": [44, 0, 30]}, "time": 4, "ease": "in_out"}],
    [{"fade": "in", "time": 0.8},
     {"line": ["brann", "SCN_EJ_1"], "time": 3},
     {"move": "lobo", "to": [[48, 26]], "speed": 4},
     {"pose": ["brann", "point"], "time": 1.5},
     {"ambience": "aldea_alba", "time": 3},
     {"line": ["player", "SCN_EJ_2"], "time": 2.5},
     {"fade": "out", "time": 0.8}]
  ]
}
```
- **Pasos:** `camera` (posición, a dónde mira, apertura; con fundido entre tomas), `move` (un actor por una ruta, andando o corriendo), `pose` (animación: andar, atacar, orar, señalar, caer, arrodillarse…), `line` (subtítulo con quién habla), `wait`, `fade`, `ambience`, `show` / `hide` (un actor), `shake` (temblor de cámara) y `fx` (fuego, humo, destello de los efectos que ya existen).
- **Actores:** PNJ por id, monstruos por tipo, **el propio jugador** (`"player"`, con su aspecto y equipo) o un aspecto suelto (`"look"`) para cultistas con máscara o Mira. Son **solo visuales**, en el cliente.
- **Escenario:** `"stage": "here"` pasa en la zona donde está el jugador; `"stage": {"zone": "bosque", "variant": "noche"}` construye ese decorado aparte para escenas **[ANIMACIÓN]** (Mira encadenada, la columna del culto), con la pantalla de carga si tarda.
- **Pantalla:** barras negras arriba y abajo, subtítulos con el nombre de quien habla, la interfaz del juego oculta. **Esc** (mantener medio segundo) salta la escena; los subtítulos avanzan solos.
- **A salvo:** mientras ve una escena, el anfitrión marca al jugador **en escena**: no se mueve, los monstruos no lo eligen ni le dañan y no cuenta para la amenaza. Una escena solo empieza **fuera de combate**; si salta en combate, espera a que acabe.
- En grupo, los demás ven al personaje quieto con un icono de escena encima (un estado más del jugador en la instantánea; el protocolo pasa a la versión 9).

### 7. Interfaz
- **Marcas sobre los PNJ:** **!** dorado si tiene una misión para ti, **!** gris si la tendrá pronto (requisito de nivel), **?** dorado si puedes entregarle una. Solo lo que te toca a ti.
- **Objetivo en el HUD:** recuadro pequeño arriba a la derecha, bajo el minimapa, con la misión seguida (`tracked`): nombre, texto del paso y contadores (*Lobos 3/5*). Se elige cuál seguir en el diario.
- **Minimapa y mapa:** marca del objetivo seguido (PNJ, punto o zona de caza); si está en otra zona, una flecha en el borde hacia la salida que lleva allí.
- **Diario (J):** ventana nueva sin scroll, con la lista de misiones a la izquierda (activas, de la historia primero) y el detalle a la derecha (resumen, paso, objetivos, objetos de misión, recompensas). Hay pestañas **Activas** y **Hechas**, y si no caben se pasa de página. Se añade a la barra de iconos.
- **Avisos:** *Misión nueva*, *Objetivo cumplido* y *Misión completada* en el centro, arriba, unos segundos.
- **Entrega:** ventana con las recompensas y, si hay `choice`, los objetos a elegir con su ficha.

### 8. El tutorial
- `on_done.marks: ["tutorial_done"]` pone la marca del Plan 8.1. La misión del asalto (8.3) la pondrá; hasta entonces sigue el comando `/tutorial hecho`.

### 9. Cadena de ejemplo (provisional, se borra en la 8.3)
Tres misiones en la aldea y el bosque provisionales, con Brann, el mercader y una **vecina** nueva (PNJ provisional):
1. **Un encargo de Brann** (`auto`, se da al entrar en la aldea): diálogo con pregunta opcional (pone una marca) → entregar un paquete al mercader (`deliver`) → recompensa de oro.
2. **Lobos en el camino** (la da el mercader): matar lobos y juntar colmillos en el bosque (en grupo cuentan para todos) → llegar al claro (`reach`) → **escena** con cámara y subtítulos → examinar unas huellas (`interact`) → volver a Brann. Recompensa: **1 nivel** y un arma a elegir.
3. **Lo que vio la noche** (Brann; pide la anterior): Brann pregunta qué hacer (**decisión** entre dos marcas) → **momento a solas** en la aldea de noche con fuego (zona propia) → matar cultistas → **escena de alba** con cambio de luz → vuelta al mundo compartido. Brann dice una frase distinta según la decisión.

## Pruebas (GUT)
- **Datos:** todas las misiones, diálogos y escenas de `data/` cargan; cada referencia existe (PNJ, monstruo, objeto, punto, zona, variante, escena, texto). Así una errata en los datos falla en los tests y no en la partida.
- **Reglas:** cada tipo de objetivo avanza y termina; los pasos van en orden; requisitos y `auto`; `on_done` pone marcas y encadena; recompensa por niveles exactos; objetos de misión que entran en la bolsa, que no se pueden vender, equipar, tirar ni sacar, y que desaparecen al entregar, terminar o abandonar.
- **Grupo:** una muerte cuenta para los cercanos con el objetivo y no para los lejanos ni para quien no lo tiene; `collect` tira por jugador; `talk`, `scene` y `choice` solo para quien los hace.
- **Validación:** el anfitrión rechaza hablar lejos del PNJ, poner una marca que el diálogo no ofrecía, entregar sin el objeto o aceptar sin requisitos.
- **Guardado:** migración 5 → 6, saneado, ida y vuelta.
- **Red:** el estado viaja en el saludo y vuelve con cada cambio; un invitado completa una misión en una partida en memoria.
- **Momentos:** la zona propia la crea solo su jugador, nadie más entra, la variante añade y quita piezas, y se cierra al salir.
- **Escenas:** el reproductor ejecuta los pasos en orden y en paralelo con un reloj de prueba; saltar deja todo en su estado final; el jugador en escena no recibe daño.
- **Diálogo:** la condición `when` elige el diálogo correcto; opciones `once` e `if_flags`; sustitución de `{nombre}`.
- **Interfaz:** diario, entrega y diálogo caben sin scroll a 1280×720 (con el ayudante de render de los tests).

## Decisiones tomadas
- Escenas con los modelos del juego, barras negras y subtítulos (elección de Claude, delegada por el usuario).
- Diálogos lineales con opciones solo cuando importan.
- En grupo, golpes compartidos y conversaciones de cada uno.
- Misiones en el anfitrión, como el progreso y la bolsa: [[D-018 Misiones en el anfitrión con objetivos fijos y marcas]].
- Objetos de misión en la bolsa, bloqueados (usuario).
- Las misiones 1 y 2 en una zona propia del jugador; tras el asalto el mundo compartido no cambia con la historia.
- **Elecciones de Claude** (corregibles al revisar): puntos de misión visibles solo para quien los necesita; jugador a salvo durante una escena; Esc mantenido para saltar; ventana de diálogo con el tema de piedra; objetivo seguido bajo el minimapa.

---
← [[Planes]]
