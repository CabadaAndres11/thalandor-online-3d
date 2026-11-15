---
tags: [plan, spec]
plan: 3.1
fecha: 2026-11-16
estado: aprobada
actualizado: 2026-11-16
---
# Plan 3.1 — Ajustes tras la 0.4.0: diseño

## Objetivo
Tres mejoras pedidas tras publicar la 0.4.0:
1. **Esqueleto arquero** con aspecto de esqueleto de verdad: huesos finos con huecos entre ellos, no un cuerpo de cubos.
2. **Ventana K** con el clic izquierdo y el derecho, para ver qué hacen.
3. **Descripciones detalladas** de las habilidades: daño con su fórmula y porcentajes, de dónde salen los cálculos.

## Fuera de alcance
- Asignar el clic izquierdo o derecho a otra habilidad (siempre van en el ratón).
- Rehacer el resto de monstruos.

## Diseño
### Esqueleto vóxel propio (decisión del usuario)
- Rig propio por partes, como el lobo y el jabalí (`tools/art/make_monsters.mjs` → `assets/monsters/vox/skeleton*.vox` y `skeleton.json`): cráneo con cuencas huecas, ojos que brillan y mandíbula; costillas con aire entre ellas y columna; pelvis; huesos de brazos y piernas de 1 vóxel con articulaciones; arco en la mano izquierda; jirones de tela en la cintura.
- Animaciones por código en `BeastRig` (forma bípeda): caminar (piernas y brazos alternos, traqueteo del cráneo), reposo (balanceo y mandíbula), disparar (alza el arco y tensa) y morir (se desmorona).
- Se retiran la piel de esqueleto sobre Kenney y su arco.

### Ventana K
- Fila **Ataques** con CI y CD: se seleccionan para leer su descripción; no se colocan en la barra 1–4.
- Sigue sin scroll a 1280×720.

### Detalle calculado (decisión del usuario)
Debajo de la descripción escrita, líneas generadas de `data/abilities/` y de las estadísticas del personaje:
- daño: base + % del poder de ataque o mágico, tipo y resultado con tus estadísticas; a quién alcanza (objetivo, arco, radio, línea, pulsos, explosión, trampa);
- curación y escudos con su fórmula; estados con porcentaje y duración;
- crítico (probabilidad y multiplicador), coste con el recurso de la clase, recarga (y la de combate si es distinta), recarga global y alcance;
- pasivas: su efecto con el número exacto.
Todos los textos en `textos.csv`.

## Pruebas
- El detalle de cada habilidad de las 5 clases se genera sin claves sin traducir ni huecos; el daño calculado coincide con la fórmula.
- La ventana K muestra CI y CD, no deja ponerlos en la barra y cabe a 1280×720.
- El esqueleto es un rig con sus partes; camina, dispara y se desmorona.
- Punto de control de arte del esqueleto (visto bueno del usuario).

## Decisiones tomadas
- Esqueleto vóxel propio con animación por código (usuario, frente a huesos sobre el modelo de Kenney).
- Detalle calculado de los datos (usuario, frente a textos escritos a mano).
- Versión 0.4.1, compatible en red con la 0.4.0. Publicación solo con permiso.

---
← [[Planes]]
