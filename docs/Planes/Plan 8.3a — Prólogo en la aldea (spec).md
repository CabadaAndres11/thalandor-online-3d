---
tags: [plan, spec]
plan: 8.3a
fecha: 2026-11-26
estado: aprobado
actualizado: 2026-11-26
---
# Plan 8.3a — Prólogo en la aldea: diseño

## El Plan 8.3 en dos partes
| Parte | Contenido |
|---|---|
| **8.3a Prólogo en la aldea** (esta spec) | Misiones 1–3 del [[Guion]]: la víspera, el asalto y «llegan tarde», con el rastro hasta el río. Es el **tutorial** del juego. |
| 8.3b Camino y capital | Misión 4: la emboscada de bandidos, Sumerhold, la audiencia y la apertura de la cripta. Allí vuelven el mercader y un PNJ de reinicios. |

## Objetivo
Que un jugador nuevo empiece el juego por el prólogo y aprenda a jugar mientras lo vive:
1. **La víspera** y **el asalto** se juegan **a solas** en la aldea, al atardecer de fiesta y de noche en llamas. Son momentos de la 0.12.0, en variantes de la aldea.
2. La **clase se elige en el asalto**, cuando despierta el poder al perseguir a Mira.
3. Al terminar el asalto la aldea queda **en ruinas para todos**, Brann ha muerto y **se abre el juego en grupo**.
4. **Llegan tarde** se juega en el mundo compartido. Termina con la anciana llamando al héroe **Thal An Dor**.
5. La aldea tiene vida: **aldeanos genéricos**, sobre todo ancianos, que **pasean por rutas**.

Sale como **0.13.0**.

## Decisiones del usuario
- **No quedas inconsciente.** Al intentar perseguir a Mira despierta tu poder y **eliges la clase** en ese momento.
- **El Heraldo es el Acólito** que ya existe.
- **El prólogo es el tutorial.** Lo enseña el recuadro de objetivos bajo el minimapa, con el título de la misión y una explicación muy breve (*Muévete con WASD hasta la forja*, *Golpes al muñeco 3/10*).
- **Sin Brann:**
  - no hay reinicios hasta la 8.3b, donde los dará un PNJ de la capital;
  - la mejora del nivel 50 sale sola, como ahora, y **ya no se puede cambiar**.
- **El mercader se va de la aldea.** En su lugar hay aldeanos genéricos, sobre todo ancianos, que caminan por rutas.
- **Los personajes que ya existen dejan de valer.** Se apartan para que no salgan (§8). La misma regla servirá tras la beta.
- **El muñeco de práctica** es el típico muñeco de madera de entrenamiento. Tiene vida infinita y no ataca.
- **El Heraldo no huye de verdad:** al dejarlo al **10 %** de vida salta una escena en la que huye.
- **Enfoques:** la aldea compartida pasa a ser la aldea en ruinas, y la víspera y el asalto son variantes (1A). Los aldeanos se mueven en cada cliente con el reloj del anfitrión, sin red (2A).

## Fuera de alcance
- La misión 4, el camino, los bandidos, Sumerhold, el mercader y el PNJ de reinicios: 8.3b.
- Compañeros que te siguen: el guion dice que no hay. Los dos soldados del rastro solo salen en las escenas.
- Voces y música (Plan 11).
- Oficios: el *oficio cotidiano* de la víspera se queda en los recados.

## Antifines
- Que el tutorial pare el juego con ventanas de texto: se enseña con el recuadro de objetivos y las escenas.
- Que alguien pueda saltarse la elección de clase o quedarse aldeano tras el asalto.
- Que un aldeano que pasea bloquee el paso o empuje al jugador.
- Que el prólogo cambie algo para un amigo que ya está en el mundo compartido.

## Diseño

### 1. La aldea en tres momentos (`data/zones/aldea.json`)
- **Base = aldea en ruinas**, el mundo compartido tras el asalto:
  - casas quemadas (piezas nuevas `house_burnt_small`, `house_burnt_large`), escombros y vigas caídas;
  - la herrería con el tejado hundido;
  - tumbas recientes junto a la colina;
  - las tropas de Verrin acampadas (tiendas y estandarte del reino);
  - aldeanos genéricos paseando;
  - PNJ: **Verrin**, **la anciana cantora**, el **panadero** y el **cazador**.
  - Sin Brann, sin Mira y sin mercader.
- **Variante `vispera`:** la aldea sana con guirnaldas, farolillos, mesas de fiesta y una hoguera en la plaza. Luz *atardecer*. Están Brann, Mira, el panadero, el cazador y la anciana, y los aldeanos de fiesta pasean. En el borde de la colina hay un **muñeco de práctica** en el patio de la forja.
- **Variante `asalto`:** la aldea de noche (`noche_fuego`) con fuegos encendidos y humo. Hordas que no reaparecen (cultistas, sabuesos marcados) en las calles y vecinos asustados quietos. Brann está en la puerta de la aldea solo en las escenas.
- Las variantes quitan las piezas de ruina y ponen las sanas (casas normales) con `remove_pieces` / `add_pieces`.

### 2. Misiones (`data/quests/prologo_*.json`), todas `story`
**Misión 1: La víspera** (`prologo_1`, `auto`, empieza al crear el personaje; `moment: aldea/vispera` desde el primer paso). Cada paso enseña algo:

| Paso | Objetivos | Texto del recuadro (tutorial) |
|---|---|---|
| Amanecer en la forja | `reach` junto a Mira (empiezas en la casa de la forja) | *Muévete con WASD hasta Mira* |
| | `talk` Mira | *Pulsa E junto a Mira para hablar* |
| Los recados | Brann da tres encargos (`give`); `deliver` al panadero, al cazador y a la anciana | *Entrega los encargos (J abre tu diario)* |
| La práctica | `hit` al muñeco ×10 con el clic izquierdo; `hit_secondary` ×3 con el clic derecho; `dodge` ×3 | *Golpea el muñeco con el clic izquierdo*, *…con el clic derecho*, *Esquiva con Espacio* |
| La colina | `reach` la colina → escena del atardecer con Mira | *Sube a la colina con Mira* |
| La fiesta | `reach` la plaza → escena de los regalos, los grillos y el cuerno | *Ve a la fiesta de la plaza* |

Recompensas: el **arma inicial** es la espada de madera de siempre, y Brann la entrega en la escena (no cambia el equipo).

**Misión 2: El asalto** (`prologo_2`, `auto` tras la 1; `moment: aldea/asalto`):

| Paso | Objetivos | Texto |
|---|---|---|
| La alarma | escena → `reach` siguiendo a Mira | *Sigue a Mira* |
| La defensa | `kill` cultistas ×6 cerca de los vecinos | *Salva a los vecinos 2/6 (Q bebe poción de vida)* |
| La plaza | escena: el Heraldo examina a los jóvenes y se llevan a Mira → `reach` tras la columna | *¡Persigue a Mira!* |
| El despertar | escena del poder → **`class`**: elegir clase | *Elige tu camino* |
| El alba | escena del amanecer (luz *alba*) → `kill` lo que queda ×4 y **el Heraldo** | *Habilidades: 1–9. Derrota al Heraldo* |
| Lo que queda | `reach` la puerta → escena de Brann caído y del cuerno lejano | *Busca a Brann* |

Al terminar: `marks: ["tutorial_done"]`, `moment: null` (a la aldea en ruinas) y empieza la 3. Recompensa: 2 niveles.

**Misión 3: Llegan tarde** (`prologo_3`, mundo compartido):

| Paso | Objetivos | Texto |
|---|---|---|
| Después del humo | `interact` ×3 (heridos y escombros) y `talk` al panadero y al cazador | *Ayuda a los supervivientes 1/3* |
| El ejército | escena de la llegada de Verrin → `talk` Verrin | *Habla con la capitana Verrin* |
| El rastro | en el **bosque**: `reach` el campamento abandonado, `interact` las huellas de carros y la máscara, y `reach` el río | *Sigue el rastro del culto* |
| El nombre | vuelta a la aldea: `talk` a la anciana → escena *Thal An Dor* (pone la marca `apodo`) → `talk` Verrin | *Vuelve a la aldea* |

Al terminar: 1 nivel y la marca `prologo_3_hecho`, que la 8.3b usará. La **máscara** es un objeto de misión (`q_mascara_culto`) que se queda en la bolsa hasta la capital (no está en ningún `deliver` de esta misión).

En grupo: las misiones 1 y 2 son a solas (aún no hay grupo). En la 3, las muertes y los lugares cuentan para el grupo, como en la 0.12.0.

### 3. La clase se elige en el asalto
- Nuevo objetivo **`class`**: se cumple cuando el personaje tiene una clase seleccionable.
- **El paso con `class` permite elegir clase en cualquier sitio.** El anfitrión acepta `CHOOSE_CLASS` si el jugador tiene ese objetivo activo, aunque no haya instructor cerca.
- El cliente abre la **ventana de clase** sola al terminar la escena del despertar (paso con `"opens": "class_choice"`). No se puede cerrar sin elegir.
- **Brann ya no enseña clases.** El rol `class_trainer` sale de los datos y el menú de Brann desaparece con él.

### 4. Sin reinicios y mejoras fijas
- Fuera la opción **reiniciar mejora**. La ventana de mejora del nivel 50 sigue saliendo sola y es obligatoria, y la elección queda fija.
- Los reinicios de atributos y talentos no tienen PNJ hasta la 8.3b. Las reglas (`ProgressRequests.reset`) se quedan para entonces.
- El comando de desarrollo del nivel de la arena se mantiene: `/arena <n>` para el anfitrión, en lugar de la opción del menú de Brann.

### 5. Objetivos nuevos del motor
| Tipo | Se cumple cuando | Quién lo cuenta |
|---|---|---|
| `hit` | El jugador golpea a un monstruo de ese tipo (`monster`) con su ataque básico, o con cualquiera si no se pone `with` | Anfitrión, con cada golpe |
| `hit_secondary` | Igual, con el ataque secundario | Anfitrión |
| `dodge` | El jugador esquiva (`count` veces) | Anfitrión |
| `class` | El personaje tiene clase | Anfitrión, al elegirla |

Todos son de cada uno (no se comparten en grupo).

### 5b. Otros ajustes del motor (elecciones de Claude)
- **Momento desde el inicio:** una misión puede llevar `"moment"` propio, que vale desde su primer paso. Lo usan la víspera y el asalto.
- **`give` con objetos normales:** la víspera da dos pociones de vida antes de la defensa (las enseña el recuadro con *Q*).
- **Las variantes pueden cambiar `walkers`**, igual que los PNJ.
- **`hit` sabe qué ataque golpeó:** la simulación recuerda la habilidad que se está resolviendo mientras aplica el daño.
- **El Heraldo huye como paso de misión:** su derrota (al huir) cumple el `kill` y el `on_done` del paso lanza la escena de huida, así que el jugador está a salvo mientras la ve. El cliente solo oculta su modelo al recibir `fled`.
- **Los cultistas del asalto son de nivel 1–2**, para un aldeano con espada de madera y dos pociones.
- **Ventana de clase obligatoria** durante el paso `class`: sin botón de cerrar y Esc no la cierra.

### 6. El muñeco de práctica (`training_dummy`)
- Monstruo nuevo: **muñeco de madera de entrenamiento** (poste, cuerpo de paja atado, brazos de madera y base), vóxel hecho por código.
- **Vida infinita:** el daño se ve (números y sacudida) pero nunca baja de 1 y se rellena a los 3 s sin golpes.
- **No ataca, no se mueve** ni genera amenaza; no da experiencia ni botín.
- `"behavior": "dummy"` en sus datos.

### 7. El Heraldo huye al 10 %
- El monstruo gana `"flee_at": 0.1`. Al bajar de ahí:
  - el anfitrión lo saca del combate (deja de atacar, nadie puede dañarlo);
  - lo cuenta como **derrotado** para las misiones y la experiencia, sin botín;
  - emite `["fled", id]` y lo quita tras **3 s**.
- **En el cliente**, `fled` reproduce una **escena corta de huida**: el Heraldo se retira hacia el oeste entre humo y desaparece, sin disolverse en binario.
- Es una versión del Acólito para el prólogo (`heraldo`): un cuarto de su vida, sin invocaciones y nivel 2. El Acólito de la cripta no cambia.

### 8. Personajes antiguos
- `CharacterData.VERSION = 7`. Al abrir *Tus personajes*, los archivos de versiones anteriores **se mueven a `user://saves/characters/antiguos/`** y no se cargan.
- La primera vez sale un aviso: *Esta versión empieza la historia desde el principio. Tus personajes anteriores se han guardado aparte y no se pueden usar.*
- Importar un personaje antiguo se rechaza con el mismo motivo.
- Se borra la cadena de ejemplo (`ej_*`), la vecina Ilsa y la marca `tutorial_done` que daba el comando. El comando `/tutorial hecho` se queda para pruebas.

### 9. Aldeanos que pasean
- **Aspectos genéricos** en `data/npcs/` (`aldeano_anciano_1…4`, `aldeana_anciana_1…3`, `aldeano_1…2`). Pelo gris o blanco, barbas, ropa sencilla de colores apagados, cuerpo robusto o delgado. Se hacen con el `HumanRig` que ya existe, sin modelos nuevos.
- **Rutas en la zona:** `"walkers": [{"npc": "aldeano_anciano_1", "route": [[x, z], …], "speed": 1.2, "pause_s": 3, "loop": true}]`. Cada variante tiene las suyas (en fiesta, más gente).
- **Movimiento en el cliente:** la posición sale del reloj del anfitrión (`tick`). Así todos los ven en el mismo sitio sin enviar nada. Andan con la animación de caminar y se paran en cada punto de la ruta `pause_s` segundos.
- **No chocan:** no son sólidos para nadie. Con E saludan con una frase suelta en el chat (`lines.greet`).
- **PNJ de misión quietos:** Mira, Brann, Verrin, la anciana, el panadero y el cazador no pasean.

### 10. Personajes y arte nuevos
- **PNJ con nombre:**
  - **Mira:** gemela, 18 años, alegre; el colgante se lo dan en la fiesta.
  - **Verrin:** capitana, con armadura del reino.
  - **Soldados del reino:** sin nombre, para escenas y el campamento.
  - **La anciana cantora**, **el panadero** y **el cazador**.
- **Piezas vóxel nuevas** (`tools/art/make_pieces_v2.mjs`):
  - de fiesta: guirnaldas, farolillos, mesas largas y hoguera;
  - de ruina: casas quemadas, escombros, vigas caídas y tumbas;
  - del ejército: tiendas y estandarte;
  - del bosque: campamento abandonado, huellas de carro y orilla del río;
  - el muñeco.
- **Poses nuevas en el `HumanRig`:** `kneel` (arrodillarse), `point` (señalar) y `lie` (caído, quieto). Se suman a las de las escenas.
- **Efectos de escena:** `fire` (llamas vóxel), `smoke` (humo) y `flash` (destello blanco al despertar el poder). Hoy son un gancho vacío.

### 11. El bosque
- **Rastro del culto** en el Bosque de Eldarra: un **campamento abandonado** (tiendas rotas, hoguera apagada, carros), **huellas de carro** marcadas por el camino y la **orilla del río** al norte, donde el rastro se pierde. Se dibuja con piezas nuevas y puntos de misión.

### 12. Textos
- Diálogos y escenas con las frases del guion (*Diálogo clave* de cada misión) y frases nuevas en el mismo tono para lo que el guion no detalla.
- Todo en `textos.csv`.

## Pruebas (GUT)
- **Datos:** las tres misiones, sus diálogos y sus escenas se validan (las mismas pruebas de la 0.12.0). Los aldeanos que pasean tienen rutas dentro del mapa y sobre casillas libres.
- **Objetivos nuevos:** `hit` cuenta solo al tipo indicado y con el ataque pedido, `dodge` cuenta las esquivas y `class` se cumple al elegir clase.
- **Clase:** se elige sin instructor solo con el objetivo `class` activo; sin él se rechaza.
- **Muñeco:** no baja de 1 de vida, se rellena, no ataca y no da experiencia.
- **Huida:** al 10 % el Heraldo deja de recibir daño, cuenta como derrotado para la misión, no suelta botín y desaparece a los 3 s.
- **Personajes antiguos:** un guardado v6 se mueve a `antiguos/` y no sale en la lista; el aviso sale una vez; un v7 sí carga.
- **Integración:** un personaje nuevo recorre las tres misiones con las peticiones del cliente:
  - acaba en la aldea en ruinas, con clase, `tutorial_done`, la marca `apodo` y el nivel esperado;
  - en ningún momento hay otro jugador en sus zonas propias.
- **Paseantes:** la posición de un aldeano en el tick N es la misma en dos clientes, y se para en los puntos de la ruta.
- **Interfaz:** la ventana de clase no se cierra sin elegir durante el asalto; los textos del recuadro caben a 1280×720.

## Decisiones tomadas
- Las del usuario, arriba, se apuntan en [[D-019 Prólogo como tutorial y clase en el asalto]].
- **Elecciones de Claude** (corregibles):
  - el Heraldo del prólogo es una versión rebajada del Acólito (`heraldo`);
  - la máscara del culto se queda en la bolsa hasta la capital;
  - los aldeanos genéricos saludan en el chat con E;
  - los personajes antiguos se mueven a `antiguos/` en vez de borrarse;
  - 2 niveles al terminar el asalto y 1 al terminar la misión 3;
  - el nivel de la arena pasa a un comando del anfitrión.

---
← [[Planes]]
