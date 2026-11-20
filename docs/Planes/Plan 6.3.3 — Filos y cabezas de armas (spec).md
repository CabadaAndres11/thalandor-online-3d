---
tags: [plan, spec]
plan: 6.3.3
fecha: 2026-11-20
estado: implementado
actualizado: 2026-11-20
---
# Plan 6.3.3 — Filos y cabezas de armas: diseño

## Objetivo
Rehacer los filos y las cabezas de todas las armas v2 con el estilo de la referencia del paladín y del martillo ([[Estilo gráfico objetivo (Plan 6)]]). Cada familia debe reconocerse de un vistazo por su silueta, y el nivel de detalle debe ir con el nuevo estilo. Sale como **0.9.3**.

**Por qué:** hoy los filos son planos (2 vóxeles), casi blancos y de un solo tono; hacha, espada y maza se confunden de lejos.

## Fuera de alcance
- Empuñaduras, mangos y pomos: no cambian, salvo donde la cabeza nueva los tape.
- Datos de juego (`bases.json`, daños, alcances), la animación y el agarre.
- Escudos, orbes y tomos (no son filos), salvo que ganen algún ribete.

## Antifines
- Que dos familias se parezcan de lejos.
- Que un nivel no se vea claramente más rico que el anterior.
- Que el arma atraviese la mano o el cuerpo en reposo de forma que se note más que hoy.

## Diseño
1. **Tamaño:** filos y cabezas un **25 % más grandes** (decisión del usuario). Las empuñaduras quedan igual, así que el arma crece hacia la punta.
2. **Grosor y volumen:**
   - Los filos pasan de 2 a 3–5 vóxeles de grosor, con una arista central.
   - Por tonos, desde el centro hacia fuera: núcleo oscuro, cuerpo medio y borde brillante de 1 vóxel.
   - Cada tono lleva textura (2–3 tonos mezclados por vóxel, como el martillo de referencia).
3. **Paleta con contraste:** acero más oscuro (gris azulado) con el borde casi blanco, en lugar del acero claro uniforme de hoy. Ribetes dorados que siguen la forma del filo o de la cabeza.
4. **Siluetas por familia:**

   | Familia | Silueta |
   |---|---|
   | Espada | Hoja con arista, que se ensancha cerca de la guarda y acaba en punta de diamante; guarda ancha con remates |
   | Espada corta | Hoja ancha en hoja de laurel |
   | Daga | Hoja triangular con canal y guarda en cruz |
   | Mandoble | Hoja larga y ancha con ricasso, guarda con alas y pomo grande |
   | Hacha | Hoja de media luna con barba hacia abajo y púa trasera |
   | Hacha a dos manos | Doble media luna con un remate en punta |
   | Maza | Cabeza con 6 aletas radiales y punta |
   | Martillo de guerra | Bloque con caras enmarcadas, púa trasera y gema central |
   | Alabarda | Hoja de hacha, punta de lanza y gancho trasero |
   | Cetro y bastón | Cabezas con jaula, cristal o gema |

   Las armas a distancia y la varita mantienen su forma, pero toman la paleta y los ribetes nuevos.
5. **Por nivel:**
   - **Nivel 1:** hierro, sin oro, filo sencillo.
   - **Nivel 2:** acero, ribetes dorados y una gema roja.
   - **Nivel 3:** acero oscuro, filo con runas que brillan, oro claro, gemas con un vóxel de reflejo, y silueta aún mayor (puntas y alas extra).
6. **Armas únicas** (las 3 de jefe): mismo trato, con su color propio.

## Pruebas
- **`node --test`:**
  - las cabezas y los filos miden al menos un 20 % más que en la 0.9.2;
  - los filos tienen al menos 3 vóxeles de grosor en el centro;
  - cada filo tiene tres tonos (núcleo, cuerpo y borde);
  - las siluetas de las familias se distinguen: su proyección de perfil difiere más de un umbral entre cada par;
  - el tamaño crece con el nivel;
  - la generación es determinista.
- **GUT:** todas las piezas existen y se cargan, y las empuñaduras siguen dentro del puño.
- **Capturas:** las 17 familias por nivel, revisadas antes de cerrar.

## Decisiones tomadas
- Más grandes, un +25 % (usuario).
- Decisiones de Claude:
  - las empuñaduras no cambian;
  - acero más oscuro con borde brillante;
  - las siluetas de la tabla.

## Durante la implementación
- Los filos y las cabezas viven en `tools/art/weapon_heads_v2.mjs`. Los tonos nuevos de acero (índices 110 a 118) son propios de las armas v2, así que la paleta compartida con el v1 no cambia.
- El test de la 6.3 que fijaba la longitud de las armas respecto al v1 pasa de un tope de +25 % a uno de +50 %.
- Las armas a distancia, la varita, el bastón y las de mano izquierda mantienen sus colores de la 6.3: el acero nuevo solo va en los filos y las cabezas rehechos. Así el escudo no cambia y la punta de la ballesta de nivel 3 sigue brillando.
- El hierro del nivel 1 tiene su propia textura, para que el núcleo, el cuerpo y el borde no se mezclen.
- Hoja de capturas por nivel: `tests/helpers/render_weapons.gd`, en `docs/Adjuntos/Plan 6.3.3/`.

---
← [[Planes]]
