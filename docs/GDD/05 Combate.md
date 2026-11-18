---
tags: [gdd]
estado: implementado
actualizado: 2026-11-18
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
- **Monstruos (0.5.0, bestiario del prólogo):** el jabalí marcado avisa una línea de 8 m y carga por ella; el arquero del culto se aleja si estás a menos de 5 m; los cultistas enmascarados despiertan a su grupo; el sabueso marcado muerde.
- **Jefe, el Acólito Cultista** (antes bestia de guardia y Rey orco, mismas reglas): encapuchado del culto con la máscara del sol negro, halo dorado con púas y garras; fase 1 zarpazo en arco; fase 2 (66 %) además salta sobre un jugador con un área de 4 m avisada 1,2 s; fase 3 (33 %) además llama a 3 cultistas cada 20 s. Su muerte se anuncia en el chat y reaparece a los 3 minutos.
- **Jefe principal: Vaelthar, Primer Apóstol** (el primero de los 5 Sacerdotes demonio). Levita a 0,7 m del suelo. Vida 6000, armadura 60, poder 32, ×2,2 de tamaño; barra de jefe arriba mientras combate. Sus ataques vienen de los datos (`specials` por fase y `phase_abilities`, válidos para los otros sacerdotes):
  - Siempre: *Azote de tentáculos* (arco de 160° a 3,5 m, sangrado), *Abrazo del abismo* (tentáculos bajo un jugador, área de 3 m avisada 1,2 s, enraíza 2 s, cada 12 s) y *Lágrimas del sol negro* (abanico de 5 proyectiles de sombra que queman, cada 8 s).
  - Fase 2: *Halo del eclipse* (estalla a su alrededor, 7 m avisados 2 s, mucho daño y debilita) y *Charca de corrupción* (charco de 4 s que envenena y ralentiza).
  - Fase 3: *Fervor del Apóstol* al entrar (más rápido y más daño hasta el final) y llama a 4 cultistas cada 25 s. Reaparece a los 5 minutos.
- **Jefe principal: Nhazar, Obispo de las Mil Voces** (el segundo Sacerdote demonio). Levita a 0,8 m; un cuerpo pequeño bajo una masa enorme de rizos negros llena de máscaras que gritan, lloran, rabian o ríen. Vida 7500, armadura 55, poder 34. **Su set gira en torno a los estados alterados** (todos sus ataques dejan uno):
  - Siempre: *Cadena penitente* (arco de 140° a 4 m: ralentiza y *armadura rota* −15 %), *Letanía de plomo* (área de 5 m que pulsa 5 s: ralentiza un 50 % y ataque lento un 35 %), *Mil susurros* (+25 % de daño recibido 6 s) y *Coro de lamentos* (abanico de 7 voces que atraviesan; debilita un 25 %).
  - Fase 2: *Confesión forzada* (área de 4 m avisada: −40 % de armadura y −20 % de daño 8 s), *Lluvia de máscaras* (5 m avisados 1,5 s: aturde 1 s y ralentiza) y *Alarido de las mil voces* (8 m a su alrededor avisados 1,8 s: mucho daño, aturde 1,5 s y −30 % de armadura).
  - Fase 3: *Coro desatado* al entrar (ataca más rápido y recibe un 25 % menos de daño), *Cántico sin fin* (un área de 9 m que le sigue 6 s: ralentiza y debilita) y llama a 3 arqueros del culto cada 22 s. Reaparece a los 5 minutos.
- **Estado nuevo, Armadura rota:** la armadura del afectado cuenta un porcentaje menos contra el daño físico.
- **Derribo:** en grupo, con algún aliado en pie, a 0 de vida quedas derribado 30 s. Un aliado a menos de 2 m mantiene E 3 s y te levanta con el 30 % de la vida (moverse, recibir daño o soltar lo cancela). Si cae todo el grupo, todos reaparecen a los 3 s.

## Plan 4 (0.6.0) **[Implementado]**
Monstruos con nivel (vida, daño y armadura crecen con él; la armadura pierde valor contra atacantes de más nivel). Bloqueo (medio daño en golpes físicos cuerpo a cuerpo), robo de vida, reducción de recargas y regeneración. Habilidades que se repiten o se canalizan, rayos, abanicos, invocaciones aliadas y 18 ganchos de pasivas para las mejoras de clase. Los números están en `data/balance.json`.

---
← [[00 Índice del GDD|Índice del GDD]]
