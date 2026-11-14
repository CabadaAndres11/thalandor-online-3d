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
| 2.2 | 2026-11-14 | **Versión 0.1.1 publicada (prueba de red):** WebRTC como red por defecto, con un servidor de enlace gratuito en Cloudflare Workers que solo presenta a los jugadores; ENet + Tailscale sigue disponible con `Jugar con ENet y Tailscale.bat`. Los códigos tienen el mismo formato en las dos redes. Corregidos: el anfitrión expulsaba a veces al invitado mientras se unía, y un error al acabar una sesión por tiempo de espera. Pendiente: prueba entre casas y decisión D-010. |
| 2.3 | 2026-11-14 | **Versión 0.1.2:** corregida la colisión con bloques. Al rozar el lateral de un bloque en diagonal, el jugador salía expulsado 1-2 m hacia atrás. |
| 2.4 | 2026-11-14 | **Plan 2 implementado (versión 0.2.0): personajes vóxel.** Modelo de Kenney Blocky Characters (CC0) con capas de textura teñidas y piezas `.vox`; 5 clases con su ropa (el Guerrero con armadura y hombreras); 2 cuerpos, 8 pieles, 6 ojos, 8 peinados, 10 colores de pelo y 5 barbas; animaciones de reposo y andar; hasta 8 personajes guardados con versión, exportación e importación; pantallas "Tus personajes" y "Crear personaje"; el personaje viaja por la red y el anfitrión lo sanea. Cierre del Plan 1: el tercer jugador ya puede entrar por WebRTC y se descartan entradas no válidas; prueba entre casas aplazada. |

Añade una fila por cada cambio de diseño o funcionalidad implementada.

---
← [[00 Índice del GDD|Índice del GDD]]
