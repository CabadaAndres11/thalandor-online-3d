---
tags: [plan, spec]
plan: 3
fecha: 2026-11-15
estado: aprobada
actualizado: 2026-11-15
---
# Plan 3 — Combate y clases: diseño

## Objetivo
Que se pueda **luchar**: tú y tus amigos, cada uno con su clase, os enfrentáis en el escenario de pruebas a lobos, jabalíes, goblins, esqueletos arqueros, limos, sus versiones élite y un jefe. Cada clase juega distinto desde el primer minuto, con su recurso y su **kit completo**:
- 7 activas y 4 pasivas por clase (GDD §4.2–4.3 y notas de cada clase);
- la esquiva común;
- la recarga global.

En grupo hay amenaza, derribo y levantamiento. Todo se ve en un HUD de combate. Las habilidades se colocan en la barra desde la ventana **K**.

**Por qué:** el combate es el corazón del juego. Los planes siguientes (progresión, objetos, mundo) dan razones para luchar, y este da la forma de hacerlo.

**Éxito:**
- Dos o más jugadores en grupo limpian el escenario y derrotan al jefe esquivando sus avisos en el suelo.
- Cada uno entiende de un vistazo su vida, su recurso y sus recargas.
- Si alguien cae, otro lo levanta con **E**.

## Fuera de alcance
- **Nivel, experiencia, atributos y talentos (Plan 4).** Todos los personajes tienen las estadísticas base de su clase a nivel 1. Todas las habilidades del kit están **desbloqueadas de forma provisional**; el Plan 4 las irá bloqueando por nivel con los datos que ya llevan (`level`).
- **Mejoras de clase del nivel 50** (Plan 4 y siguientes).
- **Botín, equipo, durabilidad y pociones (Plan 5).** Al morir no se pierde durabilidad todavía, y Q y R no hacen nada.
- **Zonas, mazmorras, puntos de control reales y reaparición por zonas (Plan 6).** El escenario de pruebas tiene un punto de reaparición y sus monstruos.
- **Audio (Plan 7).** Opciones y reasignación de teclas (Plan 7).
- **Anti-trampas** (§1.2).

## Enfoques considerados
| Enfoque | Qué es | Pros | Contras |
|---|---|---|---|
| **1. Habilidades como datos en la simulación (elegido)** | Cada habilidad es un archivo en `data/abilities/` que combina **efectos genéricos**. El anfitrión resuelve el combate en `sim/`, de forma determinista | Contenido como datos (norma 9). Encaja con la red actual. Se prueba con tests sin ventana | Las mecánicas raras necesitan reglas de clase en código |
| 2. Una clase de código por habilidad | 35 scripts | Libertad total | Cada habilidad nueva obliga a programar |
| 3. Física de Godot para los golpes | `Area3D` en la escena | Detectar impactos es fácil | No es determinista y rompe la predicción y los tests de `sim/` |

**Arte de los monstruos** (decidido con el usuario):
- **Humanoides:** el modelo de Kenney Blocky Characters, con pieles de monstruo y piezas vóxel.
- **Bestias:** **Kenney Cube Pets 2.0** (CC0) recoloreado. El usuario lo bajó a Descargas el 2026-11-15.
- **El limo:** vóxel como datos.
- **Descartados:** los packs de otros autores eran de pago o prohibían redistribuir, y el repositorio es público.

## Diseño

### 1. Estadísticas y daño (`sim/`)
- **Estadísticas de combate** de cada entidad (jugador o monstruo):
  - vida máxima;
  - recurso;
  - poder físico y mágico;
  - armadura;
  - probabilidad de crítico (5 % base);
  - esquiva;
  - velocidad;
  - multiplicadores (daño hecho, daño recibido, curación hecha y recibida, amenaza).
- **Fórmulas** del GDD §4.7, sin la parte de atributos, que llega en el Plan 4:
  - **daño** = `(base + coeficiente × poder) × variación ±10 % × multiplicadores`;
  - **mitigación** por armadura = `armadura / (armadura + K)`, con tope del 75 %;
  - **crítico** ×1,5;
  - la **esquiva** de los monstruos y del asesino o el arquero anula un golpe.
- **Azar determinista:** solo el anfitrión tira dados, con un generador con semilla por partida. Los clientes no los repiten, ven el resultado.
- **Estadísticas base por clase** en `data/characters/classes.json`. Las constantes (K, topes, recarga global, esquiva común, tiempos de derribo y reaparición) van en `data/balance.json`.

### 2. Recursos de clase (GDD §4.1)
| Recurso | Clase | Regla |
|---|---|---|
| Ira | Guerrero | Sube al golpear y al recibir daño; baja fuera de combate |
| Maná | Clérigo y Mago | Se regenera fuera de combate; en combate solo con la pasiva *Meditación*, al 50 % |
| Concentración | Arquero | Se regenera rápido parado o andando y despacio al esquivar; los disparos cargados la gastan |
| Energía | Asesino | Se regenera rápido a ritmo fijo |

"En combate" significa haber hecho o recibido daño en los últimos 5 s (valor en datos).

_Decisión mía:_ el **ataque básico (clic izquierdo) no gasta recurso** en ninguna clase. Así nadie se queda sin poder hacer nada en un combate largo, aunque el maná no se regenere en combate y todavía no haya pociones. La excepción es el disparo **cargado** del arquero, que gasta concentración (el disparo sin cargar es gratis).

### 3. Habilidades como datos (`data/abilities/<clase>.json`)
- **Cada habilidad lleva:**
  - id, claves de texto de nombre y descripción, icono;
  - tipo (`basic`, `secondary`, `active` o `passive`);
  - `level` (para el Plan 4);
  - coste, recarga, si respeta la recarga global, alcance;
  - una lista de **efectos**.
- **Efectos genéricos**, combinables y con parámetros:
  - `melee_arc`: arco frontal con ángulo y alcance;
  - `projectile`: velocidad y radio; puede atravesar o explotar en área;
  - `area`: en el cursor o alrededor, con retardo y **aviso en el suelo**;
  - `dash` y `blink`: hacia el cursor, hacia atrás o a la espalda del objetivo;
  - `heal` (directa o en el tiempo) y `shield` (absorbe daño);
  - `status`: aturdir, inmovilizar, congelar, ralentizar, veneno acumulable, quemadura, marca (+daño recibido), +daño al grupo, −daño recibido, +esquiva, provocar;
  - `trap`: se coloca en el suelo y se activa al pisarla;
  - `stealth`;
  - `cleanse`: quita efectos negativos;
  - `revive` a distancia.
- **Reglas de clase en código**, pequeñas y con tests, para lo que no es un efecto:
  - **Guerrero:** ira; *Carga* aturde al llegar.
  - **Arquero:** el disparo básico se **carga** manteniendo el botón (más daño y alcance) y gasta concentración; *Ráfaga* hace crítico cada 5.º disparo básico.
  - **Asesino:**
    - **puntos de combo** (0–5) que gasta *Eviscerar*;
    - **sigilo**: los monstruos no lo detectan, se rompe al atacar o al recibir daño, y el primer golpe es crítico con *Emboscada*;
    - **golpe por la espalda**: el ángulo respecto a hacia dónde mira el objetivo;
    - veneno acumulable hasta 5.
  - **Clérigo:** *Sanar* cura al aliado bajo el cursor y, si no hay ninguno, a sí mismo.
- **Pasivas como datos:** modificadores de estadística (+10 % armadura, +10 % maná…). Las que son reglas (*Sed de sangre*, *Ráfaga*, *Concentración*, *Ignición*, *Frío penetrante*, *Golpe por la espalda*, *Evasión mortal*, *Oportunista*, *Eco de luz*, *Bloqueo experto*, *Furia contenida*, *Meditación*) usan un **gancho** con nombre y parámetros. Ejemplos: `on_crit_heal_pct`, `every_nth_basic_crits`, `bonus_vs_status`.
- **Las habilidades de cada clase** son las del GDD, notas [[Guerrero]], [[Clérigo]], [[Mago]], [[Arquero]] y [[Asesino]]. Los **valores iniciales** los fija el plan en datos y se ajustan tras las pruebas de juego.

### 4. Controles y barra (GDD §3.2 y §4.3)
- **Clic izquierdo:** ataque básico. **Clic derecho:** secundario. **1–4:** las cuatro casillas. **Espacio:** esquiva. **E:** levantar a un aliado. Todo apunta al **punto del suelo bajo el cursor**.
- **Recarga global** de 0,5 s entre habilidades. No afecta al básico, al secundario ni a la esquiva.
- **Esquiva común:** salto corto (unos 3 m) en la dirección de movimiento, o hacia el cursor si estás quieto. Da una invulnerabilidad breve (unos 0,3 s) y tiene una recarga de unos 3 s.
- **Ventana K (Habilidades):** la clase y su recurso; todas sus activas con icono, coste, recarga y descripción; sus pasivas. Para colocar una activa, se hace clic en ella y luego en una casilla del 1 al 4.
- La barra se guarda en el personaje: `CharacterData` pasa a la **versión 2**, con migración desde la 1, y la barra por defecto son las activas de nivel 1 a 6. La ventana cabe a 1280×720 sin scroll.

### 5. Monstruos (`data/monsters/*.json`)
| Monstruo | Modelo | Comportamiento |
|---|---|---|
| Lobo | Cube Pets (`dog` o `fox`, en gris) | En manada, rápido, mordisco cuerpo a cuerpo |
| Jabalí | Cube Pets (`hog`) | **Carga** en línea recta con aviso en el suelo |
| Goblin | Kenney Blocky, piel verde, orejas vóxel y cuchillo | Cuerpo a cuerpo, en grupos |
| Esqueleto arquero | Kenney Blocky, piel de hueso y arco vóxel | A distancia, se aleja si te acercas |
| Limo | Vóxel como datos (cubo con ojos) | Lento, con mucha vida, a saltos |
| **Élite** (modificador) | Cualquiera, a ×1,3 de tamaño y con un aura | Más vida y daño |
| **Jefe: Rey orco** | Kenney Blocky a ×1,8, con armadura y hacha vóxel | 3 fases por vida: golpe en arco, salto con área avisada y llamada de goblins; los ataques fuertes se avisan en el suelo |

- **Datos de cada tipo:** estadísticas, velocidad, modelo y color, ataques (con los **mismos efectos** que los jugadores), comportamiento y distancias de detección y de **correa**, es decir, cuánto se alejan antes de volver.
- **IA en `sim/`** (determinista):
  - estados reposo → persecución → ataque → vuelta a su zona (se curan al volver);
  - **caminos** con `AStarGrid2D` sobre el mapa de colisión, en lugar de `NavigationAgent3D`, porque la simulación es propia y la física de Godot no es determinista.
- **Amenaza:** tabla por monstruo. El daño y la curación generan amenaza; *Provocar* fuerza el objetivo unos segundos; los multiplicadores vienen de pasivas y estados. El monstruo ataca al que más amenaza tiene, con un margen del 10 % para no cambiar de objetivo a cada momento.
- **Escalado por grupo:** la vida se multiplica por `1 + 0,75 × (jugadores − 1)`.
- **Cube Pets comprobado:** el zip de Descargas se llama `kenney_cube-pets_1.0.zip`, pero su licencia dice **versión 2.0**. Trae `dog`, `fox` y `hog`, entre otros 24, con piezas rígidas (cuerpo, patas, cola) y las animaciones `idle`, `walk` y `run`, además de `eat`, `dance` y gestos. No trae ataque ni muerte; esas dos se hacen por código (§8).
- **Escalado al cambiar el grupo:** _decisión mía:_ si entra o sale un jugador a mitad de combate, la vida máxima de cada monstruo se recalcula y la vida actual se ajusta en la misma proporción.
- **Escenario plano:** el escenario sigue siendo de un solo nivel (rejilla 2D), igual que la simulación actual. Alturas, rampas y escaleras llegan con el mundo (Plan 6).
- **"Limpiar el escenario":** _decisión mía:_ al morir el jefe sale en el chat "¡El Rey orco ha caído!" para todo el grupo, y el jefe reaparece a los 3 minutos. Los demás monstruos reaparecen con su temporizador. No hay pantalla de victoria.
- **Reaparición** con temporizador. Los puntos de aparición, con tipo, cantidad y tiempo, van en `data/maps/test_arena.json`. El escenario se amplía un poco para que quepan.

### 6. Muerte, derribo y reaparición (GDD §5)
- **Vida a 0 en grupo, con algún aliado en pie:** quedas **derribado**. No puedes actuar, ves una cuenta atrás y los monstruos te ignoran. Un aliado cerca mantiene **E** unos 3 s y te levanta con el 30 % de la vida. *Resurrección* del clérigo hace lo mismo a distancia.
- **Solo, o si cae todo el grupo:** pasados 3 s reapareces en el punto de reaparición con toda la vida. Los monstruos que te atacaban vuelven a su zona.
- Al morir no se pierde experiencia ni, de momento, durabilidad (Plan 5).

### 7. Red (sigue siendo host-autoritativa)
- **Entradas:** además de mover y apuntar, cada tick lleva los **botones pulsados**: básico (y si se mantiene, para la carga), secundario, casillas 1–4, esquiva e interactuar. Las acciones se marcan con su número de secuencia, para que una pulsación no se pierda ni se repita si un paquete llega dos veces o se pierde.
- **El anfitrión resuelve todo:** habilidades, efectos, daño, IA y amenaza.
- **Predicción en tu cliente:** el movimiento (como ahora) y la **esquiva** (el salto). Al pulsar una habilidad, tu personaje empieza la animación al instante, pero el impacto, el daño y el gasto de recurso se ven cuando llegan del anfitrión. La spec acepta ese retraso de un ping.
- **Instantáneas:** cada jugador lleva vida, recurso, estados y animación de acción; cada monstruo, posición, vida, estado y objetivo (para el HUD y la animación). Los monstruos se dibujan **interpolados**, como los demás jugadores.
- **Eventos de combate** (fiables, en lote por tick): impacto con su cantidad y si fue crítico, curación, aplicar o quitar un estado, aparición y destino de proyectiles, avisos en el suelo, derribo, levantamiento, muerte, reaparición, monstruos que aparecen y mueren.
- **Límites:** las instantáneas deben seguir cabiendo en el tamaño máximo de paquete con 4 jugadores y unos 30 monstruos. Si no caben, se reparten entre ticks y se envían solo los monstruos cercanos a cada jugador. Sube la versión del protocolo.

### 8. Presentación
- **Animaciones de personaje** con las que trae Kenney: `attack-melee-right/left`, `holding-*-shoot`, `interact-*` y `die`. Los lanzamientos de hechizo y la esquiva se hacen con combinaciones cortas de esas.
- **Cube Pets:** andar, correr y reposo vienen del pack; el ataque (embestida corta) y la muerte (vuelco y desaparición) se hacen por código.
- **Efectos visuales sencillos en vóxel y partículas de Godot:**
  - proyectiles (flechas, bolas de luz, de fuego y de escarcha);
  - destello del arco de golpe;
  - círculos y conos en el suelo para las áreas y los **avisos**, que se llenan hasta el impacto;
  - burbuja de escudo;
  - personaje translúcido en sigilo;
  - icono de estado sobre la cabeza (aturdido, congelado, envenenado…).
- **Números de daño flotantes:** blanco el daño normal, amarillo el crítico, verde la curación y gris la esquiva o el bloqueo.

### 9. HUD de combate (GDD §9.2)
- **Abajo en el centro:**
  - vida y recurso propios, en barras con número;
  - la barra de habilidades en **casillas cuadradas con icono** (CI, CD, 1–4, Espacio), con su tecla, barrido de recarga, la recarga global y la casilla atenuada si no llega el recurso.
- **Encima de cada personaje y monstruo:** nombre y barra de vida. Los monstruos solo la muestran si están heridos o en combate.
- **Jefe:** barra grande arriba con su nombre y la fase.
- **Aliados:** marcos sencillos a la izquierda (nombre, vida y "derribado"). Los marcos completos llegan en el Plan 7.
- **Derribado:** cuenta atrás en pantalla. Al levantar a alguien, una barra de progreso.
- **Puntos de combo** del asesino y **carga** del disparo del arquero, junto a la barra de recurso.
- **Iconos de habilidad:** generados por un script, con forma y color de la clase y un símbolo. Se cambiarán por iconos dibujados cuando los haya.
- Todo cabe a 1280×720 sin scroll y los textos van en `textos.csv`.

### 10. Arte nuevo
- **Pieles de monstruo** (goblin, esqueleto, orco) con el mismo sistema de capas que los personajes.
- **Piezas vóxel:** orejas de goblin, arco, cuchillo, hacha y armadura del jefe, y el limo entero.
- **Cube Pets recoloreado:** se copian a `assets/monsters/` solo los modelos que se usan y su textura (CC0, en `CREDITS.md`).
- **Iconos** de habilidad y **efectos visuales**, generados por scripts en `tools/art/`.
- **Puntos de control de arte:** capturas de los monstruos, y del HUD con efectos, antes de seguir.

## Orden y puntos de control
1. **Núcleo de combate:**
   - estadísticas, daño, recursos, efectos básicos (`melee_arc`, `projectile`, `area`, `dash`);
   - la esquiva y la recarga global;
   - la red de combate;
   - el **kit de nivel 1** de cada clase (3 habilidades), el lobo y el limo;
   - el HUD básico.

   **Punto de control jugable:** se publica la **0.3.0** para que el usuario lo pruebe.
2. **Resto de efectos y kits completos**, pasivas y ventana K.
3. **Resto de monstruos**, élites, el jefe, amenaza, derribo y reaparición.
4. **Cierre**, revisión y versión **0.4.0**.

## Pruebas
**Automáticas (GUT):**
- **Fórmulas:** daño, mitigación con tope, crítico, variación con semilla y esquiva.
- **Recursos:** generación, decaimiento y regeneración en combate y fuera.
- **Cada efecto genérico:** quién recibe el golpe (ángulo y alcance del arco, impacto y atravesar del proyectil, área y retardo), estados con duración y acumulación, escudos, trampas y sigilo.
- **Cada regla de clase:** combos, carga del disparo, espalda, ira, *Sanar* sobre aliado o sobre uno mismo, provocar.
- **Cada pasiva**, con un test de su gancho.
- **Recarga global y esquiva:** invulnerabilidad y recarga.
- **IA:** detección, persecución con caminos alrededor de bloques, ataque, vuelta por correa, carga del jabalí, alejarse del arquero, fases del jefe.
- **Amenaza:** elección de objetivo, margen y provocar.
- **Derribo y levantamiento:** E con su tiempo y cancelación; reaparición en solitario y si cae todo el grupo; escalado de vida.
- **Red:** acciones no perdidas ni repetidas con pérdida y duplicados; la esquiva predicha coincide con el anfitrión; varios clientes en memoria ven los mismos eventos; las instantáneas caben en un paquete con 4 jugadores y 30 monstruos.
- **Datos:** todo archivo de habilidad y monstruo es válido, sus textos existen y los efectos referenciados están implementados. `CharacterData` v1 → v2.
- **Interfaz:** HUD, ventana K y marcos caben a 1280×720.

**De juego (usuario):** la sensación de cada clase, la dificultad de cada monstruo y del jefe, que los avisos se entiendan y el combate en grupo con derribo.

## Decisiones tomadas
- **Kits completos en este plan**, desbloqueados de forma provisional. Usuario.
- **Monstruos:** modelo de Kenney para los humanoides y Cube Pets para las bestias, buscando packs que encajen. Usuario.
- **Lista de monstruos y jefe (Rey orco).** Usuario.
- **Habilidades como datos en la simulación** (enfoque 1). Usuario.
- **Decisiones mías:**
  - caminos con `AStarGrid2D` en lugar de `NavigationAgent3D`;
  - predicción solo de movimiento y esquiva;
  - iconos generados;
  - puntos de control con publicación intermedia 0.3.0 y final 0.4.0;
  - barra guardada en el personaje (`CharacterData` v2);
  - el ataque básico no gasta recurso, salvo el disparo cargado del arquero;
  - la vida de los monstruos se recalcula al cambiar el grupo;
  - el jefe reaparece a los 3 minutos y su derrota se anuncia en el chat.

---
← [[Planes]]
