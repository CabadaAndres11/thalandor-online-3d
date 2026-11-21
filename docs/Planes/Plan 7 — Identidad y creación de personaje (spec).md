---
tags: [plan, spec]
plan: 7
fecha: 2026-11-21
estado: aprobado
actualizado: 2026-11-21
---
# Plan 7 — Identidad y creación de personaje: diseño

## Objetivo
Dar al juego su **cara definitiva** antes de construir el mundo ([[14 Hoja de ruta]]):
1. **Pantalla de inicio final**, con los colores del logo y una escena vóxel animada de fondo.
2. **Selección y creación de personaje** con ese mismo estilo y en la misma escena.
3. **Cinco razas seleccionables:** humanos, elfos, enanos, ogros y hombres lagarto.
4. **Mucha más apariencia:** peinados, barbas, colores y rasgos.

**Por qué:** es lo primero que ve el jugador. La pantalla actual (fondo azul liso y botones centrados) se ve genérica, y el modelo nuevo del Plan 6 ya permite hacer razas y apariencia sin rehacerlas después.

**Publicación:** **0.10.0**.

## Fuera de alcance
- **Bonificaciones de raza.** Las razas son **solo aspecto** (usuario): no cambian atributos, clases, colisión ni velocidad.
- **Tema de las ventanas del juego** (inventario, talentos, HUD, opciones): siguen con el azul holográfico hasta el Plan 11.
- **Música y sonido de la pantalla de inicio:** Plan 11.
- **PNJ de otras razas en el mundo:** Plan 8.
- **Restringir clases por raza:** no se hace; cualquier raza puede ser cualquier clase.

## Antifines
- Que una raza **juegue distinto** a otra.
- **Equipo roto** en alguna raza: cascos que atraviesan el hocico o hombreras flotando sobre el ogro.
- Que alguna pantalla necesite **scroll** a 1280×720 (norma 7).
- **Romper personajes guardados**, la red o la importación: un personaje de la 0.9.7 se abre como humano, con el mismo aspecto.
- Que la escena de fondo **pese** más que una partida (mismo presupuesto que la arena).
- Que el arte deje de ser propio y hecho por código ([[D-010 Arte propio hecho por código]]).

## Enfoques (razas)
| Opción | Qué es | Coste | Elegida |
|---|---|---|---|
| 1. Un cuerpo con proporciones y piezas | Cada raza escala las partes del cuerpo y añade piezas (orejas, hocico, cola) | Mínimo, pero el lagarto y el ogro quedan falsos (cara humana con añadidos) | No |
| 2. Un modelo completo por raza | Cinco cuerpos esculpidos | Hay que ajustar más de cien piezas de equipo a cada cuerpo, y otra vez con cada objeto nuevo | No |
| **3. Cuerpo compartido y cabeza propia** | Proporciones por raza. **Cabeza propia** para el ogro y el lagarto, cola como pieza. Elfos, enanos y humanos usan la cabeza humana con piezas | Solo se ajustan al ogro y al lagarto las piezas que van en la cabeza (cascos, capuchas, sombreros) | **Sí (usuario)** |

## Diseño

### 1. Razas (`data/characters/races.json`)
Cada raza es un dato con: nombre y descripción (claves de traducción), **proporciones** por grupo de partes, **cabeza** (`human` o propia), **piezas fijas** (orejas, cola…), **ajuste de cabeza** para el equipo, y qué opciones de apariencia admite.

| Raza | Altura (humano = 1) | Proporciones | Cabeza y piezas | Piel | Pelo y barba |
|---|---|---|---|---|---|
| Humano | 1,00 | Las de hoy | Humana | Los 8 tonos de hoy | Todos |
| Elfo | 1,04 | Más esbelto (torso y brazos −6 % de ancho), piernas algo más largas | Humana, con **orejas largas** | Los 8 tonos + 2 (pálido lunar y ceniza) | Todos los peinados; barbas solo afeitado y perilla |
| Enano | **0,80** (más bajo que humanos y elfos, usuario) | Ancho (torso +20 %, brazos +12 %), piernas cortas, cabeza algo mayor en proporción | Humana, con **nariz grande** | Los 8 tonos de hoy | Todos, más **barbas enanas** largas y trenzadas |
| Ogro | 1,30 | Muy ancho (torso +30 %), brazos largos y gruesos, encorvado (pivote de la cabeza más adelantado) | **Propia:** mandíbula saliente, **colmillos**, ceja gruesa, ojos pequeños | 6 propios: verde gris, oliva, ocre, pizarra, azul ceniza, marrón musgo | Pocos peinados (calvo, cresta, moño alto, melena desgreñada) y barbas cortas |
| Hombre lagarto | 1,05 | Torso algo más estrecho, piernas algo más largas | **Propia:** hocico, escamas y ojos de reptil; **cola** en la cadera | 6 propios: verde, jade, arena, óxido, negro azulado, albino | Sin pelo ni barba: la fila «peinado» pasa a **cresta** (4 tipos) y «color de pelo» colorea la cresta |

- **El equipo sigue al cuerpo:** cada pieza enganchada a una parte se escala con las proporciones de la raza en esa parte, así que las hombreras del ogro crecen con su torso. Hoy las piezas van al pivote y no al escalado. Se cambia **solo para la raza**: el cuerpo esbelto o robusto sigue sin escalar las piezas, como ahora.
- **Ajuste de cabeza:** cada cabeza propia lleva `head_fit` (escala y desplazamiento) que se aplica a las piezas de la cabeza (cascos, capuchas, sombreros, pelo). Si una pieza concreta sigue sin encajar, se le añade un ajuste por raza en sus datos («lo justo», usuario).
- **Qué ocultan los cascos:** las orejas élficas llevan la etiqueta `ears`, y los cascos cerrados y las capuchas las ocultan como hoy ocultan el pelo. El hocico, los colmillos y la cola **no se ocultan nunca**; el casco se ajusta a ellos.
- **Lo que no cambia:** colisión, velocidad, alcance y altura de la cámara. La barra de vida sobre la cabeza se coloca según la altura real del modelo.
- **Arte:** las cabezas, orejas, colas, crestas, barbas enanas y peinados nuevos se esculpen en `tools/art/` (`human_v2.mjs` y `make_pieces_v2.mjs`) como el resto del vóxel 2×.

### 2. Apariencia ampliada (`data/characters/appearance.json`)
- **Nuevas filas:** `race` (primera fila) y `marks` (rasgos de la cara: ninguno, cicatriz en el ojo, cicatriz en la mejilla, pintura de guerra, tatuaje rúnico y pecas; cada uno es una capa en la cabeza).
- **Más opciones:** +8 peinados (trenzas, rapado lateral, melena suelta larga, coleta alta, trenza de guerrero, rizos, desgreñado y medio recogido), +5 barbas (dos de ellas enanas), +5 colores de pelo (platino, blanco, castaño rojizo, azul noche y verde musgo) y +2 colores de ojos (amarillo reptil y violeta).
- **Opciones por raza:** cada opción puede llevar una lista `races` con las razas que la admiten; sin lista, vale para todas. Al cambiar de raza, la opción que ya no vale pasa a la primera válida.
- **Guardado y red:** la apariencia gana las claves `race` y `marks`. `sanitize_appearance` las rellena por defecto (humano, ninguno) y corrige las opciones que no valen para la raza. **No hace falta versión nueva** de `CharacterData`: un personaje viejo se abre igual, como humano. El host valida lo que llega por la red con el mismo saneado.

### 3. Pantalla de inicio
- **Escena de fondo, el altar del Sol Negro:** un claro de noche con losas rotas, columnas caídas, braseros y velas. En el centro, un **altar con el Sol Negro** tallado, y **6 cultistas** en círculo (cultistas, acólitos y un inquisidor, con sus modelos de la 6.4.1) en una **pose de oración** en bucle: brazos alzados y balanceo leve. Lleva niebla, brasas que suben, luz de fuego que parpadea y un resplandor rojo tenue del altar, con los ambientes del Plan 6.1. La cámara hace un **recorrido lento** en bucle alrededor del círculo.
- **Disposición:**
```
┌─────────────────────────────────────── ⚙ ★ ✕ ┐
│              [  LOGO THALANDOR  ]             │
│                                               │
│      (escena del altar a pantalla completa)   │
│                                               │
│ ▶ JUGAR                                v0.10.0│
└───────────────────────────────────────────────┘
```
  - **Jugar**, grande, abajo a la izquierda.
  - Arriba a la derecha, los iconos **Ajustes** (la ventana de opciones de hoy), **Créditos** (ventana nueva con los assets y licencias: Kenney CC0, Teko OFL, Godot MIT, GUT MIT) y **Salir**.
  - El logo centrado arriba, y la versión abajo a la derecha.
- **Arte de la escena:** las piezas del decorado se hacen por código en `tools/art/make_props.mjs`. La escena es un dato (`data/scenes/title_altar.json`: decorado, cultistas, luces, ambiente y recorrido de cámara), para poder cambiarla más adelante sin tocar código.

### 4. Tema de piedra y oro (menús)
- **Tema nuevo**, `ui/stone_theme.gd`, para inicio, selección y creación, con la paleta del logo: **piedra oscura** (paneles), **oro** (bordes, títulos y botón principal) y **rojo sangre** (resaltes y selección). Los botones llevan un marco tallado.
- **Fuente:** se mantiene **Teko**, que ya está en el proyecto. Cualquier fuente nueva se pide antes (norma 3).
- Las ventanas del juego siguen con `holo_theme.gd`.

### 5. Selección y creación en la escena
- Las tres pantallas comparten **una sola escena 3D** que se carga al abrir el juego. Al pasar de una pantalla a otra cambia solo la cámara, con un movimiento suave, y la interfaz que va encima.
- **Selección:**
  - El personaje elegido aparece **delante del altar**, de cuerpo entero, con los cultistas al fondo y desenfocados por la luz.
  - A la izquierda, un panel de piedra con la lista de personajes (hasta 8: nombre, clase, nivel y raza).
  - Mantiene los mismos botones de hoy: Jugar, Unirse con código, Crear, Borrar, Exportar, Importar y Atrás.
- **Creación:**
  - El mismo encuadre con el personaje nuevo, que se gira arrastrando como hoy.
  - A la izquierda, el panel de piedra con el **nombre**, la **raza** (nombre y una línea de descripción) y las filas ◀ ▶ de apariencia.
  - Si no caben sin scroll a 1280×720, las filas se reparten en **pestañas** (Raza y cuerpo · Cabeza · Rasgos).
  - Botones: Aleatorio, Crear y Atrás. El aleatorio respeta las opciones de la raza.

## Pruebas (GUT)
- **Catálogo:**
  - Carga `races.json`, y cada raza se resuelve a un aspecto completo (cabeza, proporciones y piezas fijas).
  - Las opciones con `races` filtran bien.
  - Al cambiar de raza, las opciones que no valen se corrigen.
  - El aleatorio solo da combinaciones válidas.
- **Guardado:** un personaje de la 0.9.7 (sin `race`) se abre como humano con el mismo aspecto, y una raza o un rasgo desconocidos vuelven al valor por defecto.
- **Red:** el host sanea una apariencia con una raza inválida o con opciones de otra raza.
- **Rig:**
  - Cada raza se construye sin errores.
  - La altura del enano es menor que la del humano y la del elfo, y la del ogro, mayor.
  - Las piezas de una parte escalan con la raza.
  - El ogro y el lagarto usan su cabeza, y el lagarto lleva cola.
  - Los cascos cerrados ocultan las orejas élficas.
- **Equipo en cada raza:** todas las piezas de cabeza se enganchan a las cabezas propias sin error. Se generan **imágenes de control** (el ayudante `render_characters.gd`) de cada raza con un juego de equipo por tramo, para que las revise el usuario.
- **Pantallas:**
  - La de inicio tiene Jugar abajo a la izquierda y los tres iconos arriba a la derecha, y cada uno emite su señal.
  - Ninguna pantalla se sale de 1280×720.
  - La escena del altar carga a partir de sus datos.
  - La creación incluye la raza en la apariencia que envía.
- La suite completa pasa.

## Decisiones tomadas
- **Del usuario:**
  - las cinco razas, solo de aspecto;
  - los enanos, más bajos que elfos y humanos;
  - las piezas se adaptan lo justo a cada raza;
  - el enfoque 3 (cuerpo compartido y cabeza propia);
  - una pantalla de inicio definitiva con los colores del logo;
  - fondo animado con una escena vóxel de cultistas alrededor del altar;
  - Jugar abajo a una esquina y los iconos arriba a la derecha;
  - selección y creación con el mismo estilo y en la misma escena;
  - las ventanas del juego siguen en azul hasta el Plan 11.
- **De Claude (revisables):**
  - las alturas y proporciones de la tabla;
  - las paletas de piel de ogros y lagartos;
  - qué peinados y barbas admite cada raza;
  - las listas de opciones nuevas;
  - los rasgos (`marks`) como capa de la cara;
  - los iconos Ajustes, Créditos y Salir;
  - 6 cultistas en pose de oración;
  - mantener la fuente Teko;
  - las pestañas en la creación solo si no cabe;
  - sin versión nueva del guardado;
  - la versión 0.10.0.

---
← [[Planes]]
