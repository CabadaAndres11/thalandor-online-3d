---
tags: [referencia]
actualizado: 2026-11-14
---

> Copia del GDD 2.0 en un solo archivo, tal como se entregó. **No se edita:** el GDD vivo es [[00 Índice del GDD]].

# Thalandor Online — Game Design Document (GDD) · Versión 3D

> Documento vivo. Se actualiza cada vez que una decisión cambia o una funcionalidad se implementa.
> Estado de cada apartado: **[Diseñado]** acordado pero sin implementar · **[En curso]** · **[Implementado]** · **[Abierto]** pendiente de decidir.
>
> Este GDD sustituye al de la versión 2D (prototipo en Phaser, repositorio `CabadaAndres11/thalandor-online`, versión 0.5.3). El desarrollo empieza de cero en Godot. El prototipo 2D sirve como **referencia probada** de reglas y fórmulas (combate, amenaza, talentos, botín, red host-autoritativa), pero no se reutiliza su código.

| Campo | Valor |
|---|---|
| Versión del documento | 2.0 |
| Fecha | 2026-11-14 |
| Versión del juego | — (desarrollo desde cero) |

---

## 1. Visión

**Thalandor Online** es un RPG de acción en **3D de estilo vóxel**, con **cámara isométrica** y combate en tiempo real, para jugar online con hasta 4 amigos.

Busca la sensación de un MMO clásico (personajes persistentes, clases con roles, misiones, mazmorras, botín) sin la masividad: cada jugador tiene su personaje y avanza solo o en grupo cuando coincide con sus amigos. **No hay nivel máximo**: el personaje crece indefinidamente y su clase evoluciona cada 50 niveles.

### 1.1 Pilares
1. **Tu personaje es tuyo.** El progreso vive en el personaje, no en la partida de otro jugador. Nadie depende de otro para jugar.
2. **Solo o en grupo, sin fricción.** Se puede jugar en solitario y abrir el grupo a amigos en cualquier momento.
3. **Roles que se complementan.** Tanque, sanador y daño tienen sentido en grupo, pero cada clase puede sobrevivir sola.
4. **Progreso sin techo.** Siempre hay un siguiente objetivo: nivel, mejora de clase, talento, objeto o cambio de clase.
5. **Construido para crecer.** El contenido (zonas, monstruos, objetos, misiones, mejoras de clase) se define como datos; añadir una zona no requiere tocar el motor.

### 1.2 Restricciones del proyecto
- **Presupuesto 0 €.** Toda herramienta, servicio, hosting y asset debe ser gratuito (licencias libres o gratuitas para uso).
- **Plataforma:** PC con Windows, **ejecutable descargable**. La versión web no es objetivo.
- **Jugadores:** de 1 a 4 por partida, cada uno en su casa, por internet.
- **Sin anti-trampas:** el juego es entre amigos. El host es la autoridad de la simulación y valida lo básico de los personajes, pero no se invierte en protección contra trampas.
- **Idioma:** español. Todos los textos están en archivos de datos, preparados para traducción.
- **Desarrollo:** construido íntegramente mediante prompts con Claude. Las decisiones se toman juntos; las instalaciones se piden con permiso y las pruebas de juego las hace el equipo.

### 1.3 Alcance de la primera versión jugable (demo)
- **5 clases** con kit base y pasivas de clase, y la **primera mejora de clase (nivel 50)** con sus 2 opciones por clase.
- Niveles **1–60** con contenido (el sistema no tiene tope; la demo tiene contenido hasta ahí).
- Atributos repartibles, árbol de talentos circular y equipo visible en el personaje.
- Capital y 4 zonas de nivel, cada una con su mazmorra y jefe.
- Multijugador online hasta 4 jugadores, guardado local y exportación de personajes.

**Fuera del alcance de la demo:** intercambio entre jugadores, soporte para mando, cambio de clase (diseñado, ver §4.9), mejoras de clase a partir del nivel 100, chat de voz (se usa Discord).

---

## 2. Arquitectura técnica

### 2.1 Stack **[Diseñado]**
| Pieza | Tecnología | Coste |
|---|---|---|
| Motor | **Godot 4** (versión estable más reciente al empezar; 4.4 o superior) | Gratis (MIT) |
| Lenguaje | **GDScript** con tipado estático (`:=`, tipos en firmas). C# solo si un caso concreto lo exige | Gratis |
| Modelos vóxel | **MagicaVoxel** (modelado) y **Blockbench** (modelos por piezas y animaciones; exporta glTF) | Gratis |
| Importación | glTF 2.0 (`.glb`) nativo de Godot; `.vox` mediante un importador libre si hace falta | Gratis |
| Mundo | `GridMap` con una `MeshLibrary` de bloques vóxel, más props (`.glb`) colocados en escenas | Gratis |
| Red | API multijugador de alto nivel de Godot (ver §2.5) | Gratis |
| Guardado | Archivos JSON en `user://`, más exportación e importación | Gratis |
| Tests | **GUT** (Godot Unit Test) para la lógica; partidas de prueba automatizadas en modo sin ventana (`--headless`) | Gratis (MIT) |
| Control de versiones | Git + GitHub (repositorio público) | Gratis |
| Distribución | Exportación de Godot para Windows, publicada en **itch.io** (con `butler` para actualizar) y/o **GitHub Releases** | Gratis |

### 2.2 Modelo host-autoritativo **[Diseñado]** (probado en el prototipo 2D)
- **Siempre hay un host.** Al jugar solo, tu PC es el host y no hay invitados. En grupo, un jugador es el host y el resto se conecta a él. Hay un único camino de código para ambos casos.
- **Simulación.** El host simula el mundo a **20–30 ticks/s** en `_physics_process`, separada del render.
- **Invitados.** Envían solo **entradas** (movimiento, punto apuntado en el suelo, habilidad usada) y reciben **instantáneas del estado** del host.
- **Predicción en el cliente:** el personaje propio responde al instante (movimiento y esquiva) y se reconcilia con el estado del host.
- **Interpolación:** el resto de entidades se dibujan suavizadas entre instantáneas (unos 100 ms de retraso).
- **El host también juega:** usa la misma lógica de cliente, conectado a su propia simulación.
- **Eventos fiables** (golpes, muertes, botín, subidas de nivel) separados de las **instantáneas no fiables** (posiciones).

### 2.3 Propiedad de los datos **[Diseñado]**
- **El personaje vive en el PC de su jugador:** nivel, experiencia, atributos, talentos, clase y mejoras, equipo, inventario, oro, misiones y última ubicación.
- **Al unirse** a una partida, el invitado envía su personaje al host, que lo **sanea**: descarta objetos imposibles y reinicia atributos o talentos incoherentes con el nivel, sin expulsar al jugador.
- **El host comunica los cambios al momento** (experiencia, nivel, inventario, equipo) y el cliente los guarda.
- **El estado del mundo es temporal:** monstruos vivos, objetos en el suelo y temporizadores de reaparición no se guardan.

### 2.4 Organización del proyecto **[Diseñado]**
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

### 2.5 Conexión **[Diseñado; validar en el Plan 1]**
- **Objetivo:** el host pulsa **"Abrir grupo"** y obtiene un **código corto**; los invitados lo escriben en **"Unirse a un amigo"**. Topología en estrella (cada invitado conectado al host). Sin servidor de juego dedicado.
- **Opción principal:** **WebRTC** con el plugin oficial `webrtc-native` de Godot (MIT).
  - Un **servidor de señalización** mínimo intercambia las ofertas de conexión usando el código como sala. Se aloja en un plan gratuito (por ejemplo Deno Deploy o Cloudflare Workers); no transporta partida, solo el saludo inicial.
  - Servidores **STUN** públicos y gratuitos para atravesar el router.
- **Plan B:** **ENet** (nativo de Godot) con conexión directa, usando una VPN gratuita tipo **Tailscale** o **ZeroTier** cuando el router no deje conectar.
- **El Plan 1 incluye una prueba real** (spike) entre dos casas para elegir la opción definitiva antes de construir encima.
- **Control de versiones:** si el host y el invitado tienen versiones distintas del juego, se rechaza la conexión con un aviso para actualizar.

### 2.6 Rendimiento y escalabilidad del contenido **[Diseñado]**
- **Carga por zona:** cada zona es una escena; solo se carga la zona actual y la anterior se libera.
- **Simulación multizona:** el host simula solo las zonas con al menos un jugador presente.
- **Render:** mallas vóxel optimizadas (caras internas eliminadas al exportar), `MultiMeshInstance3D` para props repetidos, niveles de detalle simples y oclusión cuando haga falta.
- **Objetivo:** 60 FPS en un PC de gama media con 4 jugadores y unos 40 monstruos en pantalla.

---

## 3. Cámara y controles **[Diseñado]**

### 3.1 Cámara
- **Isométrica/cenital** en perspectiva (o proyección ortográfica si se ve mejor), alta e inclinada unos 50–60°, siguiendo al personaje.
- **Zoom** con la rueda del ratón entre unos límites; sin rotación libre en la demo (la rotación en pasos de 90° es una opción futura).
- **Objetos que tapan:** los tejados y paredes entre la cámara y el personaje se vuelven translúcidos.

### 3.2 Controles
| Acción | Tecla |
|---|---|
| Moverse | W A S D (relativo a la cámara) |
| Apuntar | Ratón (punto del suelo bajo el cursor) |
| Ataque básico | Clic izquierdo |
| Ataque secundario | Clic derecho |
| Habilidades | 1 · 2 · 3 · 4 |
| Esquiva / desplazamiento | Espacio |
| Pociones | Vida (Q) · Recurso (R) |
| Interactuar | E (levantar a un aliado, hablar con PNJ, abrir cofres) |
| Chat de grupo | Enter |
| Zoom de cámara | Rueda del ratón |
| Ventanas | Personaje (C), Inventario (I), Habilidades (K), Talentos (N), Misiones (J), Mapa (M), Menú (Esc) |

Todas las teclas son reasignables desde Opciones (`InputMap`).

---

## 4. Personajes y clases

### 4.1 Recursos **[Diseñado]**
- **Vida:** todas las clases.
- **Recurso de clase:**
  - **Ira** (Guerrero): se genera golpeando y recibiendo daño; decae fuera de combate.
  - **Maná** (Clérigo, Mago): se consume al lanzar y se regenera con Espíritu (al 50 % en combate solo con la pasiva adecuada).
  - **Concentración** (Arquero): se regenera rápido estando quieto o caminando, más despacio al esquivar; los disparos cargados la consumen.
  - **Energía** (Asesino): se regenera rápido a ritmo fijo.

### 4.2 Las 5 clases iniciales **[Diseñado]**
| Clase | Recurso | Rol base | Arma | Armadura |
|---|---|---|---|---|
| **Guerrero** | Ira | Tanque o daño cuerpo a cuerpo | Espada, hacha, maza, escudo | Placas (y todas las inferiores) |
| **Clérigo** | Maná | Sanador o daño sagrado | Maza, bastón, escudo, orbe | Tela |
| **Mago** | Maná | Daño mágico a distancia y control | Bastón, orbe | Tela |
| **Arquero** | Concentración | Daño físico a distancia | Arco, ballesta, carcaj | Cuero y malla |
| **Asesino** | Energía | Daño cuerpo a cuerpo con sigilo | Dagas (dos), espada corta | Cuero |

Orden de armaduras, de más ligera a más pesada: tela < cuero < malla < placas. Cada clase puede llevar su tipo y los inferiores.

**Supervivencia en solitario:**
- **Guerrero:** escudo, bloqueo y robo de vida.
- **Clérigo:** se cura a sí mismo.
- **Mago:** mantiene la distancia, congela y teletransporta.
- **Arquero:** mantiene la distancia, ralentiza y esquiva.
- **Asesino:** evasión alta y vuelta al sigilo para salir del combate.

**Mecánicas propias:**
- **Arquero:** disparos **cargados** (mantener el botón aumenta daño y alcance), **trampas** colocadas en el suelo y **marca** sobre un objetivo.
- **Asesino:** **sigilo** (los monstruos no lo detectan; se rompe al atacar o recibir daño; el primer golpe saliendo de sigilo es crítico), **puntos de combo** (0–5) que se gastan en remates, y **venenos** acumulables.

### 4.3 Habilidades **[Diseñado]**
- **Kit base por clase:** ataque básico (clic izquierdo), ataque secundario (clic derecho) y habilidades que se desbloquean por nivel (niveles 1, 3, 6, 10, 15, 20, 30 y 40).
- **Pasivas de clase:** niveles 5, 15, 25 y 35.
- **Barra:** 4 ranuras asignables (1–4); hay más habilidades que ranuras y el jugador elige cuáles lleva (ventana K).
- **Esquiva común** para todas las clases (Espacio).
- **Definición:** el listado concreto está en el **anexo A** y en `data/abilities/`. Es una propuesta inicial, ajustable tras las pruebas.

### 4.4 Mejoras de clase cada 50 niveles **[Diseñado]** (sustituyen a las especializaciones del prototipo)
- **Cada 50 niveles** (50, 100, 150…) se alcanza un **rango de clase** y se elige **una de 2 mejoras**.
- **Cada mejora aporta:** 2 habilidades activas nuevas, 2 pasivas y la **evolución de una habilidad base** (por ejemplo, el Tajo del Guerrero pasa a golpear dos veces).
- **Las mejoras se acumulan:** al nivel 100 se elige otra mejora de un segundo rango, cuyas opciones dependen de la elegida al 50 (árbol de evolución de la clase).
- **Cambiar de mejora:** posible en la capital (instructor de clase) pagando oro, fuera de combate.
- **Primer rango (nivel 50):** definido en el **anexo A**. Los rangos siguientes se diseñarán a medida que haya contenido para esos niveles.

| Clase | Mejora A (nivel 50) | Mejora B (nivel 50) |
|---|---|---|
| Guerrero | **Protector** (tanque: provocar en área, muro de escudo, represalia) | **Campeón** (daño: golpe mortal, ejecutar, temeridad) |
| Clérigo | **Sanador** (círculo de sanación, plegaria de vida, himno) | **Castigador** (fuego sagrado, juicio, lanza de luz) |
| Mago | **Piromante** (bola de fuego, columna de llamas, meteoro) | **Criomante** (descarga de escarcha, ventisca, bloque de hielo) |
| Arquero | **Francotirador** (disparo apuntado, ráfaga, marca del cazador) | **Montaraz** (disparo múltiple, trampas mejoradas, compañero animal) |
| Asesino | **Sombra** (eviscerar mejorado, desvanecer, emboscada) | **Venenero** (venenos letales, nube tóxica, contagio) |

### 4.5 Atributos **[Diseñado]**
Cada nivel otorga **5 puntos de atributo** para repartir libremente, y cada clase sube además 2 atributos principales por nivel.

| Atributo | Efecto |
|---|---|
| **Fuerza** | Poder de ataque cuerpo a cuerpo, probabilidad de bloqueo (0,2 % por punto; un bloqueo reduce a la mitad el daño físico cuerpo a cuerpo) |
| **Agilidad** | Probabilidad de crítico, esquiva, poder de ataque a distancia |
| **Intelecto** | Poder de hechizos, maná máximo |
| **Aguante** | Vida máxima |
| **Espíritu** | Regeneración de vida y maná |

**Sin nivel máximo:** para que los números no se disparen, las conversiones de atributo a estadística tienen **rendimientos decrecientes** a partir de ciertos umbrales (definidos en `data/balance.json`), y la probabilidad de crítico, esquiva y bloqueo tiene topes.

### 4.6 Árbol de talentos **[Diseñado]** (diseño probado en el prototipo 2D)
- **Puntos:** 1 por nivel a partir del 2.
- **Árbol común a todas las clases.** Los nodos solo dan estadísticas: no modifican habilidades.
- **Estructura circular:** se empieza en el centro y se avanza en cualquier dirección comprando nodos conectados a los que ya tienes (1 punto por nodo). Cada dirección está orientada a unas estadísticas.
  - **5 direcciones** en orden circular: Poderío (daño físico), Celeridad (velocidad y recargas), Vitalidad (sostenimiento), Bastión (defensa) y Arcano (daño mágico).
  - **Radios híbridos** entre direcciones vecinas que mezclan las dos.
  - **Notables** (valen el doble) y **culminantes** al final de cada dirección.
- **Crece con el personaje:** cada rango de clase (nivel 50, 100…) desbloquea un **anillo exterior** nuevo con más nodos y culminantes más potentes.
- **Puntos sobrantes (maestría):** cuando un jugador ha comprado todo lo disponible, los puntos nuevos van a **maestrías**: bonos pequeños e ilimitados (por ejemplo +0,1 % de vida por rango) con rendimiento decreciente.
- **Reinicio:** completo, cuesta oro y se hace con el instructor de la capital, fuera de combate.
- **Nodos:** el anexo C tiene la lista del círculo inicial (46 nodos).

### 4.7 Cálculo de estadísticas **[Diseñado]**
```
final = (base de clase + atributos + suma de bonos planos) × (1 + suma de bonos %)
```
- **Bonos planos:** equipo y talentos. **Bonos porcentuales:** equipo, talentos, pasivas y mejoras de clase.
- Los porcentajes de una misma estadística se **suman** antes de multiplicar.
- **Estadísticas secundarias:** daño crítico (se suma al ×1,5), reducción de recargas (tope del 40 %), robo de vida, bloqueo y multiplicador de amenaza.
- **Daño:** `(base + coeficiente × poder) × variación ±10 % × multiplicadores`; armadura con mitigación `armadura / (armadura + K)` y tope del 75 %, donde K crece con el nivel del atacante para que la armadura no pierda valor.
- **Datos:** todas las constantes viven en `data/balance.json`.

### 4.8 Progresión sin nivel máximo **[Diseñado]**
- **No hay nivel máximo.** La demo tiene contenido hasta el nivel 60.
- **Curva de experiencia:** `xpParaSubir(L) = round(100 × L^1,6)` hasta el nivel 50; a partir de ahí crece de forma **lineal** para que cada nivel cueste parecido (el valor exacto se ajusta en `data/balance.json` tras las pruebas). Objetivo orientativo: nivel 50 en unas 20–25 h de juego.
- **Experiencia por monstruo:** `8 × nivel^1,2`, ×4 si es élite. Baja si el monstruo está más de 2 niveles por debajo (mínimo 10 %).
- **Reparto en grupo:** entre los jugadores cercanos, con un bonus de `1 + 0,1 × (miembros − 1)`.
- **Al subir de nivel:** vida y recurso al máximo, efecto visual y aviso en el chat para todos.
- **Cada 50 niveles:** rango de clase (mejora a elegir, §4.4) y anillo nuevo del árbol de talentos (§4.6).
- **Muerte:** no hace perder experiencia.

### 4.9 Cambio de clase **[Diseñado; requisitos [Abierto]]**
- **Qué es:** un personaje puede cambiar a otra de las 5 clases cuando cumple ciertos requisitos.
- **Propuesta de requisitos** (a confirmar con el equipo):
  - Haber alcanzado el **primer rango de clase** (nivel 50) con la clase actual.
  - Completar una **misión de prueba** en la capital propia de la clase destino.
  - Pagar una cantidad de oro.
- **Qué se conserva y qué no** (propuesta):
  - Se conservan el **nivel**, la experiencia, el oro, el inventario, las misiones y el árbol de talentos (es común a todas las clases).
  - Cada clase lleva su **progreso propio de mejoras de clase**: si vuelves a una clase que ya tuviste, recuperas sus mejoras.
  - El equipo que la nueva clase no puede usar se queda en el inventario.
  - Los atributos repartidos se reinician gratis para recolocarlos.
- **Fuera de la demo:** se implementa después de tener contenido por encima del nivel 50.

### 4.10 Creación y apariencia del personaje **[Diseñado]**
- Hasta **8 personajes** por jugador.
- Se eligen **nombre, clase y apariencia**.
- **Apariencia vóxel:** tipo de cuerpo, tono de piel, peinado, color de pelo y color de ojos; los modelos se arman por piezas (cabeza, torso, brazos, piernas).
- **Ropa inicial:** la decide la clase. Después cambia con el equipo (§8).
- **Nombres:** de 2 a 16 caracteres (letras con tildes, números, espacios, `-` y `'`), sin repetir entre los personajes del mismo jugador.

---

## 5. Combate **[Diseñado]** (reglas probadas en el prototipo 2D)

- **Tiempo real.** Ataques cuerpo a cuerpo en arco, proyectiles y áreas, con avisos en el suelo antes de los ataques fuertes de los monstruos.
- **Hitbox en 3D:** cada personaje y monstruo tiene una **cápsula** (de los pies a la cabeza); los proyectiles impactan en cualquier punto del cuerpo, no solo en los pies.
- **Esquiva común:** salto corto con breve invulnerabilidad y recarga de unos 3 s.
- **Recarga global:** 0,5 s entre habilidades (no afecta a los ataques básicos ni a la esquiva).
- **Amenaza (aggro):** tabla de amenaza por monstruo; el daño y la curación generan amenaza; el tanque tiene provocar y multiplicadores de amenaza.
- **Sin fuego amigo.**
- **Escalado por grupo:** la vida de los monstruos escala con el número de jugadores presentes (`1 + 0,75 × (jugadores − 1)`).
- **Monstruos:** normales, élite (más fuertes, mejor botín) y jefes (fases y ataques en área que hay que esquivar).
- **IA:** reposo, combate (persecución con navegación de Godot: `NavigationAgent3D`) y vuelta a su zona si se alejan demasiado; algunos en manada, otros a distancia.
- **Muerte:**
  - **En grupo:** el jugador queda **derribado** y un compañero lo levanta manteniendo **E** unos segundos.
  - **En solitario, o si cae todo el grupo:** reaparición en el último punto de control. Se pierde **durabilidad del equipo**, no experiencia.

---

## 6. Mundo

### 6.1 Estructura **[Diseñado]**
- **Zonas:** el mundo está formado por zonas conectadas; cada una es una **escena 3D** construida con `GridMap` (bloques vóxel) y props. Se pasa entre zonas por sus bordes o portales, con una pantalla de carga breve.
- **Varias zonas a la vez:** dentro de una partida los jugadores pueden estar en zonas distintas.
- **Mazmorras:** son **instancias** (cada grupo tiene su copia).
- **Puntos de control** para reaparecer y **reaparición de monstruos** con temporizador.
- **Iluminación:** ciclo de día y noche opcional por zona; las mazmorras usan luces locales (antorchas) para dar ambiente.

### 6.2 Contenido de la demo **[Diseñado]**
| Zona | Niveles | Contenido |
|---|---|---|
| **Ciudad** (capital) | — | Zona segura: mercaderes, instructor de talentos y de clase, reparador, alijo y personajes con misiones |
| **Bosque** | 1–12 | Cadena de misiones y **mazmorra** con jefe |
| **Desierto** | 12–25 | Cadena de misiones y **mazmorra** con jefe |
| **Cementerio** | 25–40 | Cadena de misiones y **mazmorra** con jefe |
| **Volcán** | 40–60 | Cadena de misiones y **mazmorra** con jefe; prueba de rango al nivel 50 |

- **Crecimiento:** el mundo crece por **capítulos** de unos 50 niveles; cada capítulo añade zonas nuevas y un rango de clase.
- **Historia:** se escribirá a partir de un **guion que se desarrollará conjuntamente** con el equipo (anexo B). Hasta entonces, las misiones usan textos provisionales.

### 6.3 Pipeline de contenido **[Diseñado]**
Añadir una zona consiste en aportar:
1. La escena de la zona (`GridMap` + props) con sus marcadores (spawns, PNJ, puntos de control, salidas).
2. Las entradas de monstruos y spawns en `data/`.
3. Las misiones.
4. Los textos.

Sin modificar el código de `sim/`. Es un requisito de arquitectura, porque el juego está pensado para crecer a muchas zonas.

---

## 7. Misiones **[Diseñado]**

- **Tipos:** matar X, recoger objetos que sueltan los monstruos, hablar con alguien o entregarle un objeto, explorar una ubicación, derrotar a un jefe.
- **Cadenas:** se encadenan mediante requisitos (misión previa completada, nivel mínimo, clase).
- **Progreso por personaje.** En grupo, una muerte cuenta para todos los miembros cercanos que tengan la misión activa.
- **Recompensas:** experiencia, oro y, opcionalmente, un objeto a elegir entre varios.
- **Misiones especiales:** prueba de rango de clase (nivel 50) y misiones de cambio de clase (§4.9).

---

## 8. Botín, objetos y economía **[Diseñado]** (sistema probado en el prototipo 2D)

- **Botín personal:** cada jugador cercano tiene su propia tirada al morir un monstruo. Los objetos caen sueltos en el suelo, con un haz de luz y su nombre del color de su rareza, y solo los ve su dueño. Se recogen pasando por encima y desaparecen a los 2 minutos.
- **Qué cae:** oro casi siempre; objetos el 12 % de las veces en monstruos normales; el élite suelta 1 seguro y a veces 2; pociones a veces. El 75 % de los objetos es usable por la clase de quien lo recibe.
- **Rarezas:**

| Rareza | Estadísticas | Color |
|---|---|---|
| Común | Fijas | blanco |
| Poco común | Fijas + 1 propiedad aleatoria | verde |
| Raro | Fijas + 2 propiedades aleatorias | azul |
| Épico | Fijas + 3 propiedades aleatorias | morado |
| Legendario | Fijas + 4 propiedades y un efecto único | naranja |
| Único de jefe | Fijas, con nombre propio y aspecto propio | dorado |

- **Propiedades aleatorias:** planas (+12 Fuerza) o porcentuales (+5 % vida), sin repetir estadística, escaladas por el nivel del objeto.
- **Nivel del objeto:** sin tope, como los personajes. Las estadísticas base escalan con él.
- **Ranuras de equipo (11):** arma principal, mano secundaria, cabeza, hombros, pecho, manos, piernas, pies, cuello y anillo ×2.
- **Requisito de nivel:** no se puede equipar un objeto de nivel superior al del personaje.
- **Equipo visible:** cada objeto base tiene **su propio modelo vóxel**. El arma, la mano secundaria, la cabeza, los hombros, el pecho, las manos, las piernas y los pies cambian el aspecto del personaje (piezas acopladas a los huesos del modelo con `BoneAttachment3D`). El resto del grupo también lo ve.
- **Iconos:** el icono de cada pieza es una **miniatura renderizada de su propio modelo** (generada al importar o al arrancar).
- **Inventario:** 30 casillas (ventana I). Clic derecho para equipar o usar; el tooltip compara con lo equipado. **No se puede vender ni tirar fuera de un mercader.**
- **Oro:** se obtiene de monstruos, misiones y ventas. Se gasta en el mercader (pociones, objetos y reparaciones), reinicio de talentos, cambio de mejora y cambio de clase.
- **Mercaderes:** en la capital. Venden pociones y objetos comunes, compran al 25 % del valor y reparan.
- **Durabilidad:** cada pieza equipada pierde un 10 % al morir (no al quedar derribado). A 0 no da estadísticas.
- **Pociones:** vida (Q) y recurso (R), con el 35 % y una recarga compartida de 30 s, en pilas de 20.
- **Alijo:** almacén compartido entre los personajes del mismo jugador, en la capital.
- **Intercambio entre jugadores:** fuera de la demo.

---

## 9. Interfaz y flujo

### 9.1 Flujo **[Diseñado]**
1. **Pantalla de título.**
2. **Selección de personaje:** cada tarjeta muestra el **modelo 3D del personaje con su equipo**; opciones de crear, borrar, exportar e importar personajes.
3. **Jugar:** entra al mundo como host de su propia partida.
   - **"Abrir grupo"** está disponible en cualquier momento y genera un código.
   - **"Unirse a un amigo":** desde la selección de personaje, introduciendo el código.
   - **Al unirse**, el invitado aparece en su última ubicación guardada.
   - **"Ir con el grupo"** teletransporta junto al líder, solo fuera de combate.

### 9.2 HUD **[Diseñado]**
- Vida, recurso de clase, barra de experiencia y nivel.
- Barra de habilidades en **casillas cuadradas con icono** (clic izquierdo, clic derecho, 1–4, Espacio, Q y R), con barrido de recarga, tecla y casilla atenuada sin recurso.
- Indicadores propios de clase (puntos de combo del Asesino, carga del disparo del Arquero).
- Marcos de grupo con la vida y el recurso de los compañeros.
- Minimapa y seguimiento de misiones.
- Números de daño flotantes; nombre y vida sobre personajes y enemigos.
- **Textos nítidos:** los textos sobre el mundo (nombres, botín) se dibujan como interfaz (`Label` en pantalla o `Label3D` con fuente de alta resolución), nunca escalados de forma que se vean borrosos.

### 9.3 Ventanas **[Diseñado]**
- **Norma:** **ninguna ventana puede necesitar scroll** para verse entera (en una pantalla de 1280×720). Si una ventana se llena, su contenido se reparte en otra ventana con su propia tecla.
- **Personaje (C):** atributos y estadísticas a la izquierda; a la derecha, el equipo alrededor de un **modelo 3D en vivo** del personaje (un `SubViewport` que gira lentamente) con lo que lleva puesto.
- **Inventario (I):** cuadrícula de 30 casillas y oro; se puede ver a la vez que la ventana de Personaje.
- **Habilidades (K):** clase y mejoras de clase, habilidades desbloqueadas, asignación de la barra y pasivas con su descripción.
- **Talentos (N):** el árbol circular dibujado tal cual, con zoom si crece.
- **Misiones (J), Mapa (M), Mercader** y **Menú (Esc)** (en solitario pausa el mundo; en grupo la partida sigue).
- **Opciones:** controles, volumen, gráficos y pantalla completa.

### 9.4 Social **[Diseñado]**
- Chat de texto de grupo. Para la voz se usa Discord.

---

## 10. Guardado **[Diseñado]**
- **Archivos JSON** por personaje en `user://saves/` (en Windows, la carpeta de datos del usuario).
- **Autoguardado:** la posición cada 30 s, al cambiar de zona y al salir; el progreso y el inventario cada vez que el host los cambia (en cola, sin escrituras simultáneas).
- **Exportación e importación:** cada personaje se puede exportar e importar como archivo, como copia de seguridad o para jugar desde otro PC.
- **Versiones del guardado:** cada guardado lleva un número de versión y se migra automáticamente al actualizar el juego. Ninguna actualización puede borrar personajes ni objetos (lo que no quepa va a casillas extra).

---

## 11. Arte y audio **[Diseñado]**

- **Estilo:** **vóxel** 3D, colores vivos y saturados, iluminación suave con sombras (estética tipo Cube World / Trove / Minecraft Dungeons).
- **Escala:** bloques del mundo de 1 m; personajes de unas 24–32 unidades vóxel de alto, construidos por piezas.
- **Personajes:** modelo base por cuerpo, animado por **esqueleto** (las piezas rígidas siguen a los huesos), con animaciones de reposo, andar, correr, golpe en arco, estocada, lanzar hechizo, disparar, esquivar, recibir daño, derribado y morir. Se hacen en Blockbench (exporta glTF con animaciones).
- **Equipo:** un modelo vóxel por objeto base, acoplado a su hueso; variantes de material (hierro, acero, oro…) por color de paleta.
- **Monstruos:** modelos vóxel propios con sus animaciones.
- **Fuentes de assets:**
  - Primero packs gratuitos con licencia libre (CC0 preferido; CC-BY con créditos): por ejemplo los packs vóxel de **Kenney**, **itch.io** y **OpenGameArt**.
  - Lo que falte se modela en MagicaVoxel o Blockbench.
  - Antes de descargar, se proponen 2 o 3 candidatos de estilo coherente para su aprobación.
- **Créditos:** archivo `CREDITS.md` con autor y licencia de cada asset, generado o mantenido con cada importación.
- **Gráficos provisionales:** cubos y cápsulas de colores hasta tener los modelos definitivos.
- **Audio:** música y efectos de packs gratuitos con licencia libre; volumen por canal (música, efectos, interfaz).

---

## 12. Pruebas **[Diseñado]**

| Nivel | Herramienta | Qué cubre |
|---|---|---|
| Unitario | GUT | Estadísticas, daño, amenaza, talentos, mejoras de clase, misiones, botín, experiencia, migraciones de guardado |
| Simulación de red | GUT con transporte en memoria (latencia y pérdida simuladas) | 1 host y 3 invitados; sincronización y reconciliación |
| Partida automática | Godot en modo `--headless` con un script que juega | Crear personaje, entrar, combatir, guardar y cargar |
| Real | Partidas con amigos | Conexión entre casas, rendimiento y diversión |

Cada funcionalidad se entrega con sus tests; las pruebas de juego reales las hace el equipo.

---

## 13. Distribución **[Diseñado]**
- **Repositorio:** público en GitHub.
- **Ejecutable para Windows** exportado desde Godot, publicado en **itch.io** (página gratuita; `butler` para subir versiones y que la app de itch actualice sola) y en **GitHub Releases**.
- **Compilación automática:** GitHub Actions exporta el juego en cada versión etiquetada (con la imagen oficial gratuita de Godot para CI).
- **Versión visible** en la pantalla de título; el control de versiones en la conexión está en §2.5.

---

## 14. Hoja de ruta propuesta **[Diseñado]**
Cada plan se diseña (spec), se planifica, se implementa con tests, se prueba y se publica antes de pasar al siguiente.

| Plan | Contenido |
|---|---|
| 1 | **Fundaciones y red:** proyecto Godot, estructura de carpetas, cámara isométrica, personaje provisional (cápsula) que se mueve, host-autoritativo, spike de conexión entre casas (§2.5), grupo por código, chat y exportación para Windows |
| 2 | **Personajes vóxel:** creación y selección (hasta 8), modelo por piezas con animaciones, apariencia, guardado y exportación |
| 3 | **Combate y las 5 clases:** kits base, pasivas, esquiva, amenaza, derribo, monstruos con IA, HUD de combate |
| 4 | **Progresión:** experiencia sin tope, atributos, árbol de talentos circular, primera mejora de clase (nivel 50) |
| 5 | **Objetos:** botín, inventario, equipo visible, mercader, durabilidad, pociones |
| 6 | **Mundo y misiones:** capital, zonas, mazmorras instanciadas, jefes, misiones y alijo |
| 7 | **Interfaz y audio:** minimapa, marcos de grupo, opciones, música y efectos |
| 8 | **Contenido de la demo:** las 4 zonas completas hasta el nivel 60 y el cambio de clase |

---

## 15. Decisiones abiertas **[Abierto]**
- Requisitos exactos del **cambio de clase** (§4.9).
- **Ritmo de la curva** a partir del nivel 50 (horas por nivel).
- Mejoras de clase del **segundo rango** (nivel 100) en adelante.
- Opción de red definitiva tras el spike del Plan 1 (§2.5).
- Proyección de cámara: perspectiva u ortográfica (§3.1), a decidir viendo el resultado.

---

## Anexo A — Habilidades (propuesta inicial)

**Convenciones:** CI = clic izquierdo, CD = clic derecho. El número es el nivel de desbloqueo. Valores, costes y recargas en `data/abilities/`.

### Guerrero (Ira)
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Tajo (CI) | Activa | Golpe en arco frontal. Genera ira. |
| 1 | Golpe brutal (CD) | Activa | Gasta ira: gran daño a un objetivo. |
| 1 | Carga | Activa | Se lanza hacia el cursor y aturde brevemente. |
| 3 | Grito de guerra | Activa | +daño al grupo cercano unos segundos. |
| 6 | Torbellino | Activa | Daño en área alrededor. |
| 10 | Provocar | Activa | Los enemigos cercanos le atacan unos segundos. |
| 20 | Muro de escudo | Activa | −50 % de daño recibido durante 6 s. |
| 5 | Furia contenida | Pasiva | La ira decae un 50 % más lento. |
| 15 | Piel endurecida | Pasiva | +10 % de armadura. |
| 25 | Bloqueo experto | Pasiva | Los bloqueos generan ira. |
| 35 | Sed de sangre | Pasiva | Los críticos curan un 3 % de la vida. |

### Clérigo (Maná)
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Destello sagrado (CI) | Activa | Proyectil de luz. |
| 1 | Sanar (CD) | Activa | Cura al aliado bajo el cursor o, si no hay ninguno, a sí mismo. |
| 1 | Palabra de escudo | Activa | Escudo que absorbe daño. |
| 3 | Renovar | Activa | Curación en el tiempo. |
| 6 | Nova sagrada | Activa | Daño en área y curación a los aliados cercanos. |
| 10 | Purificar | Activa | Quita efectos negativos de un aliado. |
| 20 | Resurrección | Activa | Levanta a distancia a un aliado derribado (recarga larga). |
| 5 | Meditación | Pasiva | La regeneración de maná continúa al 50 % en combate. |
| 15 | Fe inquebrantable | Pasiva | +10 % de curación recibida. |
| 25 | Gracia | Pasiva | +10 % de curación realizada. |
| 35 | Eco de luz | Pasiva | Las curaciones dejan una curación extra en el tiempo. |

### Mago (Maná)
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Proyectil arcano (CI) | Activa | Proyectil mágico rápido. |
| 1 | Explosión arcana (CD) | Activa | Pequeña área en el cursor, con un breve retardo. |
| 1 | Parpadeo | Activa | Teletransporte corto hacia el cursor. |
| 3 | Nova de escarcha | Activa | Congela 2 s a los enemigos cercanos. |
| 6 | Barrera de maná | Activa | Escudo que absorbe daño. |
| 10 | Bola de fuego | Activa | Proyectil que explota en área. |
| 20 | Descarga de escarcha | Activa | Proyectil que ralentiza. |
| 5 | Mente arcana | Pasiva | +10 % de maná máximo. |
| 15 | Concentración | Pasiva | Tras 3 s sin recibir daño: +10 % de daño de hechizos. |
| 25 | Ignición | Pasiva | Los críticos de fuego dejan una quemadura. |
| 35 | Frío penetrante | Pasiva | +20 % de daño a enemigos congelados o ralentizados. |

### Arquero (Concentración)
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Disparo (CI) | Activa | Flecha a distancia; mantener carga el disparo (más daño y alcance). |
| 1 | Disparo perforante (CD) | Activa | Flecha que atraviesa a los enemigos en línea. |
| 1 | Voltereta | Activa | Salto hacia atrás disparando una flecha. |
| 3 | Red | Activa | Inmoviliza a un enemigo 3 s. |
| 6 | Lluvia de flechas | Activa | Área en el cursor. |
| 10 | Trampa explosiva | Activa | Trampa en el suelo que explota al pisarla. |
| 20 | Marca | Activa | El objetivo marcado recibe +15 % de daño. |
| 5 | Reflejos | Pasiva | +5 % de esquiva. |
| 15 | Ojo de halcón | Pasiva | +15 % de alcance. |
| 25 | Distancia letal | Pasiva | +15 % de daño a objetivos lejanos. |
| 35 | Ráfaga | Pasiva | Cada 5.º disparo básico es crítico. |

### Asesino (Energía)
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Cuchillada (CI) | Activa | Golpe con dagas que genera 1 punto de combo. |
| 1 | Eviscerar (CD) | Activa | Remate que gasta los puntos de combo; el daño escala con los puntos. |
| 1 | Paso sombrío | Activa | Se teletransporta a la espalda del objetivo. |
| 3 | Sigilo | Activa | Fuera de combate entra en sigilo; en combate, desaparece y sale del combate (recarga larga). |
| 6 | Abanico de cuchillas | Activa | Daño en área alrededor y 1 punto de combo por enemigo. |
| 10 | Veneno | Activa | Durante 30 s, los golpes aplican un veneno acumulable (hasta 5). |
| 20 | Evasión | Activa | +50 % de esquiva durante 5 s. |
| 5 | Golpe por la espalda | Pasiva | +20 % de daño por la espalda. |
| 15 | Emboscada | Pasiva | El primer golpe desde sigilo es crítico y hace +50 % de daño. |
| 25 | Evasión mortal | Pasiva | Tras esquivar, el siguiente golpe genera 2 puntos de combo. |
| 35 | Oportunista | Pasiva | +10 % de daño a objetivos aturdidos o inmovilizados. |

### Mejoras de clase del nivel 50
Cada mejora: 2 activas, 2 pasivas y la evolución de una habilidad base. Propuesta inicial; los valores se ajustan en las pruebas.

| Clase | Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|---|
| Guerrero | **Protector** | Provocar en área; Represalia (escudo que devuelve daño) | Postura defensiva (+100 % amenaza, +15 % vida); Último bastión (al bajar del 20 %: −40 % daño 8 s) | Muro de escudo protege también a los aliados cercanos |
| Guerrero | **Campeón** | Golpe mortal (reduce curación recibida); Ejecutar (gran daño por debajo del 25 %) | Maestría con armas (+10 % daño físico); Masacre (matar reinicia Carga) | Tajo golpea dos veces |
| Clérigo | **Sanador** | Círculo de sanación; Himno divino (canalizado) | Ángel guardián (salva a un aliado de un golpe mortal); Gracia mayor (+20 % curación) | Sanar rebota a un segundo aliado |
| Clérigo | **Castigador** | Fuego sagrado (quemadura); Juicio (+15 % daño recibido de todo el grupo) | Ira divina (+15 % daño sagrado); Expiación (el daño cura al aliado más herido) | Destello sagrado atraviesa enemigos |
| Mago | **Piromante** | Columna de llamas (suelo ardiendo); Meteoro | Combustión (+10 % daño a enemigos ardiendo); Fénix (renace con 30 % de vida) | Bola de fuego deja el suelo ardiendo |
| Mago | **Criomante** | Ventisca; Bloque de hielo | Escalofrío (los ralentizados atacan más lento); Corazón helado (congelar reduce recargas) | Nova de escarcha se lanza en el cursor |
| Arquero | **Francotirador** | Disparo apuntado (canalizado, gran daño); Ráfaga de 3 flechas | Punto débil (+daño crítico a distancia); Paciencia (+daño estando quieto) | Disparo cargado atraviesa |
| Arquero | **Montaraz** | Disparo múltiple (abanico de 5); Compañero animal (lobo que ataca y distrae) | Trampero (las trampas se rearman); Superviviente (+10 % vida y velocidad) | Red alcanza a varios enemigos |
| Asesino | **Sombra** | Desvanecer mejorado; Golpe sombrío (teletransporte + golpe crítico) | Asesino nato (+daño a objetivos por debajo del 30 %); Velo (+tiempo de sigilo) | Eviscerar devuelve energía por punto de combo |
| Asesino | **Venenero** | Nube tóxica (área persistente); Contagio (el veneno salta a enemigos cercanos al morir) | Toxicología (el veneno se acumula hasta 10); Sangre corrupta (los envenenados hacen −10 % daño) | Cuchillada aplica veneno siempre |

---

## Anexo B — Guion e historia **[Abierto]**
Se desarrollará conjuntamente: nombres definitivos de zonas y personajes, misiones, jefes y trasfondo de las clases y de su evolución.

---

## Anexo C — Árbol de talentos (círculo inicial)

**Forma:** 46 nodos.
- **Inicio:** un nodo central, gratis.
- **10 radios de 4 nodos:** 5 direcciones puras y 5 híbridas entre direcciones vecinas. Los nodos híbridos dan el bonus principal de sus dos direcciones al 60 % (al 100 % en el notable).
- **Anillos:** el 1.er y el 3.er paso de cada radio se conectan con los de los radios vecinos.
- **Culminantes:** al final de cada radio puro, a 5 puntos del centro.
- **Anillos exteriores:** se añaden con cada rango de clase (§4.6).

| Dirección | Paso 1 | Paso 2 | Paso 3 (notable) | Paso 4 | Culminante |
|---|---|---|---|---|---|
| Poderío | +3 % poder de ataque | +1 % crítico | +4 % poder de ataque, +5 % daño crítico | +2 % daño realizado | +8 % poder de ataque, +10 % daño crítico |
| Celeridad | +3 % velocidad | +1 % esquiva | −3 % recargas, +3 % velocidad | −2 % recargas | −8 % recargas |
| Vitalidad | +1 vida/s | +3 % curación realizada | +1 % robo de vida, +4 % curación recibida | +3 % curación recibida | +8 % curación recibida, +2 % robo de vida |
| Bastión | +4 % armadura | +3 % vida | +2 % bloqueo, −2 % daño recibido | +15 armadura | +8 % vida, −3 % daño recibido |
| Arcano | +3 % poder de hechizos | +4 % recurso máximo | +5 % daño crítico, +4 % poder de hechizos | +5 % regeneración de maná | +8 % poder de hechizos |

---

## Registro de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| 1.x | 2026-11-11 a 2026-11-13 | GDD del prototipo 2D (Phaser, pixel art LPC, navegador). Prototipo publicado hasta la versión 0.5.3: red host-autoritativa, combate, 4 clases con especializaciones, progresión hasta el nivel 30, talentos circulares, objetos y mercader. |
| 2.0 | 2026-11-14 | **Cambio de rumbo:** el juego pasa a **3D vóxel en Godot**, con cámara isométrica, ejecutable para Windows y red P2P con código. **5 clases** (Arquero y Asesino separados). **Sin nivel máximo**: mejora de clase cada 50 niveles (sustituye a las especializaciones), árbol de talentos que crece por anillos y maestrías. **Cambio de clase** diseñado (requisitos abiertos). Hoja de ruta de 8 planes desde cero. |
