---
tags: [plan, spec]
plan: 6.3.2
fecha: 2026-11-20
estado: diseñado
actualizado: 2026-11-20
---
# Plan 6.3.2 — Correcciones de la prueba 0.9.1: diseño

## Objetivo
Corregir los 10 puntos de [[Correcciones de la prueba 0.9.1]] antes del Plan 6.4. Sale como **0.9.2**, junto con la 0.9.0 y la 0.9.1, tras tu prueba.

## Antifines
- Que cambie el formato de red o de guardado de forma incompatible.
- Que la definitiva del clérigo haga invulnerable a todo el grupo.

## Diseño por punto
1. **Vista previa con equipo.** La selección de personaje pasa a `CharacterPreview` el equipo visible guardado (`Inventory.visible_bases()` de su ficha), como ya hace la ventana de personaje.
2. **Ataques básicos cuerpo a cuerpo más rápidos (todas las clases).** El daño por golpe baja en proporción para que el daño por segundo no cambie. Las animaciones se ajustan para caber en la nueva recarga.

   | Ataque | Antes | Ahora |
   |---|---|---|
   | Guerrero (*Tajo*) | 0,6 s | 0,45 s |
   | Asesino (*Puñalada*) | 0,5 s | 0,4 s |
   | Aldeano | 0,7 s | 0,55 s |
   | Templario (*Castigo* evolucionado) | 0,8 s | 0,6 s |
   | Armas a dos manos (multiplicador) | ×1,4 | ×1,25 |
   | Armas de asta (multiplicador) | ×1,2 | ×1,1 |
3. **Brazo que tiembla a dos manos.**
   - Causa: el brazo derecho se cierra hacia el pecho en saltos fijos de 0,08 rad.
   - Arreglo: el ángulo se calcula de forma continua (búsqueda binaria hasta que el mango queda a tiro), así no hay saltos entre fotogramas.
   - Test: la mano no se mueve más de 2 cm entre dos fotogramas seguidos de 1/60 s a lo largo de todo el combo.
4. **Golpes más exagerados.**
   - Preparación más amplia: torso girado ~70°, caderas, peso atrás.
   - Paso largo con hundimiento del cuerpo y recuperación más lenta.
   - El brazo libre equilibra el golpe.
   - Vale para el combo a una y a dos manos y para el golpe descendente.
5. **Objetos de la bolsa que no se venden (error grave).**
   - Causa: al recibir el inventario, el cliente compacta la bolsa (quita los huecos) y el anfitrión no. Tras vender o tirar algo, las casillas que ves ya no son las del anfitrión.
   - Consecuencia: al vender, equipar o usar se manda el número de otra casilla. Puede no pasar nada (un hueco), o vender o equipar **otro objeto**.
   - Arreglo: leer el inventario conserva la posición de cada objeto (los huecos se mantienen), tanto de la red como de las partidas guardadas.
6. **Consagración y Círculo de sanación como definitivas.**
   - Las reglas no cambian: siguen curando y dañando cada segundo.
   - Lo que se quita es el pulso visual. Hoy el círculo del suelo vuelve a crecer desde cero cada segundo; pasa a quedarse fijo toda la duración.
   - Visual de definitiva:
     - círculo sagrado;
     - coro de 6 ángeles vóxel flotando en el borde, que giran despacio;
     - motas de luz que suben de toda la zona;
     - un haz de luz en el centro.
   - La *Consagración* lleva además llamas doradas en el borde.

7. **Himno divino.** Durante la canalización (6 s):
   - el clérigo es **invulnerable** (solo él);
   - levita a 0,8 m del suelo, con alas y halo;
   - el grupo sigue recibiendo la curación.

   Si la canalización se corta (al moverse), la invulnerabilidad se acaba y el clérigo vuelve al suelo.
8. **Chat al cerrar sesión.** Al cerrar sesión o cambiar de personaje, el chat se vacía.
9. **Avisos de venta.** Cualquier venta rechazada avisa en el chat, incluido el hueco vacío.
10. **«Salir al título» pasa a «Cerrar sesión».**

## Pruebas (GUT)
- La vista previa lleva las piezas del equipo guardado.
- Las nuevas recargas y el mismo daño por segundo en los básicos cuerpo a cuerpo.
- La mano izquierda no salta entre fotogramas en todo el combo a dos manos.
- Los combos exageran el giro del torso: más de 1 rad entre la preparación y el golpe.
- La bolsa conserva los huecos al pasar por la red y por el guardado.
- Vender tras vender otro objeto vende el que ves.
- El círculo sagrado no vuelve a crecer en cada pulso.
- El coro está presente.
- Durante el himno, el clérigo no recibe daño y su avatar levita. Al moverse, vuelve a recibir daño.
- El chat se vacía al salir.
- El texto `MENU_LEAVE` es «Cerrar sesión».

## Decisiones tomadas
- Invulnerable solo el clérigo durante el himno (usuario).
- Bajar la recarga de los básicos cuerpo a cuerpo de todas las clases (usuario).
- «Pulsos» se refiere a lo visual, no a las reglas (usuario).
- Decisiones de Claude:
  - el mismo daño por segundo con las nuevas recargas;
  - los valores de la tabla.

---
← [[Planes]]
