---
tags: [plan, spec]
plan: 8.1
fecha: 2026-11-22
estado: aprobado
actualizado: 2026-11-22
---
# Plan 8.1 — Zonas y mundo: diseño

## El Plan 8 en partes
La demo cubre el **prólogo y el arco 1 completos** del guion (*Guión del juego de rol – Historia por misiones*, documento del usuario; misiones 1–14). Recorre la aldea, el bosque camino de la capital, la capital y la cripta bajo el palacio, y termina cuando el héroe sale de la capital rumbo al volcán, hacia el **nivel 50 o algo más**.

| Parte | Contenido |
|---|---|
| **8.1 Zonas y mundo** (esta spec) | Varias zonas a la vez, mapas como datos de piezas, paso entre zonas, hordas por franja de nivel, mazmorras instanciadas con dificultad, guardado de la ubicación y bloqueo del juego en grupo durante el tutorial |
| 8.2 Misiones, diálogos y escenas | Misiones como datos con progreso por personaje, ventana de diálogo nueva, escenas animadas ([ANIMACIÓN]), luz por momento de la historia, diario de misiones |
| 8.3 Prólogo (misiones 1–4) | La aldea, el Heraldo, el bosque, el camino con bandidos, la capital y la audiencia |
| 8.4 Arco 1, primera mitad (5–9) | La cripta, el archivo con puzle, el banquete con la decisión sobre Maren, el submundo y el sigilo |
| 8.5 Arco 1, final (10–14) | La noche del culto, Valk, el ritual y Vaelthar, y la despedida |

**Decisiones de juego (usuario):**
- **Cada jugador vive su momento de la historia.** Los mapas no cambian con ella; lo que cambia es de cada jugador (8.2).
- **La clase se elige antes del asalto.** Hasta terminar el asalto (misión 2, el tutorial) **no se puede jugar en grupo**.
- **Se sube de nivel sobre todo matando hordas y en mazmorras.** Completar una misión da 1 o 2 niveles, más la experiencia de sus enemigos. Es una norma del juego, no solo de la demo.
- **Nivel de los enemigos fijo por zona**; las mazmorras dejan **elegir la dificultad** al entrar.
- **Un mundo por zona en el anfitrión**, y las mazmorras como instancias.
- **Mapas como datos de piezas**, revisable más adelante.

## Objetivo
La base técnica del mundo de la demo:
1. El anfitrión mantiene **varias zonas vivas a la vez** y cada jugador está en una.
2. Una zona se describe en **datos legibles**: terreno, piezas, caminos, PNJ, salidas y hordas.
3. Se pasa de una zona a otra por sus **salidas**, con una pantalla de carga breve.
4. **Hordas** que reaparecen, con su franja de nivel.
5. **Mazmorras instanciadas** con la dificultad elegida al entrar.
6. El personaje **guarda dónde estaba** y vuelve ahí.
7. **Juego en grupo bloqueado** hasta terminar el tutorial.

Sale con **versiones provisionales de la aldea y del bosque**, conectadas, y una **cripta de prueba**, para que el usuario lo pruebe. Las zonas definitivas, con su contenido, llegan en la 8.3.

**Por qué:** hoy todo ocurre en una arena de pruebas de 48×48 con un solo mundo. La historia necesita lugares, y la norma de subir con hordas necesita zonas de caza.

## Fuera de alcance
- Misiones, diálogos, escenas animadas, la luz por momento de la historia y el diario de misiones: 8.2.
- El contenido definitivo de cada zona, el bestiario nuevo, la capital y los PNJ con nombre: 8.3 a 8.5.
- Terreno con relieve (colinas, acantilados): el suelo es llano y el relieve lo ponen las piezas (rocas, muros, terraplenes). Se revisa en 8.3 si hace falta.
- Ciclo de día y noche: lo marca la historia (8.2).
- Viaje rápido y montura.

## Antifines
- Que añadir una zona exija tocar `sim/` o el código de red: una zona nueva son solo datos (GDD §6.3).
- Que el anfitrión simule zonas vacías a coste completo.
- Que un jugador vea o reciba lo que pasa en otra zona: ni monstruos, ni golpes, ni botín.
- Perder el personaje o su inventario al cambiar de zona o al cerrar a mitad de una mazmorra.
- Romper los guardados de la 0.10: se abren en la aldea.

## Enfoques (decididos con el usuario)
| | Opción | Elegida |
|---|---|---|
| Mundo | Un `SimWorld` por zona en el anfitrión / un mundo gigante con todo / el grupo siempre junto | **Un mundo por zona** |
| Mapas | Datos de piezas / mapas generados por código / editor de Godot | **Datos de piezas** (revisable) |
| Nivel | Fijo por zona y mazmorras a elegir / todo adaptado al jugador / todo fijo | **Fijo por zona; mazmorras a elegir** |

## Diseño

### 1. Una zona como datos (`data/zones/<id>.json`)
Una zona es un JSON con estas claves:

| Clave | Qué es |
|---|---|
| `name` | Clave de texto, por ejemplo `ZONE_ALDEA` |
| `size` | `[ancho, largo]` en casillas de 1 m |
| `ambience` | El ambiente por defecto (`data/ambiences/`) |
| `levels` | La franja de nivel `[min, max]`, solo informativa (la muestra el mapa) |
| `safe` | `true` = sin combate (la capital) |
| `instanced` | `true` = mazmorra: una copia por grupo, con dificultad a elegir |
| `terrain` | Capas de suelo: base y zonas pintadas (`grass`, `dirt`, `road`, `stone`, `sand`, `water`). El agua no se pisa |
| `pieces` | Piezas colocadas: `{"id": "house_forge", "at": [20, 14], "rot": 90}` |
| `scatter` | Relleno por área: `{"area": [x, z, w, d], "pieces": ["tree_oak", "tree_pine", "bush"], "density": 0.12, "seed": 3}`. Así se hace un bosque denso sin listar cada árbol |
| `paths` | Caminos: polilíneas de casillas con anchura y tipo de suelo; el relleno no pone nada encima |
| `npcs` | Como hoy: `{"id": "brann", "at": [22, 19], "facing": 2}` |
| `exits` | Salidas: `{"area": [x, z, w, d], "to": "bosque", "entry": "from_aldea"}` |
| `entries` | Puntos de llegada con nombre: `{"from_aldea": [4, 60]}`. `default` es donde se aparece si no hay otro |
| `respawn` | Dónde se reaparece al morir en esta zona |
| `hordes` | Grupos de caza (§4) |

- **Piezas (`data/zones/pieces.json`):** cada pieza tiene el `.vox` de su modelo, su escala y una **huella**: las casillas que bloquea, giradas con la pieza. Las primeras piezas se hacen por código en `tools/art/make_world.mjs`, a vóxel de 5 cm como el decorado del menú:
  - casas de aldea (pequeña, grande y la forja);
  - valla, muro bajo, pozo, carro y cajas;
  - roble, pino, arbusto y roca (pequeña y grande);
  - tocón, puente de madera y antorcha (la de hoy);
  - arco de piedra de la cripta, pared y columna de cripta.
- **La colisión** sale de las huellas y del agua; el `CollisionMap` actual se construye desde ahí.
- **Al dibujar:** las piezas iguales comparten malla y se dibujan con `MultiMeshInstance3D` (cientos de árboles sin coste por nodo). El suelo es una malla por tipo de terreno.
- **La arena de pruebas** se convierte en una zona más (`arena`), solo accesible con un comando de desarrollo (`/zona arena`).
- **Brann y el mercader** se mudan a la aldea provisional (Brann en la forja). La elección de clase y las mejoras siguen funcionando igual hasta que la historia (8.2 y 8.3) las reparta.

### 2. Varias zonas en el anfitrión
- **`ZoneManager`** (en `net/`) guarda un `SimWorld` por zona abierta, con su `Spawner`, sus PNJ y su botín:
  - una zona se crea la primera vez que alguien entra;
  - cada tick avanzan **solo las zonas con jugadores**;
  - **una zona vacía se duerme**: no avanza, conserva sus monstruos y sigue igual cuando alguien vuelve;
  - **una instancia vacía se cierra** a los 5 minutos.
- **`HostSession`** deja de tener un solo `world`: cada jugador tiene su zona. Las entradas, los golpes, el botín, las órdenes y las peticiones van al mundo de su zona. Las snapshots y los eventos se envían **solo a los jugadores de esa zona**.
- **Los mensajes de grupo** (chat, unirse y salir, nivel, clase, equipo) siguen llegando a todos.
- **Los marcos de grupo** muestran a todos los compañeros. A los que están en otra zona se les ve con el **nombre de su zona** y sin barra de vida en directo (el anfitrión manda vida, nivel y zona cada segundo).
- **La amenaza, las curas y los objetivos** solo existen dentro de un mismo mundo.
- **El balance de grupo** (la vida de los monstruos según el número de jugadores) cuenta a los jugadores **de esa zona**.

### 3. Pasar de una zona a otra
- **Al pisar una salida:** el anfitrión saca al jugador de su mundo y lo mete en el destino, en la entrada indicada. Conserva vida, recurso, estados que no son de combate, progreso, inventario y barra. Si va en combate (le ha golpeado un enemigo hace menos de 5 s), la salida no funciona y el chat lo dice.
- **El mensaje `ZONE`** (fiable) lleva el id de la zona, la instancia y el nivel de la mazmorra. El cliente muestra una **pantalla de carga** con el nombre de la zona, monta el mapa desde sus propios datos (todos tienen los mismos archivos, porque se exige la misma versión), coloca la cámara y quita la pantalla al recibir la primera snapshot.
- **Muerte:** se reaparece en el `respawn` de la zona. En una mazmorra, en su entrada.
- **Comandos del anfitrión:** `/zona <id>` lleva al jugador a esa zona y `/zonas` lista las abiertas.

### 4. Hordas
- **Cada horda** (`hordes` de la zona) tiene:
  - un área;
  - una lista de tipos de monstruo con peso;
  - una franja de nivel `[min, max]`;
  - cuántos monstruos vivos mantiene;
  - cada cuánto repone a los muertos;
  - la probabilidad de élite.
- **Densa y continua:** repone a sus muertos de uno en uno cada `respawn_s` (por defecto, 8 s), para que siempre haya algo que cazar. Cada monstruo nuevo sale en un punto libre del área, con un tipo y un nivel al azar dentro de la franja.
- **El `Spawner` actual** se amplía para leer hordas además de los puntos sueltos de hoy (que siguen valiendo para jefes y grupos fijos).
- **La experiencia por monstruo** no cambia: la sube la franja de nivel. La curva y el balance para llegar al 50 matando hordas se ajustan en 8.3, con el contenido real.

### 5. Mazmorras instanciadas
- **Una zona con `instanced: true`.** Al pisar su entrada, el jugador elige el **nivel de la mazmorra** en una ventana (hoy la arena hace lo mismo con Brann). El nivel por defecto es el suyo, y va de su nivel −5 a +10 respecto a la franja de la mazmorra.
- **Una instancia por grupo, nivel y mazmorra.** El grupo es la partida del anfitrión. Si un compañero ya está dentro, se entra en su instancia, al nivel que eligió él.
- **Los monstruos de la instancia** escalan al nivel elegido, como hoy la arena (`arena_level` pasa a ser el nivel de la instancia).
- **Al vaciarse**, la instancia se cierra a los 5 minutos y se reinicia la próxima vez.

### 6. Guardado y vuelta
- **`CharacterData` versión 5** guarda la zona y la posición: `{"zone": "bosque", "at": [x, z]}`. Al estar en una instancia se guarda su entrada en la zona de fuera.
- **Migración:** los personajes de la 0.10 empiezan en la entrada por defecto de la **aldea**.
- **Al jugar solo** se aparece donde se guardó. **Al unirse a un amigo** se aparece en la zona guardada propia (GDD §9.1); si es la aldea del tutorial y aún no se ha terminado, no se puede unir (§7).
- **El guardado** se hace al cambiar de zona y cada 30 s, además de cuando se guarda hoy.

### 7. El juego en grupo, bloqueado hasta terminar el tutorial
- **Una marca del personaje:** `tutorial_done`. Hasta que la 8.2 marque el final del asalto, se activa con un comando de desarrollo (`/tutorial hecho`) y en los personajes de la 0.10, que ya han jugado.
- **Sin ella:**
  - en el menú de pausa, **Abrir grupo** está desactivado y el aviso dice *Termina la defensa de la aldea para jugar con amigos*;
  - en Tus personajes, **Unirse a un amigo** también está desactivado;
  - el anfitrión rechaza a un invitado sin la marca (motivo `tutorial`).

## Pruebas (GUT)
- **Zona:** la aldea de prueba carga, la colisión sale de las huellas giradas, el relleno no tapa los caminos y una pieza desconocida da error con su nombre.
- **ZoneManager:**
  - dos jugadores en zonas distintas solo reciben la snapshot y los eventos de su zona;
  - una zona vacía no avanza de tick y conserva sus monstruos;
  - una instancia se cierra a los 5 minutos de vaciarse.
- **Salida:**
  - pisar una salida lleva a la entrada correcta y conserva inventario, nivel y vida;
  - en combate no funciona.
- **Hordas:** mantienen su número, reponen con su ritmo y sus niveles quedan dentro de la franja.
- **Mazmorra:** dos jugadores del grupo comparten instancia y el nivel elegido se aplica a los monstruos.
- **Guardado:**
  - un personaje de la 0.10 aparece en la aldea;
  - la zona y la posición se guardan y se recuperan;
  - un personaje que se guardó dentro de una mazmorra vuelve a su entrada.
- **Grupo:** sin `tutorial_done`, Abrir grupo y Unirse están desactivados y el anfitrión rechaza al invitado.
- **Cliente:** el mensaje `ZONE` monta el mapa nuevo, muestra la pantalla de carga y la quita con la primera snapshot, y no quedan nodos del mapa anterior (sin fugas).
- La suite completa pasa.

## Decisiones tomadas
- **Del usuario:**
  - el prólogo y el arco 1 completos;
  - cada jugador en su momento;
  - la clase antes del asalto y sin grupo hasta terminarlo;
  - subir de nivel con hordas y mazmorras;
  - el nivel fijo por zona y las mazmorras a elegir;
  - un mundo por zona;
  - los mapas como datos de piezas.
- **De Claude (revisables):**
  - el reparto del Plan 8 en cinco partes;
  - el suelo llano en la 8.1;
  - `MultiMeshInstance3D` para las piezas repetidas;
  - dormir las zonas vacías y cerrar las instancias a los 5 minutos;
  - la salida bloqueada en combate (5 s);
  - el rango de dificultad de las mazmorras (−5 a +10);
  - las hordas que reponen de una en una cada 8 s;
  - el guardado cada 30 s;
  - los compañeros en otra zona, sin vida en directo;
  - las versiones provisionales de la aldea y del bosque y la cripta de prueba;
  - la arena como zona de desarrollo.

---
← [[Planes]]
