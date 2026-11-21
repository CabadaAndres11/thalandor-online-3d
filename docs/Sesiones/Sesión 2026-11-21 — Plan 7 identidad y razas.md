---
tags: [sesion]
fecha: 2026-11-21
tipo: desarrollo
---
# Sesión 2026-11-21 — Plan 7: identidad y creación de personaje

## Objetivo
Diseñar e implementar el [[Plan 7 — Identidad y creación de personaje (spec)|Plan 7]]: razas, apariencia ampliada y menús definitivos.

## Qué se hizo
- **Decidido con el usuario:**
  - cinco razas, solo de aspecto;
  - enanos más bajos;
  - cuerpo compartido con cabeza propia para el ogro y el lagarto ([[D-016 Razas solo de aspecto con cabeza propia]]);
  - pantalla de inicio con una escena vóxel de cultistas alrededor del altar, Jugar en una esquina inferior e iconos arriba a la derecha;
  - selección y creación con el mismo estilo; las ventanas del juego siguen en azul hasta el Plan 11.
- **Razas en el catálogo:** `races.json` y opciones por raza; la apariencia se sanea según la raza, y los guardados viejos se abren como humanos.
- **`HumanRig`:** altura y proporciones por raza que mueven pivotes y piezas, cabezas propias, ajuste de cascos y altura real para la barra de vida.
- **Arte:**
  - cabezas de ogro y lagarto, orejas, nariz, cola, 4 crestas, 8 peinados, 5 barbas y 5 rasgos;
  - decorado del altar y pose de oración;
  - iconos del menú.
- **Interfaz:** `MenuScene` con datos en `data/scenes/title_altar.json`, `StoneTheme`, pantalla de inicio con créditos, y selección y creación sobre la escena.
- Versión **0.10.0** (sin publicar).

## Qué se probó
- Suite GUT completa y tests de arte en Node (`node --test tools/art/tests/`).
- Capturas de las razas, del equipo de tramo 3 en el ogro y el lagarto, y de las tres pantallas de menú.

## Problemas encontrados
- Los cascos flotaban sobre el ogro: se ajustó `head_fit`.
- Las orejas élficas quedaban bajo el pelo: se alargaron.
- La luz del altar quemaba la estela.
- Los encuadres tapaban o cortaban al personaje.

## Siguiente paso
- Prueba de juego del usuario de la 0.10.0, revisión final y publicación.

---
← [[Sesiones]]
