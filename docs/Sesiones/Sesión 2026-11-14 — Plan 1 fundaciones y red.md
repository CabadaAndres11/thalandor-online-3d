---
tags: [sesion]
fecha: 2026-11-14
tipo: desarrollo
---
# Sesión 2026-11-14 — Plan 1: fundaciones y red

## Objetivo
Arrancar el proyecto 3D desde cero: leer el GDD, preparar el entorno, diseñar el Plan 1 y construirlo hasta la primera versión publicada.

## Qué se hizo
- **Entorno:** Godot 4.7.2 en `D:\Tools\Godot`, plantillas de exportación de Windows x86_64 y GUT 9.6.1.
- **Diseño:** spec y plan en [[Plan 1 — Fundaciones y red (spec)]] y [[Plan 1 — Fundaciones y red (plan)]]. Decisiones: prueba entre casas al final del plan, [[D-008 Red con mensajes propios]] y [[D-009 Repositorio nuevo y publicación en GitHub Releases]].
- **Repositorio:** `CabadaAndres11/thalandor-online-3d` (público), con GitHub Actions que pasa los tests en cada cambio y publica la versión al poner una etiqueta.
- **Juego (tareas 1–17 del plan):**
  - `sim/`: movimiento determinista con colisiones contra bloques de 1 m.
  - `net/`: protocolo propio, transporte intercambiable (memoria, ENet, retraso simulado), host autoritativo, predicción con corrección suavizada e interpolación a 100 ms, código de grupo y chat.
  - `game/` y `ui/`: escenario de pruebas, cámara isométrica (F9 cambia de proyección), cápsulas de colores con nombre, título, menú con código, chat, avisos y panel F3.
  - **Versión 0.1.0 publicada** en GitHub Releases.
- **Tests:** 143 tests de GUT en verde, incluida una red simulada con 1 host y 3 invitados (150 ms, variación y 5 % de pérdidas).

## Qué se probó
- Automático: suite completa en local y en GitHub Actions; el ejecutable exportado arranca sin errores.
- Pruebas de juego: **pendientes del usuario** (ver Siguiente paso).

## Problemas encontrados
- El decodificador de Godot escribe errores con paquetes truncados → los paquetes llevan una cabecera con marca y longitud.
- Las lambdas conectadas a señales dejaban objetos vivos (ciclos) → se usan métodos; el script de tests falla si hay fugas.
- 8 mensajes largos de chat no cabían a 1280×720 → cada mensaje muestra como máximo 3 líneas.

## Siguiente paso
- El usuario prueba la 0.1.0 (dos ventanas en su PC, con y sin retraso simulado, y si puede con un amigo por Tailscale).
- Después, tarea 18: prueba entre casas con WebRTC frente a ENet + Tailscale y decisión de la red.

---
← [[Sesiones]]
