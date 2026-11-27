---
tags: [gdd, talentos]
estado: implementado
actualizado: 2026-11-27
---

# Anexo C — Árbol de talentos

Generado por `tools/data/make_talents.mjs` (Plan 8.3g) en `data/talents.json`.

**Forma:** un centro y **7 anillos cerrados** de 10, 20, 30… 70 nodos (281 en total). El nodo *i* del anillo *r* está a `360·i/(10·r)` grados desde arriba. Cada anillo es un círculo (cada nodo enlaza con sus dos vecinos), el anillo 1 entero enlaza con el centro y, en los demás, uno de cada dos nodos enlaza con el más cercano del anillo interior.

**Direcciones** (centradas a 0°, 72°, 144°, 216° y 288°) y sus estadísticas:

| Dirección | Estadísticas |
|---|---|
| Poderío | poder de ataque, crítico, daño crítico, daño realizado |
| Celeridad | velocidad de movimiento, esquiva, recargas |
| Vitalidad | vida por segundo, robo de vida, curación realizada, curación recibida |
| Bastión | armadura (%), vida máxima, bloqueo, armadura plana, daño recibido, amenaza |
| Arcano | poder de hechizos, recurso máximo, regeneración de recurso |

- **Mezcla:** a partir del 40 % del camino hacia la dirección vecina, un nodo da una estadística de cada una al 60 %.
- **Valores:** el del nodo pequeño de antes (por ejemplo +3 % ataque, +1 % crítico, +15 armadura) × `1 + (anillo − 1)/6` (×1 a ×2).
- **Notables:** uno de cada cinco nodos desde el anillo 2: dos estadísticas de su dirección al 100 % (y una de la vecina al 50 % en las fronteras).
- **Culminantes:** en el centro de cada dirección en los anillos 4 y 7: sus dos primeras estadísticas × 2,5.
- **Iconos:** cada nodo usa el de su primera estadística.
- **Rutas:** por clase, 100 nodos elegidos uno a uno entre los comprables según las prioridades de la clase (con un paso de anticipación).
- **Maestrías:** cuando todos los nodos de una dirección están comprados, cada punto extra sube su maestría (rendimientos decrecientes: el rango r vale `valor × r × 100 / (r + 100)`).

---
← [[00 Índice del GDD|Índice del GDD]]
