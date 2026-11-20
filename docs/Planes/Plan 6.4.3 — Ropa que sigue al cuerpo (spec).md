---
tags: [plan, spec]
plan: 6.4.3
fecha: 2026-11-20
estado: en curso
actualizado: 2026-11-20
---
# Plan 6.4.3 — Ropa que sigue al cuerpo: diseño

## Objetivo
Última parte del Plan 6.4: que túnicas, faldas, tabardos, capas, capuchas largas y melenas dejen de ser rígidas. Sale como **0.9.6**. El usuario lo probará todo junto.

**Por qué:** hoy las piernas atraviesan las túnicas al andar y las capas no se mueven.

## Fuera de alcance
- Simulación física de tela: colisiones, viento, tela que choca con el suelo.
- Cambiar las piezas vóxel o su arte.

## Diseño
1. **Shader de tela `game/characters/cloth.gdshader`** (y su variante sin sombreado para los vóxeles que brillan).
   - Deforma los vértices de una pieza en la GPU según unos parámetros por instancia (`instance uniform`).
   - Pinta igual que el material vóxel de siempre: color de vértice en sRGB y rugosidad 1.
2. **Modo falda.** Lo usan las piezas que caen por debajo de la cadera:
   - las faldas del equipo, que van en la parte `hips`;
   - las túnicas y tabardos de la parte `torso`.

   Cada vértice por debajo de la cintura gira alrededor de la cadera de su lado, con el ángulo de esa pierna. La izquierda sigue a la pierna izquierda, la derecha a la derecha y el centro mezcla las dos. El efecto crece de la cintura hasta la rodilla.
3. **Modo capa.** Lo usan las capas del equipo (`*_cape`), las capuchas con capa (`hood_archer`, `hood_cleric`) y la melena de Vaelthar.
   - La parte trasera por debajo del ancla (hombros o nuca) se inclina hacia atrás al correr.
   - Se balancea un poco en reposo.
   - Un muelle suaviza el movimiento para que la tela llegue con retraso.
4. **`HumanRig`:**
   - decide el modo de cada pieza al montarla;
   - cada fotograma calcula, en el espacio de la pieza, las caderas, el ángulo de cada pierna y el ancla con su inclinación;
   - una función de referencia en GDScript hace la misma deformación que el shader, para los tests.
5. **Para todos:** jugadores, PNJ y enemigos humanoides. Como Vaelthar lleva las piernas ocultas, su túnica sigue el paso igual.

## Pruebas (GUT)
- Las piezas largas usan el material de tela y las cortas no.
- Con la pierna izquierda adelantada, un punto bajo de la falda izquierda va hacia delante y uno de la derecha no tanto.
- La cintura y el pecho no se mueven.
- Al correr, la punta de la capa se va hacia atrás, y en reposo vuelve.
- Los parámetros siguen a la pose: el ángulo de la pierna es el de la pierna.
- La suite completa pasa.

## Decisiones tomadas
- Seguir el 6.4 sin parar; el usuario lo prueba todo junto.
- Decisiones de Claude:
  - deformación en el shader, sin esqueleto ni física;
  - qué piezas son falda y cuáles capa.

---
← [[Planes]]
