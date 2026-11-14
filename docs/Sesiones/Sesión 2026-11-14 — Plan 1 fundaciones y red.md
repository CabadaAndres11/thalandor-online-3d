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
- Añadida después de la 0.1.0: prueba con **dos procesos reales** del juego por ENet en el mismo PC (`tests/integration/test_two_processes.gd`). El anfitrión pulsa "Jugar" y "Abrir grupo"; otro proceso de Godot sin ventana se une con el código, ambos caminan y chatean, comparan posiciones (diferencia < 5 cm) y el invitado sale. Se repite con `--lag=150 --loss=5`. Ping medido: ~96 ms sin retraso y ~434 ms con él. 145 tests en verde.
- Pruebas de juego: **pendientes del usuario** (ver Siguiente paso).

## Problemas encontrados
- El decodificador de Godot escribe errores con paquetes truncados → los paquetes llevan una cabecera con marca y longitud.
- Las lambdas conectadas a señales dejaban objetos vivos (ciclos) → se usan métodos; el script de tests falla si hay fugas.
- 8 mensajes largos de chat no cabían a 1280×720 → cada mensaje muestra como máximo 3 líneas.

## Tarea 18 (spike de WebRTC), sin publicar todavía
- `webrtc-native` 1.2.2 en `addons/webrtc_native/`, solo Windows y Linux de 64 bits.
- Servidor de señalización en `tools/signaling/` (Cloudflare Workers + Durable Objects), probado en local con `wrangler dev`.
- `WebRtcTransport` en estrella (el anfitrión con cada invitado) y `WebSocketSignaling`. WebRTC es la red por defecto y `--net=enet` vuelve a ENet. Los códigos tienen el mismo formato que los de ENet.
- Prueba opcional con dos procesos por WebRTC (variable `THALANDOR_SIGNALING`): conecta, con un ping de ~34 ms frente a ~103 ms de ENet en el mismo PC.
- Paquete de la 0.1.1 preparado: zip con el `.dll` y `Jugar con ENet y Tailscale.bat`, notas de la versión e instrucciones en [[Plan 1 — Prueba entre casas]].
- Problemas: el servidor leía mal la ruta de la sala; los códigos aleatorios podían salirse del rango que acepta el juego (ahora son de 32 bits, como una IP). Ejecutar un solo archivo de tests avisa de recursos sin liberar al salir, incluso con el test de ENet de antes; con la suite completa no pasa.

## Siguiente paso
- El usuario crea una cuenta de Cloudflare e inicia sesión con `npx wrangler login` en `tools/signaling` (desde el PC).
- Claude despliega, pone la URL en `data/balance.json` (`signaling_url`, ahora apunta a `ws://127.0.0.1:8787`), sube los cambios y publica la 0.1.1.
- Prueba entre casas con la plantilla y decisión D-010.
- Pendientes: las pruebas de juego de la 0.1.0 y revisar por qué el ping de ENet en local sale de ~100 ms.

---
← [[Sesiones]]
