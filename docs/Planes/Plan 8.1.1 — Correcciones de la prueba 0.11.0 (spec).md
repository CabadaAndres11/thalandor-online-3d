---
tags: [plan, spec]
plan: 8.1.1
fecha: 2026-11-23
estado: implementado
actualizado: 2026-11-23
---
# Plan 8.1.1 — Correcciones de la prueba 0.11.0: diseño

## Objetivo
Corregir los 13 puntos de la prueba de la 0.11.0 ([[Plan 8.1 — Zonas y mundo (spec)|Plan 8.1]]) para que el mundo por zonas se pueda jugar con fluidez, se lea bien y la interfaz quede preparada para las misiones del 8.2. Sale como **0.11.1**.

**Fuera de alcance:**
- misiones y diálogos (8.2): el icono de misiones aparece, pero su ventana llega con el 8.2;
- interiores como zonas aparte;
- niebla de guerra en el mapa.

**No debe pasar:**
- que la zona gane FPS a costa de verse peor de cerca;
- que una ventana necesite scroll a 1280×720.

## Lista de la prueba

| # | Problema | Causa | Arreglo |
|---|---|---|---|
| 1 | El juego se congela al pulsar Jugar | La zona y sus mallas se construyen de golpe en un solo fotograma | Al pulsar Jugar sale la pantalla de carga. La zona se construye por pasos repartidos en varios fotogramas (suelo, cada tipo de pieza, luces) y las mallas `.vox` se precargan mientras se ve la pantalla |
| 2 | 12 FPS en alta, 80 en baja | `VoxMesher` dibuja una cara por cada lado visible de cada vóxel. El bosque tiene ~1 800 piezas de miles de caras, y todas dan sombra | Ver «Rendimiento» |
| 3 | Las casas, menos granuladas | Las casas van a 5 cm por vóxel, como el equipo | Las casas se redibujan a **10 cm por vóxel** (escala 1.0), con menos ruido de color: tablas, piedras y tejas de varios vóxeles |
| 4 | Casas y edificios accesibles | Las casas son macizas y toda su huella bloquea | Ver «Casas accesibles» (decisión del usuario, opción 1) |
| 5 | No se distinguen los bordes del mapa | El borde no tiene nada que lo marque | Ver «Bordes y cámara» |
| 6 | La cámara enseña el vacío fuera del mapa | La cámara sigue al jugador sin límite | Ver «Bordes y cámara» |
| 7 | No se ve la pantalla de carga al ir al bosque | Carga en menos de un fotograma | La pantalla de carga dura al menos **0,6 s** y se funde al salir. Con la construcción por pasos (punto 1) siempre se ve |
| 8 | La máscara de asesino queda mal en el hombre lagarto, y la elección de clase no enseña el equipo que recibes | La vista previa monta el atuendo de clase y no el equipo inicial. La máscara no se ajusta al hocico | La vista previa monta el **equipo inicial real** de esa clase (el mismo que entrega el host). La máscara usa `head_fit` del lagarto para abrazar el hocico (decisión del usuario) |
| 9 | Mapa con la M y minimapa | No existían | Ver «Mapa y minimapa» |
| 10 | Botón para ordenar el inventario | No existía | Botón **Ordenar** en la bolsa. Ordena en el host: tipo de objeto, después rareza (de más a menos), nivel (de más a menos) y nombre. Las pilas iguales se juntan. No toca lo equipado |
| 11 | Quitar «Unirse a un amigo» del menú principal | El botón está en la selección de personaje | Se quita. El menú de pausa gana **Unirse a un grupo** con un campo para el código, junto a «Abrir grupo». Al unirse se guarda el personaje, se cierra la partida en solitario y se conecta al amigo con ese mismo personaje, tras la pantalla de carga. Sigue bloqueado hasta acabar el tutorial |
| 12 | Iconos de bolsa, personaje, misiones, etc. arriba a la derecha | Las ventanas solo se abrían con teclas | Ver «Barra de iconos» |
| 13 | No se encontraba la cripta | Está al **sureste** del bosque (en la nota de prueba puse noreste por error) y los árboles sembrados la tapan | La siembra deja un claro de 6 casillas alrededor de la entrada. Un camino de tierra llega desde el camino principal, con dos antorchas en la puerta. La cripta sale marcada en el mapa y en el minimapa |

## Rendimiento
Objetivo: el bosque a **60 FPS o más en alta** en el equipo del usuario. Lo comprueba el usuario. Los tests vigilan el número de triángulos y de nodos.

1. **Caras fusionadas.** `VoxMesher` junta en un solo rectángulo las caras vecinas del mismo plano que tengan el mismo color y la misma oclusión en sus esquinas (*greedy meshing*). De cerca se ve igual. Se aplica a todo lo que pasa por `VoxMesher`, también a personajes y monstruos.
2. **Piezas por trozos.** Cada tipo de pieza se reparte en un `MultiMeshInstance3D` por trozo de **16×16 casillas**. Así Godot descarta lo que queda fuera de cámara.
3. **Distancia de dibujo.** Los trozos tienen distancia de visibilidad: matorrales, rocas pequeñas y tocones a 35 m, el resto a 70 m. La niebla del ambiente ya oculta ese corte.
4. **Sombras por calidad.**
   - Matorrales, rocas pequeñas, tocones y antorchas nunca dan sombra.
   - Árboles, casas y rocas grandes dan sombra en media y alta.
   - En baja no da sombra ninguna pieza.
5. **Suelo.** Una sola malla por tipo de suelo y por trozo, también 16×16.

## Casas accesibles
Decisión del usuario: se entra por la puerta y la casa se abre en la misma zona, sin pantalla de carga.

- Cada casa se genera en **cuatro mallas**:
  - suelo y muebles;
  - paredes;
  - paredes recortadas a 1 m;
  - tejado.
- Las paredes tienen una puerta de 2 casillas de ancho.
- La huella de colisión de cada pieza pasa a ser solo la de las paredes y los muebles grandes. La puerta y el interior se pueden pisar. `pieces.json` gana `interior` (las casillas de dentro) y la huella deja de ser un bloque macizo.
- **Al entrar:** cuando el jugador local pisa una casilla `interior`, el tejado de esa casa se funde a transparente en 0,25 s y sus paredes cambian a las recortadas. Al salir, al revés. Como la cámara gira, se recortan todas las paredes, no solo las delanteras.
- Los demás jugadores ven la casa cerrada; cada cliente abre solo la casa en la que está su jugador.
- **Muebles por casa:**
  - casa pequeña: cama, mesa y baúl;
  - casa grande: dos camas, mesa larga, chimenea y estantería;
  - forja: yunque, fragua encendida (con luz) y barril.
- Brann sigue fuera, junto a su forja, para que se le encuentre a simple vista.

## Bordes y cámara
- **Margen decorado.** Alrededor de cada zona exterior hay una franja de 14 casillas fuera del mapa, nunca pisable. Se rellena de árboles muy juntos y rocas grandes (en la cripta, paredes de roca), con un suelo más oscuro. El borde del mapa jugable queda como una línea clara de árboles: lo que se ve es bosque espeso, no vacío.
- **Salidas visibles.**
  - Cada salida es un hueco en esa línea, con su camino.
  - Lleva un poste con cartel (el nombre de la zona de destino, que se ve al acercarse) y dos antorchas.
  - El suelo de la casilla de salida brilla suavemente.
  - Los datos de la zona generan esto solos a partir de `exits`.
- **Cámara.** El punto que sigue la cámara se limita a la zona menos 6 casillas. Con el margen de 14 casillas, en vista isométrica y con el zoom máximo, la pantalla nunca llega al vacío. En tercera persona la niebla tapa el horizonte. Si el zoom máximo enseñara vacío, ese zoom se reduce.

## Mapa y minimapa
- **Mapa (tecla M).**
  - Es una ventana con la zona entera, sin scroll, ajustada a 1280×720.
  - Se dibuja con los datos de la zona: el suelo por colores, los caminos, el agua y las piezas (casas, árboles agrupados como manchas de bosque, rocas).
  - Marcas: tú (flecha con tu orientación), tus compañeros en la zona, los PNJ con nombre (Brann, el mercader), las salidas con el nombre de su destino, y las entradas a mazmorras con su icono.
  - Leyenda pequeña y el nombre de la zona arriba.
- **Minimapa.**
  - Cuadrado de 180 px bajo la barra de iconos.
  - Lleva las mismas marcas que el mapa y, encima, el nombre de la zona.
  - Gira con la cámara para que «arriba» sea hacia donde mira, con una N en el borde.
  - Se oculta con la opción `minimapa` de Ajustes, activada por defecto.
- La imagen de la zona se genera una vez al cargarla y la comparten mapa y minimapa.

## Barra de iconos
- **Arriba a la derecha**, de izquierda a derecha:
  - Personaje (C);
  - Bolsa (I);
  - Habilidades (K);
  - Talentos (T);
  - Misiones (J);
  - Mapa (M);
  - Menú (Esc).
- Cada icono muestra su tecla en pequeño, se ilumina al pasar el ratón y se queda marcado mientras su ventana está abierta. Usan `HoloTheme`, como las ventanas, hasta el Plan 11.
- **Misiones** sale atenuado, con la indicación «Llega con las misiones» hasta el 8.2.
- Las teclas actuales no cambian. Solo se añaden M (mapa) y J (misiones, sin efecto por ahora).

## Pruebas (GUT)
- **Fusión de caras:** una malla fusionada tiene menos triángulos y cubre exactamente las mismas caras (mismo área por color). Un cubo de un solo color queda en 12 triángulos.
- **Trozos:** las piezas de un bosque de prueba se reparten por trozos de 16×16. Las sombras siguen la tabla según la calidad, y los trozos tienen su distancia de visibilidad.
- **Casas:**
  - la huella de una casa deja libres la puerta y el interior, y una búsqueda en anchura llega de la puerta a todas las casillas de dentro;
  - pisar `interior` abre la casa (tejado oculto, paredes recortadas) y salir la cierra;
  - solo se abre la casa del jugador local.
- **Bordes:**
  - el margen no es pisable y rodea toda la zona menos las salidas;
  - cada salida tiene cartel y antorchas;
  - la cámara no pasa del límite.
- **Carga:** la construcción por pasos acaba con la misma escena que la construcción de golpe, y la pantalla de carga dura al menos 0,6 s.
- **Vista previa de clase:** monta el equipo inicial que da el host para esa clase.
- **Mapa:**
  - la imagen de la zona tiene el tamaño de la zona y los colores del suelo;
  - las marcas salen en su casilla;
  - la ventana cabe en 1280×720.
- **Ordenar:** el orden es el de la tabla, las pilas se juntan y lo equipado no cambia.
- **Unirse desde la pausa:** guarda, cierra la sesión en solitario y conecta con el código. Si el tutorial no está hecho, sigue bloqueado.
- **Barra de iconos:** cada icono abre su ventana y queda marcado; Misiones está deshabilitado.
- **Cripta:** hay un claro alrededor de la entrada y un camino continuo desde la salida de la aldea.
- La suite completa pasa.

## Decisiones tomadas
- **Del usuario:**
  - casas accesibles en la misma zona, con el tejado que se funde (opción 1);
  - vista previa con el equipo inicial real y máscara ajustada al lagarto;
  - el resto, a criterio de Claude.
- **De Claude:**
  - casas a 10 cm por vóxel, como interpretación de «menos granuladas»;
  - fusión de caras, trozos de 16×16, distancias de dibujo de 35 m y 70 m, y sombras por calidad;
  - margen de 14 casillas de bosque espeso y salidas con cartel y antorchas;
  - límite de la cámara;
  - carga por pasos con un mínimo de 0,6 s;
  - mapa con M sin niebla de guerra, y minimapa de 180 px que gira con la cámara;
  - orden del inventario por tipo, rareza, nivel y nombre;
  - unirse a un grupo desde el menú de pausa;
  - orden y teclas de la barra de iconos, con J para misiones.

---
← [[Planes]]
