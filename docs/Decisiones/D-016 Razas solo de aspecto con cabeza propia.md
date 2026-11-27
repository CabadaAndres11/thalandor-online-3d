---
tags: [decision]
id: D-016
fecha: 2026-11-21
estado: aceptada
---
# D-016 · Razas solo de aspecto con cabeza propia

## Contexto
El Plan 7 añade razas seleccionables. Faltaba decidir cuáles, si dan bonificaciones y cómo se construyen sobre el humanoide v2. A ese humanoide se enganchan más de cien piezas de equipo por hueso.

## Decisión
- **Cinco razas:** humanos, elfos, enanos, ogros y hombres lagarto.
- **Solo aspecto:** no cambian atributos, clases, colisión, velocidad ni cámara.
- **Los enanos son más bajos** que humanos y elfos.
- **Un cuerpo compartido** con proporciones por raza (`data/characters/races.json`). Las piezas de cada parte crecen o encogen con ella, y el pivote de cada articulación se mueve con la parte de la que cuelga, así que los pies siguen en el suelo.
- **Cabeza propia** para el ogro (mandíbula, colmillos, ceja gruesa) y el lagarto (hocico, escamas, ojos de reptil). El lagarto lleva además una cola como pieza. Elfos y enanos usan la cabeza humana con piezas: orejas largas y nariz grande.
- **Encaje del equipo:** las piezas de la cabeza se ajustan a las cabezas propias con `head_fit` y, si hace falta, con un ajuste por pieza (`piece_fit`). Las orejas élficas se ocultan con lo que oculta el pelo corto (capuchas y yelmos cerrados).

## Por qué
- Que la raza dé aspecto y no ventajas mantiene el equilibrio de las clases.
- Un cuerpo compartido evita ajustar todo el equipo a cinco modelos distintos.
- Las cabezas propias evitan que el ogro y el lagarto parezcan humanos con añadidos.

## Alternativas consideradas
- **Un cuerpo con piezas pegadas para todas las razas:** el lagarto y el ogro quedaban falsos.
- **Un modelo completo por raza:** obliga a ajustar más de cien piezas de equipo a cinco cuerpos, y otra vez con cada objeto nuevo.

## Afecta a
- [[04 Personajes y progresión]]
- [[11 Arte y audio]]
- Plan 7 — Identidad y creación de personaje (spec)

---
← [[Índice de decisiones]]
