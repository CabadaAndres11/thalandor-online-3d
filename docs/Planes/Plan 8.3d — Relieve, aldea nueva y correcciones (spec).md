---
tags: [plan, spec]
plan: 8.3d
fecha: 2026-11-26
estado: borrador
actualizado: 2026-11-26
---
# Plan 8.3d — Relieve, aldea nueva y correcciones: diseño

## Objetivo
Los 18 puntos que el usuario encontró al probar la 0.14.1, en un solo plan:
- **relieve en el mapa** (colinas, cuestas, altos y bajos);
- la **aldea rediseñada**, con casas distintas, calles y un rancho;
- **el asalto rehecho**, para que el primer combate sea ya con clase;
- una tanda de **correcciones de interfaz y escenas**.

Sale como **0.15.0**.

## Decisiones del usuario
- **Todo en un solo plan.**
- **Relieve en el terreno, con la lógica en plano** (opción 1):
  - cada zona lleva alturas en sus datos y todo se dibuja a la altura del suelo;
  - las cuestas se andan y los desniveles bruscos no se cruzan;
  - el combate, el alcance y la red siguen en 2D.
- **La aldea:**
  - 3 o 4 diseños de casa distintos, además de la herrería;
  - calles, aunque sean caminos de tierra entre las casas;
  - más casas, colocadas con sentido (en hilera a los lados del camino);
  - un **rancho con animales no agresivos** (vacas u otros) dentro.
- **El asalto:**
  - el secuestro y las peleas pasan en la escena;
  - el primer combate del jugador es ya con la clase elegida;
  - el recuadro dice *cultistas derrotados*, no *vecinos salvados*.
- **Sin zoom en los diálogos** (anula el arreglo 4 de la 8.3c).

## Fuera de alcance
- Alturas en la simulación: no hay saltos, ni ventaja por altura, ni línea de visión que tenga en cuenta el relieve.
- Rediseñar el bosque, la capital o el palacio: solo ganan relieve donde ayude (el bosque, suave).
- Nuevas misiones.

## Antifines
- Que un personaje, PNJ, monstruo o pieza flote sobre el suelo o se hunda en una cuesta.
- Que una cuesta deje al jugador atascado o le permita subir por un acantilado.
- Que el asalto deje al aldeano sin clase frente a enemigos.
- Que un aviso del tutorial siga en pantalla cuando ya no aplica.

## Diseño

### 1. Relieve (`sim/zone_layout.gd`, `game/zone_view.gd` y quien dibuje cosas en el mundo)
- **Datos:** `"relief": [...]` en la zona, con formas que se suman:
  - `{"kind": "hill", "at": [x, z], "radius": r, "height": h}`: colina suave, con caída en coseno;
  - `{"kind": "plateau", "area": [x, z, w, d], "height": h, "slope": s}`: meseta con cuestas de `s` casillas;
  - `{"kind": "hollow", ...}`: como `hill`, con altura negativa (hondonadas y orillas).
- **`ZoneLayout.height_at(x, z) -> float`** (metros): interpola las esquinas de cada casilla. Es la única fuente de la altura del suelo.
- **Desniveles:** una casilla cuya diferencia de altura con una vecina supera **0,6 m** es **sólida** (acantilado). Así la búsqueda de caminos y el movimiento no cambian.
- **Dibujo:**
  - el suelo se hace con las alturas de las esquinas;
  - piezas, casas, antorchas, PNJ, paseantes, jugadores, monstruos, botín, marcas y efectos se colocan a `height_at`;
  - el agua se queda en su nivel;
  - la cámara sigue la altura del jugador.
- **Simulación:** sigue en 2D. El cliente añade la altura al dibujar.
- **Sombras de escenas:** los actores de las escenas también se colocan a la altura del suelo.

### 2. La aldea nueva (`data/zones/aldea.json` y sus variantes)
- **Cuatro diseños de casa** con sus versiones quemadas (`tools/art/make_world.mjs`):
  - **cabaña** (la `house_small` de ahora, de yeso y paja);
  - **casa de entramado** de dos plantas, de yeso con vigas vistas y tejado de tablas;
  - **cabaña de troncos** del cazador, de troncos horizontales y tejado de tablas;
  - **casa de piedra** del panadero, con horno de ladrillo y chimenea.
  - La `house_large` de ahora se queda como **casa grande** de familia (quinto modelo).
- **Rancho:** un **establo** abierto (como el cobertizo de la forja, más grande, con heno y comederos) y un **cercado** con **vacas** que pasean dentro. Las vacas son **paseantes con modelo de pieza** (`"model": "piece:cow"`), no monstruos: no atacan ni se atacan.
- **Calles:**
  - una calle mayor de tierra de oeste a este, hasta la salida al bosque, con las casas en hilera a los dos lados mirando a la calle;
  - la plaza en el cruce con el camino del norte;
  - callejones de tierra hacia la herrería, el rancho y la colina.
- **Más casas:** de 7 a unas **14**, cada una con su sentido: la del panadero junto a la plaza, la del cazador hacia el bosque, la de la anciana cerca de la colina…
- **Relieve:**
  - **la colina** al noroeste, con cuesta, las tumbas y el sitio de Mira;
  - **una hondonada** con el río al suroeste;
  - **el pueblo** en una terraza suave.
- **Los tres momentos** se rehacen sobre el plano nuevo: ruinas (base), `vispera` y `asalto`. Los puntos de misión y las rutas de los paseantes se recolocan, y los tests de zonas siguen valiendo (todo alcanzable, la reaparición del asalto segura).
- Los jabalíes que hoy se cazan dentro del cercado salen del pueblo, al prado del sureste, fuera de las casas.

### 3. El asalto rehecho (`prologo_2`)
1. **La alarma:** escena → `reach` siguiendo a Mira (sin enemigos aún).
2. **La plaza:** escena de las peleas y el secuestro:
   - los vecinos luchan contra cultistas, Brann sostiene la puerta;
   - el Heraldo examina a los jóvenes y se llevan a Mira.
3. **Persigue a Mira:** `reach` tras la columna → escena del despertar → `class`.
4. **Primer combate, ya con clase:**
   - los cultistas y los sabuesos aparecen ahora, porque las hordas del asalto llevan `"requires": {"flags": ["despertar"]}` y el paso de clase pone esa marca;
   - `kill` cultistas ×6 (*Cultistas derrotados*), con el texto *Habilidades: 1–9. Q bebe una poción de vida*.
5. **El alba:** escena → `kill` sabuesos ×4 y el Heraldo → huida.
6. **Busca a Brann** → escena de Brann caído.
- Las hordas y los puntos de aparición pueden llevar `requires`, como las salidas: el `Spawner` no los llena mientras ningún jugador de esa copia tenga las marcas.

### 4. Correcciones
| # | Punto del usuario | Arreglo |
|---|---|---|
| 1 | El código de la última vez se queda en el recuadro | El recuadro de unirse empieza **vacío**; ya no se guarda el código. |
| 2 | Botón *Cerrar juego* en el menú de Esc | Botón **Cerrar juego** en el menú de pausa, con confirmación. Guarda el personaje antes, como al salir. |
| 3 | El muñeco no se marca en el mapa durante la misión | Ver 7: los objetivos de golpear, matar y recoger marcan a sus monstruos. Además, un brillo sobre el muñeco mientras haga falta golpearlo. |
| 4 | Los edificios tapan al jugador aunque no esté dentro | Una casa que queda entre la cámara y el jugador se **abre** como cuando entras (tejado fuera, muros cortados a 1 m) mientras tape. |
| 5 | Los nombres tapan las escenas | Durante una escena no se ven nombres, avisos ni marcas sobre nadie. |
| 6 | Quitar la marca visible donde empiezan las escenas | Los puntos que solo sirven para lanzar una escena no tienen brillo (`look` vacío). La estrella del mapa sigue guiando. |
| 7 | Los enemigos de las misiones como puntos rojos en el minimapa | Los monstruos que cuentan para un objetivo activo salen como **puntos rojos** en el minimapa y en el mapa (M). |
| 8 | La flecha del jugador se queda quieta con el mapa abierto | El mapa (M) redibuja la posición y la dirección del jugador cada fotograma mientras está abierto. |
| 9 | Brann sale primero de pie al morir; añadir charco de sangre | Un actor puede empezar en una pose (`"pose": "lie"` en el actor), ya terminada. Efecto de escena **`blood`**: un charco oscuro en el suelo. |
| 10 | No hay ningún herido en «Llegan tarde» | Dos **heridos tumbados** (PNJ con pose `lie` y vendas) junto a sus puntos. |
| 11 | Los escombros no se apartan ni están donde marca la misión | Un montón de escombros en el punto `escombros_1`, que **desaparece para ese jugador** cuando lo aparta. Esto lo hacen las **piezas de historia** (`story_pieces`: una pieza que se ve hasta que se cumple el objetivo de un punto). |
| 12 | Quitar el zoom en los diálogos | Hablar ya no acerca la cámara. |
| 13 | Avisos en pantalla y efectos azules al subir de nivel | Aviso grande **«¡Nivel N!»** en el centro y un **destello azul** (columna de luz y chispas) alrededor del personaje. Los compañeros ven el destello. |
| 14 | Quitar «Termina la defensa…» al terminarla | El aviso del menú de pausa y la ayuda del botón de unirse desaparecen en cuanto el personaje tiene `tutorial_done`, sin volver a entrar. |

## Pruebas (GUT)
- **Relieve:**
  - `height_at` en el centro de una colina vale su altura, en el borde 0 y entre medias crece suave;
  - una meseta con cuesta es alcanzable por la cuesta y no por el borde;
  - el suelo, una pieza, un PNJ y el jugador se dibujan a `height_at`.
- **Aldea:**
  - carga sin errores en sus tres momentos;
  - tiene al menos 4 diseños de casa más la herrería, el rancho con vacas y 12 casas o más;
  - todo es alcanzable;
  - las casas no pisan las calles;
  - la reaparición del asalto es segura;
  - las rutas son válidas.
- **Asalto:**
  - antes de la clase no hay enemigos en la copia; tras elegirla aparecen;
  - el test de integración del prólogo recorre los pasos nuevos.
- **Correcciones:** un test por cada punto que se pueda comprobar sin mirar (código vacío, cerrar juego, nombres ocultos en escena, marcas de puntos de escena, puntos rojos, flecha del mapa, pose inicial y sangre, heridos, escombros que desaparecen, sin zoom, aviso y destello de nivel, aviso del tutorial).

## Decisiones tomadas
- Todo en un plan; relieve con lógica en plano; aldea con cuatro diseños más la casa grande, calles en hilera y rancho; asalto con el primer combate ya con clase (usuario).
- **Elecciones de Claude:**
  - desnivel máximo de 0,6 m entre casillas;
  - vacas como paseantes con modelo de pieza;
  - los jabalíes cazables salen al prado del sureste;
  - hordas con `requires`;
  - piezas de historia con un punto;
  - el código de unirse ya no se guarda;
  - *Cerrar juego* con confirmación.

---
← [[Planes]]
