---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 9. Interfaz y flujo

## 9.1 Flujo **[Diseñado]**
1. **Pantalla de título.**
2. **Selección de personaje:** cada tarjeta muestra el **modelo 3D del personaje con su equipo**; opciones de crear, borrar, exportar e importar personajes.
3. **Jugar:** entra al mundo como host de su propia partida.
   - **"Abrir grupo"** está disponible en cualquier momento y genera un código.
   - **"Unirse a un amigo":** desde la selección de personaje, introduciendo el código.
   - **Al unirse**, el invitado aparece en su última ubicación guardada.
   - **"Ir con el grupo"** teletransporta junto al líder, solo fuera de combate.

## 9.2 HUD **[Diseñado]**
- Vida, recurso de clase, barra de experiencia y nivel.
- Barra de habilidades en **casillas cuadradas con icono** (clic izquierdo, clic derecho, 1–4, Espacio, Q y R), con barrido de recarga, tecla y casilla atenuada sin recurso.
- Indicadores propios de clase (puntos de combo del Asesino, carga del disparo del Arquero).
- Marcos de grupo con la vida y el recurso de los compañeros.
- Minimapa y seguimiento de misiones.
- Números de daño flotantes; nombre y vida sobre personajes y enemigos.
- **Textos nítidos:** los textos sobre el mundo (nombres, botín) se dibujan como interfaz (`Label` en pantalla o `Label3D` con fuente de alta resolución), nunca escalados de forma que se vean borrosos.

## 9.3 Ventanas **[Diseñado]**
- **Norma:** **ninguna ventana puede necesitar scroll** para verse entera (en una pantalla de 1280×720). Si una ventana se llena, su contenido se reparte en otra ventana con su propia tecla.
- **Personaje (C):** atributos y estadísticas a la izquierda; a la derecha, el equipo alrededor de un **modelo 3D en vivo** del personaje (un `SubViewport` que gira lentamente) con lo que lleva puesto.
- **Inventario (I):** cuadrícula de 30 casillas y oro; se puede ver a la vez que la ventana de Personaje.
- **Habilidades (K):** clase y mejoras de clase, habilidades desbloqueadas, asignación de la barra y pasivas con su descripción.
- **Talentos (N):** el árbol circular dibujado tal cual, con zoom si crece.
- **Misiones (J), Mapa (M), Mercader** y **Menú (Esc)** (en solitario pausa el mundo; en grupo la partida sigue).
- **Opciones:** controles, volumen, gráficos y pantalla completa.

## 9.4 Social **[Diseñado]**
- Chat de texto de grupo. Para la voz se usa Discord.

---
← [[00 Índice del GDD|Índice del GDD]]
