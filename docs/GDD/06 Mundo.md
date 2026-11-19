---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 6. Mundo

## 6.1 Estructura **[Diseñado]**
- **Zonas:** el mundo está formado por zonas conectadas; cada una es una **escena 3D** construida con `GridMap` (bloques vóxel) y props. Se pasa entre zonas por sus bordes o portales, con una pantalla de carga breve.
- **Varias zonas a la vez:** dentro de una partida los jugadores pueden estar en zonas distintas.
- **Mazmorras:** son **instancias** (cada grupo tiene su copia).
- **Puntos de control** para reaparecer y **reaparición de monstruos** con temporizador.
- **Iluminación:** cada zona elige un **ambiente** de `data/ambiences/` con `"ambience"` en su JSON y coloca antorchas con `"torches"` **[Implementado 0.8.0]**. Ciclo de día y noche opcional por zona (Plan 8); las mazmorras usan luces locales (antorchas) para dar ambiente.

## 6.2 Contenido de la demo **[Diseñado]**
| Zona | Niveles | Contenido |
|---|---|---|
| **Ciudad** (capital) | — | Zona segura: mercaderes, instructor de talentos y de clase, reparador, alijo y personajes con misiones |
| **Bosque** | 1–12 | Cadena de misiones y **mazmorra** con jefe |
| **Desierto** | 12–25 | Cadena de misiones y **mazmorra** con jefe |
| **Cementerio** | 25–40 | Cadena de misiones y **mazmorra** con jefe |
| **Volcán** | 40–60 | Cadena de misiones y **mazmorra** con jefe; prueba de rango al nivel 50 |

- **Crecimiento:** el mundo crece por **capítulos** de unos 50 niveles; cada capítulo añade zonas nuevas y un rango de clase.
- **Historia:** se escribirá a partir de un **guion que se desarrollará conjuntamente** con el equipo (ver [[Anexo B — Historia]]). Hasta entonces, las misiones usan textos provisionales.

## 6.3 Pipeline de contenido **[Diseñado]**
Añadir una zona consiste en aportar:
1. La escena de la zona (`GridMap` + props) con sus marcadores (spawns, PNJ, puntos de control, salidas).
2. Las entradas de monstruos y spawns en `data/`.
3. Las misiones.
4. Los textos.

Sin modificar el código de `sim/`. Es un requisito de arquitectura, porque el juego está pensado para crecer a muchas zonas.

---
← [[00 Índice del GDD|Índice del GDD]]
