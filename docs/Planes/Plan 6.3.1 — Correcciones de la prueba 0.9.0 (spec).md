---
tags: [plan, spec]
plan: 6.3.1
fecha: 2026-11-20
estado: diseñado
actualizado: 2026-11-20
---
# Plan 6.3.1 — Correcciones de la prueba 0.9.0: diseño

## Objetivo
Corregir los 9 puntos de [[Correcciones de la prueba 0.9.0]] antes del Plan 6.4. Sale como **0.9.1**, junto con la 0.9.0.

## Fuera de alcance
- Cambios de reglas de combate que no estén en la lista.
- Física de ropa y monstruos (6.4).

## Antifines
- Que algo cambie la red o los guardados de forma incompatible.
- Que una ventana necesite scroll a 1280×720.

## Diseño por punto

1. **Objetos en el suelo.**
   - Causa: `LootView` solo dibuja un haz de luz y el nombre.
   - Arreglo: añade el modelo vóxel del objeto (las mismas piezas que su icono) tumbado en el suelo y girando despacio sobre el haz.
   - Las pociones y los objetos sin modelo usan un saquito vóxel.
2. **Fondo rojo en lo que no puedes equipar.**
   - `ItemSlot` pinta el fondo de rojo translúcido cuando el objeto no es consumible y se cumple una de estas dos cosas:
     - tu clase no puede usarlo (`ItemDB.can_use`);
     - su nivel supera el tuyo.
   - Vale para la bolsa, el comerciante y los tooltips.
3. **Modelo de anillos y amuletos.**
   - Los bases de joyería tienen `look: []`, por eso no tienen icono.
   - Nuevo generador de joyas v2: un anillo y un amuleto por tramo, cada vez más ricos (oro, gema con brillo en tramo 3).
   - Van en un campo nuevo `model` de `bases.json`. Lo usan el icono y el objeto en el suelo, pero **no** se ve en el personaje.
4. **Regeneración de vida fuera de combate.**
   - Hoy solo regenera el atributo espíritu (`hp_regen`, muy poco).
   - Se añade una regeneración base fuera de combate (`in_combat_s`, 5 s) del **2 % de la vida máxima por segundo**, que se suma a la de espíritu.
   - Es un dato en `balance.json` (`out_of_combat_hp_pct`).
5. **Efectos del clérigo.** Nuevos efectos vóxel dorados con cruces y ángeles:
   - *Castigo:* cruz dorada que gira como proyectil.
   - *Sanación* y *Renovar:* cruz que sube sobre el objetivo, con plumas.
   - *Escudo:* alas de ángel que envuelven al objetivo un instante.
   - *Nova sagrada:* cruces que salen en anillo.
   - *Purificar:* columna de luz.
   - *Resurrección:* ángel vóxel que baja sobre el caído.
   - *Círculo de sanación* y *Consagración:* círculo en el suelo con una cruz dentro.
   - *Himno divino:* alas y halo sobre el clérigo.
   - *Golpe del cruzado:* cruz brillante en el impacto.
6. **Templario con animación cuerpo a cuerpo.**
   - Causa: el cliente elige la animación con la habilidad sin evolucionar, así que el *Castigo* del templario sigue usando `cast`.
   - Arreglo: el cliente usa `AbilityDB.resolved()` con la mejora del jugador.
7. **Combo cuerpo a cuerpo.**
   - Las tres animaciones del ataque básico con armas de filo o contundentes (`melee` a una mano y `heavy` a dos manos) pasan a ser, en orden:
     1. tajo lateral hacia la izquierda;
     2. tajo lateral hacia la derecha;
     3. tajo descendente.
   - Las lanzas (`thrust`) y las dagas (`stab`) conservan sus combos.
8. **No deja vender.** Causas:
   - Los objetos baratos de nivel 1 valen 0 al venderlos y la venta se rechaza en silencio. Arreglo: precio mínimo de 1 oro.
   - Al borde del radio del comerciante, el anfitrión puede verte fuera. Arreglo: medio metro de margen para comerciar.
   - Si la venta se rechaza (en combate, lejos…), sale un aviso en el chat.
9. **Agarre a dos manos.** La mano izquierda se coloca en el mango, por debajo de la derecha, con cinemática inversa de dos huesos (brazo y antebrazo). Esto se aplica:
   - a las armas `two_hand` (mandoble, hacha y maza a dos manos) y `polearm` (alabarda, lanza);
   - tanto en reposo como durante los ataques.

## Pruebas
- **GUT:**
  - piezas del objeto en el suelo;
  - fondo rojo según clase y nivel;
  - joyas con `model` e icono;
  - regeneración (sube fuera de combate y no dentro);
  - templario con anim `melee`;
  - orden del combo (izquierda, derecha y descendente, por la rotación del torso);
  - venta de un objeto de nivel 1 y aviso de rechazo;
  - mano izquierda a menos de 6 cm del mango en reposo y a mitad de cada golpe.
- **`node --test`:** joyas deterministas y con tamaño creciente por tramo.
- Capturas de los efectos del clérigo, del agarre y del suelo.

## Decisiones tomadas
Todas son decisiones de Claude, pendientes de tu visto bueno:
- 2 %/s de regeneración;
- el combo solo cambia `melee` y `heavy`;
- un saquito para las pociones en el suelo;
- 0.9.1.

---
← [[Planes]]
