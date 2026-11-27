---
tags: [plan, spec]
estado: implementado
actualizado: 2026-11-27
---

# Plan 8.3h — Kit elemental del mago y Venenero (spec)

Lleva al juego [[D-021 Kit elemental del mago y Detonar toxinas del Venenero|D-021]]. Versión prevista: **0.17.1**. La spec lleva las tareas.

## Qué cambia para el jugador
- **Venenero:** Contagio deja de ser activa y pasa a **pasiva** (el veneno que pones salta a los enemigos a 6 m cuando el envenenado muere). Activa nueva **Detonar toxinas** (nivel 50, 30 de energía, 12 s, 12 m, objetivo bajo el cursor): consume todas las cargas de veneno del objetivo y le da **un golpe por carga** (6 + 0,5 × PA cada uno, físico, pueden ser críticos). Sin veneno no hace nada (no se puede lanzar).
- **Mago:** con una mejora elegida, las habilidades base que D-021 traduce se ven y se llaman según el elemento, con los mismos números que la base salvo el control:

| Base | Piromante | Criomante | Arcano |
|---|---|---|---|
| Proyectil arcano | Saeta de fuego (fuego) | Esquirla de hielo (escarcha) | — |
| Explosión arcana | Erupción (fuego) | Estallido glacial (escarcha) | — |
| Parpadeo | Paso de llamas (solo aspecto) | Paso helado (solo aspecto) | — |
| Nova de escarcha | Nova ígnea: aturde 1,5 s (fuego) | — | Nova arcana: inmoviliza 2 s (arcano) |
| Barrera de maná | Escudo de llamas: quien te golpea cuerpo a cuerpo arde (4/s, 4 s) | Armadura de hielo: quien te golpea cuerpo a cuerpo se ralentiza (30 %, 3 s) | — |
| Bola de fuego | — | Cometa de hielo: la explosión ralentiza (30 %, 3 s) (escarcha) | Orbe arcano (arcano) |
| Descarga de escarcha | Lanza de fuego: quemadura (6/s, 4 s) en vez de ralentizar (fuego) | — | Descarga arcana: ralentiza igual (arcano) |

  - **Ignición** ya afecta a todo hechizo de fuego, así que con el kit del Piromante vale para todos (sin cambiar la pasiva).
  - **Frío penetrante** cuenta enemigos **ardiendo** con el Piromante e **inmovilizados** con el Arcano (con el Criomante, congelados o ralentizados, como ahora).
  - La evolución de cada mejora (Bola de fuego, Nova de escarcha, Explosión arcana) no choca con ninguna traducción y sigue igual.
  - La barra no cambia de huecos: el hueco de «Proyectil arcano» lanza «Saeta de fuego» si eres Piromante. Al reiniciar la mejora con maese Corwin vuelve la base.

## Cómo se hace
- **Variantes como datos:** una habilidad con `"upgrade": "<mejora>"` y `"replaces": "<id base>"` sustituye a la base para quien tiene esa mejora. Va en `data/abilities/mage.json` (activas y la pasiva Frío penetrante) y vale para cualquier clase.
  - `AbilityDB.resolved(id, upgrade)` devuelve la variante (con su propio id) antes de aplicar la evolución; `actives()`/`unlocked()`/`default_bar()` no listan variantes; `Passives.collect` usa la variante de una pasiva en lugar de la base.
  - Los recargos siguen con el id del hueco (la base). El evento `cast` añade el id de la variante al final, para que los efectos visuales (color por elemento) y la animación la usen; los proyectiles, áreas y parpadeos ya llevan el id de la habilidad resuelta.
  - La barra, la ventana K, las fichas y la ventana de mejora muestran la variante del jugador (nombre, icono, descripción). La ventana de mejora lista además «Tu kit cambia: …».
  - `UpgradeDB` valida que cada `replaces` apunte a una habilidad de la misma clase y que no haya dos variantes de la misma base en una mejora.
- **Escudo con represalia:** `shield {on_melee_hit: <estado>}`: mientras dura el escudo, quien golpea cuerpo a cuerpo al portador recibe ese estado.
- **Detonar toxinas:** efecto nuevo `detonate {status, damage}`: cuenta las cargas del estado en el objetivo, hace un golpe por carga y quita el estado. Necesita objetivo con ese estado.
- **Contagio pasiva:** gancho `poison_spreads_on_death {radius}`. Al morir un enemigo, su veneno salta si tiene el estado `contagion` (monstruos, como ahora) o si la fuente de su veneno tiene el gancho. Las barras guardadas con `assassin_contagion` lo pierden solas (la barra se valida al cargar).
- **Iconos:** 15 nuevos (14 del mago y Detonar toxinas). Hasta que el usuario los pinte, cada uno es una copia del icono más parecido; los prompts se le dan al terminar.
- **Textos:** nombres y descripciones en `data/texts/textos.csv`.

## Tareas
1. Variantes en `AbilityDB` y `Passives`, validación en `UpgradeDB`, evento `cast` con la variante. Tests: resolución por mejora, listas sin variantes, pasiva sustituida, barra sin cambios, validación.
2. Venenero: gancho de contagio, efecto `detonate`, datos y textos. Tests: el veneno salta sin la activa, golpes por carga, sin veneno no se lanza, la barra vieja pierde Contagio.
3. Mago: las 14 variantes activas y las 2 de Frío penetrante, `shield.on_melee_hit`, datos y textos. Tests: cada mejora lanza su variante con su elemento y control, represalia del escudo, Frío penetrante por mejora.
4. Interfaz: barra, ventana K, fichas y ventana de mejora con la variante. Tests de las ventanas.
5. Iconos provisionales, GDD (notas de clase, §4.4), registro, versión 0.17.1 y suite rápida.

## Fuera de esta spec
- Los iconos definitivos (los pinta el usuario).
- Rehacer el resto de kits o las mejoras de otras clases.

---
← [[Planes]]
