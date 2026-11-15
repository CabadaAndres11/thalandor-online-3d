---
tags: [gdd]
estado: implementado
actualizado: 2026-11-15
---

# 5. Combate **[Implementado]** (Plan 3, 0.4.0: daño, esquiva, recarga global, kits completos, amenaza con provocar, lobos, jabalíes, goblins, esqueletos arqueros, limos, élites y el jefe Rey orco, escalado por grupo, derribo y levantar con E. Pendiente: la durabilidad al morir llega con los objetos en el Plan 5, y la reaparición es en el punto del escenario de pruebas)

- **Tiempo real.** Ataques cuerpo a cuerpo en arco, proyectiles y áreas, con avisos en el suelo antes de los ataques fuertes de los monstruos.
- **Hitbox en 3D:** cada personaje y monstruo tiene una **cápsula** (de los pies a la cabeza); los proyectiles impactan en cualquier punto del cuerpo, no solo en los pies.
- **Esquiva común:** salto corto con breve invulnerabilidad y recarga de unos 3 s.
- **Recarga global:** 0,5 s entre habilidades (no afecta a los ataques básicos ni a la esquiva).
- **Amenaza (aggro):** tabla de amenaza por monstruo; el daño y la curación generan amenaza; el tanque tiene provocar y multiplicadores de amenaza.
- **Sin fuego amigo.**
- **Escalado por grupo:** la vida de los monstruos escala con el número de jugadores presentes (`1 + 0,75 × (jugadores − 1)`).
- **Monstruos:** normales, élite (más fuertes, mejor botín) y jefes (fases y ataques en área que hay que esquivar).
- **IA:** reposo, combate (persecución con caminos `AStarGrid2D` calculados en la simulación, sin nodos) y vuelta a su zona si se alejan demasiado; algunos en manada, otros a distancia.
- **Muerte:**
  - **En grupo:** el jugador queda **derribado** y un compañero lo levanta manteniendo **E** unos segundos.
  - **En solitario, o si cae todo el grupo:** reaparición en el último punto de control. Se pierde **durabilidad del equipo**, no experiencia.

## Cómo quedó en la 0.4.0
- **Amenaza:** el daño suma su valor × multiplicador de amenaza; curar suma la mitad de lo curado en los monstruos que persiguen al curado; *Provocar* fuerza el objetivo unos segundos y deja al tanque con la amenaza máxima + 10 %. El monstruo solo cambia de objetivo si otro le supera en más de un 10 %.
- **Élites:** ×1,3 de tamaño, ×2,5 de vida y ×1,4 de daño, con un aura en el suelo; cada punto de aparición tiene su probabilidad (`data/maps/test_arena.json`).
- **Monstruos:** el jabalí avisa una línea de 8 m y carga por ella; el esqueleto arquero se aleja si estás a menos de 5 m; los goblins despiertan a su manada.
- **Jefe, Rey orco:** fase 1 tajo en arco; fase 2 (66 %) además salta sobre un jugador con un área de 4 m avisada 1,2 s; fase 3 (33 %) además llama a 3 goblins cada 20 s. Su muerte se anuncia en el chat y reaparece a los 3 minutos.
- **Derribo:** en grupo, con algún aliado en pie, a 0 de vida quedas derribado 30 s. Un aliado a menos de 2 m mantiene E 3 s y te levanta con el 30 % de la vida (moverse, recibir daño o soltar lo cancela). Si cae todo el grupo, todos reaparecen a los 3 s.

---
← [[00 Índice del GDD|Índice del GDD]]
