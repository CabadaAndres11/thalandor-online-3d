---
tags: [gdd]
actualizado: 2026-11-14
---

# Registro de cambios del GDD

| Versión | Fecha | Cambio |
|---|---|---|
| 1.x | 2026-11-11 a 2026-11-13 | GDD del prototipo 2D (Phaser, pixel art LPC, navegador). Prototipo publicado hasta la versión 0.5.3: red host-autoritativa, combate, 4 clases con especializaciones, progresión hasta el nivel 30, talentos circulares, objetos y mercader. |
| 2.0 | 2026-11-14 | **Cambio de rumbo:** el juego pasa a **3D vóxel en Godot**, con cámara isométrica, ejecutable para Windows y red P2P con código. **5 clases** (Arquero y Asesino separados). **Sin nivel máximo**: mejora de clase cada 50 niveles (sustituye a las especializaciones), árbol de talentos que crece por anillos y maestrías. **Cambio de clase** diseñado (requisitos abiertos). Hoja de ruta de 8 planes desde cero. |
| 2.1 | 2026-11-14 | **Plan 1 implementado (versión 0.1.0):** proyecto Godot 4.7.2 con la estructura de §2.4, simulación host-autoritativa del movimiento con predicción e interpolación, red ENet con código de grupo (IP del host, puerto fijo 24680), chat, control de versiones, cámara isométrica con alternancia de proyección (F9), exportación a Windows y publicación en GitHub Releases con CI. Pendiente: prueba entre casas (WebRTC frente a ENet + VPN). Decisiones [[D-008 Red con mensajes propios]] y [[D-009 Repositorio nuevo y publicación en GitHub Releases]]. |

Añade una fila por cada cambio de diseño o funcionalidad implementada.

---
← [[00 Índice del GDD|Índice del GDD]]
