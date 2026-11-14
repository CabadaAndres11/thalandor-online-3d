---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 5. Combate **[Diseñado]** (reglas probadas en el prototipo 2D)

- **Tiempo real.** Ataques cuerpo a cuerpo en arco, proyectiles y áreas, con avisos en el suelo antes de los ataques fuertes de los monstruos.
- **Hitbox en 3D:** cada personaje y monstruo tiene una **cápsula** (de los pies a la cabeza); los proyectiles impactan en cualquier punto del cuerpo, no solo en los pies.
- **Esquiva común:** salto corto con breve invulnerabilidad y recarga de unos 3 s.
- **Recarga global:** 0,5 s entre habilidades (no afecta a los ataques básicos ni a la esquiva).
- **Amenaza (aggro):** tabla de amenaza por monstruo; el daño y la curación generan amenaza; el tanque tiene provocar y multiplicadores de amenaza.
- **Sin fuego amigo.**
- **Escalado por grupo:** la vida de los monstruos escala con el número de jugadores presentes (`1 + 0,75 × (jugadores − 1)`).
- **Monstruos:** normales, élite (más fuertes, mejor botín) y jefes (fases y ataques en área que hay que esquivar).
- **IA:** reposo, combate (persecución con navegación de Godot: `NavigationAgent3D`) y vuelta a su zona si se alejan demasiado; algunos en manada, otros a distancia.
- **Muerte:**
  - **En grupo:** el jugador queda **derribado** y un compañero lo levanta manteniendo **E** unos segundos.
  - **En solitario, o si cae todo el grupo:** reaparición en el último punto de control. Se pierde **durabilidad del equipo**, no experiencia.

---
← [[00 Índice del GDD|Índice del GDD]]
