---
tags: [decision]
id: D-015
fecha: 2026-11-19
estado: aceptada
---
# D-015 · Vóxel 2× y renovación gráfica en cuatro partes

## Contexto
El Plan 6 quiere dejar atrás el aspecto infantil ([[Estilo gráfico objetivo (Plan 6)]]). Hoy el humanoide mide 49 vóxeles (unos 3,6 cm por vóxel) y todo el arte (381 `.vox`, unas 2.700 líneas en `tools/art/`) está hecho a esa escala.

## Decisión
- **Vóxel 2×:** unos 1,8 cm; el humanoide pasa a 98 vóxeles de alto y la cabeza a unos 20.
- El Plan 6 se divide en **cuatro partes publicables**: 6.1 iluminación, ambientes y opciones; 6.2 humanoide y piezas; 6.3 equipo; 6.4 monstruos, PNJ y ropa que sigue al cuerpo.

## Por qué
- 2× da sitio para cejas, barba con forma, remaches y pliegues, con unas 4 veces más caras por modelo, asumible con 4 jugadores y una docena de monstruos.
- Rehacer los generadores es mucho trabajo; por partes, cada una se prueba y publica sin semanas sin versión jugable. La iluminación va primero porque no depende de los modelos y los modelos nuevos se revisan con la luz final.

## Alternativas consideradas
- **1,5×** (73 vóxeles): poca mejora, seguiría pareciendo «bloque».
- **3×** (147 vóxeles): más cerca de las referencias, pero unas 9 veces más caras y mucho más costoso de dibujar por código.
- **Un único plan grande:** sin versiones intermedias.

## Afecta a
- [[14 Hoja de ruta]]
- [[11 Arte y audio]]
- Plan 6.1 — Iluminación, ambientes y opciones (spec)

---
← [[Índice de decisiones]]
