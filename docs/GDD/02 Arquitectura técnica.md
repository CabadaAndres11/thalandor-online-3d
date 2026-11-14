---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 2. Arquitectura técnica

## 2.1 Stack **[Diseñado]**
| Pieza | Tecnología | Coste |
|---|---|---|
| Motor | **Godot 4** (versión estable más reciente al empezar; 4.4 o superior) | Gratis (MIT) |
| Lenguaje | **GDScript** con tipado estático (`:=`, tipos en firmas). C# solo si un caso concreto lo exige | Gratis |
| Modelos vóxel | **MagicaVoxel** (modelado) y **Blockbench** (modelos por piezas y animaciones; exporta glTF) | Gratis |
| Importación | glTF 2.0 (`.glb`) nativo de Godot; `.vox` mediante un importador libre si hace falta | Gratis |
| Mundo | `GridMap` con una `MeshLibrary` de bloques vóxel, más props (`.glb`) colocados en escenas | Gratis |
| Red | API multijugador de alto nivel de Godot (ver [[02 Arquitectura técnica|§2.5]]) | Gratis |
| Guardado | Archivos JSON en `user://`, más exportación e importación | Gratis |
| Tests | **GUT** (Godot Unit Test) para la lógica; partidas de prueba automatizadas en modo sin ventana (`--headless`) | Gratis (MIT) |
| Control de versiones | Git + GitHub (repositorio público) | Gratis |
| Distribución | Exportación de Godot para Windows, publicada en **itch.io** (con `butler` para actualizar) y/o **GitHub Releases** | Gratis |

## 2.2 Modelo host-autoritativo **[Diseñado]** (probado en el prototipo 2D)
- **Siempre hay un host.** Al jugar solo, tu PC es el host y no hay invitados. En grupo, un jugador es el host y el resto se conecta a él. Hay un único camino de código para ambos casos.
- **Simulación.** El host simula el mundo a **20–30 ticks/s** en `_physics_process`, separada del render.
- **Invitados.** Envían solo **entradas** (movimiento, punto apuntado en el suelo, habilidad usada) y reciben **instantáneas del estado** del host.
- **Predicción en el cliente:** el personaje propio responde al instante (movimiento y esquiva) y se reconcilia con el estado del host.
- **Interpolación:** el resto de entidades se dibujan suavizadas entre instantáneas (unos 100 ms de retraso).
- **El host también juega:** usa la misma lógica de cliente, conectado a su propia simulación.
- **Eventos fiables** (golpes, muertes, botín, subidas de nivel) separados de las **instantáneas no fiables** (posiciones).

## 2.3 Propiedad de los datos **[Diseñado]**
- **El personaje vive en el PC de su jugador:** nivel, experiencia, atributos, talentos, clase y mejoras, equipo, inventario, oro, misiones y última ubicación.
- **Al unirse** a una partida, el invitado envía su personaje al host, que lo **sanea**: descarta objetos imposibles y reinicia atributos o talentos incoherentes con el nivel, sin expulsar al jugador.
- **El host comunica los cambios al momento** (experiencia, nivel, inventario, equipo) y el cliente los guarda.
- **El estado del mundo es temporal:** monstruos vivos, objetos en el suelo y temporizadores de reaparición no se guardan.

## 2.4 Organización del proyecto **[Diseñado]**
| Carpeta | Responsabilidad |
|---|---|
| `sim/` | Reglas del juego **sin nodos visuales**: estadísticas, daño, amenaza, IA, habilidades, progresión, botín, misiones. Clases GDScript puras (`RefCounted`), testeables con GUT. |
| `net/` | Transporte (`MultiplayerPeer`), mensajes, sincronización, predicción e interpolación. |
| `game/` | Escenas jugables: mundo, personajes, monstruos, cámara, efectos. Leen el estado de `sim/` y lo dibujan. |
| `ui/` | HUD y ventanas (`Control`). |
| `save/` | Guardado, exportación e importación, migraciones de versión. |
| `data/` | Contenido en JSON o recursos `.tres`: clases, habilidades, mejoras de clase, talentos, monstruos, objetos, tablas de botín, misiones, zonas y textos. |
| `assets/` | Modelos vóxel (`.glb`, `.vox`), texturas, audio y fuentes. |
| `tests/` | Tests de GUT. |

Separar `sim/` de las escenas permite probar las reglas sin abrir el juego y cambiar el render sin tocar las reglas.

## 2.5 Conexión **[Diseñado; validar en el Plan 1]**
- **Objetivo:** el host pulsa **"Abrir grupo"** y obtiene un **código corto**; los invitados lo escriben en **"Unirse a un amigo"**. Topología en estrella (cada invitado conectado al host). Sin servidor de juego dedicado.
- **Opción principal:** **WebRTC** con el plugin oficial `webrtc-native` de Godot (MIT).
  - Un **servidor de señalización** mínimo intercambia las ofertas de conexión usando el código como sala. Se aloja en un plan gratuito (por ejemplo Deno Deploy o Cloudflare Workers); no transporta partida, solo el saludo inicial.
  - Servidores **STUN** públicos y gratuitos para atravesar el router.
- **Plan B:** **ENet** (nativo de Godot) con conexión directa, usando una VPN gratuita tipo **Tailscale** o **ZeroTier** cuando el router no deje conectar.
- **El Plan 1 incluye una prueba real** (spike) entre dos casas para elegir la opción definitiva antes de construir encima.
- **Control de versiones:** si el host y el invitado tienen versiones distintas del juego, se rechaza la conexión con un aviso para actualizar.

## 2.6 Rendimiento y escalabilidad del contenido **[Diseñado]**
- **Carga por zona:** cada zona es una escena; solo se carga la zona actual y la anterior se libera.
- **Simulación multizona:** el host simula solo las zonas con al menos un jugador presente.
- **Render:** mallas vóxel optimizadas (caras internas eliminadas al exportar), `MultiMeshInstance3D` para props repetidos, niveles de detalle simples y oclusión cuando haga falta.
- **Objetivo:** 60 FPS en un PC de gama media con 4 jugadores y unos 40 monstruos en pantalla.

---
← [[00 Índice del GDD|Índice del GDD]]
