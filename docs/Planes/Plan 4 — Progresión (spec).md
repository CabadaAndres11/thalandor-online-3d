---
tags: [plan, spec]
plan: 4
fecha: 2026-11-16
estado: borrador
actualizado: 2026-11-16
---
# Plan 4 — Progresión: diseño

## Objetivo
Que el personaje **crezca**: gana experiencia al matar, sube de nivel sin tope, desbloquea habilidades y pasivas, reparte atributos y talentos, y al nivel 50 elige su primera mejora de clase. Todo el progreso se guarda con el personaje.

**Por qué:** hasta la 0.5.0 todos los personajes son de nivel 1 y nada de lo que se juega deja huella. La progresión es lo que da sentido a repetir combates y es requisito de los objetos (Plan 5) y de las zonas (Plan 6).

**Versión:** 0.6.0, protocolo de red 6, personajes versión 3 (hoy 2).

## Fuera de alcance
- Oro, objetos y equipo (Plan 5). Los reinicios son **gratis** hasta entonces.
- Capital e instructor de clase (Plan 6). **Brann** hace de instructor provisional.
- Cambio de clase (§4.9) y rangos de clase del nivel 100 en adelante.
- Rehacer los kits base de Guerrero, Clérigo, Mago y Arquero (solo se rehace el del Asesino).
- Sonido.

## Antifines
- Que añadir un nodo, una mejora o un nivel exija tocar `sim/`: todo es dato en `data/`.
- Que un cliente pueda darse niveles, puntos o nodos: el anfitrión valida cada petición.
- Que una actualización borre o rebaje un personaje guardado.
- Que alguna ventana necesite scroll a 1280×720.
- Que las estadísticas se disparen a niveles altos (rendimientos decrecientes y topes).

## Enfoques
- **A (elegido): el anfitrión manda.** Las reglas viven en `sim/progression/` (portadas del prototipo 2D, `D:\RPG\src\sim\progression`). El cliente pide, el anfitrión valida y aplica, y devuelve el progreso a su dueño, que lo guarda en su archivo de personaje. Es el mismo patrón que la elección de clase (0.5.0).
- **B: el cliente calcula su personaje** y envía las estadísticas finales. Descartado: incoherencias entre jugadores y trampas triviales.
- **C: el anfitrión guarda el progreso de todos.** Descartado: el personaje dejaría de poder jugar solo o con otro anfitrión.

Con A, el anfitrión **se fía del progreso que trae cada jugador** en el `HELLO` (como hoy con la clase), pero lo **sanea**: si los puntos gastados no cuadran con el nivel, se reinician atributos o talentos.

## Diseño

### 1. Experiencia y niveles
- **Curva** (`data/balance.json`, bloque `xp`): `xp_para_subir(L) = round(100 × L^1,6)` hasta el nivel 50; desde el 50, lineal: `xp(50) + 2500 × (L − 50)` *(propuesta de Claude, ajustable)*.
- **Experiencia por monstruo:** `round(8 × nivel^1,2)`, ×4 si es élite, ×10 el jefe *(el ×10 es propuesta de Claude)*. Si el jugador supera al monstruo en más de 2 niveles, −20 % por nivel de más, con mínimo del 10 %.
- **Reparto:** entre los jugadores vivos o derribados a 30 m o menos del monstruo; cada uno recibe `total × (1 + 0,1 × (n − 1)) / n`, con su propio factor de nivel.
- **Al subir:** vida y recurso al máximo (la ira no se rellena), efecto visual sobre el personaje y aviso en el chat para todos.
- **Morir** no quita experiencia. **Sin nivel máximo.**
- **HUD:** barra de experiencia fina bajo la barra de habilidades y el nivel junto al nombre (propio, aliados y sobre la cabeza).

### 2. Monstruos con nivel y arena que escala
- Cada monstruo tiene un **nivel**. Sus estadísticas de `data/monsters/` son las de nivel 1 y crecen por nivel con factores de `balance.json` (bloque `monster_scaling`): vida ×(1 + 0,12 × (L − 1)), daño ×(1 + 0,08 × (L − 1)), armadura ×(1 + 0,06 × (L − 1)) *(propuesta de Claude; se ajustará para que un jugador de nivel L con puntos repartidos tarde parecido en matar a un monstruo de nivel L)*.
- **`armor_k` crece con el nivel del atacante** (§4.7), para que la armadura no pierda valor.
- **Nivel de la arena:** un número de 1 a 60, estado de la partida en el anfitrión (no se guarda; empieza en 1). Los monstruos toman ese nivel; el jefe, +2. El mapa puede fijar un desfase por grupo (`level_offset`).
- **Se cambia con Brann:** solo el anfitrión ve la opción *Nivel de la arena*. Al cambiarlo, los monstruos vivos fuera de combate se rehacen al nivel nuevo y los que están en combate lo harán al reaparecer. Aviso en el chat.
- El nivel se muestra junto al nombre del monstruo, sobre su barra.
- **Comandos de pruebas** en el chat, solo para el anfitrión: `/xp <cantidad> [nombre]` y `/nivel <n> [nombre]`. Sin nombre actúan sobre su propio personaje; con nombre, sobre ese jugador de la partida. `/nivel` solo sube, nunca baja. Marcados como herramienta de pruebas; se retirarán antes de la demo.

### 3. Desbloqueos por nivel
- Cada habilidad ya trae `level` en `data/abilities/`. Las **activas** de nivel superior al del personaje aparecen con candado en la ventana K y no se pueden poner en la barra; el anfitrión las quita en `sanitize_bar` y rechaza su lanzamiento.
- Las **pasivas** se activan al llegar a su nivel (ya se recogen por nivel; ahora el nivel cambia).
- Al desbloquear una habilidad con hueco libre en la barra, se coloca sola y se avisa en el chat.

### 4. Atributos (§4.5)
- **Cinco atributos:** Fuerza, Agilidad, Intelecto, Aguante y Espíritu.
- **Por nivel:** 5 puntos libres, más 2 puntos automáticos en los atributos principales de la clase (`main_attributes` en `classes.json`: Guerrero fuerza y aguante; Clérigo intelecto y espíritu; Mago intelecto y espíritu; Arquero agilidad y aguante; Asesino agilidad y fuerza) *(propuesta de Claude: 1 punto en cada uno)*.
- **Conversión a estadísticas** en `balance.json` (bloque `attributes`), con valores de partida del prototipo 2D y rendimientos decrecientes por tramos; crítico, esquiva y bloqueo con tope.
  - Fuerza: poder de ataque cuerpo a cuerpo y bloqueo (0,2 % por punto).
  - Agilidad: crítico, esquiva y poder de ataque a distancia.
  - Intelecto: poder de hechizos y maná máximo.
  - Aguante: vida máxima.
  - Espíritu: regeneración de vida y de maná.
- **Bloqueo** pasa a existir como estadística: un bloqueo reduce a la mitad el daño físico cuerpo a cuerpo. *Bloqueo experto* del Guerrero se engancha a él.
- El **aldeano** también sube de nivel y reparte puntos; al elegir clase los conserva.

### 5. Cálculo de estadísticas (§4.7)
Una sola función, `Progression.rebuild(player)`, que se llama al entrar, subir de nivel, gastar o reiniciar puntos y elegir mejora:
```
final = (base de clase + atributos + bonos planos) × (1 + suma de bonos %)
```
- Bonos de talentos, pasivas (base y de mejora) y maestrías. Los porcentajes de una misma estadística se suman antes de multiplicar. Sustituye al `Passives.apply_stats` actual, que multiplica en cadena.
- Estadísticas nuevas en `CombatStats`: bloqueo, daño crítico, reducción de recargas (tope 40 %), robo de vida, regeneración de vida, y poder de ataque y de hechizos en %.
- Al reconstruir se conserva el **porcentaje** de vida y de recurso que tenía el personaje.

### 6. Árbol de talentos (§4.6, [[Anexo C — Árbol de talentos]])
- **Datos:** `data/talents.json` con los 46 nodos del anexo (posición, tipo, bonos y enlaces), generado por un script de `tools/` a partir de la tabla del anexo.
- **Puntos:** 1 por nivel desde el 2. Se compra un nodo conectado al centro o a uno ya comprado.
- **Anillo exterior del nivel 50** *(diseño de Claude, no estaba en el anexo)*: 20 nodos más, 2 por radio a continuación del último nodo actual, con los mismos bonos del radio a un valor mayor. En las 5 direcciones puras, el segundo de esos nodos es un **culminante mayor**. Los primeros nodos nuevos de radios vecinos se conectan entre sí formando un anillo. Visible desde el principio, en gris y con el texto *Se desbloquea con el rango de clase (nivel 50)*. Los valores se añaden al anexo.
- **Maestrías:** cuando no queda nada por comprar, cada punto sube un rango de una maestría a elegir entre 5 (una por dirección; por ejemplo +0,1 % de vida por rango) con rendimiento decreciente.
- **Ventana (T):** el círculo completo, centrado, sin scroll. Nodos comprados encendidos, comprables resaltados, el resto apagados. Al pasar el ratón, panel lateral con nombre y bonos; clic para comprar; contador de puntos libres. Las maestrías, en una fila bajo el círculo cuando están disponibles.

```
┌──────────────────────── Talentos ─────── Puntos: 3 ┐
│            Poderío                    ┌───────────┐│
│      Arc·     ◆      ·Cel             │ Nodo      ││
│        ○──○──●──○──○                  │ +3 % poder││
│   Arcano ○──●─(★)─●──○ Celeridad      │ de ataque ││
│        ○──○──●──○──○                  │           ││
│      Bas·     ◆      ·Vit             │ [Comprar] ││
│    Bastión         Vitalidad          └───────────┘│
│  Maestrías: [P 0] [C 0] [V 0] [B 0] [A 0]          │
└────────────────────────────────────────────────────┘
```

### 7. Ventana de personaje (C)
Nombre, clase, mejora, nivel y experiencia; los 5 atributos con botón **+** y puntos libres; y la lista de estadísticas finales (vida, recurso, poderes, armadura, crítico, esquiva, bloqueo, etc.). Sin scroll. Los cambios se envían al momento.

### 8. Mejoras de clase del nivel 50 (§4.4)
- Al llegar al 50, aviso en el chat: *Habla con Brann para elegir tu mejora de clase*.
- **Brann** abre la ventana *Mejora de clase*: las 2 opciones (3 para el Mago) con sus 2 activas, 2 pasivas y la evolución, cada una con el mismo detalle calculado que la ventana K. Confirmar aplica la mejora.
- **Efecto:** las 2 activas pasan a estar disponibles en la ventana K, las 2 pasivas se activan y la habilidad base evoluciona (un bloque `evolves` en la mejora que sustituye campos de la habilidad base).
- **Datos:** `data/upgrades/<clase>.json`; las habilidades nuevas van en `data/abilities/<clase>.json` con `upgrade: <id>`.

| Clase | Mejora | Activas | Pasivas | Evolución |
|---|---|---|---|---|
| Guerrero | **Protector** | Provocar en área; Represalia (escudo que devuelve daño) | Postura defensiva (+100 % amenaza, +15 % vida); Último bastión (bajo el 20 % de vida: −40 % daño 8 s) | Muro de escudo protege también a los aliados cercanos |
| Guerrero | **Berserker** | Frenesí (10 s: más daño y recargas más cortas, +15 % daño recibido); Ejecutar (gran daño bajo el 25 %; si mata, devuelve la ira) | Furia sangrienta (hasta +25 % de daño según la vida que falta); Masacre (matar reinicia Carga y cura un 5 %) | Tajo golpea dos veces |
| Clérigo | **Sanador** | Círculo de sanación; Himno divino (canalizado) | Ángel guardián (salva a un aliado de un golpe mortal); Gracia mayor (+20 % curación) | Sanar rebota a un segundo aliado |
| Clérigo | **Templario** | Golpe de cruzado (mazazo sagrado cuerpo a cuerpo que cura parte del daño); Consagración (suelo sagrado alrededor: daña enemigos y cura un poco a los aliados) | Armadura de fe (+40 % armadura, +15 % vida); Celo (los golpes cuerpo a cuerpo devuelven maná) | Destello sagrado pasa a ser un mazazo cuerpo a cuerpo en arco |
| Mago | **Piromante** | Columna de llamas (suelo ardiendo); Meteoro | Combustión (+10 % daño a enemigos ardiendo); Fénix (renace con el 30 % de vida) | Bola de fuego deja el suelo ardiendo |
| Mago | **Criomante** | Ventisca; Bloque de hielo | Escalofrío (los ralentizados atacan más lento); Corazón helado (congelar reduce recargas) | Nova de escarcha se lanza en el cursor |
| Mago | **Arcano** | Misiles arcanos (canalizado, 5 proyectiles); Lanza arcana (rayo en línea que atraviesa) | Carga arcana (+4 % daño por hechizo arcano, hasta 5; se pierde a los 6 s); Poder puro (+15 % de crítico con hechizos arcanos) | Explosión arcana estalla sin retardo y con más área |
| Arquero | **Francotirador** | Disparo apuntado (canalizado, gran daño); Ráfaga de 3 flechas | Punto débil (+daño crítico a distancia); Paciencia (+daño estando quieto) | Disparo cargado atraviesa |
| Arquero | **Cazador** | Disparo múltiple (abanico de 5); Compañero animal (lobo) | Trampero (las trampas se rearman); Superviviente (+10 % vida y velocidad) | Red alcanza a varios enemigos |
| Asesino | **Sombra** | Desvanecer mejorado; Golpe sombrío (teletransporte y crítico) | Asesino nato (+daño bajo el 30 %); Velo (+tiempo de sigilo) | Eviscerar devuelve energía por punto de combo |
| Asesino | **Venenero** | Nube tóxica (área persistente); Contagio (el veneno salta al morir) | Toxicología (veneno hasta 10); Sangre corrupta (los envenenados hacen −10 % daño) | Cuchillada aplica veneno siempre |

- **Templario:** con la evolución su ataque básico es cuerpo a cuerpo y usa poder de hechizos; conserva Sanar y los escudos. Su aspecto cambia la capucha por un yelmo abierto *(propuesta de Claude)*.
- **Cazador:** el arco del personaje se cambia por una **ballesta** (pieza vóxel nueva) y dispara virotes; la carga funciona igual.
- **Arcano:** los hechizos llevan una escuela (`school`: `arcane`, `fire`, `frost`, `holy`) en sus datos; Proyectil arcano y Explosión arcana ya son arcanos.
- **Compañero animal:** un lobo aliado (rig del sabueso sin collar del culto, teñido) que dura 30 s, sigue al arquero, ataca a su último objetivo y genera amenaza. Es una entidad de combate del equipo de los jugadores con la IA de monstruo cuerpo a cuerpo; viaja en las instantáneas como un monstruo más, marcado como aliado.
- **Mecánicas nuevas en `sim/`** que piden estas mejoras (cada una como efecto o gancho genérico, definido por datos): áreas persistentes en el suelo, canalizados, proyectil que atraviesa, golpe doble, escudo que devuelve daño, reducción de curación, ejecutar por umbral de vida, salvar de un golpe mortal y renacer, contagio al morir, invocación aliada, y daño según vida que falta.
- **Números** (daño, coste, recarga) a criterio de Claude como propuesta inicial; quedan en la nota de cada clase.

### 9. Kit nuevo del Asesino
| Nivel | Habilidad | Efecto |
|---|---|---|
| 1 | Cuchillada (CI) | Sin cambios |
| 1 | Eviscerar (CD) | Sin cambios |
| 1 | Paso sombrío | Sin cambios |
| 3 | **Lanzar cuchillo** | A 12 m: daño, ralentiza un 40 % durante 3 s y da 1 punto de combo |
| 6 | Sigilo | Antes nivel 3 |
| 10 | Abanico de cuchillas | Antes nivel 6 |
| 15 | Veneno | Antes nivel 10 |
| 20 | **Desgarro** | Golpe fuerte que deja un sangrado y da 2 puntos de combo |
| 30 | **Aluvión de puñaladas** | Cuatro golpes rápidos a un objetivo; da 2 puntos de combo |

- Se **quita Evasión**; las pasivas no cambian. Los personajes guardados con Evasión en la barra pierden esa ranura (queda vacía).
- El Asesino tiene 9 habilidades; las demás clases siguen con 7.

### 10. Brann como instructor provisional
E junto a Brann abre un **menú** con lo que toque:
- *Elegir clase* (aldeano; como hoy).
- *Mejora de clase* (nivel 50 o más sin mejora).
- *Reiniciar atributos*, *Reiniciar talentos*, *Cambiar de mejora*: gratis, con confirmación, fuera de combate.
- *Nivel de la arena* (solo el anfitrión).

Si solo hay una opción posible (aldeano), se abre directamente, como hoy.

### 11. Red (protocolo 6)
- `HELLO` lleva el progreso: nivel, experiencia, atributos, nodos, maestrías y mejora.
- **Peticiones** cliente → anfitrión: `SPEND_ATTRIBUTE`, `BUY_TALENT`, `BUY_MASTERY`, `CHOOSE_UPGRADE`, `RESET {qué}`, `SET_ARENA_LEVEL`. El anfitrión valida (puntos, conexión del nodo, nivel, cercanía a Brann donde aplique, fuera de combate) y responde.
- **Anfitrión → dueño:** `PROGRESS {…}` completo y fiable cada vez que cambia (experiencia incluida, agrupada como mucho una vez por segundo).
- **Anfitrión → todos:** `LEVEL_UP {id, nivel}`, `PLAYER_UPGRADE {id, mejora}` y el nivel de la arena. El nivel de cada jugador y de cada monstruo viaja en las instantáneas.
- Las estadísticas finales las calcula el anfitrión; el cliente recalcula las suyas con las mismas reglas solo para mostrarlas.

### 12. Guardado
- `CharacterData` sube de versión y añade `level`, `xp`, `attributes`, `talents`, `masteries` y `upgrade`. Los personajes anteriores migran a nivel 1 sin puntos.
- El cliente guarda al recibir `PROGRESS`, en cola y sin escrituras simultáneas (§10), y al salir.

## Orden y puntos de revisión
1. Experiencia, niveles, monstruos con nivel, arena que escala y comandos de pruebas.
2. Desbloqueos por nivel, atributos, cálculo de estadísticas y ventana C.
3. Árbol de talentos, maestrías y ventana T.
4. Guardado y red completos (`PROGRESS`, saneado, migración).
5. Kit nuevo del Asesino.
6. Mejoras del nivel 50: mecánicas nuevas, las 11 mejoras, ventana y menú de Brann, ballesta, yelmo y lobo.
7. Documentación, versión 0.6.0 y publicación.

**Parada tras el paso 4** para que el usuario pruebe la progresión base antes de las mejoras *(propuesta de Claude; se salta si dices «implementa directamente»)*.

## Pruebas (GUT)
- **Experiencia:** curva antes y después del 50; experiencia por monstruo, élite y jefe; factor por diferencia de nivel; reparto en grupo y por distancia; varias subidas con una sola ganancia; vida y recurso al subir.
- **Monstruos:** escalado por nivel; cambio del nivel de la arena con monstruos en combate y fuera; `armor_k` por nivel.
- **Desbloqueos:** `sanitize_bar` quita las activas bloqueadas; lanzar una bloqueada se rechaza; las pasivas se activan en su nivel.
- **Atributos:** puntos libres por nivel, gasto, rechazo sin puntos, puntos automáticos por clase, rendimientos decrecientes y topes.
- **Estadísticas:** la fórmula con bonos planos y porcentuales sumados; conservación del porcentaje de vida al reconstruir.
- **Talentos:** `talents.json` es un grafo conexo con 46 + 20 = 66 nodos y enlaces simétricos; comprar exige conexión y puntos; el anillo exterior exige mejora de clase; maestrías solo con todo comprado; reinicio.
- **Mejoras:** cada mejora de `data/upgrades/` tiene 2 activas, 2 pasivas y una evolución que existen; elegir exige nivel 50, cercanía a Brann y no tener ya una; cambiar y reiniciar; una prueba por cada mecánica nueva y por cada evolución.
- **Asesino:** el kit carga con 9 habilidades y sus niveles; una barra guardada con Evasión se sanea.
- **Lobo:** se invoca, sigue, ataca, genera amenaza y desaparece; no da experiencia ni cuenta como jugador.
- **Red:** cada mensaje nuevo se empaqueta y valida; un `HELLO` con progreso imposible se sanea; `PROGRESS` llega solo al dueño; sesiones en memoria con dos clientes.
- **Guardado:** migración de la versión anterior; ida y vuelta de un personaje con progreso.
- **Ventanas:** C, T, mejora y menú de Brann caben en 1280×720 sin scroll.
- Siguen pasando todas las pruebas existentes.

## Decisiones tomadas
- Plan 4 en una sola entrega, con las mejoras del nivel 50 incluidas (usuario).
- Arena que escala: el anfitrión elige el nivel con Brann (usuario).
- Campeón → **Berserker**; Castigador → **Templario**, combatiente cuerpo a cuerpo; tercera mejora del Mago, **Arcano**; Montaraz → **Cazador**, con ballesta (usuario; el contenido de cada una es propuesta de Claude, aceptada).
- Kit del Asesino rehecho con más daño y *Lanzar cuchillo*; se quita Evasión (usuario pidió el cambio; el kit es propuesta de Claude, aceptada).
- El anfitrión manda y cada jugador guarda su progreso (enfoque A; propuesta de Claude, aceptada).
- Brann como instructor provisional y reinicios gratis hasta que haya oro (propuesta de Claude, aceptada).
- Teclas C y T, anillo exterior de 20 nodos, lobo aliado, comandos de pruebas y protocolo 6 (propuesta de Claude, aceptada).
- A criterio de Claude: todos los números de `balance.json` y de las habilidades nuevas, el ×10 de experiencia del jefe, el reparto 1+1 de los puntos automáticos, la escuela de los hechizos, el yelmo del Templario y la parada tras el paso 4.

---
← [[Planes]]
