---
tags: [plan, spec]
plan: 6.4.4
fecha: 2026-11-20
estado: implementado
actualizado: 2026-11-20
---
# Plan 6.4.4 — Correcciones de la prueba 0.9.6: diseño

## Objetivo
Corregir los 5 puntos que encontró el usuario al probar la 0.9.6. Sale como **0.9.7**.

| # | Problema | Causa | Arreglo |
|---|---|---|---|
| 1 | Sin regeneración de maná en combate | `regen_in_combat_mult` 0 en mago y clérigo | En combate el maná se recupera al **50 %** (usuario). La pasiva *Meditación* del clérigo sube al 100 %, para que siga valiendo la pena |
| 2 | Cada punto de atributo debe notarse | Valores por punto muy bajos y rendimiento decreciente desde 200 | **Efecto visible por punto** (usuario), ver la tabla siguiente. Sin rendimiento decreciente. Los puntos automáticos por nivel bajan de 5 a 2 en cada atributo, para que los monstruos sigan siendo un reto y cuenten los puntos que reparte el jugador |
| 3 | La agilidad debe subir la velocidad de movimiento | No lo hacía | **+0,05 % de velocidad por punto** de agilidad, con un máximo de +30 % |
| 4 | Quitar la cota gris del costado de los jabalíes | Las placas de hierro con remaches de los flancos | Se quitan; el jabalí conserva collar, cresta y colmillos |
| 5 | Los básicos del arquero no deben gastar | El disparo cargado cuesta 15 de concentración, y con ballesta todos los disparos son cargados | La carga deja de costar |

| Por punto | Antes | Ahora |
|---|---|---|
| Fuerza (o el atributo de ataque de la clase) | +0,5 ataque | **+1 ataque** |
| Intelecto | +0,5 poder mágico, +2 maná | **+1 poder mágico, +4 maná** |
| Aguante | +5 vida | **+10 vida** |
| Agilidad | +0,05 % crítico, +0,03 % esquiva | **+0,1 % crítico, +0,06 % esquiva, +0,05 % velocidad** |
| Espíritu | +0,05 vida/s, +0,03 maná/s | **+0,1 vida/s, +0,06 maná/s** |
| Fuerza (bloqueo, con escudo) | +0,2 % | **+0,4 %** |

Los topes de crítico, esquiva y bloqueo no cambian.

## Pruebas (GUT)
- El maná sube en combate al 50 % y, con *Meditación*, al 100 %.
- Un punto de cada atributo da exactamente lo de la tabla, también por encima de 200 puntos.
- La agilidad sube la velocidad, con su tope.
- El jabalí no lleva placas.
- El disparo cargado y el de ballesta no gastan concentración.
- La suite completa pasa.

## Decisiones tomadas
- Del usuario:
  - el maná se recupera al 50 % en combate;
  - cada punto tiene un efecto visible.
- De Claude:
  - los valores de la tabla;
  - los puntos automáticos bajan a 2 por nivel;
  - *Meditación* sube al 100 %;
  - tope de velocidad del +30 %.

---
← [[Planes]]
