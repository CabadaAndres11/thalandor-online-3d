---
tags: [plan, spec]
plan: 3.2
fecha: 2026-11-16
estado: borrador
actualizado: 2026-11-16
---
# Plan 3.2 — Vóxel propio, bestiario del prólogo y clase con Brann: diseño

## Objetivo
Que el desarrollo avance en paralelo al guion (*Guión del juego de rol – Historia por misiones*), antes del Plan 4 (progresión):
1. **Todo el arte hecho por código.** Se retira el único paquete externo (Kenney Blocky Characters): los personajes pasan a un rig vóxel propio.
2. **Bestiario del prólogo.** Los enemigos genéricos se sustituyen por los del asalto a la aldea (misión 2).
3. **Clase dentro de la partida.** El personaje se crea sin clase (aldeano) y la elige hablando con Brann, como en «La práctica» de la misión 1.

**Por qué:** el guion define el mundo; el contenido jugable debe ser el suyo y no uno provisional. La clase va ligada a la historia (Brann entrena al protagonista con el arma de su clase).

## Lo que dice el guion (fuente: doc del usuario, no está en el repo)
- **Brann:** antiguo sargento del ejército de la capital y ahora herrero de la aldea; ha criado a los gemelos huérfanos. Aspecto *(propuesta de Claude)*: hombre maduro y robusto, pelo y barba grises, delantal de herrero sobre ropa de aldea, espada al cinto.
- **Aldea:** fantasía medieval, heroica y épica. Ropa de aldeano *(propuesta de Claude)*: camisa de lino y pantalón pardo, cinturón de cuero.
- **Culto del rey demonio:** cultistas «con máscaras». El guion no describe la máscara ni el símbolo; *propuesta de Claude:* máscara lisa hueso con un sol negro partido en cinco (los cinco sellos), y el mismo símbolo en collares y marcas de las bestias.
- **Asalto (misión 2):** monstruos por las calles, cultistas enmascarados, una criatura que derriba al protagonista y «una bestia que ha quedado de guardia» al alba.
- Todos los textos nuevos (línea de Brann, ventana de clases) se marcan provisionales en `textos.csv` hasta que el guion los fije.

## Fuera de alcance
- Misiones, mapa de la aldea, cinemáticas y otros diálogos. Brann vive en el mapa de pruebas actual.
- Enemigos del arco 1 (guardianes de piedra, sombras, Hermano Valk) y del arco 2.
- Niveles, bloqueo de habilidades por nivel y cambio de clase (Plan 4).
- Sonido.

## Antifines
- Que quede cualquier archivo, textura o animación derivada de un paquete externo.
- Que el aldeano sea jugable como clase «completa» o que la elección de clase pueda repetirse.
- Que el cambio de rig empeore lo que ya se ve hoy: animaciones de acción, proporciones por tipo de cuerpo, piezas de clase.

## Diseño

### 1. Humanoide vóxel propio (`HumanRig`) — enfoque A, elegido por el usuario
- **Rig por huesos**, el mismo camino que `BeastRig` y el esqueleto arquero: partes `.vox` (cadera, torso, cabeza, brazo y pierna izquierdos y derechos) colgadas de pivotes, descritas en `assets/characters/vox/human.json`.
- **Generado por código:** `tools/art/make_humans.mjs` crea las partes y la cara (ojos y cejas pintados en vóxeles). `make_pieces.mjs` rehace en vóxel lo que hoy son capas de textura: peinados (corto, media melena, peinado hacia atrás, rapado) y barbas (completa, bigote, corta, perilla). Las piezas vóxel actuales se reaprovechan reubicadas en las nuevas partes.
- **Color por canales de tinte** de `VoxMesher`: se añaden canales para la piel y los ojos, junto a los de pelo, primario y secundario. La ropa de cada clase es el color primario y secundario del torso y las piernas, más sus piezas (hombreras, capucha, sombrero, máscara).
- **Tipos de cuerpo** (esbelto/robusto): escala por parte, como hoy.
- **Animaciones por código**, con un estilo épico y con peso:
  - reposo (respiración);
  - andar, sincronizado con la velocidad como hoy;
  - golpe cuerpo a cuerpo;
  - disparo (alzar el arco y tensar);
  - lanzamiento de hechizo;
  - esquiva o embestida;
  - caído (en el suelo, sin girar con el ratón);
  - muerte.
  `PlayerAvatar` y `MonsterAvatar` llaman a estas acciones por nombre (`melee`, `shoot`, `cast`, `dash`, `die`, `downed`) en lugar de a las animaciones de Kenney.
- **Arma en la mano** según la clase: espada, maza, bastón, arco y dagas. El aldeano lleva una espada de madera. *(Propuesta de Claude: el guion habla de armas de entrenamiento y del regalo de Brann.)*
- **Compatibilidad de apariencia:** se mantienen los ids de `appearance.json` (piel, ojos, color de pelo, peinado, barba, cuerpo), así que los personajes guardados se ven igual sin migración. Cambia solo cómo se dibuja cada id.
- **Se elimina:**
  - `assets/characters/base/`, `assets/characters/layers/` y `character.gdshader`;
  - los scripts que trabajaban sobre Kenney: `extract_layers.mjs` y `paint_outfits.mjs`;
  - la fila de Kenney en `CREDITS.md`.

### 2. Bestiario del prólogo
Los monstruos siguen siendo datos en `data/monsters/`. Los comportamientos y fórmulas de `sim/` no cambian: se reutilizan los de hoy.

| Enemigo (nombre en el juego) | Sustituye a | Modelo | Comportamiento y habilidades |
|---|---|---|---|
| Cultista enmascarado | goblin | `HumanRig`: túnica oscura, máscara del culto, puñal | `melee` en grupo (`pack`); stats del goblin |
| Arquero del culto | esqueleto arquero | `HumanRig`: capucha, máscara, arco | `ranged_kite`; stats del esqueleto |
| Sabueso marcado | lobo | rig del lobo, más fiero, con collar del culto | `melee`; stats del lobo |
| Jabalí marcado | jabalí | rig del jabalí con collar y placas | `charger` con embestida; stats del jabalí |
| Bestia de guardia (jefe) | rey orco | `BeastRig` bípedo nuevo y grande: bruto con cuernos, cadenas y collar del culto | `boss` con tajo y salto; stats y habilidades del rey orco renombradas |

- Los collares y las marcas del culto comparten un símbolo propio (por código) que también lleva la máscara de los cultistas.
- **Se retiran del juego el limo y el esqueleto arquero**, con sus datos, `.vox`, generadores, textos y habilidades. El rig bípedo de `BeastRig` se queda: lo usa la bestia de guardia.
- `data/maps/test_arena.json` reparte los nuevos enemigos y los élites como hoy.

### 3. Aldeano y elección de clase con Brann
- **Aldeano** (`villager` en `classes.json`, marcado como no elegible): stats base modestas y sin recurso de clase. Ataque básico con el arma de madera, sin secundario ni habilidades en la barra; la esquiva funciona igual. Viste ropa de aldea.
- **Creación de personaje:** desaparece el paso de clase. Se elige nombre y apariencia, y la vista previa muestra al aldeano. Todo personaje nuevo nace aldeano.
- **Brann** es un NPC definido en datos (`data/npcs/brann.json`: nombre, aspecto con `HumanRig`, líneas de diálogo en `textos.csv`) y colocado desde el mapa (`npcs` en `test_arena.json`). Es inmóvil e invulnerable, no es una entidad de combate y lleva un nombre sobre la cabeza.
- **Interacción:** con E a 2,5 m o menos. Si hay a la vez un aliado caído en rango, gana la reanimación. Si eres aldeano, Brann abre la **ventana de clases**: las cinco clases con nombre, descripción, recurso y vista previa del personaje con esa clase, más un botón de confirmar. Al confirmar, la elección es definitiva. Si ya tienes clase, Brann dice una línea corta.
- **Ventana de clases** sin scroll a 1280×720 (norma 7). Esc la cierra sin elegir.
- **Red:** el cliente pide `CHOOSE_CLASS {class_id}`. El anfitrión comprueba que el jugador es aldeano, que está vivo y a 2,5 m o menos de Brann, y que la clase es elegible. Si todo cuadra, aplica `ClassRules.setup_player` con el recurso lleno y la barra por defecto, y avisa a todos con `PLAYER_CLASS {id, class_id}`. Los avatares rehacen su rig y los marcos del grupo se actualizan. Sube el protocolo y la versión del juego.
- **Guardado:** el cliente guarda la clase y la barra nuevas en su personaje. `CharacterData` sube de versión; los personajes antiguos conservan su clase y el aldeano se guarda como `villager`.
- **Ventana K** del aldeano: muestra solo su ataque básico y un aviso en texto de datos («Habla con Brann para elegir tu clase»).

## Orden y punto de revisión
1. `HumanRig`, piezas y animaciones, conviviendo con Kenney. Capturas lado a lado (todas las clases, tipos de cuerpo y acciones) para el usuario. **Parada: visto bueno del usuario** antes de seguir.
2. Cambio de todos los personajes a `HumanRig` y borrado de lo de Kenney.
3. Bestiario del prólogo.
4. Aldeano, Brann y elección de clase en red.

## Pruebas (GUT)
- **`HumanRig`:** se construye con todas las partes y piezas de cualquier combinación de clase y apariencia; ninguna ruta apunta a `assets/characters/base` ni a `layers`; cada acción (`melee`, `shoot`, `cast`, `dash`, `downed`, `die`) existe y termina.
- **Catálogo:** todos los ids de `appearance.json` siguen resolviendo; el aldeano no es elegible.
- **Monstruos:** cada archivo de `data/monsters/` carga, su modelo existe y sus habilidades están en `monsters.json`; el mapa solo nombra monstruos existentes.
- **Elección de clase:**
  - el anfitrión acepta una petición válida;
  - rechaza que ya tenga clase, que esté lejos, muerto o caído, que pida el aldeano o una clase desconocida;
  - el resultado aplica stats, recurso y barra;
  - el mensaje llega a todos (sesiones en memoria).
- **Protocolo:** `CHOOSE_CLASS` y `PLAYER_CLASS` se empaquetan y validan; un `HELLO` de otra versión se rechaza como hoy.
- **Guardado:** migración de la versión anterior; un personaje nuevo nace aldeano.
- **Interacción:** prioridad de la reanimación sobre Brann.
- Siguen pasando todas las pruebas existentes, adaptadas donde nombren monstruos o clases retirados.

## Decisiones tomadas
- El bestiario cubre solo el prólogo; el arco 1 queda para más adelante (usuario).
- La clase se elige con Brann, como en «La práctica» de la misión 1; antes se juega como aldeano (usuario).
- Humanoide vóxel por huesos con animaciones por código (enfoque A) frente a malla con esqueleto exportada a `.glb` (B) o mantener el esqueleto de Kenney (C, descartada por ser externa) (usuario).
- La elección de clase es definitiva hasta el Plan 4 (propuesta de Claude, aceptada con la opción 1).
- Se retiran el limo y el esqueleto arquero (propuesta de Claude).
- Armas visibles en la mano y espada de madera del aldeano (propuesta de Claude).
- Brann en el mapa de pruebas, definido en datos (propuesta de Claude).
- Revisión visual del humanoide antes de borrar Kenney (usuario).
- Stats del aldeano, ids internos de monstruos, número de versión y prioridad de E (pulsar para Brann, mantener para reanimar) quedan a criterio de Claude.

---
← [[Planes]]
