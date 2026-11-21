---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-21
---

# 11. Arte y audio **[En curso]** (0.5.0: todo el arte es propio, hecho por código)

- **Renovación pendiente ([[14 Hoja de ruta|Plan 6]]):** vóxel más fino en todos los modelos para ganar detalle y alejarse del aspecto infantil o indie actual; proporciones más realistas, materiales, iluminación y postprocesado. Referencias en [[Estilo gráfico objetivo (Plan 6)]]. Vóxel 2× y cuatro partes: [[D-015 Vóxel 2× y renovación gráfica en cuatro partes]]. Primera parte: [[Plan 6.1 — Iluminación, ambientes y opciones (spec)|ambientes como datos, calidad de vídeo y volúmenes]] **[Implementado 0.8.0]**: `exterior_dia` (sol cálido de tarde, polvo, antorchas casi apagadas) y `mazmorra_noche` (luna tenue, niebla baja, brasas y antorchas como luz principal); calidad Baja, Media o Alta, que solo quita efectos.
- **Estilo:** **vóxel** 3D, colores vivos y saturados, iluminación suave con sombras (estética tipo Cube World / Trove / Minecraft Dungeons).
- **Escala:** bloques del mundo de 1 m. Dos cuerpos humanoides:
  - **v2 [Implementado, sale en la 0.9.0]** ([[Plan 6.2 — Humanoide y piezas a vóxel 2× (spec)|Plan 6.2]]): vóxel de 1,8 cm, 98 vóxeles de alto (≈1,76 m), unas 5,8 cabezas de alto. Cara con cejas, ojos con iris, nariz con volumen y boca. Esculpido con `tools/art/sculpt.mjs` y tonos de textura por vóxel. Lo usan los jugadores y los PNJ, con sus piezas de `pieces_v2.json`.
  - **v1:** vóxel de 3,6 cm, 49 vóxeles de alto. Lo usan los cultistas y los jefes hasta la 6.4. El equipo aún no rehecho se pone sobre el cuerpo v2 al doble de tamaño hasta la 6.3.
- **Personajes [Implementado 0.5.0]:** humanoide vóxel propio por huesos (`HumanRig`). Partes `.vox` generadas por `tools/art/make_humans.mjs`: cadera, torso, cabeza, brazos con antebrazo y mano, muslos y piernas con bota. Están animadas por código:
  - reposo y andar, con codos y rodillas;
  - golpe, disparo, hechizo y embestida;
  - caído y muerte.
- **Color y sombreado:** cada material tiene un tono oscuro y otro claro pintados en los vóxeles, y el mallador añade **oclusión ambiental en los vértices**. El aspecto, menos «bloque», se aprobó con una referencia del usuario.
- **Piezas:** pelo, barbas, ropa de cada clase, tocados y armas en la mano son `.vox` de `tools/art/make_pieces.mjs`. Las teñibles usan los canales piel, ojos, pelo, color principal, secundario y pantalón. Es el mismo sistema que usará el equipo visible.
- **Equipo:** un modelo vóxel por objeto base, acoplado a su hueso; variantes de material (hierro, acero, oro…) por color de paleta. **[Implementado 0.9.0]** versión v2 de todas las piezas (`tools/art/make_gear_v2.mjs`, `data/items/gear_pieces_v2.json`), con los mismos diseños y más épica por tramo. Los colores por clase y tramo están en `gear_style.mjs`, compartido con el v1.
- **Monstruos:** modelos vóxel propios con sus animaciones. Los humanoides del culto y su jefe, el Acólito Cultista, usan `HumanRig`; los sabuesos y jabalíes usan `BeastRig`, que aún tiene el vóxel grueso (pasarlos al fino está en [[15 Decisiones abiertas]]).
- **Fuentes de assets [Decidido, [[D-010 Arte propio hecho por código]]]:** todo el arte se genera con los scripts de `tools/art/`; no se usan packs de terceros.
- **Créditos:** archivo `CREDITS.md` con autor y licencia de cada asset, generado o mantenido con cada importación.
- **Logo e icono [Implementado]:** logo "Thalandor Online" con el Sol Negro del culto en las O, en la pantalla de inicio (`assets/brand/logo.png`); el mismo sol como icono del ejecutable y de la ventana (`assets/brand/icono.ico`).
- **Razas [Implementado 0.10.0]:** cabezas propias del ogro y del lagarto en `tools/art/races_v2.mjs`, que se escriben junto al cuerpo v2 (`human_v2.json`, apartado `heads`). Orejas, nariz, cola, crestas, peinados, barbas y rasgos nuevos en `make_pieces_v2.mjs`. Ver [[D-016 Razas solo de aspecto con cabeza propia]].
- **Escena del menú [Implementado 0.10.0]:** altar del Sol Negro, columnas rotas, braseros, velas y losas en `make_props.mjs`, a vóxel de 5 cm. La escena es un dato (`data/scenes/title_altar.json`) y la construye `MenuScene`. Los cultistas usan la pose de oración en bucle (`pray`).
- **Gráficos provisionales:** cubos y cápsulas de colores hasta tener los modelos definitivos.
- **Audio:** música y efectos de packs gratuitos con licencia libre; volumen por canal (música, efectos, interfaz).

---
← [[00 Índice del GDD|Índice del GDD]]
