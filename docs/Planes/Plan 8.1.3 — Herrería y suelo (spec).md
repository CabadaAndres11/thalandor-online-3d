---
tags: [plan, spec]
plan: 8.1.3
fecha: 2026-11-23
estado: implementado
actualizado: 2026-11-23
---
# Plan 8.1.3 — Herrería y suelo: diseño

## Objetivo
Dar a la herrería de Aelhest un estilo propio, con hornos dentro y un cobertizo abierto al costado, y mejorar la textura del suelo con detalles vóxel. Las referencias son las imágenes del usuario: una herrería de maqueta y la escena de *Voxile*, adaptadas a nuestro estilo. Sale como **0.11.3**.

## Herrería
- **Edificio:**
  - muros de piedra con entramado de madera (no de yeso);
  - tejado de tablas;
  - chimenea de ladrillo con remate de metal.
- **Dentro:**
  - dos hornos de ladrillo con brasas que dan luz;
  - fuelles;
  - estante de herramientas;
  - barril de temple.
- **Cobertizo abierto** al costado (`forge_shed`):
  - postes de madera y tejado de tablas;
  - suelo empedrado;
  - muro de ladrillo al fondo y en un lado;
  - fragua con brasas y luz;
  - yunque sobre un tocón;
  - banco de trabajo;
  - barril de agua.
- El cobertizo es una casa más: se abre al entrar, y su interior y su frente se pisan.
- **Brann** está en el cobertizo. La entrada por defecto de la aldea queda delante.

## Suelo
- **Textura:**
  - Cada casilla son 4×4 píxeles de tres tonos de su tipo, en manchas.
  - En el borde entre tipos, unos pocos píxeles toman el color del vecino, para que no haya líneas rectas.
  - Una sola textura por zona, con filtrado de píxel. El agua sigue aparte, más baja.
- **Detalles vóxel**, generados por la vista con una semilla por casilla (no son datos de la simulación):
  - sobre hierba: matas de hierba y flores azules, blancas y amarillas;
  - sobre tierra y caminos: piedrecitas.
- **Rendimiento de los detalles:**
  - van por trozos de 16×16, como las piezas;
  - no dan sombra y solo se ven a menos de 30 m;
  - en calidad baja, menos de la mitad.
- El suelo sigue plano.

## Pruebas (GUT y Node)
- **Cobertizo:**
  - tiene sus cuatro partes;
  - su interior se pisa y se alcanza desde fuera en las cuatro rotaciones;
  - la fragua da luz.
- **Herrería:** dos hornos con luz.
- **Aldea:** Brann se alcanza y está a menos de 2,5 m de la entrada por defecto, y no hay solapes con caminos ni piezas.
- **Suelo:**
  - la textura mide la zona × 4;
  - un píxel de camino tiene el color de camino;
  - hay detalles en la hierba y ninguno en el agua ni en la linde;
  - en calidad baja hay menos.
- La suite completa pasa.

## Tareas
1. Herrería de piedra y cobertizo en `make_world.mjs`, con sus tests de Node.
2. La aldea con el cobertizo, Brann y la entrada.
3. La textura del suelo en `ZoneView`.
4. Las piezas de detalle y su siembra.
5. Capturas de carga nuevas, versión 0.11.3, documentación y subida.

---
← [[Planes]]
