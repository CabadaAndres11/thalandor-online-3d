---
tags: [plan, spec]
plan: 8.3b
fecha: 2026-11-26
estado: aprobado
actualizado: 2026-11-26
---
# Plan 8.3b — Camino y capital: diseño

## Objetivo
Cerrar el prólogo con la **misión 4 del [[Guion]], «La capital»**:
1. **El camino:** el héroe sale del bosque con una **caravana de mercaderes**, y unos **bandidos** que creen que lleva botín la asaltan. Es el primer contacto con terceros que no sirven al rey demonio.
2. **La llegada:** en la puerta de Sumerhold espera la multitud, que repite «Thal An Dor».
3. **La audiencia** en el palacio con el rey, la archivista **Oriel** y **lord Maren**: los sellos, el deber del portador, la tensión con Maren y el encargo del primer sello.
4. **El descenso:** se abre la puerta de la cripta bajo el palacio, y con ella empieza el arco 1 (8.4).

Además, la capital trae lo que quedó pendiente en la 8.3a: **vuelve el mercader** y llega un **PNJ de reinicios**.

Sale como **0.14.0**.

## Decisiones del usuario
- **La capital es compacta y se puede recorrer:** la puerta, la plaza, el mercader, el PNJ de reinicios y la entrada al palacio.
- **El palacio es otra zona compartida**, como la aldea o la capital, y no una instancia.
- **El camino es una zona nueva**, el **Camino de Sumerhold**, de nivel 4–8, con la emboscada a la caravana. Está entre el bosque y la capital.
- **El PNJ de reinicios** reinicia **atributos y talentos a cambio de oro**, con un precio que sube con el nivel. La mejora del nivel 50 sigue fija.
- **Arte:** un juego de piezas de ciudad nuevas, aprovechando lo que ya hay (opción 1).

## Enfoques considerados
| Enfoque | Qué supone | Elegido |
|---|---|---|
| **1. Piezas de ciudad nuevas, aprovechando lo que ya hay** | Muralla, puerta, casas de piedra de dos plantas que se pueden visitar, puestos de mercado y fuente. El palacio es una zona interior con columnas, alfombra, estandartes, trono y la reja de la cripta. Su suelo y sus muros salen del estilo de la cripta. Los personajes salen del `HumanRig` y la ropa que ya existen. | **Sí:** la ciudad se distingue de la aldea por un trabajo razonable. |
| 2. Reutilizar casi todo | Casas de la aldea en piedra y el palacio con las piezas de la cripta tal cual. | No: la capital parecería una aldea grande. |
| 3. Arte a medida por edificio | Fachada del palacio, torres y barrios. | No: daría para un plan solo de arte. |

## Fuera de alcance
- El **arco 1** (8.4–8.5): las misiones de la cripta, las afueras, las alcantarillas y el resto de la capital. La cripta sigue siendo la de pruebas; solo cambia su entrada.
- Recorrer el palacio entero: solo el salón del trono y el pasillo de entrada.
- Cambiar la mejora del nivel 50, que sigue fija.
- Voces y música (Plan 11).

## Antifines
- Que la capital o el palacio necesiten ventanas con scroll a 1280×720.
- Que se pueda entrar a la cripta antes de que el rey la abra.
- Que un jugador de nivel 4 recién salido del prólogo encuentre en el camino monstruos imposibles.
- Que el prólogo cambie algo para un amigo que ya ha pasado por él. La 4 es una misión de mundo compartido, como la 3.

## Diseño

### 1. Zonas y cómo se enlazan
`aldea → bosque → camino → capital → palacio → (cripta)`

- **Bosque (cambia):**
  - nueva salida al **este**, por el camino real, hacia `camino`;
  - **se quita la salida a la cripta**: el arco de piedra se queda como ruina, sin entrada;
  - el camino del bosque lleva hasta la nueva salida.
- **Camino de Sumerhold (`camino`, nueva):** exterior, alargada (unos 160 × 64), nivel **4–8** y con linde de bosque.
  - La calzada la cruza de oeste a este.
  - **Hordas suaves** a los lados (sabuesos y jabalíes marcados de nivel 4–8) y un **campamento de bandidos** apartado.
  - El punto **`emboscada`**, a mitad de camino.
  - **La caravana** (carros, cajas y caballos quietos) parada a la entrada, con el **caravanero**.
  - Salidas al **bosque** (oeste) y a la **capital** (este).
- **Sumerhold, Capital del Reino (`capital`, nueva):** exterior **segura** (`"safe": true`, sin hordas), compacta (unos 96 × 80).
  - **Muralla** con la **puerta sur** (entrada desde el camino) y una **plaza** con fuente y puestos.
  - **Casas de piedra** de dos plantas, algunas visitables, y el **acceso al palacio** al norte.
  - PNJ fijos: el **mercader** (el mismo de la aldea), el **PNJ de reinicios** y **guardias**.
  - **Ciudadanos** que pasean (`walkers`).
- **Palacio de Sumerhold (`palacio`, nueva):** interior, **seguro**, sin linde de bosque (margen de roca o ninguno).
  - Pasillo de entrada y **salón del trono** con columnas, alfombra, estandartes y trono.
  - PNJ: el **rey**, **Oriel**, **lord Maren** y guardias.
  - Al fondo, la **reja de la cripta**, una salida a `cripta_prueba` que está **cerrada hasta que la historia la abre** (§4).
  - Salida al sur, hacia la capital.
- **Cripta de pruebas:** su salida vuelve ahora al **palacio** (`from_cripta`), no al bosque.

### 2. Misión 4: «La capital» (`prologo_4`, `story`, `auto` tras la 3, en el mundo compartido)
| Paso | Objetivos | Texto del recuadro |
|---|---|---|
| La caravana | `reach` la caravana (en `camino`) → `talk` al caravanero | *Únete a la caravana en el Camino de Sumerhold* |
| La emboscada | `reach` `emboscada` → escena de los bandidos → `kill` bandidos ×6 y el cabecilla ×1 | *¡Defiende la caravana!* |
| Después | `talk` al caravanero (los bandidos no son del culto: buscan botín) | *Habla con el caravanero* |
| La llegada | `reach` la puerta de la capital → escena de la multitud («Thal An Dor») | *Llega a Sumerhold* |
| La audiencia | `reach` el salón del trono → escena de la audiencia → `deliver` la máscara a Oriel | *Preséntate ante el rey* |
| El encargo | `talk` al rey → escena del descenso (se abre la reja) → marca `cripta_abierta` | *Escucha el encargo del rey* |

- **Recompensa:** 1 nivel y oro.
- **Marca `prologo_hecho`.** La máscara (`q_mascara_culto`) se entrega en esta misión.
- **Escenas:** la emboscada, la llegada, la audiencia y el descenso. Llevan los diálogos clave del guion y frases nuevas en el mismo tono:
  - Oriel: los sellos que dividen al rey demonio se debilitan; el portador responde a la llamada y su poder crece con cada sello; se conocen dos (uno bajo el palacio y otro en un volcán o montaña sagrada), de un tercero solo hay leyendas y de dos no se sabe nada;
  - Maren exige custodia y el héroe se niega;
  - Oriel intercede: el culto necesita a los jóvenes con vida, y seguir los sellos puede llevar a Mira.
- **Bandidos de la emboscada:**
  - en un `spawns` del punto `emboscada` que reaparece, para que cada jugador y cada grupo los tenga, como las hordas del mundo compartido;
  - están quietos (vigilan) hasta que alguien se acerca, y la escena se lanza al llegar al punto, antes de que ataquen;
  - el cabecilla tiene más vida y vuelve a su sitio si se le deja.

### 3. Bandidos (monstruos nuevos)
- **`bandit`** (espada y escudo, cuerpo a cuerpo), **`bandit_archer`** (arco, se aleja) y **`bandit_chief`** (hacha a dos manos, más vida y un golpe pesado avisado).
- Son **humanos normales**: ropa de cuero y tela en tonos tierra, capuchas y pañuelos, sin máscaras ni marcas del culto.
- Se hacen con el **cuerpo humano y ropa vóxel** que ya existen (elección de Claude; si el modelo de monstruo humanoide no acepta un aspecto como el de los PNJ, se añade).
- Dan oro y botín normales; el cabecilla, un poco más.

### 4. Salidas que se abren con la historia
- Una salida puede llevar **`requires`**: `{"flags": [...]}`. El **anfitrión** no deja cruzarla a quien no tiene esas marcas y le avisa en el chat (*La reja está cerrada*). El cliente pinta la reja **cerrada o abierta** según las marcas del jugador.
- La reja de la cripta pide **`cripta_abierta`**.

### 5. El PNJ de reinicios
- Un PNJ de la capital con rol **`class_trainer`**: el anfitrión ya acepta los reinicios cerca de ese rol.
- Al hablarle (E), un **diálogo con dos opciones**: *Reiniciar atributos* y *Reiniciar talentos*, cada una con su **precio** a la vista. Si no te llega el oro o no hay nada que reiniciar, la opción sale apagada con el motivo.
- **Precio** (elección de Claude, ajustable en `balance`): **20 de oro × nivel** por cada reinicio; por ejemplo, 200 a nivel 10. El anfitrión cobra y reinicia, o no hace nada si no te llega.
- No reinicia la mejora del nivel 50.

### 6. Personajes y arte nuevos
- **PNJ con nombre:** el **rey** (nombre por decidir en el guion; provisional *el rey Aldren*), **Oriel**, **lord Maren**, el **caravanero**, el **PNJ de reinicios** (provisional *maese Corwin*) y **guardias de palacio**.
- **PNJ genéricos de ciudad:** ciudadanos y ciudadanas de varias edades, con ropa de ciudad más viva que la de la aldea, que pasean.
- **Piezas vóxel nuevas** (`tools/art/make_world.mjs`):
  - **ciudad:** muralla, puerta (torreones), casa de piedra de dos plantas (visitable, como las de la aldea), puesto de mercado, fuente y farola de ciudad;
  - **palacio:** columna, alfombra, estandarte del reino (ya existe), trono, braseros y reja de la cripta (cerrada y abierta);
  - **camino:** carro de caravana con lona, caballo quieto y empalizada del campamento de bandidos.
- **Ambiente `palacio`** (interior cálido con luz de braseros).
- **Pantallas de carga** para las tres zonas nuevas, con capturas.

### 7. Lo que no cambia
- El grupo, el combate, las misiones (motor de la 0.12.0 y la 0.13.0), el guardado (sigue la versión 7) y la red, salvo el aviso de la salida cerrada.

## Pruebas (GUT)
- Zonas: las tres nuevas cargan sin errores, sus salidas y entradas se alcanzan, y la capital y el palacio son seguros (sin hordas).
- Las rutas de los paseantes de la capital son válidas.
- Una salida con `requires` rechaza a quien no tiene la marca y deja pasar a quien la tiene.
- El reinicio cobra 20 × nivel, reinicia y no hace nada si no llega el oro o no hay nada que reiniciar.
- Los bandidos son válidos (datos y modelo).
- Integración: `prologo_4` de principio a fin en el anfitrión, con la máscara entregada a Oriel, la reja abierta y la cripta que vuelve al palacio.
- Arte: cada pieza nueva cabe en su huella; la casa de dos plantas tiene puerta e interior libres.

## Decisiones tomadas
- Capital compacta y jugable; palacio como zona compartida; camino como zona nueva de nivel 4–8 (usuario).
- Reinicios por oro, con precio que sube con el nivel (usuario).
- Arte: piezas de ciudad nuevas aprovechando lo que ya hay (usuario).
- Viaje con una caravana de mercaderes, para casar «viaje solo» y «asaltan el convoy» del guion (Claude, aceptado con el camino).
- Precio de 20 × nivel, máscara entregada a Oriel, salida de la cripta trasladada al palacio, salidas con marcas, nombres provisionales del rey y del PNJ de reinicios (Claude).

---
← [[Planes]]
