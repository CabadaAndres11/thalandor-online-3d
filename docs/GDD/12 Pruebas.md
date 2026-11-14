---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 12. Pruebas **[Diseñado]**

| Nivel | Herramienta | Qué cubre |
|---|---|---|
| Unitario | GUT | Estadísticas, daño, amenaza, talentos, mejoras de clase, misiones, botín, experiencia, migraciones de guardado |
| Simulación de red | GUT con transporte en memoria (latencia y pérdida simuladas) | 1 host y 3 invitados; sincronización y reconciliación |
| Partida automática | Godot en modo `--headless` con un script que juega | Crear personaje, entrar, combatir, guardar y cargar |
| Real | Partidas con amigos | Conexión entre casas, rendimiento y diversión |

Cada funcionalidad se entrega con sus tests; las pruebas de juego reales las hace el equipo.

---
← [[00 Índice del GDD|Índice del GDD]]
