---
tags: [gdd]
estado: en curso
actualizado: 2026-11-22
---

# 9. Interfaz y flujo

## 9.1 Flujo **[En curso]** (título, selección y creación de personaje, Jugar, Abrir grupo y Unirse implementados en la 0.2.0; falta la última ubicación y "Ir con el grupo")
1. **Pantalla de título [Implementado 0.10.0]:** el logo sobre una escena vóxel en vivo: cultistas orando alrededor del altar del Sol Negro, de noche, con braseros, velas y brasas, mientras la cámara gira despacio. **Jugar** va abajo a la izquierda; arriba a la derecha están los iconos de Ajustes, Créditos y Salir; la versión, abajo a la derecha. Las tres pantallas de menú usan el tema de **piedra, oro y rojo** del logo (`StoneTheme`); las ventanas del juego siguen en azul hasta el Plan 11. Los botones y paneles de los menús tienen **luz dinámica** (`MenuFx`, `assets/ui/ember_glow.gdshader`): sus bordes se encienden al pasar el ratón, les cruzan destellos de luz y Jugar respira.
- **Juego en grupo** **[Implementado 0.11.0]**: hasta terminar la defensa de la aldea (el tutorial), **Abrir grupo** y **Unirse a un grupo** están desactivados y el anfitrión rechaza a quien no la ha terminado.
- **Mazmorras** **[Implementado 0.11.0]**: en su puerta, una ventana para elegir el nivel; entre zonas, una pantalla de carga con el nombre de la zona.
2. **Selección de personaje:** lista de hasta 8 personajes (nombre, raza, clase y nivel) en un panel de piedra; el elegido aparece **delante del altar**, en la misma escena; opciones de crear, borrar (con confirmación), exportar e importar personajes. **[Implementado]**
3. **Jugar:** entra al mundo como host de su propia partida.
   - **"Abrir grupo"** está disponible en cualquier momento y genera un código.
   - **"Unirse a un grupo"** **[0.11.1]**: desde el menú de pausa, con el código; guarda el personaje, deja la partida en solitario y entra en la del amigo con ese mismo personaje. La selección de personaje ya solo tiene Jugar.
   - **Al unirse**, el invitado aparece en su última ubicación guardada.
   - **"Ir con el grupo"** teletransporta junto al líder, solo fuera de combate.

## 9.2 HUD **[Implementado]** (0.4.0: vida, recurso, casillas con recarga, combos, carga, barra de jefe con su fase, marcos de aliados, cuenta atrás de derribo y barra de levantar. La experiencia y el nivel llegan en el Plan 4; las pociones en el 5; el minimapa y las misiones en el 6; los marcos completos en el 7)
- Vida, recurso de clase, barra de experiencia y nivel.
- Barra de habilidades en **casillas cuadradas con icono** (clic izquierdo, clic derecho, 1–4, Espacio, Q y R), con barrido de recarga, tecla y casilla atenuada sin recurso.
- Indicadores propios de clase (puntos de combo del Asesino, carga del disparo del Arquero).
- Marcos de grupo con la vida y el recurso de los compañeros.
- Minimapa y seguimiento de misiones.
- Números de daño flotantes; nombre y vida sobre personajes y enemigos.
- **Textos nítidos:** los textos sobre el mundo (nombres, botín) se dibujan como interfaz (`Label` en pantalla o `Label3D` con fuente de alta resolución), nunca escalados de forma que se vean borrosos.

## Barra de iconos, mapa y minimapa (0.11.1) **[Implementado]**
- **Barra de iconos** arriba a la derecha: Personaje (C), Bolsa (I), Habilidades (K), Talentos (T), Misiones (J, atenuado hasta el Plan 8.2), Mapa (M) y Menú (Esc). Cada icono muestra su tecla, brilla al pasar el ratón y se queda encendido con su ventana abierta.
- **Mapa (M):** la zona entera sin scroll, dibujada desde sus datos, con marcas para ti (flecha), tu grupo, los PNJ con su nombre, las salidas con su destino y las puertas de mazmorra, y una leyenda.
- **Minimapa:** cuadrado de 180 px bajo la barra, centrado en el jugador y girado con la cámara, con la N en el borde y el nombre de la zona. Se puede quitar en Ajustes (Minimapa).
- **Bolsa:** botón **Ordenar** (por hueco, rareza, nivel y nombre; junta las pilas; no toca lo equipado).
- **Elección de clase:** la vista previa lleva el equipo inicial real de la clase.

## 9.3 Ventanas **[En curso]** (Habilidades (K) implementada en la 0.4.0; en la 0.4.1 muestra también CI y CD y un detalle calculado de cada habilidad; el resto está diseñado)
- **Norma:** **ninguna ventana puede necesitar scroll** para verse entera (en una pantalla de 1280×720). Si una ventana se llena, su contenido se reparte en otra ventana con su propia tecla.
- **Personaje (C):** atributos y estadísticas a la izquierda; a la derecha, el equipo alrededor de un **modelo 3D en vivo** del personaje (un `SubViewport` que gira lentamente) con lo que lleva puesto.
- **Inventario (I):** cuadrícula de 30 casillas y oro; se puede ver a la vez que la ventana de Personaje.
- **Habilidades (K):** clase y mejoras de clase, habilidades desbloqueadas, asignación de la barra y pasivas con su descripción.
- **Talentos (N):** el árbol circular dibujado tal cual, con zoom si crece.
- **Misiones (J), Mapa (M), Mercader** y **Menú (Esc)** (en solitario pausa el mundo; en grupo la partida sigue).
- **Opciones [Implementado 0.8.0]:** ventana desde el título y el menú de pausa (Esc) con dos pestañas: **Vídeo** (calidad Baja/Media/Alta, escala de resolución del 50 al 100 %, pantalla completa, VSync, límite de FPS) y **Sonido** (General, Música, Efectos, Interfaz y silenciar). Se aplica al momento y se guarda al cerrar. Reasignar controles queda para el [[14 Hoja de ruta|Plan 11]].

## 9.4 Social **[Implementado]**
- Chat de texto de grupo. Para la voz se usa Discord.

## Plan 4 (0.6.0) **[Implementado]**
Barra de experiencia bajo las habilidades, nivel junto a los nombres, ventana de personaje (**C**), árbol de talentos (**T**), menú de Brann con reinicios, nivel de la arena y mejora de clase. Las ventanas C, T y K se cierran con Esc y con su tecla, abrir una cierra las otras y bloquean el ataque con el ratón pero no el movimiento. Ninguna necesita scroll a 1280×720.

## Plan 5 (0.7.0) **[Implementado]**
Inventario (**I**) de 5 × 6 casillas y el oro, acoplado a la derecha: la ventana C y la del mercader se apartan para caber a su lado a 1280×720. Clic derecho equipa o bebe; en el mercader, vende. Tooltips con nombre en el color de la rareza, estadísticas, durabilidad, valor y la comparación con lo equipado (verde mejor, rojo peor). Ventana C con **11 huecos** alrededor del modelo vestido con el equipo; clic derecho desequipa. Ventana del mercader con pestañas *Comprar* y *Vender y reparar*. HUD con las pociones (**Q** vida, **R** recurso), su cantidad y la recarga compartida, y el aviso *¡Reparar!*. Botín con haz de luz y nombre de color en el suelo; oro como número dorado.

---
← [[00 Índice del GDD|Índice del GDD]]


## Estilo holográfico (0.6.0)
Paneles azules translúcidos con borde celeste fino y brillo, título centrado, líneas separadoras finas y dorado para lo destacado (clase, atributos recomendados, avisos). Se define en `ui/holo_theme.gd` y se aplica a todas las ventanas. Ventana C: modelo 3D entre ocho huecos de objetos (vacíos hasta que existan). Ventana K: habilidades en listas, sin huecos fijos.

Un brillo azul se desplaza despacio por cada ventana (shader `assets/ui/holo_shine.gdshader`). La barra de habilidades tiene 9 huecos (teclas 1–9); los nombres sobre personajes, PNJ y monstruos tienen tamaño de mundo y se encogen con el zoom.

## Efectos de magia (0.6.0)
Los hechizos usan modelos voxel creados en código. Arcano: prisma morado y pentagrama en el suelo. Fuego: bola de llamas y suelo ardiendo. Hielo: sin proyectil, estacas que brotan del suelo y crecen hacia el final, remate grande, nieve y cascarón de hielo en los congelados. Los hechizos con tiempo de lanzamiento muestran una barra en el HUD y una esfera que se forma y brilla delante del personaje.

## Combate cuerpo a cuerpo y reacciones (0.6.0)
Cada golpe del arma dibuja un corte (`game/slash_fx.gd`, shader `assets/fx/slash.gdshader`): se graban los puntos de la hoja durante el recorrido y una textura de corte con máscara aparece y se desvanece con el movimiento. Todo el cuerpo cambia de postura en el ataque (cadera, torso, piernas, brazo libre, avance). Los enemigos destellan en blanco, sangran y retroceden un poco al recibir daño.
