---
tags: [decision]
id: D-008
fecha: 2026-11-14
estado: aceptada
---
# D-008 · Red con mensajes propios

## Contexto
El modelo host-autoritativo ([[02 Arquitectura técnica|§2.2]]) necesita predicción del personaje propio, reconciliación con el host e interpolación del resto, y tests de red simulada con 1 host y 3 invitados ([[12 Pruebas]]).

## Decisión
Godot se usa solo para enviar paquetes (`MultiplayerPeer`); los mensajes (entradas, instantáneas, eventos, chat) son propios. La conexión queda detrás de una interfaz `Transport` intercambiable (loopback, memoria, ENet, WebRTC).

## Por qué
Es el modelo probado en el prototipo 2D, da control total sobre predicción y reconciliación, permite tests de red en memoria con latencia y pérdida, y cambiar de ENet a WebRTC solo toca una pieza.

## Alternativas consideradas
- Nodos de sincronización de Godot (`MultiplayerSynchronizer`/`MultiplayerSpawner`): rápidos de empezar, pero sin predicción y difíciles de testear.
- Mixto (`@rpc` + mensajes propios): dos sistemas que mantener.

## Afecta a
- [[02 Arquitectura técnica]]
- Plan 1 — Fundaciones y red (spec)

---
← [[Índice de decisiones]]
