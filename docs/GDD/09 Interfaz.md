---
tags: [gdd]
estado: en curso
actualizado: 2026-11-16
---

# 9. Interfaz y flujo

## 9.1 Flujo **[En curso]** (título, selección y creación de personaje, Jugar, Abrir grupo y Unirse implementados en la 0.2.0; falta la última ubicación y "Ir con el grupo")
1. **Pantalla de título.**
2. **Selección de personaje:** lista de hasta 8 personajes con el **modelo 3D** del elegido girando; opciones de crear, borrar (con confirmación), exportar e importar personajes. **[Implementado]**
3. **Jugar:** entra al mundo como host de su propia partida.
   - **"Abrir grupo"** está disponible en cualquier momento y genera un código.
   - **"Unirse a un amigo":** desde la selección de personaje, introduciendo el código.
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

## 9.3 Ventanas **[En curso]** (Habilidades (K) implementada en la 0.4.0; en la 0.4.1 muestra también CI y CD y un detalle calculado de cada habilidad; el resto está diseñado)
- **Norma:** **ninguna ventana puede necesitar scroll** para verse entera (en una pantalla de 1280×720). Si una ventana se llena, su contenido se reparte en otra ventana con su propia tecla.
- **Personaje (C):** atributos y estadísticas a la izquierda; a la derecha, el equipo alrededor de un **modelo 3D en vivo** del personaje (un `SubViewport` que gira lentamente) con lo que lleva puesto.
- **Inventario (I):** cuadrícula de 30 casillas y oro; se puede ver a la vez que la ventana de Personaje.
- **Habilidades (K):** clase y mejoras de clase, habilidades desbloqueadas, asignación de la barra y pasivas con su descripción.
- **Talentos (N):** el árbol circular dibujado tal cual, con zoom si crece.
- **Misiones (J), Mapa (M), Mercader** y **Menú (Esc)** (en solitario pausa el mundo; en grupo la partida sigue).
- **Opciones:** controles, volumen, gráficos y pantalla completa.

## 9.4 Social **[Implementado]**
- Chat de texto de grupo. Para la voz se usa Discord.

## Plan 4 (0.6.0) **[Implementado]**
Barra de experiencia bajo las habilidades, nivel junto a los nombres, ventana de personaje (**C**), árbol de talentos (**T**), menú de Brann con reinicios, nivel de la arena y mejora de clase. Las ventanas C, T y K se cierran con Esc y con su tecla, abrir una cierra las otras y bloquean el ataque con el ratón pero no el movimiento. Ninguna necesita scroll a 1280×720.

---
← [[00 Índice del GDD|Índice del GDD]]


## Estilo holográfico (0.6.0)
Paneles azules translúcidos con borde celeste fino y brillo, título centrado, líneas separadoras finas y dorado para lo destacado (clase, atributos recomendados, avisos). Se define en `ui/holo_theme.gd` y se aplica a todas las ventanas. Ventana C: modelo 3D entre ocho huecos de objetos (vacíos hasta que existan). Ventana K: habilidades en listas, sin huecos fijos.

Un brillo azul se desplaza despacio por cada ventana (shader `assets/ui/holo_shine.gdshader`). La barra de habilidades tiene 9 huecos (teclas 1–9); los nombres sobre personajes, PNJ y monstruos tienen tamaño de mundo y se encogen con el zoom.
