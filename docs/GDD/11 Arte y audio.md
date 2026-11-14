---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 11. Arte y audio **[En curso]** (personajes vóxel hechos en la 0.2.0)

- **Estilo:** **vóxel** 3D, colores vivos y saturados, iluminación suave con sombras (estética tipo Cube World / Trove / Minecraft Dungeons).
- **Escala:** bloques del mundo de 1 m; personajes de unas 24–32 unidades vóxel de alto, construidos por piezas.
- **Personajes:** modelo base por cuerpo, animado por **esqueleto** (las piezas rígidas siguen a los huesos), con animaciones de reposo, andar, correr, golpe en arco, estocada, lanzar hechizo, disparar, esquivar, recibir daño, derribado y morir. Se hacen en Blockbench (exporta glTF con animaciones).
- **Implementado (0.2.0):** en lugar de Blockbench, los personajes usan el modelo y las animaciones de **Kenney Blocky Characters 2.0** (CC0). El aspecto se monta con **capas de textura teñidas** (recortadas de las texturas de Kenney o pintadas con scripts de `tools/art/`) y **piezas `.vox`** de MagicaVoxel enganchadas a las partes del cuerpo. Las piezas son el mismo sistema que usará el equipo visible. Créditos en `CREDITS.md`.
- **Equipo:** un modelo vóxel por objeto base, acoplado a su hueso; variantes de material (hierro, acero, oro…) por color de paleta.
- **Monstruos:** modelos vóxel propios con sus animaciones.
- **Fuentes de assets:**
  - Primero packs gratuitos con licencia libre (CC0 preferido; CC-BY con créditos): por ejemplo los packs vóxel de **Kenney**, **itch.io** y **OpenGameArt**.
  - Lo que falte se modela en MagicaVoxel o Blockbench.
  - Antes de descargar, se proponen 2 o 3 candidatos de estilo coherente para su aprobación.
- **Créditos:** archivo `CREDITS.md` con autor y licencia de cada asset, generado o mantenido con cada importación.
- **Gráficos provisionales:** cubos y cápsulas de colores hasta tener los modelos definitivos.
- **Audio:** música y efectos de packs gratuitos con licencia libre; volumen por canal (música, efectos, interfaz).

---
← [[00 Índice del GDD|Índice del GDD]]
