---
tags: [plan, prueba]
estado: pendiente
actualizado: 2026-11-14
---

# Plan 1 — Prueba entre casas (versión 0.1.1)

Qué se prueba: si **WebRTC** (no hay que instalar nada) conecta entre casas distintas igual de bien que **ENet + Tailscale**. Regla de decisión en [[Plan 1 — Fundaciones y red (spec)#10. Prueba entre casas (fase 7)|spec §10]]: si WebRTC conecta en todas las casas probadas, se elige WebRTC; si no, ENet + VPN.

## Antes de empezar
- Todos descargan la **0.1.1** desde GitHub Releases y **descomprimen todo**, porque el `.dll` va junto al `.exe`.
- Para la parte de ENet, todos instalan **Tailscale** y el anfitrión comparte su red.

## Pasos (con cada amigo, o con todos a la vez)
1. **WebRTC:** abrid `ThalandorOnline.exe`. El anfitrión pulsa **Esc → Abrir grupo**, espera a que salga el código y lo comparte; los demás pulsan **Unirse a un amigo**.
2. Jugad 3-5 minutos: caminad, chocad con bloques, mandad mensajes. Con **F3** abierto, apuntad el ping y fijaos en si hay saltos.
3. Probad a que **otro haga de anfitrión**, porque el router de quien abre el grupo influye.
4. **ENet + Tailscale:** repetid los pasos 1-3 abriendo `Jugar con ENet y Tailscale.bat`. Pulsando F3 tiene que verse "ENet".

## Plantilla de resultados
Copiad una fila por cada combinación de anfitrión e invitado y red:

| Anfitrión → invitado | Red | ¿Conecta? | Ping (F3) | Tirones o saltos | Esfuerzo de preparación | Notas |
|---|---|---|---|---|---|---|
| Yo → Amigo 1 | WebRTC | sí / no (mensaje de error) | ~ ms | ninguno / pocos / muchos | ninguno / poco / mucho | |
| Yo → Amigo 1 | ENet + Tailscale | | | | | |

Si no conecta, apuntad **el mensaje exacto** que sale y quién era el anfitrión.

## Resultados
*(Pendiente.)*

---
← [[Planes]]
