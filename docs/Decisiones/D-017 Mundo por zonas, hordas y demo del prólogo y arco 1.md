---
tags: [decision]
id: D-017
fecha: 2026-11-22
estado: aceptada
---
# D-017 · Mundo por zonas, hordas y demo del prólogo y arco 1

## Contexto
El Plan 8 lleva el juego de la arena de pruebas a un mundo con historia. El guion del usuario (*Guión del juego de rol – Historia por misiones*) define el prólogo y los arcos. El GDD hablaba de cuatro zonas hasta el nivel 60 que el guion no recoge.

## Decisión
- **La demo:** el **prólogo y el arco 1** completos (misiones 1–14): aldea, bosque camino de la capital, capital y cripta bajo el palacio. Termina al salir de la capital rumbo al volcán, **hacia el nivel 50 o algo más** (sin tope), para que se vean las mejoras de clase.
- **Cada jugador vive su momento de la historia.** Los mapas no cambian con ella; lo que cambia es de cada jugador (PNJ, objetivos, luz).
- **La clase se elige antes del asalto**, y **no se juega en grupo hasta terminarlo** (el tutorial).
- **Se sube de nivel sobre todo matando hordas y en mazmorras.** Una misión da 1–2 niveles al completarse, más sus enemigos. Es norma del juego, no solo de la demo.
- **El nivel de los enemigos es fijo por zona**, y las **mazmorras dejan elegir la dificultad** al entrar.
- **Un mundo por zona en el anfitrión**, y las mazmorras como instancias del grupo.
- **Los mapas son datos de piezas** (`data/zones/`), revisable en el futuro.

## Por qué
- Cada uno en su momento: los amigos pueden jugar juntos aunque vayan por misiones distintas.
- Las hordas como vía principal de subida separan la experiencia de las misiones, que pueden ser pocas y cuidadas.
- Un mundo por zona permite muchas zonas sin simularlas todas y encaja con las mazmorras instanciadas.

## Alternativas consideradas
- **Mundo:** uno gigante con todas las zonas (simula todo; las instancias serían un apaño) o el grupo siempre en la misma zona (choca con cada uno en su momento).
- **Historia:** que mande el anfitrión, o un progreso compartido del grupo.
- **Nivel:** todo adaptado al jugador (se pierde la sensación de progreso) o todo fijo (harían falta más zonas para llegar al 50).
- **Mapas:** generados enteros por código, o hechos a mano en el editor de Godot.

## Afecta a
- [[06 Mundo]]
- [[07 Misiones]]
- [[04 Personajes y progresión]]
- [[14 Hoja de ruta]]
- Plan 8.1 — Zonas y mundo (spec)

---
← [[Índice de decisiones]]
