---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 11. Arte y audio **[En curso]** (0.5.0: todo el arte es propio, hecho por código)

- **Estilo:** **vóxel** 3D, colores vivos y saturados, iluminación suave con sombras (estética tipo Cube World / Trove / Minecraft Dungeons).
- **Escala:** bloques del mundo de 1 m. Los humanoides usan un **vóxel fino** (unos 3,6 cm): 49 vóxeles de alto, unos 1,76 m, con proporciones de adulto.
- **Personajes [Implementado 0.5.0]:** humanoide vóxel propio por huesos (`HumanRig`). Partes `.vox` generadas por `tools/art/make_humans.mjs`: cadera, torso, cabeza, brazos con antebrazo y mano, muslos y piernas con bota. Están animadas por código:
  - reposo y andar, con codos y rodillas;
  - golpe, disparo, hechizo y embestida;
  - caído y muerte.
- **Color y sombreado:** cada material tiene un tono oscuro y otro claro pintados en los vóxeles, y el mallador añade **oclusión ambiental en los vértices**. El aspecto, menos «bloque», se aprobó con una referencia del usuario.
- **Piezas:** pelo, barbas, ropa de cada clase, tocados y armas en la mano son `.vox` de `tools/art/make_pieces.mjs`. Las teñibles usan los canales piel, ojos, pelo, color principal, secundario y pantalón. Es el mismo sistema que usará el equipo visible.
- **Equipo:** un modelo vóxel por objeto base, acoplado a su hueso; variantes de material (hierro, acero, oro…) por color de paleta.
- **Monstruos:** modelos vóxel propios con sus animaciones. Los humanoides del culto y la bestia de guardia usan `HumanRig`; los sabuesos y jabalíes usan `BeastRig`, que aún tiene el vóxel grueso (pasarlos al fino está en [[15 Decisiones abiertas]]).
- **Fuentes de assets [Decidido, [[D-010 Arte propio hecho por código]]]:** todo el arte se genera con los scripts de `tools/art/`; no se usan packs de terceros.
- **Créditos:** archivo `CREDITS.md` con autor y licencia de cada asset, generado o mantenido con cada importación.
- **Gráficos provisionales:** cubos y cápsulas de colores hasta tener los modelos definitivos.
- **Audio:** música y efectos de packs gratuitos con licencia libre; volumen por canal (música, efectos, interfaz).

---
← [[00 Índice del GDD|Índice del GDD]]
