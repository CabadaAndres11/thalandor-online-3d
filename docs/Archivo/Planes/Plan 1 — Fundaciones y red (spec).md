---
tags: [plan, spec]
plan: 1
fecha: 2026-11-14
estado: aprobada
actualizado: 2026-11-14
---
# Plan 1 — Fundaciones y red: diseño

## Objetivo
Tener la **base técnica del juego funcionando entre casas**: abres el juego, entras con una cápsula en un escenario de pruebas con cámara isométrica, te mueves con WASD y apuntas con el ratón. Pulsas **"Abrir grupo"**, das un código a tus amigos y hasta 3 se unen; os veis moveros con fluidez y podéis escribir en un chat. Si alguien tiene otra versión del juego, se le avisa y no entra. El juego se exporta a un ejecutable de Windows y se publica en **GitHub Releases**. Al final, una **prueba real entre dos casas** decide la conexión definitiva (WebRTC o ENet con VPN).

**Por qué:** todo lo demás (combate, monstruos, botín) se construye encima de esta base. Si la red, la predicción o la estructura fallan, fallan todos los planes siguientes.

**Éxito:** tú y al menos un amigo, cada uno en su casa, os movéis por el escenario sin tirones ni saltos visibles, con el chat funcionando, usando el ejecutable publicado.

## Fuera de alcance
- Combate, habilidades, esquiva, monstruos, IA (Plan 3).
- Personajes vóxel, creación/selección de personaje y guardado de personajes (Plan 2). En este plan solo hay un **nombre de jugador provisional**.
- Zonas reales, transiciones entre zonas, mazmorras (Plan 6).
- Opciones, reasignación de teclas, audio (Plan 7).
- itch.io (más adelante; ver [[D-009 Repositorio nuevo y publicación en GitHub Releases]]).
- Anti-trampas (fuera del proyecto, §1.2).

## Diseño

### 1. Proyecto y estructura
- Proyecto Godot **4.7.2** en la raíz de `D:\Thalandor3D`, junto a `docs/`. Un archivo `docs/.gdignore` impide que Godot importe la bóveda.
- Carpetas según [[02 Arquitectura técnica|§2.4]]: `sim/`, `net/`, `game/`, `ui/`, `save/`, `data/`, `assets/`, `tests/`, más `addons/gut/` (GUT 9.6.1).
- GDScript con **tipado estático** en todo el código.
- **Repositorio:** nuevo y público, `CabadaAndres11/thalandor-online-3d`. Email del usuario configurado solo en este repositorio. `.gitignore` para `.godot/` y `exports/`.
- **Versión del juego:** `0.1.0`, en `project.godot` (`application/config/version`), visible en la pantalla de título.
- **Textos:** archivo de traducción CSV en `data/texts/textos.csv` (columnas `keys,es`); el código usa `tr("CLAVE")`. Ningún texto de interfaz escrito en el código.
- **Constantes:** `data/balance.json` (velocidad de movimiento, radio del jugador, ticks por segundo, retraso de interpolación…).
- **Integración continua (GitHub Actions, gratis en repositorios públicos):** en cada `push` se pasan los tests de GUT sin ventana; en cada etiqueta `v*` se exporta el ejecutable y se adjunta el `.zip` a la Release. Godot se descarga del GitHub oficial dentro del flujo.

### 2. Simulación (`sim/`)
Clases puras (`RefCounted`), sin nodos, deterministas y testeables.
- `SimWorld`: número de tick, jugadores y mapa de colisión. `step(inputs)` avanza un tick.
- `PlayerState`: id, posición (`Vector3`), punto apuntado, dirección a la que mira.
- `PlayerInput`: número de secuencia, dirección de movimiento ya en coordenadas del mundo (plano XZ, longitud ≤ 1) y punto apuntado en el suelo.
- `Movement`: función pura `apply(state, input, dt, collision_map)`. Velocidad constante (5 m/s inicial), diagonal normalizada.
- **Colisiones:** el jugador es un círculo (radio 0,4 m) en el plano XZ contra las **celdas sólidas** de una rejilla de 1 m, con deslizamiento a lo largo de las paredes y sin atravesar bloques aunque el paso sea grande. El mapa de colisión se obtiene de la `GridMap` del escenario. _Mi decisión:_ física propia y sencilla en `sim/` en lugar de la física de Godot, porque la predicción necesita **repetir** movimientos de forma exacta y la física de Godot no lo garantiza. Alturas, rampas y escaleras se añadirán cuando haga falta (Plan 6).
- **Simulación a 30 ticks/s** en el host (`_physics_process` a 30 Hz).

### 3. Red (`net/`) — mensajes propios ([[D-008 Red con mensajes propios]])
**Transporte intercambiable.** Una interfaz `Transport` (enviar bytes a un par, fiable o no, y recibir paquetes y avisos de conexión/desconexión). Implementaciones:
| Transporte | Para qué |
|---|---|
| `LoopbackTransport` | El jugador del host conectado a su propia simulación, sin latencia |
| `MemoryTransport` | Tests: varios pares en memoria con **latencia, variación y pérdida** configurables |
| `EnetTransport` | `ENetMultiplayerPeer` en modo paquetes (puerto UDP 24680 por defecto) |
| `WebRtcTransport` | Solo en la prueba entre casas (fase 7) |
| `LaggyTransport` | Envoltorio de depuración que añade retraso/pérdida a cualquier otro transporte |

**Un único camino de código:** al pulsar "Jugar" siempre se crea un `HostSession` y un `ClientSession` local unidos por `LoopbackTransport`. "Abrir grupo" solo empieza a aceptar conexiones de fuera; jugar solo y en grupo es el mismo código ([[02 Arquitectura técnica|§2.2]]).

**Mensajes** (arrays codificados con `var_to_bytes`, sin objetos; versión de protocolo propia):
| Mensaje | Dirección | Canal | Contenido |
|---|---|---|---|
| `HELLO` | invitado → host | fiable | versión del juego, versión del protocolo, nombre |
| `WELCOME` | host → invitado | fiable | id asignado, tick actual, lista de jugadores |
| `REJECT` | host → invitado | fiable | motivo: versión distinta (con ambas versiones), grupo lleno, nombre inválido |
| `INPUT` | invitado → host | no fiable | las últimas 3 entradas (redundancia ante pérdidas) |
| `SNAPSHOT` | host → todos | no fiable | tick, última entrada procesada de cada jugador, estado de todos los jugadores |
| `PLAYER_JOINED` / `PLAYER_LEFT` | host → todos | fiable | id y nombre |
| `CHAT` | ambos | fiable | autor y texto |

Paquetes mal formados o desconocidos se ignoran sin romper la partida.

**Host (`HostSession`):** recoge las entradas de cada jugador, avanza la simulación a 30 ticks/s y envía una instantánea por tick. Si un jugador no ha mandado entrada para un tick, repite la última; las entradas que llegan duplicadas (por la redundancia) se descartan por número de secuencia, y si se acumulan más de 4 pendientes se descartan las más antiguas para que el retraso no crezca. Acepta como máximo 4 jugadores (él incluido).

**Predicción y reconciliación (`ClientSession`):** el personaje propio se mueve al instante con la misma función `Movement`. Se guardan las entradas no confirmadas; al llegar una instantánea, se coloca el personaje donde dice el host y se **repiten** las entradas pendientes. Si queda una diferencia visible, se corrige suavemente en unos 100 ms en lugar de dar un salto.

**Interpolación:** los demás jugadores se dibujan unos **100 ms en el pasado**, interpolando entre las dos instantáneas que rodean ese momento. Si faltan instantáneas, se mantienen en la última posición conocida (sin extrapolar).

**Control de versiones:** si la versión del juego del invitado no es **exactamente** la del host, el host responde `REJECT` y el invitado ve: "El grupo usa la versión X y tú tienes la Y. Actualiza el juego para unirte." ([[02 Arquitectura técnica|§2.5]]).

**Desconexiones:** si un invitado se va, el resto lo ve en el chat. Si el host se va o se pierde la conexión (tiempo de espera de 5 s), el invitado vuelve al menú con un aviso. No hay migración de host.

### 4. Código de grupo
Una interfaz `Lobby` con `open_group() → código` y `join(código)`, para que la pantalla sea la misma con ENet o con WebRTC.
- **Con ENet:** el código codifica la **IP del host** en 8 caracteres (7 de datos y 1 de control) con un alfabeto sin caracteres ambiguos (sin 0/O, 1/I/L), mostrado como `ABCD-EFGH` y sin distinguir mayúsculas. El **puerto es fijo (24680)**: IP y puerto juntos no caben en 8 caracteres. Si el PC tiene una IP de Tailscale (`100.64.0.0/10`) se usa esa; si no, la de la red local. Así, en una misma casa funciona sin VPN y entre casas con Tailscale.
- **Con WebRTC (fase 7):** el código es el nombre de una sala del servidor de señalización.
- La primera vez que se abre un grupo, Windows pedirá permiso en el cortafuegos: hay que aceptarlo (se explicará en las instrucciones de prueba).

### 5. Juego (`game/`)
- **Escenario de pruebas:** suelo plano de 40×40 bloques con algunos bloques y columnas para probar colisiones, hecho con una `GridMap` y una `MeshLibrary` de bloques de colores provisionales. Iluminación direccional con sombras.
- **Jugadores:** cápsula de un color por posición en el grupo (4 colores), nombre encima (`Label3D` nítido, [[09 Interfaz|§9.2]]) y un indicador de hacia dónde apunta. La cápsula gira hacia el punto apuntado.
- **Cámara:** sigue al personaje propio, inclinada 55°, girada 45° (vista isométrica clásica), sin rotación libre. **Zoom** con la rueda entre unos límites. **Perspectiva por defecto; F9 alterna a ortográfica** para decidir viéndolo ([[15 Decisiones abiertas]]).
- **Controles** ([[03 Cámara y controles|§3.2]]): WASD relativo a la cámara (W = hacia arriba en pantalla); el ratón apunta al punto del suelo bajo el cursor (intersección con el plano del suelo, sin física); Enter abre el chat; Esc abre el menú.
- **Panel de depuración (F3):** FPS, ping, tick, entradas pendientes y tamaño de la última corrección. Sirve para medir la prueba entre casas.

### 6. Interfaz (`ui/`)
Resolución base 1280×720, escalado `canvas_items`. Ninguna ventana con scroll ([[D-007 Interfaz sin scroll]]).
- **Título:** nombre del juego y versión; campo **nombre** (2–16 caracteres, como §4.10); botones **Jugar**, **Unirse a un amigo** (campo de código) y **Salir**. Se recuerdan el nombre y el último código.
- **Menú en partida (Esc):** **Abrir grupo** (muestra el código grande con botón **Copiar**), **Volver al juego**, **Salir al título**. En grupo la partida no se pausa.
- **Chat:** abajo a la izquierda. Enter abre el campo y envía; Esc cancela; máximo 120 caracteres; mientras se escribe no se mueve el personaje. Se ven los últimos 8 mensajes, que se desvanecen a los 10 s; los avisos del sistema (entra, sale) en otro color. Texto sin formato (sin BBCode).
- **Avisos:** ventana sencilla para errores de conexión, versión distinta y grupo lleno.

### 7. Guardado (`save/`)
Solo ajustes: `user://settings.json` con el nombre de jugador y el último código. Lleva número de versión desde el principio ([[10 Guardado]]).

### 8. Exportación y publicación
- Preajuste de exportación **Windows x86_64**, con los datos dentro del ejecutable: `ThalandorOnline.exe`.
- Se publica `ThalandorOnline-0.1.0-windows.zip` en **GitHub Releases** con unas notas en español de qué probar.
- Sin firma de código: Windows SmartScreen avisará la primera vez ("Más información → Ejecutar de todas formas"); se explicará en las notas.

### 9. Fases
1. Proyecto, repositorio, GUT, CI y estructura.
2. Simulación de movimiento y colisiones con tests.
3. Escenario, cámara, cápsula y control local (jugando solo vía loopback).
4. Protocolo, transportes en memoria, host y cliente con predicción e interpolación, con tests de red simulada.
5. ENet, código de grupo, menús, chat y control de versiones.
6. Exportación y **publicación de la 0.1.0**. _Prueba tuya:_ dos ventanas en tu PC y, si puedes, con un amigo por Tailscale.
7. **Prueba entre casas (spike)** y decisión de la red; publicación de la versión resultante.

### 10. Prueba entre casas (fase 7)
Se prueban las dos opciones de [[02 Arquitectura técnica|§2.5]] con el mismo juego:
- **ENet + Tailscale:** host e invitado instalan Tailscale (gratis, requiere cuenta) y se usa el código normal.
- **WebRTC:** requiere el plugin `webrtc-native` (35 MB; se pedirá permiso), un servidor de señalización mínimo en un **plan gratuito** (Cloudflare Workers o Deno Deploy; necesita una cuenta tuya, se decidirá entonces) y servidores STUN públicos. Sin servidor TURN, algunos routers no conectan; eso es justo lo que la prueba mide.
- **Qué se mide:** si conecta a la primera, ping (F3), tirones o saltos visibles, y cuánto les cuesta a los amigos prepararlo.
- **Regla de decisión:** si WebRTC conecta en todas las casas probadas, se elige WebRTC (los amigos no instalan nada). Si no, ENet + VPN. El resultado se apunta en una decisión nueva, en [[02 Arquitectura técnica|§2.5]] y en [[15 Decisiones abiertas]].

## Pruebas
**Automáticas (GUT, las escribe y pasa Claude):**
- **Simulación:** velocidad y diagonal; colisión con bloques (no atraviesa, se desliza, no se cuela con pasos grandes); orientación hacia el punto apuntado; determinismo (mismas entradas → mismo estado).
- **Protocolo:** codificar y decodificar cada mensaje; paquetes mal formados ignorados.
- **Código de grupo:** ida y vuelta IP/puerto ↔ código; códigos inválidos rechazados; mayúsculas/minúsculas y guion indiferentes.
- **Red simulada** (`MemoryTransport`, 1 host + 3 invitados): unirse y lista de jugadores; 5.º jugador rechazado; versión distinta rechazada; las entradas mueven a los jugadores en el host; con latencia 0 la predicción coincide con el host; con **150 ms de latencia y 5 % de pérdida**, al pararse todos, las posiciones de todos los clientes convergen con las del host; correcciones acotadas; la interpolación da posiciones entre instantáneas; el chat llega a todos en orden; desconexión del invitado y del host.
- **Arranque sin ventana** (`--headless`): el juego arranca, crea la partida, un cliente en memoria se une, se mueve y sale sin errores.
- **CI:** los tests pasan en GitHub Actions y la exportación genera el ejecutable.

**Manuales (las haces tú):** dos ventanas en tu PC (con y sin retraso simulado), luego con amigos entre casas. Se te darán instrucciones exactas al terminar cada fase que lo requiera.

## Decisiones tomadas
- La prueba entre casas va **al final** del plan; la conexión queda aislada tras `Transport` y `Lobby` para cambiarla sin rehacer nada.
- Repositorio nuevo `thalandor-online-3d` y publicación inicial en **GitHub Releases** → [[D-009 Repositorio nuevo y publicación en GitHub Releases]].
- Red con **mensajes propios** sobre la capa de paquetes de Godot → [[D-008 Red con mensajes propios]].
- _Decisiones de Claude (corregibles):_ 30 ticks/s; colisiones propias en `sim/` con rejilla de 1 m; cámara 55°/45° con alternancia de proyección en F9; escenario plano de pruebas; puerto UDP 24680; código de 8 caracteres; CI con tests y exportación desde el principio.

---
← [[Planes]]
