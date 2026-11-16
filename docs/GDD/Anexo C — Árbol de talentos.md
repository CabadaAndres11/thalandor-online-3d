---
tags: [gdd, talentos]
estado: implementado
actualizado: 2026-11-16
---

# Anexo C — Árbol de talentos

**Forma:** 46 nodos.
- **Inicio:** un nodo central, gratis.
- **10 radios de 4 nodos:** 5 direcciones puras y 5 híbridas entre direcciones vecinas. Los nodos híbridos dan el bonus principal de sus dos direcciones al 60 % (al 100 % en el notable).
- **Anillos:** el 1.er y el 3.er paso de cada radio se conectan con los de los radios vecinos.
- **Culminantes:** al final de cada radio puro, a 5 puntos del centro.
- **Anillos exteriores:** se añaden con cada rango de clase ([[04 Personajes y progresión|§4.6]]).

| Dirección | Paso 1 | Paso 2 | Paso 3 (notable) | Paso 4 | Culminante |
|---|---|---|---|---|---|
| Poderío | +3 % poder de ataque | +1 % crítico | +4 % poder de ataque, +5 % daño crítico | +2 % daño realizado | +8 % poder de ataque, +10 % daño crítico |
| Celeridad | +3 % velocidad | +1 % esquiva | −3 % recargas, +3 % velocidad | −2 % recargas | −8 % recargas |
| Vitalidad | +1 vida/s | +3 % curación realizada | +1 % robo de vida, +4 % curación recibida | +3 % curación recibida | +8 % curación recibida, +2 % robo de vida |
| Bastión | +4 % armadura | +3 % vida | +2 % bloqueo, −2 % daño recibido | +15 armadura | +8 % vida, −3 % daño recibido |
| Arcano | +3 % poder de hechizos | +4 % recurso máximo | +5 % daño crítico, +4 % poder de hechizos | +5 % regeneración de maná | +8 % poder de hechizos |


## Anillo exterior (con mejora de clase)

20 nodos más, dos por radio (`<radio>_5`, `<radio>_6`); solo se pueden comprar con una mejora del nivel 50 elegida.
- **Paso 5:** el bonus del paso 1 del radio × 1,5. Los pasos 5 de radios vecinos se enlazan en anillo.
- **Paso 6:** el bonus del notable (radios híbridos) o del culminante (radios puros) × 1,5. En los puros es un segundo culminante.
- Se llega a él desde el final del radio (paso 4 o culminante). Al reiniciar la mejora se pierden estos nodos y se devuelven sus puntos.
- **Maestrías:** cuando todos los nodos disponibles de una dirección están comprados, cada punto extra sube su maestría (rendimientos decrecientes: el rango r vale `valor × r × 100 / (r + 100)`).
- Datos: `data/talents.json`, generado con `tools/data/make_talents.mjs`.

---
← [[00 Índice del GDD|Índice del GDD]]
