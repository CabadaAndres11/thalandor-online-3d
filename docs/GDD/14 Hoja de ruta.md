---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-27
---

# 14. Hoja de ruta **[En curso]** (revisada el 2026-11-19, tras la 0.7.0)

Cada plan se diseña (spec), se planifica, se implementa con tests, se prueba y se publica antes de pasar al siguiente.

## Hechos
| Plan | Contenido | Versión |
|---|---|---|
| 1 | **Fundaciones y red:** proyecto Godot, cámara isométrica, red host-autoritativa, grupo por código, chat y exportación | 0.1.x |
| 2 | **Personajes vóxel:** creación y selección, modelo por piezas, apariencia, guardado | 0.2.0 |
| 3 | **Combate y las 5 clases** (3.1 y 3.2: vóxel propio, bestiario del prólogo, Brann) | 0.3.0–0.5.0 |
| 4 | **Progresión:** experiencia sin tope, atributos, talentos, mejoras del nivel 50 | 0.6.x |
| 5 | **Objetos:** botín, inventario, equipo visible por clase y tramo, mercader, durabilidad, pociones | 0.7.0 |
| 6 | **Renovación gráfica:** vóxel 2×, iluminación, ambientes, equipo, monstruos y ropa que sigue al cuerpo | 0.8.0–0.9.7 |
| 7 | **Identidad y creación de personaje:** cinco razas, apariencia ampliada, pantalla de inicio con el altar del Sol Negro y menús de piedra y oro | 0.10.0 |

## Pendientes (nuevo orden)
El orden pone primero lo que cambia la base de todo lo demás: la renovación gráfica antes de crear más modelos, y el mundo antes de esconder secretos en él.

| Plan | Contenido | Por qué en este orden |
|---|---|---|
| 6 | **Renovación gráfica:** vóxel más fino en todos los modelos (humanoide, piezas, equipo, monstruos, PNJ) para ganar detalle y dejar atrás el aspecto infantil; proporciones más realistas, materiales e iluminación, sombras y postprocesado; las capas, túnicas y auras siguen al cuerpo **Vóxel 2× y cuatro partes** ([[D-015 Vóxel 2× y renovación gráfica en cuatro partes]]): 6.1 iluminación, ambientes y opciones; 6.2 humanoide y piezas; 6.3 equipo; 6.4 monstruos, PNJ y ropa que sigue al cuerpo | Todo el arte que venga después (razas, bestiario, sets ocultos) se hará ya en el estilo nuevo, sin rehacerlo dos veces |
| 7 | **Identidad y creación de personaje:** logo, menú de inicio, pantallas de selección y creación con estilo propio; **razas** seleccionables; muchos más peinados, colores, rasgos y elementos de apariencia | Se apoya en el modelo nuevo del Plan 6 |
| 8 | **Mundo y misiones** ([[D-017 Mundo por zonas, hordas y demo del prólogo y arco 1]]): el **prólogo y el arco 1** del guion, en cinco partes: 8.1 zonas y mundo (**0.11.0**), 8.2 misiones, diálogos y escenas (**0.12.0**), 8.3 prólogo, 8.4 arco 1 (primera mitad) y 8.5 arco 1 (final) | Da el espacio donde ocurre todo lo demás |
| 9 | **Secretos y clases ocultas:** condiciones ocultas que desbloquean **clases nuevas con sets propios** y **habilidades nuevas para cualquier clase**; registro de descubrimientos | Necesita mundo, misiones y PNJ donde esconder las pistas |
| 10 | **Oficios:** herrero, peletero y demás; recolección de materiales, recetas y fabricación de objetos | Se apoya en objetos (Plan 5) y en el mundo (Plan 8) |
| 11 | **Interfaz y audio:** minimapa, marcos de grupo, opciones, música y efectos | Pulido general con todos los sistemas ya presentes |
| 12 | **Contenido de la demo:** las 4 zonas completas hasta el nivel 60, **bestiario ampliado**, historia principal, legendarios y cambio de clase; equilibrio | Llena todo lo anterior de contenido |

Notas:
- El **bestiario** crece en dos momentos: los enemigos de las primeras zonas en el Plan 8 y el resto en el Plan 12.
- Las **clases ocultas** se diseñan en el Plan 9 de forma genérica (condiciones y recompensas como datos); su contenido concreto se reparte por las zonas del Plan 12.
- La prueba de red entre casas se superó con WebRTC ([[D-020 WebRTC como red definitiva]]).

---
← [[00 Índice del GDD|Índice del GDD]]
