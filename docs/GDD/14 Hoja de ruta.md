---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-27
---

# 14. Hoja de ruta **[En curso]** (revisada el 2026-11-27, tras la 0.17.0)

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
| 8 (prólogo) | **Mundo y misiones, el prólogo:** zonas como datos, misiones, diálogos y escenas, el prólogo como tutorial, camino y capital, relieve, cuerpos de hombre y mujer, árbol de talentos en anillos y la primera bajada a la cripta | 0.11.x–0.17.0 |

## Pendientes
La demo es el **prólogo y el arco 1** completos, con las zonas que hagan falta, y acaba **hacia el nivel 60** ([[D-017 Mundo por zonas, hordas y demo del prólogo y arco 1|D-017]]). El orden define primero **qué hay en el mundo** (enemigos, misiones, secretos, oficios) y después **los objetos**, que se diseñan sabiendo para qué clases son, de dónde salen y con qué materiales se hacen.

| Plan | Contenido | Por qué en este orden |
|---|---|---|
| 9 | **Misiones secundarias y bestiario ampliado:** misiones secundarias en las zonas que ya existen; el resto de enemigos y monstruos del prólogo y el arco 1 | Saber qué enemigos hay dice qué objetos y materiales pueden soltar |
| 10 | **Secretos:** clases ocultas con sus condiciones; **habilidades ocultas** que se desbloquean con condiciones ocultas o misiones y que la mayoría de clases pueden equiparse; **ventana de títulos**, que se ganan con misiones e hitos y dan estadísticas o efectos únicos | Usan el mismo motor de condiciones e hitos; fija cuántas clases hay antes de diseñar objetos |
| 11 | **Oficios:** herrero, peletero y demás; los enemigos sueltan **materiales**; recolección, recetas y fabricación | Fija los materiales disponibles antes de definir los objetos |
| 12 | **Sistema de objetos nuevo:** sin sets ni tiers; muchos objetos independientes, cada uno con sus estadísticas y, a partir de cierto nivel, **pasivas o habilidades propias**; **objetos únicos** con dónde y cómo conseguirlos; objetos fabricables; objetos como recompensa de misión | El núcleo del juego tras los oficios: conseguir los mejores objetos. Se diseña con enemigos, clases y materiales ya conocidos |
| 13 | **Mazmorra rehecha** (aspecto y funcionamiento) y **cofres con recompensas** | Reparte el botín nuevo |
| 14 | **Arco 1, primera mitad** (misiones 6–10): afueras de la capital y sus zonas | Con todos los sistemas listos |
| 15 | **Arco 1, final** (misiones 11–14): alcantarillas y submundo, las bajadas a la cripta y la salida rumbo al volcán | Cierra la historia de la demo |
| 16 | **Interfaz y audio:** marcos de grupo, música y efectos | Pulido con todos los sistemas presentes |
| 17 | **Contenido y equilibrio de la demo:** colocar los objetos únicos y secretos, ajustar la progresión hasta el nivel 60 | Llena y equilibra todo lo anterior |

Notas:
- Los ajustes de kit del Venenero y del mago están decididos ([[D-021 Kit elemental del mago y Detonar toxinas del Venenero|D-021]]), sin plan asignado.
- La prueba de red entre casas se superó con WebRTC ([[D-020 WebRTC como red definitiva]]).

---
← [[00 Índice del GDD|Índice del GDD]]
