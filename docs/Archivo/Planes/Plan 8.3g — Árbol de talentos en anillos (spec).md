---
tags: [plan, spec]
plan: 8.3g
fecha: 2026-11-27
estado: implementado
actualizado: 2026-11-27
---
# Plan 8.3g — Árbol de talentos en anillos: diseño

## Objetivo
Un árbol de talentos **mucho más grande, más vistoso y con más elección de estadísticas**, al estilo de Path of Exile en lo visual (iconos en marcos), pero manteniendo nuestra idea: **anillos alrededor de un centro común**, todo conectado.
- **Por qué:** el árbol actual (66 nodos) se completa hacia el nivel 67 y ofrece poca elección; el usuario quiere más nodos, más combinaciones y que se vea mejor.
- **Para quién:** todos los jugadores; un solo árbol común a las cinco clases.
- **Éxito:** a nivel 50 cada jugador ha cogido una parte pequeña del árbol y dos personajes de la misma clase pueden ir por caminos distintos; quien llegue al nivel 300 puede completarlo.

## Fuera de alcance (y antiobjetivos)
- **Nada de mejorar habilidades:** los nodos solo dan estadísticas. Todas las clases comparten el árbol.
- **Sin estadísticas nuevas:** solo las que ya maneja el juego (ver abajo).
- **Sin bloqueos por nivel o rango:** todos los nodos están disponibles desde el principio, partiendo del centro. La mejora de clase del nivel 50 deja de abrir un anillo.
- **Sin iconos únicos** por nodo en este plan (quizá en otro): un icono por estadística.
- Antiobjetivo: rutas o zonas aisladas que obliguen a gastar puntos en algo que no quieres para llegar a otra zona. Todo anillo es un círculo cerrado y cada anillo se une al siguiente por muchos puntos.

## Diseño

### Forma
- **Centro** común (gratis) y **unos 7 anillos** concéntricos con ~300 nodos en total. Cada anillo tiene más nodos que el anterior (aprox. 10, 20, 30… por anillo).
- Cada anillo es un **círculo cerrado** (cada nodo enlaza con sus dos vecinos) y se une al anillo interior y al exterior en muchos puntos (aprox. uno de cada dos nodos).
- Cinco **sectores** en orden circular, como ahora: Poderío (daño físico), Celeridad (velocidad y recargas), Vitalidad (sostenimiento), Bastión (defensa) y Arcano (daño mágico).

### Contenido de los nodos
- **Estadísticas** (las que ya existen en el juego): poder de ataque, poder de hechizos, crítico, daño crítico, daño realizado, daño recibido, velocidad de movimiento, esquiva, bloqueo, armadura (plana y %), vida máxima, vida por segundo, robo de vida, curación realizada, curación recibida, recurso máximo, regeneración de recurso, recargas y **amenaza** (la de las pasivas, para tanques).
- Cada sector tiene sus estadísticas propias; **entre dos sectores los nodos mezclan** las de ambos según el ángulo.
- **Tipos:** nodo pequeño (1 estadística), **notable** (2–3 estadísticas, cada pocos nodos), **culminante** (grande, en el anillo exterior, uno o dos por sector).
- **Valores que crecen anillo a anillo:** cuanto más lejos del centro, más da cada nodo. Los valores exactos se fijan en el generador para que el total del árbol completo quede equilibrado con el árbol actual × la escala que se decida al equilibrar (ver «Lo que queda al constructor»).
- **Maestrías:** como ahora, cuando todos los nodos de un sector están comprados, los puntos sobrantes van a su maestría (rendimientos decrecientes).

### Puntos
- Igual que ahora: **1 punto por nivel a partir del 2**. El árbol completo (~300) se alcanza hacia el nivel 300.

### Rutas recomendadas por clase
- Cada clase tiene una **ruta recomendada**: una secuencia ordenada de nodos desde el centro.
- La calcula el generador a partir de una lista de **prioridades de estadísticas por clase** (por ejemplo, guerrero: armadura > vida > ataque > bloqueo; mago: hechizos > recurso > crítico…), eligiendo en cada paso el nodo comprable que más aporta.
- En la ventana se **resalta** (línea dorada discontinua y número de paso) y se puede ocultar con una casilla. Es solo una guía: el jugador compra lo que quiera.

### Ventana (tecla T)
- **Estilo holograma azul** de las demás ventanas del juego (HoloTheme).
- Ocupa la pantalla, con **zoom (rueda) y arrastre** para moverse; no hay scroll de lista (cumple la norma de interfaz sin scroll a 1280×720).
- **Un único lienzo dibujado por código**: líneas entre nodos y cada nodo como **icono dentro de un marco**: círculo fino (pequeño), marco adornado (notable), marco grande con halo del color de su sector (culminante). Comprado: brillo cian; comprable: borde iluminado; no comprable: apagado.
- Barra superior: puntos libres, gastados / total, casilla de ruta recomendada y coste del reinicio.
- **Detalle del nodo bajo el ratón:** tipo, sector, estadísticas y paso de la ruta si lo es.
- Clic en un nodo comprable lo compra (como ahora, lo confirma el anfitrión).

### Iconos
- **Un icono por estadística** (unos 21), 128 px, generados por el usuario con IA en el estilo de los de habilidades. Cada nodo usa el icono de su estadística principal; notables y culminantes reutilizan el suyo con su marco.
- Mientras no estén, el juego dibuja un icono provisional (la inicial o un símbolo de la estadística) para poder probar.
- Claude prepara la lista de prompts, uno por estadística, como en la fase de iconos de habilidades.

### Datos y compatibilidad
- `data/talents.json` lo sigue escribiendo `tools/data/make_talents.mjs` (formato compacto): nodos con tipo, sector, anillo, posición, estadísticas, enlaces e icono; y las rutas por clase.
- **Personajes existentes:** como el árbol cambia, al cargar se les devuelven gratis todos los puntos de talento (y sus maestrías).
- **Reinicio** con Maese Corwin: sin cambios.
- **Mejora de clase del nivel 50:** deja de abrir el anillo exterior; conserva lo demás que da.

## Pruebas
- Generador (Node): unos 300 nodos; todo conectado desde el centro; cada anillo cerrado; enlaces simétricos; cada nodo con al menos una estadística válida y un icono; valores crecientes por anillo; cada ruta de clase empieza en el centro, es una secuencia de nodos conectados y no repite.
- GUT: compra y validez sin bloqueo por rango; personajes antiguos con nodos del árbol viejo reciben sus puntos; maestrías al completar un sector; la ventana dibuja, hace zoom y arrastre, compra con clic y muestra la ruta; cabe a 1280×720.

## Enfoques considerados
- **Elegido: generado por script + lienzo dibujado por código.** El árbol, los valores y las rutas salen de reglas; equilibrar es cambiar números y regenerar. Un lienzo con zoom va fluido con 300 nodos.
- Nodos generados y rutas a mano: más control fino de las rutas, pero cinco listas largas que rehacer en cada cambio.
- Todo a mano en el JSON: inmanejable con 300 nodos.
- Un botón por nodo en vez del lienzo: más sencillo al principio, pero el zoom con 300 botones se complica.
- Formas descartadas por el usuario: constelación estilo PoE y ramas.

## Decisiones de Claude (revísalas)
- **Valores:** los anillos interiores dan lo mismo que los nodos pequeños de hoy (+3 % ataque, +1 % crítico…) y el exterior hasta el doble; así a nivel 50 el personaje queda como ahora y el poder sigue creciendo sin tope, como el nivel.
- **Maestrías:** cada nodo mixto pertenece al sector más cercano; la maestría de un sector se abre al comprar todos sus nodos.
- **Rutas:** cubren los primeros ~100 nodos (hasta el nivel ~100); a partir de ahí el jugador elige libremente.
- **Guardado:** sube la versión de los personajes; al cargar uno antiguo se vacían sus talentos y maestrías y conserva los puntos.

## Lo que queda al constructor
- Número exacto de nodos por anillo, cada cuántos hay un notable y los valores de cada estadística por anillo (manteniendo el total equilibrado con el resto del personaje).
- Las listas de prioridades de cada clase para las rutas.
- El icono provisional y los marcos exactos.

## Decisiones tomadas
- Unos 300 nodos que se completan hacia el nivel 300; todo disponible desde el principio desde el centro común (usuario).
- Forma de anillos conectados, sin rutas aisladas (usuario).
- Ruta recomendada resaltada, sin botón de compra automática (usuario).
- Ventana con el holograma azul de las demás e iconos de estadística en marcos al estilo PoE (usuario).
- Combinar las estadísticas existentes, incluida la velocidad de movimiento y lo que ya usan las pasivas, como la esquiva (usuario).
- Un icono por estadística (usuario).
- Generado por script y lienzo dibujado por código (usuario).
- Devolver los puntos a los personajes existentes y que la mejora del nivel 50 no abra anillo (propuesta de Claude).

---
← [[Planes]]
