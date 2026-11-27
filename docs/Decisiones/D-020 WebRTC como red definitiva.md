---
tags: [decision]
id: D-020
fecha: 2026-11-27
estado: aceptada
---
# D-020 · WebRTC como red definitiva

## Contexto
Desde la 0.1.1 conviven WebRTC (código de grupo, sin instalar nada) y ENet + VPN (Tailscale). La regla del [[Plan 1 — Fundaciones y red (spec)|Plan 1]] era elegir WebRTC si conectaba en todas las casas probadas.

## Decisión
La [[Plan 1 — Prueba entre casas|prueba entre casas]] funcionó con WebRTC (confirmado por el usuario el 2026-11-27): **WebRTC es la red definitiva**. ENet se mantiene para las pruebas locales y como alternativa (`Jugar con ENet y Tailscale.bat`).

## Por qué
Conecta entre casas distintas sin que nadie instale una VPN ni abra puertos, con el servidor de enlace gratuito en Cloudflare Workers.

## Alternativas consideradas
- ENet + VPN como red principal: obliga a instalar Tailscale o ZeroTier.

## Afecta a
- [[02 Arquitectura técnica]]
- [[15 Decisiones abiertas]]

---
← [[Índice de decisiones]]
